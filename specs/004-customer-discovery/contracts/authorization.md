# Contract — authorization

Every case below becomes a pgTAP assertion in `supabase/tests/discovery_rls_test.sql`, **written and
seen to fail before the migration exists**. A negative test that passes on its first run has proven
nothing.

Notation: ✓ succeeds, ✗ returns zero rows or fails.

> **Why this file exists even though no policy changes.** E3 adds no RLS policy. It adds a *new way
> of asking* — a ranking function — and **every existing authorization test passes whether or not
> that path leaks**, because none of them go through it. A green suite is not evidence about a route
> it does not travel. That is the 2026-08-06 finding restated: five checks in this repository were
> found incapable of failing, three of them because a different policy refused first.

## Search must refuse exactly what reading refuses

| # | Actor | Attempt | Expected |
|---|---|---|---|
| 1 | Nobody (`anon`) | Search and reach a `published` Meal | ✓ |
| 2 | Nobody (`anon`) | Search and reach a `draft` Meal | ✗ zero rows |
| 3 | Nobody (`anon`) | Search and reach an `unavailable` Meal | ✗ zero rows |
| 4 | Nobody (`anon`) | Search and reach an `archived` Meal | ✗ zero rows |
| 5 | Another signed-in person | Search and reach someone else's `draft` | ✗ zero rows |
| 6 | The owning Cook | Search and reach their own `draft` | ✗ zero rows |
| 7 | Nobody (`anon`) | Reach a Kitchen Profile whose Cook has a Meal on offer | ✓ |
| 8 | Nobody (`anon`) | Reach a Kitchen Profile whose Meals are all drafts | ✗ zero rows |

**Case 6 is the one that will be argued about, and the answer is no.** A Cook can read their own
draft — E2 case 1, unchanged. But *discovery* is the Customer-facing surface, and a draft appearing
in a Cook's own search results would mean the ranking function returns rows on a different rule from
the one it advertises. Search shows what is on offer. The Cook's own drafts have their own screen.

**Cases 2 to 5 must be seen to fail before `search_meals` exists.** The way this passes for the wrong
reason: the function is written `SECURITY DEFINER`, every Meal becomes findable, and these assertions
still pass because the *test fixture* only inserted published Meals. Insert one of each status, then
watch each assertion go red when the function is made `SECURITY DEFINER` on purpose.

## The embedding column is not writable by a Cook

| # | Actor | Attempt | Expected |
|---|---|---|---|
| 9 | The owning Cook | Update `meals.embedding` on their own Meal | ✗ rejected |
| 10 | Another signed-in person | Update `meals.embedding` on someone else's Meal | ✗ zero rows affected |
| 11 | Nobody (`anon`) | Update `meals.embedding` on any Meal | ✗ zero rows affected |

**Case 9 is the important one and RLS does not give it to you.** The existing `cook updates own
meals` policy permits a Cook to update their own row, and that includes this column. Left as is, a
Cook can write whatever vector they like — the vector nearest every query — and their Meal ranks
first for everything, invisibly and permanently. That is ranking manipulation, and it is why
`embed-meal` reads a Meal's text from the database rather than from a request body.

The column must be closed at the write path — a column-level privilege, a trigger that rejects a
client-supplied change, or both. **Whichever is chosen, case 9 proves it, and it must be seen to
fail first**: with no protection at all, case 9 passes trivially in the wrong direction.

## `search_meals` runs as the caller

| # | Property | Expected |
|---|---|---|
| 12 | The function's security mode | `SECURITY INVOKER` |
| 13 | Calling it as `anon` returns only what `anon` may read | ✓ |
| 14 | Calling it as a signed-in person returns only what they may read | ✓ |

**Case 12 is asserted against the catalogue, not inferred from behaviour.** A `SECURITY DEFINER`
function can return correct-looking results in a test whose fixtures happen to be public, and the
one-word difference removes the entire authorization story.

## What the mutation check must find

`scripts/mutate-policies.py` weakens one predicate clause at a time and reports which assertions
notice. After this feature it must report **zero clauses with no assertion behind them**, as it does
today.

The specific thing to watch: the two-policy defence on kitchen discoverability that E2 measured — the
kitchen policy and the meals policy each mask the other, so weakening one alone leaves everything
green. Cases 7 and 8 above inherit that property. **Weakening both together must turn them red**, and
if it does not, these assertions are decoration.
