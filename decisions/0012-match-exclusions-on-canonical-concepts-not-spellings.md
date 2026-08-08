# ADR-0012 — Match exclusions on canonical concepts, not on spellings

**Status:** Proposed
**Date:** 2026-08-07
**Decider:** Founder

## Context

A Customer says what they cannot eat. Kafoo has to decide which Meals to withhold. Today that
decision is made by comparing **strings**: the Customer's word is resolved against a closed list of
surface forms, and those forms are matched as substrings against what the Cook typed into
`meals.ingredients` and `meals.allergens`.

That design has been measured twice this week and it fails in both directions.

**It under-excludes when the two sides spell a word differently.** 13 of 156 plausible Cook
spellings reached no form of their own exclusion, and a single tatweel — one invisible character —
defeated all 93 forms at once. Folding closed that class (`public.fold_arabic` and its two
siblings), and folding cannot close the next one: `سمنة` and `لبن` are the same allergen and share
no letters.

**It over-excludes when one food's name sits inside another's.** `بيض` (eggs) is a substring of
`أبيض` (white). Measured against ordinary ingredient text, a Customer excluding eggs currently loses
white pepper, white rice, white sauce, white bread, white onion and white cheese. `ملبن` (Turkish
delight) reads as dairy; `خبز لبناني` (Lebanese bread) reads as dairy.

**Measured properly on 2026-08-08, and it changed which option is worth taking.** Against 70 pieces
of Cook-side text — what `analyze-meal` extracted in every pinned golden, what `seed.sql` holds, and
the multi-word entries a Cook produces by editing the model's list — the vocabulary matches 44
times, of which **7 are wrong**. All seven are `أبيض` or `ملبن`.

Two things fell out of that measurement, both in `exclusion_over_exclusion_test.dart`:

- **Matching at a word boundary on BOTH sides would break the feature.** It removes 14 more matches
  and 11 of them are correct — `جبنة`, `سمنة`, `لبنة`, `لحمة`, `كبدة`, `بيضة مسلوقة`. Arabic glues
  its feminine and plural endings onto the back of a noun, so a right-hand boundary is silent
  under-exclusion dressed as precision.
- **A LEFT-hand boundary does not fix the case that motivated any of this.** `جبنة بيضاء` — white
  cheese — *begins* the word `بيضاء` with `بيض`, so it survives. So does `خبز لبناني`. The masculine
  adjective `أبيض` is reachable by a letter rule; the feminine `بيضاء` and the nisba `لبناني` are
  not.

So the string path cannot be repaired by looking harder at letters, which is the argument this ADR
was already making from a different direction.

**And the meaning is already computed on both sides, then discarded.** This is the finding that
makes the change small rather than speculative:

- `discover/parse.ts` resolves a Customer's phrase to `{ kind: 'found', id: 'egg', terms: [...] }`.
  It knows the Customer means eggs. `index.ts` then sends `terms` to the database and drops `id` —
  except into the response, where the interface uses it to say *what* was filtered. **The concept is
  trusted to tell a Customer what happened and not trusted to make it happen.**
- `analyze-meal` reads what the Cook wrote and returns structured `ingredients[]` and `allergens[]`,
  which the Cook approves; `nutrition_source` flips from `ai` to `cook` the moment they edit it, and
  a database trigger enforces that so a client cannot claim it. An AI interpretation step with human
  approval already exists at publish. It simply emits free text rather than a controlled vocabulary.

So both ends already speak in concepts and meet in the middle as strings.

**What is not in question.** An exclusion is never handed to a model at search time. Measured
2026-08-06: asking for food with no meat *by meaning* returned meat dishes, first correct answer at
rank 6, precision@5 of 0.00. The representation of "no meat" sits beside the representation of
"meat". That measurement is why the current design is a database predicate, and nothing in this ADR
moves it.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| **A. Keep strings, add prefix-aware matching** | Small — one predicate change plus its measurement | **Measured 2026-08-08: fixes 7 of the 44 matches and misses `جبنة بيضاء`, the case it was proposed for.** Buys that with a closed list of Arabic clitics, where anything unlisted is silent under-exclusion. `سمنة` vs `لبن` stays unreachable, and every synonym is a manual list entry forever | Easy |
| **B. Replace strings with concepts outright** | Medium — taxonomy, schema, classifier, backfill | **A missing concept is silent under-exclusion.** The classifier does not tag a dish, the Cook confirms a list that looks fine, the filter passes it, and someone with a nut allergy sees it with nothing to warn anyone | Hard once Meals are published against it |
| **C. Concepts decide; strings catch the Meals that have none** (chosen) | Medium — as B, plus the string path staying alive until it is unreachable | A Meal with confirmed concepts is filtered on concepts alone. A Meal with none falls back to today's predicate, which is FR-021's rule — an unknown is a possible yes | Moderate — the fallback retires itself when every published Meal carries concepts |
| **D. Ask a model at search time** | Low to build | Rejected on measurement, not taste: precision@5 of 0.00, plus a model on the critical path FR-011 forbids and a per-search cost | n/a |

