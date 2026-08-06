# Which authorization assertions can actually fail

Measured 2026-08-06 by `scripts/mutate-policies.py` against a local Postgres 17 built by
`scripts/local-db.sh`. Re-run it after adding a policy or a fixture — isolation is not a property a
suite keeps by default.

| | Before | After |
|---|---|---|
| Assertions | 104 | 114 |
| Policies / clause mutations | 19 / 29 | 19 / 29 |
| **Clauses with no assertion behind them** | **15** | **0** |
| Assertions passing for a reason other than their name | 3 | 0 (renamed; replacements added) |

The ten new assertions are in `supabase/tests/policy_isolation_test.sql`. Every one of them was
seen to go red for the clause it was written for — that is the whole point of the file, and the
sweep is how it is checked rather than asserted.

## Why this was measured

On 2026-08-05, WP-006 found by accident that `non-owner cannot write another Cook's address form`
passed with the `kitchen_profiles` UPDATE policy weakened to `USING (true)`. That fixture's kitchen
has no Meal on offer, so the SELECT policy refuses the statement before the UPDATE policy is ever
consulted. The assertion was green and measuring nothing.

**An assertion that cannot fail is worse than no assertion**, because it occupies the place where a
real one would go and reads as coverage in every summary. One instance was known. Nobody knew
whether there were seventy-five more.

## Method, and the one that was wrong first

Each policy predicate is split into its top-level `AND` conjuncts. **One clause at a time** is
replaced by `true`, the other clauses kept, all 104 assertions run, and the clause restored — with
the restore read back out of the catalog and compared before the next mutation. Nothing on disk is
ever weakened.

The obvious method — replace the whole predicate with `true` — was tried first **and gave a
confidently wrong answer.** It also removes the policy's scoping, so `bucket_id = 'kitchen-photos'`
disappears, a bucket-scoped policy briefly governs the whole table, and because permissive policies
are OR'd it starts permitting rows belonging to a different policy entirely. That made the
kitchen-photos INSERT policy look like it was guarding a meal-photos assertion, and hid the fact
that **nothing guards kitchen-photo uploads at all.** The first numbers would have been wrong in
the reassuring direction.

## What a result means, stated narrowly

- **A clause with at least one red assertion is load-bearing for that assertion.** It does not
  follow that the assertion tests only that clause. Permissive policies are OR'd, so a "cannot"
  assertion always tests the union of every policy on the table — a mutation sweep can prove a
  clause matters and can never attribute a refusal to one policy.
- **A clause with no red assertion is covered by nothing in the suite.** That result is not
  probabilistic, and it is what this document is for.

## The three assertions that passed for a reason other than their name

All three are the same mechanism, and it is the one worth internalising: **PostgreSQL applies
`SELECT` policies to the rows an `UPDATE` or `DELETE` touches.** A row you cannot see is a row you
cannot change, so the read policy refuses first and the write policy under test is never reached.

| Assertion, as it was named | Claimed | Actually exercises | Now |
|---|---|---|---|
| `another signed-in person cannot delete a Cook's draft` | the DELETE policy's ownership clause | the SELECT policies. Removing `cook_id = auth.uid()` from the DELETE policy left it green. | renamed; `a stranger who can SEE a draft still cannot delete it` bites |
| `owner cannot reassign cook_id to another person (WITH CHECK)` | the UPDATE policy's `WITH CHECK` | the SELECT policies. The reassigned row stops being visible to its updater, which is what raises 42501. | renamed; `the UPDATE policy WITH CHECK refuses a reassign on its own, with the row still visible` bites |
| `non-owner cannot write another Cook's address form` | the UPDATE policy | the SELECT policies. WP-006's original find, in its original location. | renamed; WP-006's discoverability assertion already bites |

**None of the three was deleted.** Each still pins a real outcome — a stranger's write really does
fail against a closed kitchen — and each is renamed to say which layer refuses, so a TAP line
reading `a closed kitchen is invisible, so a stranger's UPDATE finds no row (SELECT policy, not
UPDATE)` cannot be mistaken for coverage of the UPDATE policy.

