# Measuring discovery latency

**SC-006 — "results within 1 second".** Measured against the demo database, never production.
Regenerate with:

```bash
DENO_CERT=/root/.ccr/ca-bundle.crt deno run --allow-net --allow-env --allow-read --allow-write \
  scripts/measure-discovery-latency.ts --runs=20 --load=0 --report
```

## The number

| | n | p50 | p95 | min | max |
|---|---|---|---|---|---|
| **End-to-end** (`discover`) — what a Customer waits | 20 | 990 ms | 1199 ms | 704 ms | 2267 ms |
| **Database**, full rows (`search_meals`) | 20 | 359 ms | 577 ms | 261 ms | 579 ms |
| **Database**, ids only (`?select=id`) — the scan alone | 20 | 164 ms | 354 ms | 157 ms | 360 ms |

**Corpus: 13 published Meals carrying an embedding**.
Measured against `pzyngffppwfsvdsnslkb`. End-to-end p95 is **OVER the 1 s budget**.

Percentiles are **nearest-rank over 20 samples**, so p95 is the 19th observation rather than an estimate of a tail. A latency figure without its n and its
percentile is not a budget check, which is why both are here and in every sentence that quotes them.

## What the two halves mean

The Customer's wait is dominated by **one paid embedding call to the model provider**, which does
not care how many Meals exist. The database half is the part that grows: `search_meals` ranks
**exactly** rather than approximately — it computes the distance to every surviving row — so its
cost is linear in the corpus. See `supabase/migrations/20260806231625_add_meal_embeddings.sql`,
which explains why the HNSW index exists and is deliberately not used.

Reporting only the end-to-end figure would hide the growing half inside a vendor round trip and
call the budget met. That is the reading this file exists to prevent.

## Response size

Each search returns **132,336 bytes at the median** for a median of 13 results — about 10,180 bytes per Meal, against 635 bytes for the same rows as ids alone.

`search_meals` is `RETURNS SETOF public.meals`, so every row carries its 768-float `embedding`,
and `discover` passes what the database returned straight through. No client reads that column —
it is "shown to nobody" by the column's own comment.

**The two database rows above are the same scan.** The only difference is whether the vectors are
serialised and sent, so the gap between them — 195 ms at the median — is what the
unread column costs on the wire, at a corpus of 13. At the 50-result limit it is roughly
four times that. This is paid on **every search, by every Customer, on an Egyptian mobile
network**, and dropping the column from what `discover` returns is the cheapest large win
available against this budget.

## What this does not measure

- **A real network.** This runs from a cloud container. Add the Customer's own latency to every
  figure above; the budget is spent at their phone, not at the container.
- **Retrieval quality.** `scripts/discovery-retrieval-regression.py` owns that, nightly.
- **Anything about the HNSW index.** A benchmark corpus carries random unit vectors, which time
  identically under exact ranking and say nothing about approximate traversal.