## Decision

**Kafoo matches exclusions on canonical concepts. The concepts are extracted at publish, confirmed
by the Cook, and compared deterministically in the database. Language is used to *identify* a
concept and never to *decide* whether a Meal is withheld.**

### Three levels, and the top one is not part of the filter

```
                           ALLERGEN / DIETARY
                                  │
                        ┌─────────┴─────────┐
                       EGG                DAIRY          ← category
                        │                   │
                  ┌─────┴─────┐       ┌─────┴─────┐
                 egg      mayonnaise  milk      cheese    ← concept
                  │           │        │          │
             بيض, بيضة,   مايونيز,    لبن,      جبنة,     ← alias
             بيض مسلوق,  mayonnaise  حليب,    جبنة رومي,
                eggs                  milk     cheese
```

**An alias is an input, not a rule.** Aliases exist so that `مايونيز` typed by a Cook and
`mayonnaise` typed by anyone else both arrive at the concept `MAYONNAISE`. The moment that
identification is made, **string matching stops entirely** and everything downstream compares
concept ids and category ids. That single rule removes the whole class this ADR opened with:
`فلفل أبيض` is not a near-miss for eggs, it is a phrase that was never identified as `EGG`, and
`جبنة بيضاء` is `CHEESE`, full stop.

The middle level is what makes mayonnaise tractable. Today it is an unanswerable question, because
the vocabulary has one level and mayonnaise either *is* an egg word or is not. With a concept
between, mayonnaise is itself and rolls up to egg, and tahini and cheese need no special case.

**Aliases are data, not code.** They live in a table keyed by concept and locale. Adding a synonym
is an INSERT; it must never require touching the extraction step, the search predicate, or a Dart
or TypeScript file. This is the property that makes the design worth the migration — the current
vocabulary costs three files in lockstep for one new word, which is why they drifted.

### Two axes, kept separate — founder's decision, 2026-08-08

An allergen taxonomy alone has no home for `meat`, `chicken`, `onion` or `garlic` — which are
religious rules, dietary choices and intolerances, and are almost certainly the most-used exclusions
in this market. Adopting an allergen framework as the only axis would silently remove the ability to
say "no meat", which is the phrase this entire feature was built around.

**They are two axes and not one list, deliberately.** An allergen is a medical fact about a food; a
dietary exclusion is a choice, a rule or an intolerance. They are collected the same way and they
mean different things to a Customer, so merging them would let the interface imply that avoiding
pork is a safety claim and that avoiding peanuts is a preference. Both are wrong and the second one
is dangerous.

**Allergen axis** — the EU 14 as the baseline, which subsumes the FDA nine:

`MILK` · `EGG` · `PEANUT` · `TREE_NUT` · `SESAME` · `GLUTEN_CEREAL` · `WHEAT` · `SOY` · `FISH` ·
`CRUSTACEAN` · `MOLLUSC` · `MUSTARD` · `CELERY` · `LUPIN` · `SULPHITES`

**Dietary axis** — not allergens, and not optional:

`MEAT` · `PORK` · `POULTRY` · `ALCOHOL` · `ONION` · `GARLIC`

**`PORK` and `ALCOHOL` are in by the founder's decision, 2026-08-07.** Their base rate in Egyptian
home cooking is near zero. That is the argument for including them now rather than against it: the
cost is two rows in a taxonomy today, and the cost of adding an axis member after Meals are
published against the model is a backfill and a re-approval. "Near zero" and "cannot be expressed"
are different things, and this is the moment the model is being designed.

### Three separations that are load-bearing

**`PEANUT` never merges into `TREE_NUT`.** A peanut is not a nut and someone allergic to one is
frequently not allergic to the other. Kafoo's vocabulary already separates them for this reason; the
taxonomy formalises it.

**`FISH`, `CRUSTACEAN` and `MOLLUSC` stay three.** Today Kafoo has one `shellfish` entry merging
prawns, crab, squid, mussels and clams, with a comment admitting it over-excludes deliberately.
Splitting them is a real improvement: a mollusc allergy and a crustacean allergy are different
conditions, and today someone with either loses both.

**`WHEAT` and `GLUTEN_CEREAL` stay two.** The regulatory definition is *cereals containing gluten* —
wheat, rye, barley, oats — and a wheat allergy is not coeliac disease. Kafoo's current gluten entry
already includes `شوفان` (oats) deliberately, for cross-contamination.

### Customer-facing vocabulary is simpler than the internal one, and fans out

