# Evaluating the discovery judgement

What `judge-results` has been measured against, and what it has not.

**SC-004 is met, measured against a live model on 2026-08-07 — 20 of 20, with no degradation across
list sizes.** Read "What this does NOT establish" before extending the claim any further than that
sentence: the goldens below still measure Kafoo's rules rather than a model's judgement, and they
are a different thing from the replay.

## What the goldens prove

`packages/ai/test/goldens/discovery_judgement/` holds twelve fixtures, built from the Meals in
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
| `invented_meal_is_dropped` | A number outside the handed range refuses the whole reply (FR-015) |
| `adversarial_description_injection` | A Cook cannot forge the request's structure from their own description |
| `dialect_*`, `typical_*`, `empty_garbage_request` | The coverage `.claude/rules/ai.md` requires, rather than the kinds that happened to exist |

Everything above is a property of Kafoo's code. It is worth having and it is not a measurement of a
model.

## Measured against a live model, 2026-08-07

**SC-004 is met.** `gemini-3.1-flash-lite`, 28 calls, run by `scripts/replay-judgement.ts` with the
founder's approval.

| | |
|---|---|
| Requests nothing answers, stated correctly | **20/20 — 100%** |
| At 5 Meals / 15 / 34 | 12/12 · 4/4 · 4/4 — **no degradation with corpus size** |
| False refusals on requests something DOES answer | 0/8 |
| Replies refused before a verdict existed | 0/28 |
| Alternatives named outside the handed set | 0 |

**The near-misses are what make this worth believing.** The cases that passed are not "sushi in an
Egyptian marketplace". They are mango kunafa when pistachio kunafa is on offer; pasta with béchamel
when only white-sauce pasta is there; fried chicken against grilled chicken; beef shawarma against
chicken shawarma; a burger against minced meat served in bread. Every one of those is close enough
that `research.md` §4 measured a score getting it backwards, and the model said `false` to all of
them while still naming the near-miss as an alternative — which is the honest shape the prompt asks
for: *no, and here is what there is.*

**The strictness worry did not materialise.** `judge-results` refuses any reply carrying a field the
schema does not have, and the concern was that a chatty model would make the feature silently dead.
Zero of 28 replies were refused. On this model, strict costs nothing.

### What this does NOT establish

- **Retrieval was not run.** The handed sets are constructed to be what a vector search would
  plausibly return, by removing the food that would answer and keeping the nearest. A full
  end-to-end run needs the corpus embedded, which is a separate paid step.
- **One model, one day.** A provider switch or a model bump is a new measurement, not a
  continuation of this one. `AI_PROVIDER` is one environment variable, so this can change without
  a code diff — which is exactly why the date and the model id are recorded here.
- **36 Meals, not 50.** `search_meals` caps at 50 and the corpus holds 36. The trend across 5, 15
  and 34 is flat, so there is no reason to expect a cliff at 50, and no measurement of one either.
- **This measures the verdict, not the wording.** The sentence a Customer reads is Kafoo's own
  copy; nothing here tests it.

Raw outcomes: `docs/ops/replay-judgement-result.json`.

## Running it again

```bash
deno run --allow-env --allow-read --allow-write --allow-net scripts/replay-judgement.ts
```

**It costs money and it resumes.** An outcome already recorded with a real verdict is kept; only
cases the transport ate are asked again. That matters because the first run hit the provider's rate
limit on the thirteenth call and recorded twelve un-judged cases as failures — it printed "60%",
and the truth was that 60% of the cases had been asked at all. A measurement that reports the
harness as though it were the model is worse than no measurement, so the script now paces itself,
backs off on a rate limit, and distinguishes a refusal the model produced from one the network did.

Record every run here with the date, the model id and the failures — never only the score.
