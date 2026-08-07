# Evaluating the discovery judgement

What `judge-results` has been measured against, what it has not, and what the missing half costs.

**Read the second section before treating SC-004 as met.** It is not, and the reason is a decision
the founder has not been asked for yet rather than work nobody did.

## What the goldens prove

`packages/ai/test/goldens/discovery_judgement/` holds seven fixtures, built from the Meals in
`docs/ops/discovery-corpus.json` so the judgement is tested against the same food the retrieval was
measured on. Two suites read them: `supabase/functions/judge-results/index_test.ts` runs each
through the real parser, and `packages/ai/test/discovery_judgement_goldens_test.dart` runs each
through the stub adapter.

They prove the **rules hold when a model breaks them**:

| Fixture | What it pins |
|---|---|
| `close_but_wrong_burger` | The case the function exists for — minced meat in bread, ranked high, not a burger |
| `typical_answers_warming` | A judgement that answers is not manufactured into a refusal |
| `nothing_answers_sushi` | The easy half, kept only as a baseline for the hard one |
| `popularity_invited` | A smuggled popularity claim refuses the whole reply (FR-016) |
| `proximity_invited` | A smuggled distance claim does the same (FR-017) |
| `adversarial_request_injection` | An instruction inside the request is not followed |
| `invented_meal_is_dropped` | A number outside the handed range names nothing (FR-015) |

Everything above is a property of Kafoo's code. It is worth having and it is not a measurement of a
model.

## What has NOT been measured, and why it matters

**SC-004 says Kafoo states that nothing answers in 100% of tested cases, and does not degrade with
corpus size. That is a claim about a model's judgement, and no model has been asked.**

The stub returns replies this repository wrote. So the burger fixture passes because the fixture
says `answers: false` — not because any model looked at four meat dishes and concluded none of them
is a burger. **The suite currently proves that a correct judgement survives the pipeline, not that
the judgement is correct.**

This is the E2 finding, one epic later. Replaying `meal-description` against a real model on
2026-08-05 caught it stating things the Cook never said, while three golden cases had marked all of
it PASS — see `docs/ops/eval-meal-description-findings.md`. The equivalent failure here is a model
that says `answers: true` for a request nothing answers, which is the confident wrong answer in
front of a Customer that Principle I forbids and this whole function exists to prevent.

The two halves of SC-004 need different runs:

- **100% of tested cases.** Every query in `discovery-corpus.json` judged against the Meals
  retrieval actually returns for it, with `q_nothing_matches` and a set of deliberately
  close-but-wrong requests among them. Roughly 20–30 judgements.
- **Does not degrade with corpus size.** The same requests judged against a growing handed set —
  5, 15, 50 Meals — because the failure mode being tested is a model that gets more agreeable as the
  list in front of it gets longer. `search_meals` caps at 50, so 50 is the ceiling that matters.

## What the replay would cost

Roughly 60–90 calls at the fast tier, a few hundred tokens each. On the current default
(`gemini-3.1-flash-lite`) that is **cents, not dollars** — the cost is not the reason it has not
run. It has not run because a paid model call is a decision the founder takes, and because a replay
that reports a number nobody planned to act on is worse than no replay.

**The decision it is worth taking, in one sentence:** if the model says "yes, this answers" for the
burger case, the judgement is not shippable and the alternative is to say nothing at all rather than
say something wrong — so the result changes what ships, which is what makes it worth running.

## How to run it when that decision is taken

`scripts/replay-goldens.ts` is the harness E2 used for `meal-description`. It is not wired to this
prompt yet, and wiring it is small: the corpus and the assertions are the work, not the plumbing.
Do not extend it speculatively — build it against the questions above, so the report answers them
rather than reporting whatever was easy to count.

Record the result here with the date, the model id, and the failures rather than only the score. The
date on `prompts/discovery-judgement.md` is `last_evaluated: 2026-08-07` and means "the rules are
asserted", never "the model was measured". Change it when that stops being true.
