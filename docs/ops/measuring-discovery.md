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
| **End-to-end** (`discover`) — what a Customer waits | 20 | 684 ms | 847 ms | 528 ms | 1002 ms |
| **Database**, full rows (`search_meals`) | 20 | 171 ms | 175 ms | 160 ms | 176 ms |
| **Database**, ids only (`?select=id`) — the scan alone | 20 | 168 ms | 185 ms | 162 ms | 374 ms |

**Corpus: 1013 published Meals carrying an embedding**, of which 1000 were a benchmark corpus loaded and removed by this run.
Measured against `pzyngffppwfsvdsnslkb`. End-to-end p95 is WITHIN the 1.5 s budget.

Percentiles are **nearest-rank over 20 samples**, so p95 is the 19th observation rather than an estimate of a tail. A latency figure without its n and its
percentile is not a budget check, which is why both are here and in every sentence that quotes them.

## Where the time goes

Subtracting the rows above, at the median: **513 ms is the model provider's embedding call plus the Edge Function's own overhead**, 3.2 ms is serialising and sending the vectors, and **168 ms is the scan and its round trip**.

The scan is the only one of the three that grows with the marketplace. `search_meals` ranks
**exactly** rather than approximately — it computes the distance to every surviving row — so its
cost is linear in the corpus. See `supabase/migrations/20260806231625_add_meal_embeddings.sql`,
which explains why the HNSW index exists and is deliberately not used.

## Against the previous measurement

Same script, same target, same corpus. Baseline: **2026-08-08, before the vector stopped being returned**, 1013 Meals.

| | before | now | change |
|---|---|---|---|
| End-to-end p50 — what a Customer waits | 1112 ms | 684 ms | −428 ms |
| End-to-end p95 | 1438 ms | 847 ms | −591 ms |
| Database, full rows p50 | 581 ms | 171 ms | −410 ms |
| Database, ids only p50 — the scan | 166 ms | 168 ms | +2.0 ms |

**The scan did not move, and it was never supposed to.** What moved is the gap between the two
database rows — the cost of serialising vectors into the response — which has gone from
415 ms to 3.2 ms.

## Corpus size, settled

Measured at **13 Meals and again at 1,013** on 2026-08-08: the scan ran at 164 ms and 166 ms. **78×
the corpus moved it by about 2 ms**, inside the noise between two runs.

Search latency is therefore not currently a scaling problem, and a bigger corpus is not the way to
find the next one. Exact ranking is linear and reaches a second somewhere near 180,000 Meals; until
then the wait is a vendor call and a round trip.

## Response size

Each search returns **28,626 bytes at the median** for a median of 50 results — about 573 bytes per Meal, against 2,448 bytes for the same rows as ids alone.

**`search_meals` returned `SETOF public.meals` until 2026-08-08**, so every row carried its
768-float `embedding` and `discover` passed that straight through. No client reads the column —
it is "shown to nobody" by the column's own comment, and `CookMeal.fromRow` does not mention it.

`20260808165000_stop_returning_meal_embeddings_from_search.sql` gives the function a return type
with no `embedding` in it. Fixed in the database rather than in `discover`, so no future caller
can select it back.

**The figures above are from after that migration**, which is why the two database rows now agree.
If a future run shows them diverging again, something has put a large column back into what search
returns.

**The two database rows above are the same scan.** The only difference is whether the vectors are
serialised and sent, so the gap between them — 3.2 ms at the median — is what the
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