**The second one was predicted in writing, in the file, above the assertion.** The comment says that
when a later epic makes kitchens publicly discoverable, "this test stops covering the thing its name
suggests", and that whoever writes that migration "must add an assertion that fails with
`WITH CHECK (true)` in place, because this one will not." E2 shipped that migration. Nobody re-read
the note. A warning in the right place is not a control — the mutation sweep is.

## The 15 clauses that had nothing behind them

**One on `public`, and it was the sharp one:**

| Policy | Clause with no assertion |
|---|---|
| `meals :: cook deletes own drafts` | `cook_id = auth.uid()` |

Nothing proved a stranger cannot delete your draft. The DELETE policy's other half (`status =
'draft'`) was covered twice over.

**Six ownership clauses on `storage.objects`:**

| Policy | Status |
|---|---|
| `owner reads own kitchen photo` (SELECT) | no assertion |
| `owner reads own meal photo` (SELECT) | no assertion |
| `owner updates kitchen photo` (UPDATE) | no assertion |
| `owner updates meal photo` (UPDATE) | no assertion |
| `owner deletes kitchen photo` (DELETE) | no assertion — its meal-photos twin has a structural one |
| `owner uploads kitchen photo` (INSERT) | no assertion — its meal-photos twin has a behavioural one |

The kitchen-photos SELECT policy is the one that closed the Cook-roster enumeration hole in
`20260802065138`. That migration was verified by real anonymous HTTP requests against a preview
branch and recorded the before/after in its own comment — good evidence, and none of it is a test
that runs again.

**Eight `bucket_id = …` clauses, one per storage policy — lower severity, and stated rather than
counted silently.** Dropping a bucket clause widens a policy from one bucket to both. Today that is
harmless because the two buckets carry identical owner-scoped predicates, so the union permits
exactly what it permitted before. It stops being harmless the moment a third bucket exists with a
different rule, and no assertion would notice.

## Full result

Every clause now has at least one assertion that goes red when it is dropped. The counts are
lower bounds on coverage, not a score — one assertion that genuinely isolates a clause is worth
more than four that pass through it.

| Policy (cmd) | Clause | Assertions that notice |
|---|---|---|
| `analytics_events :: anonymous records pre-sign-in funnel only (INSERT)` | `person_id IS NULL` | 1 |
| `analytics_events :: anonymous records pre-sign-in funnel only (INSERT)` | `name = ANY (…)` | 1 |
| `analytics_events :: person records own events (INSERT)` | `person_id = auth.uid` | 2 |
| `kitchen_profiles :: anyone reads a kitchen with food on offer (SELECT)` | `EXISTS (… published …)` | 8 |
| `kitchen_profiles :: cook creates own kitchen profile (INSERT)` | `cook_id = auth.uid` | 1 |
| `kitchen_profiles :: cook reads own kitchen profile (SELECT)` | `cook_id = auth.uid` | 4 |
| `kitchen_profiles :: cook updates own kitchen profile (UPDATE)` | `cook_id = auth.uid` | 2 |
| `meals :: anyone reads a published meal (SELECT)` | `status = 'published'::text` | 3 |
| `meals :: cook creates own meals (INSERT)` | `cook_id = auth.uid` | 1 |
| `meals :: cook deletes own drafts (DELETE)` | `cook_id = auth.uid` | 1 |
| `meals :: cook deletes own drafts (DELETE)` | `status = 'draft'::text` | 2 |
| `meals :: cook reads own meals (SELECT)` | `cook_id = auth.uid` | 2 |
| `meals :: cook updates own meals (UPDATE)` | `cook_id = auth.uid` | 2 |
| `storage :: owner deletes kitchen photo (DELETE)` | `bucket_id = 'kitchen-photos'::text` | 1 |
| `storage :: owner deletes kitchen photo (DELETE)` | folder = `auth.uid()` | 1 |
| `storage :: owner deletes meal photo (DELETE)` | `bucket_id = 'meal-photos'::text` | 1 |
| `storage :: owner deletes meal photo (DELETE)` | folder = `auth.uid()` | 1 |
| `storage :: owner reads own kitchen photo (SELECT)` | `bucket_id = 'kitchen-photos'::text` | 1 |
| `storage :: owner reads own kitchen photo (SELECT)` | folder = `auth.uid()` | 1 |
| `storage :: owner reads own meal photo (SELECT)` | `bucket_id = 'meal-photos'::text` | 1 |
| `storage :: owner reads own meal photo (SELECT)` | folder = `auth.uid()` | 1 |
| `storage :: owner updates kitchen photo (UPDATE)` | `bucket_id = 'kitchen-photos'::text` | 1 |
| `storage :: owner updates kitchen photo (UPDATE)` | folder = `auth.uid()` | 1 |
| `storage :: owner updates meal photo (UPDATE)` | `bucket_id = 'meal-photos'::text` | 1 |
| `storage :: owner updates meal photo (UPDATE)` | folder = `auth.uid()` | 1 |
| `storage :: owner uploads kitchen photo (INSERT)` | `bucket_id = 'kitchen-photos'::text` | 1 |
| `storage :: owner uploads kitchen photo (INSERT)` | folder = `auth.uid()` | 1 |
| `storage :: owner uploads meal photo (INSERT)` | `bucket_id = 'meal-photos'::text` | 1 |
| `storage :: owner uploads meal photo (INSERT)` | folder = `auth.uid()` | 1 |

`kitchen_profiles :: cook updates own kitchen profile` shows 2, and **both** were written after a
mutation showed the clause bare: one by WP-006 in `kitchen_discoverability_test.sql` when the
masking was first found, one here. Before either existed the clause read **0** — the whole "a Cook
owns their own kitchen" write rule was untested.

The eight `bucket_id` clauses each show 1, and that one is structural: `every storage.objects policy
names the bucket it governs`. They cannot be covered behaviourally, because widening a policy from
one bucket to both changes nothing observable while the two buckets carry identical predicates.
A check on the predicate's text is the honest shape for a clause whose effect is currently
unobservable — and it is the thing that will notice the day a third bucket arrives with a different
rule.

## One assertion that did not run rather than passing

Weakening `kitchen_profiles :: cook creates own kitchen profile` aborted
`kitchen_profiles_rls_test.sql` before `unset address_form is legal and reads NULL` executed. An
assertion that does not run is not an assertion that passed, so the harness reports it separately
rather than counting it as coverage. It is a fixture that depends on the policy being narrow, not a
hole: the clause itself has an assertion that goes red.

**The same thing happened once in the new suite and was fixed rather than documented.** Under the
kitchen-photo upload mutation the stranger's INSERT succeeded, collided with the owner's later
upload on a unique key, and aborted four later assertions — which the harness correctly reported as
unmeasured rather than as coverage. The fixture now plants its file under a different name. A suite
has to survive the mutation it exists to catch, or it goes quiet exactly when it should shout.

## What was NOT done here, deliberately

**No policy was changed.** Every finding above is a missing or misnamed *test*. WP-008's rule is
that a policy change coming out of this package is a stop-and-report to the founder, because the
quickest way to turn a red authorization test green is to weaken the thing it guards — and this is
the one package where that temptation is in front of you all day.

Two policy-shaped things were checked and are correct as they stand:

- **The storage UPDATE policies have no `WITH CHECK`.** `.claude/rules/supabase.md` warns that
  omitting it "lets a Cook reassign a Meal to someone else". Here it does not: PostgreSQL uses the
  `USING` expression as the check when `WITH CHECK` is absent, so the folder scoping applies to the
  new row too. Verified behaviourally — a Cook renaming their photo into another Cook's folder is
  refused. Do not "fix" this by adding a redundant clause.
- **`storage.protect_delete()` refuses every direct `DELETE` from `storage.objects`**, whoever asks.
  That is why the meal-photos DELETE policy is checked structurally, by reading the predicate out of
  the catalog, and why the same is the only option for its kitchen-photos twin.
