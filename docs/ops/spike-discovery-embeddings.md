# Spike: does embedding retrieval find a Meal from Egyptian Arabic?

Run 2026-08-06 against the live `GEMINI_API_KEY`, before E3 was specified. Re-runnable:

```bash
python3 scripts/spike-discovery-embeddings.py                       # the full sweep
python3 scripts/spike-discovery-embeddings.py gemini-embedding-2:768  # one candidate
```

Corpus: `docs/ops/discovery-corpus.json` — 36 Meals written in a Cook's voice, 20 queries written
in a Customer's voice. Numbers below are the script's output, not hand-written.

## The question, and the answer

E3's design assumes an embedding model places `نفسي في حاجة خفيفة` near a salad and a soup. Three
questions, and the third is the one that changes the design:

1. **Does cross-language retrieval work?** `.claude/rules/supabase.md` requires `برجر` → Burger and
   forbids `ILIKE`. **YES, and better than the rule asks for.**
2. **Is dialect retrieval good enough to ship?** **Mostly yes, with one class of failure.**
3. **Can Kafoo tell when nothing matched?** **NO. Neither an absolute nor a relative threshold
   separates a query nothing answers from one that is answered.** This breaks a mechanism the
   design depends on.

## What was measured

| Candidate | top-1 | P@5 | recall@5 | MRR |
|---|---|---|---|---|
| `gemini-embedding-001` @ 768d | 13/19 | 0.644 | 0.605 | 0.778 |
| `gemini-embedding-001` @ 1536d | 13/19 | 0.660 | 0.621 | 0.816 |
| `gemini-embedding-2` @ 768d | 14/19 | 0.660 | 0.620 | 0.838 |
| **`gemini-embedding-2` @ 1536d** | **15/19** | **0.670** | **0.629** | **0.864** |

**`gemini-embedding-2` wins at every dimension measured.** It beats 001 at 768 and at 1536, and its
768 configuration beats 001's 1536 — a smaller vector from the better model outperforms a larger
vector from the worse one.

3072d was **deliberately not measured**: it cannot ship (below), so a number for it would be a
number nobody can act on.

**Doubling the dimensions buys almost nothing.** 768 → 1536 moves MRR by 0.026 and top-1 by one
query out of nineteen, for twice the storage and twice the index. **768 is the recommendation.**

**3072 is not an option even though it is Gemini's default.** pgvector's HNSW index refuses more
than 2000 dimensions, and `.claude/rules/supabase.md` requires an HNSW index on a vector column. A
3072-dimension column would work and be unindexable — correct answers, sequential scans, no error.

## Question 1 — cross-language retrieval works, and it is the strongest result here

Every cross-script and cross-language query returned the right Meal at **rank 1**:

| Query | Script | Result |
|---|---|---|
| `برجر` | Arabic | Burger, rank 1, score 0.816 |
| `burger` | **Latin** | Burger, rank 1, score 0.738 |
| `pizza` | **Latin** | بيتزا مارجريتا, rank 1 |
| `grilled chicken` | **English** | فراخ مشوية, rank 1, perfect P@5 |
| `something spicy` | **English** | كبدة إسكندراني, rank 1 — it knew شطة is chilli |

`burger` in Latin script shares **no character** with any Meal in the corpus. `ILIKE` scores zero
here by construction. This is the requirement the rules name, and it is met.

## Question 2 — dialect retrieval mostly works, and fails in one specific way

Queries with no shared vocabulary still worked: `حاجة تدفي في البرد` → both soups, perfect. `حلويات
رمضان` → قطايف and كنافة at ranks 1 and 2, though the Meals never mention Ramadan. `حاجة العيال
بتحبها` → بشاميل first, with pizza and burger behind it. That is cultural inference, not word
matching.

**The failure is negation, and it is the worst result in the run.**

`أكل من غير لحمة خالص` — "food with no meat at all" — returned meat dishes. First correct answer at
**rank 6**, precision@5 of **0.00** on both embedding-2 candidates.

This is a known property of embeddings rather than a surprise: the vector for "no meat" sits near
the vector for "meat". What makes it Kafoo's problem rather than a curiosity is who asks it. A
Customer excluding meat is usually doing so for dietary, religious or health reasons, and serving
them the opposite is a trust failure, not a relevance miss. Kafoo already treats health-adjacent
data as a special category.

**Exclusion must be a filter in the query, never a phrase in the embedding.** That is a structural
fix and it belongs in the plan.

## Question 3 — Kafoo cannot detect a failed search from the scores. This changes the design.

