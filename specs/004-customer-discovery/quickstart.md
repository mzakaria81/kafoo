# Quickstart: Customer Discovery

How to verify E3 by hand, written for someone with none of the context that produced it.

**Nothing here is implemented yet.** This file is the acceptance procedure, written before the code
so it cannot be quietly shaped to match what got built.

## Before anything — check which environment you are in

```bash
curl -sS -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects
```

Kafoo's project is named `kafoo`, region `eu-central-1`. If `$SUPABASE_PROJECT_REF` is not that
project, **stop and switch environments** — do not override the variable. The whole of 2026-07-31 ran
against another product's database this way. `docs/HANDOFF.md` has the full story.

## 0. Toolchain

```bash
./scripts/install-toolchain.sh   # ~3s warm
melos bootstrap
```

## 1. The authorization suites, which must be red first

This is the step people skip and it is the only one that proves anything.

```bash
./scripts/local-db.sh test        # no Docker needed
```

**Before the migration exists**, `discovery_rls_test.sql` must **fail**. If it passes on its first
run it is testing nothing — see `contracts/authorization.md`. Then apply the migration and watch it
go green.

Then break it deliberately, which is the part that matters:

```bash
python3 scripts/mutate-policies.py
```

It weakens one predicate clause at a time and reports which assertions notice. **Zero clauses with no
assertion behind them.** If a clause can be weakened with everything still green, the assertion
guarding it is decoration.

Two specific things to try by hand, because a mutation tool will not think of them:

1. **Make `search_meals` `SECURITY DEFINER`.** Cases 2–6 must go red. If they stay green, the test
   fixtures only contain published Meals and the suite is proving nothing.
2. **Remove whatever stops a Cook writing `meals.embedding`.** Case 9 must go red.

## 2. Prove the search still fits the budget — the HNSW index is deliberately NOT used

**This section used to say the opposite, and following it would reintroduce a defect.** It told you
to look for the HNSW index in the plan and to treat a sequential scan as the thing to fix. A
sequential scan is now the correct state, and the arrangement that used the index is the one that
told a Customer their governorate was empty when it was not. See the note above the function body in
`20260806231625_add_meal_embeddings.sql`.

```sql
EXPLAIN ANALYZE SELECT * FROM search_meals(<a query vector>, NULL, 'أسوان');
```

Expect a `CTE Scan on candidate` with the filters applied **inside** the CTE, before the ordering.
An `Index Scan using meals_embedding_hnsw` with the filters in a `Filter:` line underneath it is the
defect returning: the index chooses its candidates first and the filters then discard them, so a
narrow search over a large corpus returns nothing while matching Meals exist.

What to actually check:

1. **`discovery_search_test.sql` assertions 2–4 pass.** They are the behavioural statement of the
   above, and assertion 2 fails within seconds of the CTE being un-materialised.
2. **The timing fits the budget.** Exact ranking is linear: measured at 27 ms for 5,001 Meals
   against a one-second budget for search, so the budget is reached somewhere near 180,000 Meals.
   **This is the number that will change**, and the day it stops fitting is the day the HNSW index
   earns its place back — with a design that filters before it ranks, not by reverting this.

## 3. Retrieval quality

```bash
python3 scripts/spike-discovery-embeddings.py gemini-embedding-2:768
```

Expect roughly: top-1 on 14 of 19, mean P@5 0.66, MRR 0.84 — the numbers in
`docs/ops/spike-discovery-embeddings.md`. A large drop means the model, its version, or the corpus
changed, and which one it is matters before anything is tuned.

**The free tier allows 1,000 requests a day and this run spends about 56.**

## 4. By hand, in the app

Sign in as a Cook and publish three Meals — one with meat, one without, one with no ingredients
listed at all. Take a fourth to draft. Then sign out and act as a Customer.

| # | Do this | Expect |
|---|---|---|
| 1 | Open discovery without searching | The three published Meals. Not the draft. |
| 2 | Open a Meal | Its kitchen is reachable from it |
| 3 | Type `برجر` when a burger is on offer | It appears |
| 4 | Type `burger` in Latin script | **It still appears.** This is the cross-language requirement and the one most likely to be quietly broken. |
| 5 | Type `نفسي في حاجة خفيفة` | Something light, and the words need not appear in any Meal |
| 6 | Type `عايز حاجة من غير لحمة` | **No Meal containing meat, at any position.** The Meal with no ingredients listed is also absent — an unknown is withheld, FR-021. |
| 7 | Type `عايز حاجة من غير سوشي` (a noun outside the vocabulary) | Kafoo says it did not understand the exclusion. It does **not** silently return everything. |
| 8 | Type `سوشي ياباني` | Kafoo says nothing matches and names Meals that are on offer |
| 9 | Watch step 8 closely | Results appear **before** the sentence about them does |
| 10 | Turn off the network mid-search | Browsing still works. Search failing does not take browsing with it. |
| 11 | Name an area no Cook wrote | Kafoo says so and names the areas that do have food. It does not silently show them. |
| 12 | Have the Cook take every Meal off the menu | Their kitchen disappears from discovery entirely |

**Step 6 is the one to repeat.** It is the only case where getting it wrong harms someone rather than
disappointing them.

**Step 9 is the one that is easiest to break later** and produces no error when it is — the feature
just becomes slow, the way E2 was measured to be.

## 5. Without installing anything

```bash
cd apps/web && npm run dev
```

Reach a kitchen and a Meal in a browser, signed in to nothing:

- The five public details, and no sixth. No Cook's personal name, no phone number, no rating.
- A kitchen with nothing on offer is **not** reachable.
- Right-to-left, Arabic first.
- **Check the shared preview separately from the page.** Name, area, photo — FR-027a. A fourth thing
  in the preview is a failure even if the page is correct.

Then confirm the bundle carries no service-role key:

```bash
npm run build && grep -r "service_role\|SERVICE_ROLE" .open-next/ || echo "clean"
```

## 6. The gate

```bash
./scripts/verify.sh
```

This is the definition of passing — not `flutter test`, which misses the pure-Dart packages, and not
`flutter analyze`, which misses RLS coverage, credentials, vocabulary, ARB parity and the Edge
Function type-check.

**A failing RLS check or committed-credential check is a stop-and-report, never something to iterate
against.** The quickest way to turn a red authorization test green is to weaken the policy, which is
the one outcome the test exists to prevent.

## 7. Then check the acceptance criteria by name

Walk `spec.md`'s SC-001 to SC-013 individually. Four of them are stated as **zero** rather than a
percentage — SC-005, SC-008, SC-010, SC-013 — and a single occurrence is a failure of the feature
rather than a ranking miss.
