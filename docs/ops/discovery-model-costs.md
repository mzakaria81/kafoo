# What discovery costs to run

Prepared 2026-08-07 because WP-014 and WP-016 both make paid model calls and neither can start
until somebody accepts a number. **This document is the decision, not the implementation.**

Prices read from <https://ai.google.dev/gemini-api/docs/pricing> on 2026-08-07. They are published
list prices and they move; re-read the page before treating any figure here as current.

## The short version

**Embedding a Meal is free in practice. Judging a search is the entire cost, and it is small.**

| | per unit | at 1,000 searches/day | at 10,000 searches/day |
|---|---|---|---|
| Judge with **Flash-Lite** | ~$0.00013/search | **~$4/month** | ~$40/month |
| Judge with **Flash** | ~$0.00046/search | ~$14/month | ~$140/month |
| Embedding a Meal | ~$0.00002/Meal | — | — |
| Embedding a query | ~$0.000002/search | under $0.10/month | under $1/month |

**Recommendation: `gemini-2.5-flash-lite` for the judge**, with a rule for when to move up rather
than a promise that it will do. See "When to spend more" below.

## Where the numbers come from

The spike (`spike-discovery-embeddings.md`) established the shape: **the judge runs on every search,
not rarely.** Vector search never returns nothing — it returns Meals in an order — so "did anything
actually answer this" is a judgement on every query, not an exception path. That correction to the
original design is what makes the judge the cost centre and the embedding a rounding error.

**Embedding, `gemini-embedding-2` at $0.20 per million input tokens.** A Meal's title and
description together run about 100 tokens, so one Meal costs $0.00002 to embed. A thousand Meals
costs two cents. Re-embedding on every edit does not change the order of magnitude. A Customer's
query is roughly ten tokens.

**Judging, per search.** The judge receives the query, the top handful of Meals, and its
instructions — call it 1,100 input tokens and 50 output tokens:

- Flash-Lite at $0.10 in / $0.40 out per million → **$0.00013**
- Flash at $0.30 in / $2.50 out per million → **$0.00046**

The gap is the output price, not the input: Flash charges six times more for what it writes, and the
judge writes very little. That is why the ratio between the two rows is smaller than it looks.

## What is NOT in these numbers

- **A retry.** A failed judgement that is retried doubles that search's cost. FR-018 says a failed,
  slow or malformed judgement leaves results exactly as they are, so the honest default is not to
  retry at all — the Customer already has their results.
- **Abuse.** A search endpoint reachable without an account is a search endpoint reachable by a
  script. Nothing in E3 rate-limits it. At Flash-Lite prices a million searches is $130, which is
  cheap enough to ignore and not cheap enough to leave unbounded forever.
- **The free tier.** 1,000 requests/day total, shared between embedding and judging, and every
  published Meal spends one. It cannot serve production discovery. This is a planning fact, not a
  tuning detail.

## When to spend more

Do not choose the more expensive model on a feeling about quality. WP-016 already carries the test
that decides it:

> the topically-close-but-wrong case passes — if the judgement only catches obviously unrelated
> results it has bought nothing a score already failed to do

**Start on Flash-Lite. If that golden case fails on Flash-Lite and passes on Flash, the difference
is worth $10/month at current volumes and the answer is Flash.** If it fails on both, the problem is
the prompt rather than the model, and buying a bigger model hides that.

## Decided 2026-08-07 by the founder

1. **Cost accepted.** Roughly $4/month to start, on `gemini-2.5-flash-lite`, growing with searches.
2. **The paid tier is NOT on yet — "later".** Development and testing run on the free tier, whose
   1,000 requests/day is ample for building and for the golden cases. **It is not ample for
   launch**: publishing Meals alone spends against it, so discovery cannot be turned on for real
   Customers until the tier is switched. This is a launch blocker, not a build blocker, and it
   belongs on the pre-launch checklist rather than in a work package.
3. **Search stays open to people without an account.** It is what makes discovery work without
   signing up — the whole point of E3 — and it is accepted with its consequence: the endpoint is
   reachable by a script and nothing in E3 rate-limits it. At Flash-Lite prices a million searches
   is $130. Worth revisiting when there is something to abuse, not before.

## The other half of the decision

`gemini-embedding-2` at 768 dimensions is already chosen and measured — research.md §1, and the
spike table behind it. Nothing here reopens that. What needs a human is only:

1. **Accept the judge cost** at roughly $4/month to start, growing with searches.
2. **Confirm the paid tier is turned on** for the Gemini project before WP-014 runs, because the
   free tier's 1,000 requests/day is spent by publishing Meals alone.
3. **Decide whether search stays open to people without an account.** It is what makes discovery
   work without signing up, and it is also what makes the cost unbounded. Both are true.
