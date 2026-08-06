# Research: Customer Discovery

Phase 0 for [plan.md](plan.md). Each section is a decision, why it was taken, and what was rejected.

Most of §1, §3 and §4 are settled by measurement rather than by reasoning —
`docs/ops/spike-discovery-embeddings.md`, run 2026-08-06 against a live provider **before** this
specification was written. That ordering was deliberate and it earned its keep: the measurement
removed a mechanism the approved design depended on, and correcting two paragraphs is cheaper than
correcting twenty requirements.

## §1 — The embedding model, and the shape of the vector

**Decision: `gemini-embedding-2`, 768 dimensions, task-typed for retrieval.**

**Rationale.** Measured across four configurations on a 36-Meal, 20-query Egyptian Arabic corpus:

| Candidate | top-1 | mean P@5 | MRR |
|---|---|---|---|
| `gemini-embedding-001` @ 768 | 13/19 | 0.644 | 0.778 |
| `gemini-embedding-001` @ 1536 | 13/19 | 0.660 | 0.816 |
| `gemini-embedding-2` @ 768 | 14/19 | 0.660 | 0.838 |
| `gemini-embedding-2` @ 1536 | 15/19 | 0.670 | 0.864 |

`gemini-embedding-2` wins at every dimension measured, and its 768 beats the older model's 1536 — a
smaller vector from the better model beats a larger vector from the worse one.

**768 rather than 1536**: doubling moves MRR by 0.026 and top-1 by one query in nineteen, for twice
the storage and twice the index.

**Not 3072, which is the provider's default and would have been the accidental choice.** pgvector's
HNSW index refuses more than 2000 dimensions. A 3072-dimension column would work perfectly and be
unindexable — correct answers, sequential scans, no error anywhere. This is the failure mode this
repository keeps meeting and it is worth naming again: the wrong choice here produces no symptom
except slowness that arrives later, at scale, with no error to trace.

**Vectors must be normalised when the dimension is reduced.** The provider normalises at its native
3072 only; a truncated vector is not unit length, and cosine similarity computed on it is quietly
wrong. The spike normalises unconditionally and the implementation must too.

**Rejected**: `gemini-embedding-001` (loses at both dimensions measured); 3072 (unindexable);
untyped embedding calls (the provider distinguishes a document from a query and the distinction is
free).

## §2 — Where ranking happens

**Decision: inside Postgres, in a `SECURITY INVOKER` function, as the calling identity.**

**Rationale.** Ranking outside the database forces a choice between two failures. Either the ranker
holds a service-role key — which hands the read path a write capability and gives the AI Assistant
the database access Principle II exists to deny it — or the ranker re-implements which Meals a
caller may see, in a second place, in a second language, where it will drift from the policies.

The second failure is the dangerous one because it is silent. A Meal that should be invisible
becoming findable does not raise an error; it returns a row. And **every existing authorization test
would still pass**, because none of them go through a ranking path that does not yet exist.

So the vector comparison happens in a database function that runs as the caller. RLS decides what is
visible; the function ranks only what survived. Discovery gains no authority of its own — it is a
different way of asking the same question E2 already answered.

**Consequence for the index, and it is the trap in this section.** The visibility predicate and the
vector ordering must be arranged so the HNSW index is actually used. Written naively — filter after
ordering, or order inside a subquery the planner cannot push into — Postgres falls back to scanning
every Meal, computing every distance, and returning **the right answer slowly**. Nothing fails. The
query plan must be checked directly; correctness of results is not evidence.

**Rejected**: ranking in the Edge Function (needs either a service-role key or a duplicated
visibility model); ranking in the client (same, plus it would ship every Meal to every device);
`SECURITY DEFINER` (makes every Meal findable regardless of state, and no existing test would
notice).

## §3 — Exclusions, and why they cannot be a matter of meaning

**Decision: exclusions are SQL predicates over `meals.ingredients` and `meals.allergens`, derived
from a controlled vocabulary. They are never phrased to a model.**

**Rationale, measured rather than assumed.** The spike put `أكل من غير لحمة خالص` — "food with no
meat at all" — against a corpus containing both meat and meatless Meals. It returned **meat dishes**:
first correct answer at rank 6, precision@5 of **0.00**. This is a known property of embeddings
rather than a surprise — the vector for "no meat" sits near the vector for "meat" — and it is the
single worst result in the measurement.

What makes it Kafoo's problem rather than a curiosity is who asks. A Customer excluding a food is
usually doing so for dietary, religious or health reasons. Serving them the opposite is a betrayal,
not a poor result.

**How the exclusion is found in the sentence, without a model call on the critical path.** Egyptian
Arabic marks negation with a small closed set of phrases — `من غير`, `بدون`, `مش عايز`, `من غير ما
يكون فيه`. Those markers are matched deterministically. The noun after the marker is mapped against a
controlled vocabulary of excludable things, each with its Arabic surface forms, held in
`packages/domain/lib/exclusion.dart`.

