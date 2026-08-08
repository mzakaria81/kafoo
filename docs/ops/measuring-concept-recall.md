# Does the AI name the food a Meal contains?

**Measured 2026-08-08. Recall 100%: 75 of 75.** Model `gemini-3.1-flash-lite`, fast tier, 36 live
calls at the founder's explicit approval.

This is ADR-0012's open question 1, the one that gates the rest of it.

## Why the number decides something

ADR-0012 says the AI proposes concepts, the Cook confirms or corrects, and the database filters on
what was confirmed. **That only describes the product if the AI is actually proposing.** If it names
the food in nine dishes out of ten, the Cook is checking. If it names it in six, the Cook is doing
the extraction by hand with a model guessing beside them — a different product, and one nobody
agreed to build.

The ADR's revisit trigger was set at 90%.

## What was measured, and what was not

**Measured:** given a Meal whose own text states a food, does `analyze-meal`'s extracted
`ingredients[] + allergens[]` contain a word for it?

**Not measured:** whether a word maps to the right concept and category. There is no taxonomy yet,
and inventing one to grade against would have graded the taxonomy rather than the model. That half
is a lookup, and a lookup is testable without spending anything.

Ground truth is `docs/ops/concept-recall-truth.json`: all 36 corpus Meals, hand-labelled against
ADR-0012's two axes, **from each Meal's own words only**. A dish that certainly contains something
its text never mentions is not labelled — أم علي is made with pastry and كريب with egg batter, and
neither description says so. Scoring those would have graded the model on knowledge it was never
given.

The recogniser that turns an extracted word into a category is deliberately generous, in Arabic and
English. It exists to recognise the model's answer, not to be Kafoo's vocabulary: a thin list would
report its own gaps as the model's misses. There were no misses to inspect.

## Result

| | |
|---|---|
| Meals graded | 36 of 36 |
| Category instances | 75 |
| **Recall** | **100% (75/75)** |

| Category | Recall | |
|---|---|---|
| MILK | 100% | 15/15 |
| GLUTEN_CEREAL | 100% | 14/14 |
| WHEAT | 100% | 14/14 |
| MEAT | 100% | 9/9 |
| POULTRY | 100% | 7/7 |
| GARLIC | 100% | 5/5 |
| TREE_NUT | 100% | 4/4 |
| EGG · SESAME | 100% | 2/2 each |
| CRUSTACEAN · FISH · ONION | 100% | 1/1 each |

Per category rather than as an average, because an average hides the one that matters: a model that
names dairy every time and nuts never has a fine overall number and a nut-allergy problem.

Ten categories were never exercised — `PEANUT`, `SOY`, `MOLLUSC`, `MUSTARD`, `CELERY`, `LUPIN`,
`SULPHITES`, `PORK`, `ALCOHOL`. **Nothing is known about recall on any of them**, and that is
ADR-0012's open question 3 arriving from the other side: a category no Meal ever declares is
indistinguishable from a filter that works.

## What this does not say

**It is an upper bound, not an estimate.** The corpus descriptions were written to exercise
retrieval, so they already read as ingredient lists — `عدس ومكرونة وأرز وحمص وصلصة وشطة وتقلية بصل`
is most of the extraction done in advance. Real Cook speech is looser and names less, and the number
against real speech will be lower. How much lower is unmeasured, and the honest way to find out is
to measure it against what Cooks actually say once there are Cooks.

**One corpus, one model, one day.** 75 instances is enough to rule out a broken classifier and not
enough to distinguish 100% from 97%.

## The one thing that did go wrong

**Two of the 36 first replies failed schema validation** — `warak_enab` and `kebda`. Both passed on
a bare re-run with no change to the request, so they are flaky rather than hard failures, and both
Meals then scored full marks.

This script takes the first reply and does not retry. **Production does**: `callProviderWithRetry`
in `analyze-meal` retries once and feeds the validation errors back as user content. So the rate a
Cook would meet is lower than 2-in-36, and it is not zero, and nobody has measured it.

**That is now a product question rather than an engineering detail**, because the founder decided on
2026-08-08 that publish is BLOCKED until the Cook confirms the concepts. A reply that never
validates is a Cook who cannot publish their Meal. Whatever the real rate is, the Cook needs a way
through that is not "try again later" — see ADR-0012's open question 7.

## Reproducing it

```bash
deno run --allow-env --allow-read --allow-write --allow-net scripts/measure-concept-recall.ts
```

Costs money — 36 fast-tier calls. It resumes, so a rate limit does not mean paying for the first
thirty again. Results land in `docs/ops/concept-recall-result.json`, one row per Meal with what was
extracted, so any figure above can be checked rather than believed.
