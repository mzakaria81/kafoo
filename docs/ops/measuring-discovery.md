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
| **End-to-end** (`discover`) — what a Customer waits | 20 | 1135 ms | 1263 ms | 899 ms | 1360 ms |
| **Database**, full rows (`search_meals`) | 20 | 581 ms | 605 ms | 559 ms | 614 ms |
| **Database**, ids only (`?select=id`) — the scan alone | 20 | 168 ms | 195 ms | 161 ms | 203 ms |

**Corpus: 1013 published Meals carrying an embedding**, of which 1000 were a benchmark corpus loaded and removed by this run.
Measured against `pzyngffppwfsvdsnslkb`. End-to-end p95 is WITHIN the 1.5 s budget.

Percentiles are **nearest-rank over 20 samples**, so p95 is the 19th observation rather than an estimate of a tail. A latency figure without its n and its
percentile is not a budget check, which is why both are here and in every sentence that quotes them.

## Where the time goes

Subtracting the rows above, at the median: **554 ms is the model provider's embedding call plus the Edge Function's own overhead**, 413 ms is serialising and sending the vectors, and **168 ms is the scan and its round trip**.

The scan is the only one of the three that grows with the marketplace. `search_meals` ranks
**exactly** rather than approximately — it computes the distance to every surviving row — so its
cost is linear in the corpus. See `supabase/migrations/20260806231625_add_meal_embeddings.sql`,
which explains why the HNSW index exists and is deliberately not used.

## What corpus size actually did

Same script, same target, 2026-08-08, at **13** Meals against **1013** here —
78× the corpus:

| | 13 Meals | 1013 Meals | change |
|---|---|---|---|
| End-to-end p50 | 990 ms | 1135 ms | +145 ms |
| Database, full rows p50 | 359 ms | 581 ms | +222 ms |
| **Database, ids only p50 — the scan** | **164 ms** | **168 ms** | **+4.4 ms** |
| Median results returned | 13 | 50 | |

**The scan did not move.** 78× the Meals changed it by 4.4 ms, which is inside the noise
between two runs. Everything that got worse got worse because more rows came back — the `LIMIT 50`
in `search_meals` binds once the corpus passes fifty Meals, so the response grew and the wait grew
with it.

So the thing to fix is not the corpus and not the ranking. It is what a search sends back.

## Response size

Each search returns **505,261 bytes at the median** for a median of 50 results — about 10,105 bytes per Meal, against 2,448 bytes for the same rows as ids alone.

`search_meals` is `RETURNS SETOF public.meals`, so every row carries its 768-float `embedding`,
and `discover` passes what the database returned straight through. No client reads that column —
it is "shown to nobody" by the column's own comment.

**The two database rows above are the same scan.** The only difference is whether the vectors are
serialised and sent, so the gap between them — 413 ms at the median — is what the
unread column costs on the wire. This run sat at the `LIMIT 50`, so that is the worst case rather than a projection from a small result set — it is what every search costs once the marketplace holds more than fifty Meals, which is to say almost immediately.

Paid on **every search, by every Customer, on an Egyptian mobile network**. Dropping the column
from what `discover` returns is the cheapest large win available against this budget, and it is
not a scaling problem — it is the same size on the day Kafoo launches as it is at a million Meals.

## What this does not measure

- **A real network.** This runs from a cloud container. Add the Customer's own latency to every
  figure above; the budget is spent at their phone, not at the container.
- **Retrieval quality.** `scripts/discovery-retrieval-regression.py` owns that, nightly.
- **Anything about the HNSW index.** A benchmark corpus carries random unit vectors, which time
  identically under exact ranking and say nothing about approximate traversal.