**When the marker is recognised and the noun is not, Kafoo says it did not understand the exclusion
rather than ignoring it.** This is the whole safety property. An unparsed exclusion that is silently
dropped is the failure the spike found, arriving by a different route.

**The sharp edge, stated plainly because it is life-adjacent.** `meals.allergens` is frequently an
**AI estimate** — the column travels with `nutrition_source`, and the schema permits an empty array
when the AI Assistant was unreachable or the Cook declined it. So an exclusion filter can be wrong in
the direction that matters: a Meal containing peanuts whose estimated allergen list omitted them.

Two consequences, both required:

- **A Meal whose relevant field is empty is withheld, not shown.** FR-021. An unknown is treated as a
  possible yes. This will hide Meals that are perfectly fine, and that is the correct direction to be
  wrong in.
- **Kafoo states what it filtered on and never states that a Meal is safe.** The interface says the
  equivalent of "Meals whose ingredients do not list meat", never "safe for you". The distinction is
  the difference between a filter and a medical claim.

**Rejected**: putting the exclusion in the phrase sent for embedding (measured to invert); asking a
model to extract exclusions before searching (puts a generative call on the critical path, which
FR-011 and the 2026-08-06 latency ruling both forbid); separate exclusion controls in the interface
(a form, at the exact point Principle IV forbids one).

## §4 — Deciding that nothing matched

**Decision: the AI Assistant judges relevance after retrieval, on every search. There is no score
threshold, because no score threshold works.**

**Rationale.** Vector search never returns nothing — it returns everything, ordered. "Nothing
matched" therefore needs a rule, and two candidate rules were measured against a query the corpus
cannot answer (`سوشي ياباني`, Japanese sushi):

| Rule | No-match query | Worst genuine match | Gap |
|---|---|---|---|
| Absolute similarity | 0.6154 | 0.4319 | **−0.1835** |
| Relative margin against the corpus distribution | 2.355 | 1.691 | **−0.664** |

**Both come out backwards.** The query nothing answers scores *higher* than a query that is answered
correctly. A threshold tuned to reject sushi rejects `نفسي في حاجة خفيفة` first.

The reason is structural and a better model will not fix it: **within a corpus that is entirely
food, every food query is topically similar to everything in it.** Cosine similarity measures topic,
and the topic always matches.

**Two of the four candidates printed `separable`** — on gaps of +0.0037 and +0.0020, from a single
example. Noise wearing a verdict's clothes. They were caught only because the check prints the gap
beside the verdict, which is the general lesson worth carrying: a categorical verdict destroys the
information needed to disagree with it.

**Consequence, and it corrects the approved design.** The AI Assistant was to speak only when nothing
was found, and that was costed as rare. It is not rare; it is once per search. Latency is unaffected
because results are already on screen — that ordering was right and survives — but the cost model
changes and must be measured before this ships.

**Rejected**: a fixed similarity floor (measured backwards); a relative margin (measured backwards);
returning results with no judgement at all (leaves `SearchFailed` unemittable and puts a confident
wrong answer in front of a Customer, which is the failure this feature exists to prevent).

## §5 — A Customer's words leave Kafoo, and that needs saying out loud

**Decision: disclose before the first search, on both surfaces, the way E2 disclosed before a Meal
description left.**

**Rationale.** FR-029 forbids *recording* what a Customer searched for, and that requirement is
sound and unchanged. But a phrase has to reach a vendor to become a vector — that is what
understanding it means — and **not recording something is not the same as not sending it.**

This was raised by neither the specification nor the founder, which is why it is here rather than
assumed. E2 already set the precedent and the shape of the answer: FR-029 in that specification
discloses before a Meal photo and description leave, and allows refusal. A Customer is owed the same
courtesy about their own words, and a search phrase is more revealing of a person than a Meal
description is of a Cook — it is what someone wanted, at a moment, in their own voice.

**What this does not require**: consent recorded per search, an extra screen, or a new stored field.
It is a disclosure, not a permission gate, and Kafoo storing nothing is exactly what makes that
sufficient.

**Open, and routed to the founder rather than decided here**: whether a Customer may refuse and fall
back to browsing only. E2 allowed a Cook to refuse. The symmetry argues yes; the cost is a path that
must then work, and browsing already exists to be that path.

## §6 — The web surface's route to data

**Decision: the web surface reads Supabase directly with the publishable key, under the same RLS,
and calls the same Edge Functions. It gets no data path of its own.**

**Rationale.** ADR-0008 Amendment 1 commits to both front-ends being presentation with the database
as the arbiter. A second data path would be a second place for the visibility rules to be
approximated, which is §2's failure one level out.

The publishable key in a web bundle is fine by design and ADR-0008 says so. **The service-role key
must never reach any client bundle**, and `verify.sh` already fails on a tracked one — but a bundle
is not a tracked file, so this needs its own check rather than inheriting that one.