A Customer saying `مكسرات` or "nuts" may mean tree nuts, peanuts, or both. Someone saying "seafood"
means fish, crustaceans and molluscs together. **A customer term therefore resolves to a SET of
category ids, not one**, and where it is ambiguous it resolves wide — because wide shows less food,
and narrow shows the food they asked to avoid.

### Where each step runs

| Step | Where | Who decides |
|---|---|---|
| Cook's words → concepts and categories | `analyze-meal`, at publish | **The AI proposes. The Cook confirms or corrects.** |
| Customer's phrase → category ids | `discover`, by alias lookup against the closed vocabulary | Nobody — it is a lookup, not a generation |
| Categories → which Meals are withheld | `search_meals`, in SQL | Nobody — deterministic set overlap |

**The AI is the interpreter. The Cook is the authority on their Meal. The database is the enforcer.**
No model runs at search time, and no model decides whether a Meal is safe.

### The uncertainty is shown, never absorbed

**Non-negotiable.** When the AI identifies a concept, the Cook sees what it identified and what that
implies, in those terms:

```
AI identified:  Cheese
Allergen:       Dairy
                [ Confirm ]   [ Correct ]
```

Two rules follow from that, and the second is the one with teeth:

**A low-confidence identification is never silently resolved.** If the model cannot place
`جبنة بيضاء` on a concept, it says so and asks, rather than picking the nearest one and presenting
the result as though it were known.

**AN UNCONFIRMED CONCEPT FILTERS NOTHING.** A concept the Cook has not confirmed is a suggestion,
and Kafoo must not tell a Customer that a Meal was withheld — or kept — on the strength of one. This
is Principle II applied to a field nobody would think of as a write: the AI is proposing a fact
about somebody else's food, and only the Cook can make it true.

**PUBLISH IS BLOCKED UNTIL THE COOK CONFIRMS — founder's decision, 2026-08-08.** A Meal cannot go on
offer carrying concepts nobody has checked. The alternative considered and rejected was letting such
a Meal publish and fall to the string predicate, which is quieter and wrong: it puts food in front
of Customers filtered by a mechanism this ADR exists to replace, with no one having looked.

Two things follow, and both are real costs rather than details:

- **A Cook must always be able to get through.** Correcting must be enough on its own — a Cook who
  disagrees with every proposed concept, or whose Meal has none, still publishes. Blocking on
  confirmation must never become blocking on agreement.
- **A model that will not answer must not trap a Meal.** Measured 2026-08-08, 2 of 36 first replies
  failed schema validation and both passed on a bare retry; `analyze-meal` already retries once. The
  rate a Cook would meet is lower than that and is not zero, so the flow needs a route through when
  the AI proposes nothing at all — see open question 7.

### Concepts decide; the string predicate catches the Meals that have none

**A Meal with confirmed concepts is filtered on concepts alone. Its text is never matched again.**
That is the authoritative path and the reason for the whole change.

**A Meal with no confirmed concepts falls back to today's string predicate.** This is not a second
opinion on a Meal that has concepts — it never runs against one. It exists because the failure being
guarded is *absence*: the classifier tags nothing, the Cook confirms a list that looks complete, and
a Meal that plainly contains eggs carries no `EGG`. With no fallback, nothing catches that and the
Customer is served the food they refused, silently.

That is the same rule FR-021 already states — an unknown is a possible yes — applied one level up.
**And it retires itself.** When every published Meal carries confirmed concepts the fallback is
reachable by nothing, and it can then be deleted on evidence rather than on hope. Deleting it before
that point is the failure mode this section exists to prevent.

### Scope: fourteen categories, six dietary, and concepts only where something needs one

**This must not become a food ontology before launch.** The two axes are fixed lists and are the
whole of the taxonomy. The concept level is populated *on demand*: a concept earns a row when a
Customer's word or a Cook's ingredient actually needs it. `MAYONNAISE` earns one because it is an
egg product nobody would guess from its name; `SUMAC` does not, because nothing excludes it.

The architecture is what has to be finished, not the vocabulary. Adding a concept or an alias later
must be data — a row — and must not change the extraction step, the search predicate or any code.

**The interface's wording does not change.** It says what was filtered on, that it rests on what
Cooks wrote and an AI estimate, and that it does not mean the rest are free of that food. Adopting
regulatory category names must not make the screen look like an allergen declaration: this data is
an AI extraction from a text box in a home kitchen, with no label, no verification and no control
over a shared fryer. **Excluding `PORK` is not a halal claim**, and Kafoo must not let it read as
one.

## Open questions

These are deliberately unresolved. Each needs an answer before the part of the work it governs, and
none of them blocks drafting the taxonomy.

