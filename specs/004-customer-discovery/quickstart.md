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
2. **The scan itself fits the budget.** Exact ranking is linear: measured at 27 ms for 5,001 Meals
   in Postgres, so the *scan* reaches a one-second budget somewhere near 180,000 Meals — and the
   scan is not what spends the budget, see below.
   **This is the number that will change**, and the day it stops fitting is the day the HNSW index
   earns its place back — with a design that filters before it ranks, not by reverting this.

   **That 27 ms is not SC-006 and must not be quoted as though it were.** It is `EXPLAIN ANALYZE`
   inside Postgres. SC-006 is what a Customer waits, which is a model provider's embedding call
   plus a round trip plus the bytes coming back — measured at 1112 ms median and 1438 ms at p95.
   **SC-006's budget is 1.5 s, raised from 1 s by the founder on 2026-08-08 against exactly that
   measurement.** Figures and method in `docs/ops/measuring-discovery.md`, procedure in §2a.

   And the scan is not what is spending it. Measured at 13 Meals and again at 1,013 on the same
   day, **78× the corpus moved the scan by about 2 ms.** What grew was the response: `search_meals`
   returns whole Meal rows including the `embedding` column, so a full page of fifty results is
   half a megabyte of vectors no client reads.

## 2a. Search latency, end to end — the SC-006 check

```bash
DENO_CERT=/root/.ccr/ca-bundle.crt \
DEMO_SUPABASE_URL=<demo url> DEMO_SUPABASE_PUBLISHABLE_KEY=<demo publishable key> \
deno run --allow-net --allow-env --allow-read --allow-write \
  scripts/measure-discovery-latency.ts --runs=20 --report
```

Writes `docs/ops/measuring-discovery.md`. Read that file for the current figures and for what the
measurement does not cover — chiefly that it runs from a cloud container, so a real Customer's
network is added to every number in it.

**It refuses production, and the refusal is the control rather than the intention.** `--load`
publishes Meals no Cook cooks, which `.claude/rules/business-rules.md` calls product-fatal on the
real marketplace. Point it at the demo database — `docs/ops/demo-environment.md`.

**A figure over the budget is reported, never tuned away or re-run until it passes.** That is
CLAUDE.md's performance-budget rule, and this measurement is currently over.

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

| 13 | Arrive for the first time and browse without searching | **Nothing asks about anything.** The question about a Customer's words appears at the first attempt to search, never on arrival — FR-029a. |
| 14 | Now type anything and press search | Kafoo says the words will leave and offers both answers. Nothing has been sent yet. |
| 15 | Refuse | Search is **gone**, not broken: there is no input to type into, a sentence says searching is off, and browsing is untouched. |
| 16 | Close Kafoo, reopen it, try to search again | **The question does not come back.** SC-015. The answer is on the device. |
| 17 | Open Settings from the bar and turn the switch on | Search works from the next attempt. The question still does not come back. |
| 18 | Type `عايز حاجة من غير لحمة في المهندسين` | One sentence carries all three things: a line names what was filtered on, a line names the area, and the results honour both. |
| 19 | Read the line about the exclusion | It says **what was removed and where that came from**. It never says a Meal is safe. |
| 20 | Name an area with nothing in it | Kafoo names the areas that do have food and shows **nothing from them** until one is chosen. No distance, no "nearest", no promise anyone delivers. |

**Steps 13 to 17 are one requirement, not five.** Run them in order and on a fresh install; the
failure they catch — being asked twice, or asked on arrival — is invisible on the second run.

**Step 6 is the one to repeat.** It is the only case where getting it wrong harms someone rather than
disappointing them.

**Step 9 is the one that is easiest to break later** and produces no error when it is — the feature
just becomes slow, the way E2 was measured to be.

## 4a. Meals published before search existed

A Meal with no vector is invisible to search and fully visible to browsing, so the corpus needs
filling in once. It is a script rather than a migration — the reasoning is at the top of the file.

```bash
DENO_CERT=/root/.ccr/ca-bundle.crt deno run --allow-net --allow-env \
  scripts/backfill-meal-embeddings.ts --dry-run     # spends nothing, writes nothing
```

Then without `--dry-run`, optionally with `--limit=5` for a first run against production.

**Interrupt it halfway on purpose.** The Meals it reached are searchable, the rest are exactly as
they were, and running it again picks up where it stopped. If an interrupted run ever loses a
Cook's words, that is the defect this design exists to prevent.

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

## 5b. The judgement — what Kafoo says when nothing answers

Search for something the marketplace plainly cannot answer (`سوشي ياباني`), and for something it
answers well (`حاجة تدفي في البرد`). By hand, on a device or the simulator:

- The results appear **first**, and the sentence arrives afterwards or not at all. If you never see
  it, that is a correct outcome — a judgement that fails costs a sentence and never a result.
- When it says nothing here answers, **every Meal is still on the screen, in the same order**. The
  named Meals are named in the sentence; nothing is removed, nothing moves up. A screen showing only
  the named Meals is a bug, not a tidier layout.
- The Meals it names are on offer right now. Open one and check it is real.
- The sentence never says a Meal is popular, nearby, fast, or safe. Kafoo knows none of those things.
- Read it at 200% text scale, in Arabic. It must address a woman as readily as a man — there should
  be no `you` in it at all.

Then take the network away mid-search and repeat. The results must be unchanged and the sentence
simply absent.

**SC-004 is not met by any of this.** The judgement's accuracy has never been measured against a
real model — only its rules have, against replies this repository wrote. Read
`docs/ops/eval-discovery-judgement.md` before signing that criterion off.

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