**Consequence for anonymous access**: it already works. `anyone reads a published meal` is granted
`TO anon, authenticated`, and E2's widening policy makes a kitchen with a Meal on offer readable to
the same. Discovery without an install needs no new policy, which is the part of ADR-0008 that was
genuinely free.

## §7 — Keeping vectors true to the text

**Decision: a Meal is embedded when it is published and re-embedded when its title or description
changes. Nothing else triggers it.**

**Rationale.** The vector is a representation of the words a Customer searches against. Price,
status, and photo changes do not alter those words and must not spend a model call. A Meal taken off
the menu keeps its vector — status is a visibility question answered by RLS, not by the index.

**A Meal published before this feature has no vector and is unfindable until it gets one.** The
backfill is mechanical and its shape is a `tasks.md` question, but the property to preserve is that
**a Meal with no vector is invisible to search and still visible to browsing** — so the failure mode
of an incomplete backfill is a Meal that is harder to find, never a Meal that is lost.

**Rejected**: embedding on every write (spends a model call on a price edit); a database trigger
calling the vendor (a vendor credential inside Postgres); embedding lazily at search time (makes the
first search for a Meal slow and unpredictable, and would need a write from the read path).

## §8 — Matching an area a Cook wrote against an area a Customer named

**Decision: normalise both sides, then compare exactly. A small alias table handles the areas that
genuinely have two names. No embedding, no fuzzy distance, no model call.**

**Rationale.** `kitchen_profiles.area` is free text a Cook wrote about their own kitchen. It is not
validated, standardised, or drawn from a list, and it never will be — it is one of exactly five
public details and adding structure to it is a change to that rule rather than a schema tweak.

Two Cooks writing the same neighbourhood will disagree on spelling in ways Arabic makes routine, and
none of them are ambiguities to a human reader:

| Written | Also written | Why |
|---|---|---|
| `الدقي` | `الدقى` | final `ي` against `ى`, indistinguishable in speech |
| `المهندسين` | `مهندسين` | the definite article dropped |
| `المُهَنْدِسِين` | `المهندسين` | diacritics, which most typing omits |
| `العجوزه` | `العجوزة` | `ة` against `ه`, ordinary in casual typing |
| `إمبابة` | `امبابة` | hamza forms |

**Normalisation is a closed, deterministic transformation**: unify the alef forms, `ة` to `ه`, `ى` to
`ي`, strip diacritics and tatweel, drop a leading definite article, collapse whitespace, fold case.

**It lives in SQL and nowhere else — `normalise_area(text)`, `IMMUTABLE`.** Writing it in Dart for
the Customer's side and SQL for the Cook's side would be one rule in two languages, and it would
drift. That is exactly the failure ADR-0008 Amendment 1 names as the cost of a second front-end,
arriving *inside a single feature* rather than across two surfaces — which makes it worth catching
here, because the same mistake will be available every time E3's two clients want the same
behaviour. The rule for this repository is the one the amendment already states: **the database is
the arbiter, and a rule restated in a client is a convenience that may be wrong without being
dangerous.**

A Cook's stored area is never rewritten. Matching uses an **expression index** on
`normalise_area(area)`, so no column is added to `kitchen_profiles` and its public face stays at
exactly five details.

**Ceiling, written down because it is silent.** Changing `normalise_area` does not recompute the
expression index — Postgres keeps the old values and the index quietly disagrees with the function.
Any migration touching the function must `REINDEX` in the same file. This is the same shape as
everything else that has gone wrong in this repository: correct-looking results, no error, a wrong
answer that arrives later.

**The alias list is folded into the same function rather than into a table.** A table would be a new
table, which needs RLS in the same migration by non-negotiable rule, for a handful of rows nobody
writes at runtime. A list that changes through a reviewed migration is also better than one that
changes through an `INSERT` — and the `REINDEX` obligation above then applies to alias changes too,
which is the correct coupling rather than an accident.

**What this deliberately does not do, and the boundary matters.** It does not merge two genuinely
different neighbourhoods. FR-022a governs how a name is *written*; a Customer asking for one place
must not be handed another. Fuzzy or edit-distance matching would cross that line — `المعادي` and
`المعادى` are one area, but a tolerance loose enough to also catch a real typo is loose enough to
match a different place, and the failure would be invisible.

**Rejected**: embedding the area and matching by similarity (would make "Maadi" match "Zamalek",
because both are areas — this is §4's problem restated, where everything in a category resembles
everything else); edit-distance matching (crosses the boundary above); a canonical list of Egyptian
neighbourhoods (turns a Cook's own words into a dropdown, which is the sixth-public-detail change
this feature is not permitted to make); requiring Cooks to pick from a list (same, one step earlier).

**Known ceiling, stated rather than discovered later**: a Cook who writes a landmark instead of a
neighbourhood — "behind the mosque in Faisal" — is reachable by nobody naming an area. FR-024 makes
that visible rather than silent, because a Customer is told their area is empty and offered the areas
that are not. The fix is a better prompt when a Cook writes their area, and that is E2's screen
rather than this feature's.