1. ~~**What is the classifier's recall?**~~ **ANSWERED 2026-08-08: 100%, 75 of 75.** Every Meal in
   the corpus whose own text states a food had that food named in `analyze-meal`'s extraction, across
   twelve categories. `docs/ops/measuring-concept-recall.md` has the method and the limits, and the
   two that matter are: it is an **upper bound**, because the corpus descriptions already read as
   ingredient lists and real Cook speech names less; and **ten categories were never exercised** —
   `PEANUT`, `SOY`, `MOLLUSC`, `MUSTARD`, `CELERY`, `LUPIN`, `SULPHITES`, `PORK`, `ALCOHOL` — so
   nothing at all is known about recall on any of them.

   The revisit trigger was 90%. It is not tripped, so the sequencing in this ADR stands: the AI
   proposes and the Cook checks, rather than the Cook extracting with a model guessing beside them.
2. **How do already-published Meals get concepts?** A backfill classification is AI-derived data
   written without a Cook approving it — the same shape as ADR-0011's exception and it needs the
   same explicit decision. The alternative is that concepts appear only as Cooks next edit a Meal,
   which is slower and needs no exception. Not decided here.
3. **What does an empty category do?** If `SOY` exists and no Egyptian home cook ever tags it, a
   Customer excluding soy gets the whole marketplace back under a message saying it was filtered —
   a filter that fires on nothing is indistinguishable from one that works. The same applies to
   `PORK`, `ALCOHOL`, `MUSTARD`, `CELERY`, `LUPIN` and `SULPHITES` on day one. The interface needs
   an answer ("no Meal on Kafoo declares this") rather than silence.
4. **Cross-contamination has no home in this model.** A shared fryer is a real allergen path that no
   ingredient list captures. Not to be built now; the question is whether the schema leaves room, or
   whether every category stays a hard boolean and this gets bolted on badly later.
5. **Which customer words fan out to which sets?** Specifically whether `مكسرات` includes `PEANUT`,
   and whether a Customer can ask for the narrow category at all. Needs a native Cairene ear.
6. **When may the fallback be deleted?** Stated as a condition, not a date. The fallback stops
   running against a Meal the moment that Meal has confirmed concepts, so the question is only when
   the code itself goes: when no published Meal lacks them, and it stays that way through a full
   publish cycle.
7. **How does a Cook get past a step that will not complete?** The blocking decision is taken —
   publish waits for confirmation — so the remaining question is the way out. A Meal whose analysis
   never validates, a Cook who rejects every proposed concept, a provider that is down: each is a
   Cook who cannot sell their food today. Retrying is not an answer a person can act on. Whether
   they may confirm an empty set, pick concepts by hand, or publish under an explicit "no allergen
   information" state is undecided, and it is the difference between a safety step and a wall.
8. **The five vocabulary calls still open from WP-017** — `مايونيز`, `تونة`, `جوز`,
   `كندوز`/`ضاني`/`مبحبش`, and the `مبكلش` marker — become concept-level entries under this model
   rather than surface forms. They are cheaper to decide here than there, and `جوز` in particular
   becomes clearer: it can be a concept that maps to `TREE_NUT` only when disambiguated, rather than
   a spelling that also matches a husband and a pair of pigeons.

## Consequences

**Accepted costs.**

The vocabulary stops being a flat list and becomes a taxonomy with a mapping table — more to
maintain, and a wrong mapping is now wrong for every Meal at once rather than for one word. **The
Cook is asked to confirm something at publish**, which is a real cost in a flow built to be fast and
conversational, and it is accepted because the alternative is Kafoo asserting a fact about somebody
else's food. Two paths must both stay correct until no Meal needs the fallback. And a
regulatory-looking taxonomy needs the interface actively defended against the impression that Kafoo
certifies anything.

**What this forecloses.**

Deleting the fallback becomes a decision requiring evidence, not a cleanup — it is what stands
between a classifier's silence and a Customer being served the food they refused. Adding a category
after Meals are published against the model costs a backfill and a re-confirmation, which is exactly
why `PORK` and `ALCOHOL` are in now.

**Revisit trigger — tested 2026-08-08 and not tripped.** The trigger was: recall below 90% means
this ADR is wrong in its sequencing, because concepts would then be something the Cook writes with
the AI guessing beside them rather than something the AI proposes and the Cook checks. Measured
recall is 100% on 75 category instances. **The trigger stands for the next measurement rather than
being retired** — the figure is an upper bound taken on descriptions that read like ingredient
lists, and the number to re-test it against is recall on what Cooks actually say.

## Notes for Claude Code

The AI is the interpreter, the Cook is the authority, the database is the enforcer. Aliases exist to
identify a concept and are never consulted again afterwards — once a Meal has confirmed concepts,
its text is not matched. A Meal with no confirmed concepts falls back to the string predicate, and
that fallback is deleted only when nothing reaches it. An unconfirmed concept filters nothing. No
model call sits on the search path, and no model decides whether a Meal is safe.
