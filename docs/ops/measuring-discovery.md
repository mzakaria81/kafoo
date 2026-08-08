# Measuring discovery latency

**SC-006 — "results within 1 second".** Measured against the demo database, never production.
Regenerate with:

```bash
DENO_CERT=/root/.ccr/ca-bundle.crt deno run --allow-net --allow-env --allow-read --allow-write \
  scripts/measure-discovery-latency.ts --runs=20 --load=1000 --report
```

## The number

| | n | p50 | p95 | min | max |
|---|---|---|---|---|---|
| **End-to-end** (`discover`) — what a Customer waits | 20 | 1112 ms | 1291 ms | 858 ms | 1315 ms |
| **Database**, full rows (`search_meals`) | 20 | 578 ms | 598 ms | 554 ms | 608 ms |
| **Database**, ids only (`?select=id`) — the scan alone | 20 | 170 ms | 209 ms | 161 ms | 211 ms |

**Corpus: 1013 published Meals carrying an embedding**, of which 1000 were a benchmark corpus loaded and removed by this run.
Measured against `pzyngffppwfsvdsnslkb`. End-to-end p95 is WITHIN the 1.5 s budget.

Percentiles are **nearest-rank over 20 samples**, so p95 is the 19th observation rather than an estimate of a tail. A latency figure without its n and its
percentile is not a budget check, which is why both are here and in every sentence that quotes them.

## Where the time goes

Subtracting the rows above, at the median: **534 ms is the model provider's embedding call plus the Edge Function's own overhead**, 408 ms is serialising and sending the vectors, and **170 ms is the scan and its round trip**.

The scan is the only one of the three that grows with the marketplace. `search_meals` ranks
**exactly** rather than approximately — it computes the distance to every surviving row — so its
cost is linear in the corpus. See `supabase/migrations/20260806231625_add_meal_embeddings.sql`,
which explains why the HNSW index exists and is deliberately not used.

## What corpus size actually did

Same script, same target, 2026-08-08, at **13** Meals against **1013** here —
78× the corpus:

| | 13 Meals | 1013 Meals | change |
|---|---|---|---|
| End-to-end p50 | 990 ms | 1112 ms | +122 ms |
| Database, full rows p50 | 359 ms | 578 ms | +219 ms |
| **Database, ids only p50 — the scan** | **164 ms** | **170 ms** | **+6.3 ms** |
| Median results returned | 13 | 50 | |

**The scan did not move.** 78× the Meals changed it by 6.3 ms, which is inside the noise
between two runs. Everything that got worse got worse because more rows came back — the `LIMIT 50`
in `search_meals` binds once the corpus passes fifty Meals, so the response grew and the wait grew
with it.

So the thing to fix is not the corpus and not the ranking. It is what a search sends back.

## Response size

Each search returns **505,347 bytes at the median** for a median of 50 results — about 10,107 bytes per Meal, against 2,448 bytes for the same rows as ids alone.

**`search_meals` returned `SETOF public.meals` until 2026-08-08**, so every row carried its
768-float `embedding` and `discover` passed that straight through. No client reads the column —
it is "shown to nobody" by the column's own comment, and `CookMeal.fromRow` does not mention it.

`20260808165000_stop_returning_meal_embeddings_from_search.sql` gives the function a return type
with no `embedding` in it. Measured on the same rows before deploying it: **497 KB → 29 KB** at
the 50-result limit, a 94% cut in what a search sends back. Fixed in the database rather than in
`discover`, so no future caller can select it back.

**If the figures above still show a large gap between the two database rows, this report predates
that migration reaching the target.** Re-run it after deploying to refresh them.

**The two database rows above are the same scan.** The only difference is whether the vectors are
serialised and sent, so the gap between them — 408 ms at the median — is what the
unread column costs on the wire. This run sat at the `LIMIT 50`, so that is the worst case rather than a projection from a small result set — it is what every search costs once the marketplace holds more than fifty Meals, which is to say almost immediately.

Paid on **every search, by every Customer, on an Egyptian mobile network** — and not a scaling
problem: it was the same size on the day Kafoo launches as at a million Meals, which is why it was
worth fixing before the corpus was.

## What this does not measure

- **A real network.** This runs from a cloud container. Add the Customer's own latency to every
  figure above; the budget is spent at their phone, not at the container.
- **Retrieval quality.** `scripts/discovery-retrieval-regression.py` owns that, nightly.
- **Anything about the HNSW index.** A benchmark corpus carries random unit vectors, which time
  identically under exact ranking and say nothing about approximate traversal.
