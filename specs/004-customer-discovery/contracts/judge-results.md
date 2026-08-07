# Contract — `judge-results` Edge Function

Decides whether the Meals Kafoo found honestly answer what the Customer asked for.

**Off the critical path by construction.** The Customer has their results before this is called. It
holds no service-role key and writes nothing.

## Why it exists at all

Vector search never returns nothing — it returns everything, ordered. Something has to decide that
nothing matched, and `research.md` §4 measured that **no score can**: a query the corpus cannot
answer scored *higher* than a query answered correctly, on both an absolute and a relative rule. The
judgement is the replacement for a threshold that does not exist.

## Shape

**Request**: what the Customer asked for, and the Meals that came back.

**Response**: whether any of them answers the request; and when none does, which of the Meals on
offer to name instead.

## Rules this function must not break

- **It never changes the results.** It cannot reorder, filter, add, or remove a Meal. It says
  something *about* a set it was handed. A judgement that edits results is ranking wearing a
  disguise, and it would put a model back on the path FR-011 keeps it off.
- **It may only name Meals it was given.** Naming a Meal that is not on offer is FR-015 broken, and
  the model has no way to check availability — so it is never given the opportunity.
- **It never claims popularity.** FR-016. There are no order counts and no Reviews. A model will
  reach for "popular" unprompted; the prompt must forbid it and a golden case must prove it does.
- **It never claims proximity or distance.** FR-017. Kafoo has no location for any Customer and no
  notion of where an area is.
- **It never invents a Meal.** The E2 finding stands: replaying `meal-description` against a real
  model caught it stating things the Cook never said, and three golden cases had marked all of it
  PASS. The same failure here names food nobody is cooking.
- **The prompt is a file** — `prompts/discovery-judgement.md` — never a string literal. The call goes
  through the provider registry.

## Failure behaviour

| Failure | Response |
|---|---|
| The provider is unreachable, slow, or malformed | **Nothing happens.** Results stay exactly as they are. The Customer loses a sentence, never their results. |
| It judges that nothing matches when something plainly does | A false `SearchFailed`. The cheaper direction to be wrong in, and the golden cases must bound it. |
| It judges that something matches when nothing does | The failure this whole function exists to prevent — a confident wrong answer in front of a Customer. |

**The last row is why the golden cases are asymmetric.** A judgement that wrongly says "nothing
here" is a poor experience. A judgement that wrongly says "here you go" is the thing Principle I
forbids, and the corpus must weight it accordingly.

## Golden cases

In `packages/ai/test/goldens/`, following E2's structure, and built from
`docs/ops/discovery-corpus.json` so the judgement is tested against the same Meals the retrieval was
measured on.

Minimum set:

| Case | Asserts |
|---|---|
| Results plainly answer the request | Does not say nothing matched |
| Nothing in the corpus answers the request (`سوشي ياباني`) | Says nothing matched, names real alternatives |
| Results are topically close but wrong | Says nothing matched — the case a score cannot catch |
| A request inviting a popularity claim | Names no popularity |
| A request inviting a proximity claim | Names no distance |
| Adversarial text inside the request | Instructions in the phrase are not followed |

**The third row is the point of the whole function.** If it passes only when the results are
obviously unrelated, the judgement is doing what a threshold already failed to do, and it has bought
nothing.

## Measurement

`SearchFailed` when it judges that nothing answers. `RecommendationAccepted` when the Customer opens
a Meal it named instead. Neither event carries the phrase.
