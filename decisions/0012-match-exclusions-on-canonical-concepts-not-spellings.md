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
| **A. Keep strings, add prefix-aware matching** | Small — one predicate change plus its measurement | Fixes over-exclusion and nothing else. `سمنة` vs `لبن` stays unreachable, and every synonym is a manual list entry forever | Easy |
| **B. Replace strings with concepts** | Medium — taxonomy, schema, classifier, backfill | **A missed concept is silent under-exclusion.** The classifier does not tag a dish, the filter passes it, and someone with a nut allergy sees it with nothing to warn anyone | Hard once Meals are published against it |
| **C. Concepts UNION strings** (chosen) | Medium — as B, plus keeping the string path alive | Strictly more exclusion than today. Costs some over-exclusion until the string floor can be narrowed | Moderate — either half can be removed later on evidence |
| **D. Ask a model at search time** | Low to build | Rejected on measurement, not taste: precision@5 of 0.00, plus a model on the critical path FR-011 forbids and a per-search cost | n/a |

## Decision

**Kafoo matches exclusions on canonical concepts, computed at publish, approved by the Cook, and
matched deterministically in the database — in union with the existing string predicate, never
instead of it.**

### The model has three levels

```
what somebody wrote        canonical concept        category
─────────────────────      ─────────────────        ────────
مايونيز / mayonnaise  →    mayonnaise          →    EGG
طحينة / tahini        →    tahini              →    SESAME
جبنة رومي / cheese     →    cheese              →    DAIRY
عين جمل / walnut       →    walnut              →    TREE_NUT
فول سوداني / peanut    →    peanut              →    PEANUT
```

The middle level is what makes mayonnaise tractable. Today it is an unanswerable question, because
the vocabulary has one level and mayonnaise either *is* an egg word or is not. With a concept
between, mayonnaise is itself and rolls up to egg, and tahini and cheese need no special case.

### Two axes, because four of today's twelve exclusions are not allergens

An allergen taxonomy alone has no home for `meat`, `chicken`, `onion` or `garlic` — which are
religious rules, dietary choices and intolerances, and are almost certainly the most-used exclusions
in this market. Adopting an allergen framework as the only axis would silently remove the ability to
say "no meat", which is the phrase this entire feature was built around.

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

| Step | Where | Who approves |
|---|---|---|
| Cook's words → concepts and categories | `analyze-meal`, at publish | **The Cook**, as they already approve allergens |
| Customer's phrase → category ids | `discover`, deterministically against the closed vocabulary | Nobody — it is a lookup, not a generation |
| Categories → which Meals are withheld | `search_meals`, in SQL | Nobody — deterministic set overlap |

**No model runs at search time, and no model decides whether a Meal is safe.** The AI translates
language into an id. The database decides what contains it.

### Union, not replacement — the direction is what decides it

A Meal is withheld if **its categories match, or its text matches**. The two mechanisms fail in
opposite directions: a missed concept is silent under-exclusion, a missed string is over-exclusion.
Union is strictly more exclusion than today, which is the safe direction, and it makes the string
path the floor that catches what the classifier missed.

**The interface's wording does not change.** It says what was filtered on, that it rests on what
Cooks wrote and an AI estimate, and that it does not mean the rest are free of that food. Adopting
regulatory category names must not make the screen look like an allergen declaration: this data is
an AI extraction from a text box in a home kitchen, with no label, no verification and no control
over a shared fryer. **Excluding `PORK` is not a halal claim**, and Kafoo must not let it read as
one.

## Open questions

These are deliberately unresolved. Each needs an answer before the part of the work it governs, and
none of them blocks drafting the taxonomy.

1. **What is the classifier's recall?** Unmeasured. How often does `analyze-meal` produce the right
   category for a dish whose ingredients plainly contain the food? **This gates everything else.**
   If recall is poor, the union carries the feature and concepts are an optimisation; if it is
   strong, the string floor can eventually narrow to Meals that have no concepts yet. Measure before
   building, on the existing corpus and demo Meals.
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
6. **When may the string floor narrow?** Stated as a condition, not a date: at what measured recall
   does the string path stop applying to Meals that carry approved concepts.
7. **The five vocabulary calls still open from WP-017** — `مايونيز`, `تونة`, `جوز`,
   `كندوز`/`ضاني`/`مبحبش`, and the `مبكلش` marker — become concept-level entries under this model
   rather than surface forms. They are cheaper to decide here than there, and `جوز` in particular
   becomes clearer: it can be a concept that maps to `TREE_NUT` only when disambiguated, rather than
   a spelling that also matches a husband and a pair of pigeons.

## Consequences

**Accepted costs.**

The vocabulary stops being a flat list and becomes a taxonomy with a mapping table — more to
maintain, and a wrong mapping is now wrong for every Meal at once rather than for one word. Publish
gains a step, and the Cook has one more thing to approve. Two code paths must both stay correct
until the union can be narrowed, which is more surface than either alone. And a regulatory-looking
taxonomy needs the interface actively defended against the impression that Kafoo certifies anything.

**What this forecloses.**

Removing the string path becomes a decision requiring evidence, not a cleanup — the union is the
safety property and deleting half of it silently is the failure mode this ADR exists to prevent.
Adding a category after Meals are published against the model costs a backfill and a re-approval,
which is exactly why `PORK` and `ALCOHOL` are in now.

**Revisit trigger.** If the measured classifier recall on question 1 is below 90% on the corpus,
this ADR is wrong in its sequencing — concepts would then be a ranking aid rather than a filter, and
the string path would have to remain primary rather than become a floor.

## Notes for Claude Code

The AI translates language into a category id; the database decides which Meals contain it. No model
call sits on the search path, and no model decides whether a Meal is safe. A Meal is withheld if its
categories match **or** its text matches — never one alone. Concepts are computed at publish and
approved by the Cook, exactly as allergens are today.