The corpus contains `سوشي ياباني` — Japanese sushi — which nothing in it answers. It should score
far below every real match. It does not.

| Separation attempt | No-match query | Worst real match | Gap |
|---|---|---|---|
| Absolute cosine score | 0.6154 | 0.4319 | **−0.1835** |
| Relative margin (top-1 vs the corpus distribution, in standard deviations) | 2.355 | 1.691 | **−0.664** |

**Both are backwards.** The query nothing answers scores *higher* than a query that is answered
correctly. A threshold set to reject sushi would reject `نفسي في حاجة خفيفة` first.

The reason is structural and will not be fixed by a better model: **within a corpus that is entirely
food, every food query is topically similar to everything.** "Japanese sushi" is food-shaped text
against food-shaped text. Cosine similarity measures topic, and the topic always matches.

**Two numbers here are a warning about checks, not about search.** Both `gemini-embedding-001`
candidates printed `separable` on the absolute score — on gaps of **+0.0037** and **+0.0020**, from
one no-match query, on one corpus. Both then failed the relative test on the same data. That is
noise wearing a verdict's clothes, and it is the 2026-08-06 lesson arriving in new clothing: a green
check is a claim. The check prints the gap beside the verdict for exactly this reason, which is the
only reason the verdict could be caught being wrong.

### What this means for the design

The approved design says the AI Assistant speaks **only when retrieval returns nothing**. Vector
search never returns nothing — it returns 36 Meals in an order. Detecting "nothing matched" needed a
threshold, and there isn't one.

**Recommendation: the model judges relevance after retrieval, on every search.** It receives the
query and the top handful of Meals and decides whether any of them honestly answer it. The
architecture is unchanged and still correct — results render at database speed, the model arrives
afterwards and never blocks them. What changes is the cost claim, and the design should be corrected
rather than quietly left standing:

- **The design said the model call is rare, so it costs a fraction.** It is not rare. It is once per
  search.
- **Latency is still unaffected.** Results are already on screen when the judgement arrives.
- **Embedding cost is negligible either way** — a query embeds to roughly ten tokens. The judge call
  is the entire cost of search, and it is the one to measure before E3 ships.

`SearchFailed` then means "the AI Assistant judged that nothing answered this", which is a defensible
definition and an honest one. It cannot mean "the scores were low", because the scores are not
telling the truth.

## Operational notes

- **The free tier's limits, read off the console rather than guessed**: both embedding models allow
  **100 requests/minute, 30,000 tokens/minute, and 1,000 requests/day**. Tokens were never the
  constraint — the whole corpus is under 1,000 tokens. Requests were. The script batches 20 texts
  per HTTP call, but batch *items* appear to count individually against the per-minute cap, so a
  four-candidate sweep issues roughly 224 of them back to back and trips the limit partway through.
  That is inference from where it failed, not something the API states.

  Two false readings came out of this and both are worth naming. The retry first backed off for 15
  seconds total and reported a quota failure that a 60-second wait cleared — **a message saying
  "exceeded your quota" meant "you are going too fast"**, and reading it literally would have
  retired a usable model. And the sweep looked exhausted while a single call still succeeded
  immediately, which is what proved it. Both are fixed: the script now paces by item.

- **The free tier cannot serve production discovery, and this is a planning fact rather than a
  spike detail.** 1,000 requests/day is roughly 1,000 searches/day across all Customers, and every
  Meal published spends one too. Kafoo needs a paid tier before discovery ships to anyone.
- **The spike calls Gemini directly**, outside the provider abstraction. That is fine for a spike
  and not fine in Kafoo: ADR-0005 Amendment 1 requires production model calls to go through
  `supabase/functions/_shared/ai/`. Productionising means moving the call, not copying the script.
- **The corpus is synthetic and must stay out of production.** Kafoo's trust rules forbid synthetic
  Meals as seed or demo data. These are measurement fixtures and belong nowhere near a migration.

## What this spike did not establish

- **Whether the corpus is representative.** 36 Meals written in one sitting by one author is not 400
  Meals written by 40 Cooks. The queries were deliberately written to avoid sharing words with the
  Meals, which makes the test harder than reality — but one author writing both sides can still
  share assumptions invisibly. Re-run this against real Meals once there are any.
- **Whether recall holds at scale.** Retrieval against 36 documents is a different problem from
  retrieval against 4,000. Rankings that look clean here can collapse when near-duplicates exist —
  forty Cooks all offering كشري.
- **Anything about voice.** Every query here was typed. `ar-EG` speech recognition remains
  unmeasured on real hardware (WP-004), and it sits in front of all of this.
