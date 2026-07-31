# Contract — who may read and write what

The most important contract in this feature. Everything else is a screen; this is the promise.

Read it as the definition of the negative tests in `supabase/tests/`, which are written **before**
the policies they check. A policy nobody tested is a policy that does not work.

## Actors

| Actor | Means |
|---|---|
| **Anonymous** | Nobody signed in. An app that has just launched. |
| **Owner** | The signed-in person the row belongs to. |
| **Other** | A different signed-in person. Behaving normally, not attacking. This is the actor most likely to exist and least likely to be tested. |
| **Service role** | Kafoo's own trusted server-side code. Never reaches a phone. |

## `kitchen_profiles`

| Operation | Anonymous | Owner | Other | Notes |
|---|---|---|---|---|
| Read | ✗ | ✓ | ✗ | No public policy exists in E1. Widened in E2 when Meals arrive. |
| Create | ✗ | ✓ own only | ✗ | `cook_id` must equal the caller. |
| Update | ✗ | ✓ own only | ✗ | Both `USING` and `WITH CHECK`, so `cook_id` cannot be reassigned. |
| Delete | ✗ | ✗ | ✗ | Nobody. It goes with the account, by cascade. |

**A refused read returns zero rows, never an error.** FR-018 is specific about this: an error
saying "not authorised" confirms the row exists, which is itself a disclosure. The absence of a
policy produces silence, which is the correct answer to a question the asker had no right to ask.

## `analytics_events`

| Operation | Anonymous | Owner | Other | Service role |
|---|---|---|---|---|
| Read | ✗ | ✗ | ✗ | ✓ |
| Insert | ✓ *narrowed* | ✓ own only | ✗ | ✓ |
| Update | ✗ | ✗ | ✗ | ✗ |
| Delete | ✗ | ✗ | ✗ | ✗ |

**Nobody reads these through the app — including the person they describe.** They exist to improve
Kafoo, not to be shown to anyone.

**The anonymous insert is narrowed to two events** (`SignInStarted`, `SignInFailed`) with
`person_id` null, because they happen before there is a person to attribute them to. Without it the
sign-in funnel — the one that would reveal Egyptian SMS delivery failing — cannot be measured.

## Storage — `kitchen-photos`

| Operation | Anonymous | Owner | Other |
|---|---|---|---|
| Read | ✓ | ✓ | ✓ | 
| Write | ✗ | ✓ own prefix | ✗ |
| Delete | ✗ | ✓ own prefix | ✗ |

Public read is deliberate — FR-019 makes the photo public. **Nothing private goes in this bucket.**

## Tests this contract requires

Each is a row above that must be proven, not assumed. The ✗ cases matter more than the ✓ cases: a
feature that does not work is discovered immediately, and a permission that is too wide is
discovered by the wrong person.

**`kitchen_profiles_rls_test.sql`**

1. Other reads Owner's Kitchen Profile → **zero rows**, no error.
2. Other updates Owner's Kitchen Profile → affects **zero rows**; Owner's row unchanged in every
   column.
3. Owner sets `cook_id` to Other → **rejected**. This is the `WITH CHECK` test, and it is the one
   that fails if somebody writes the `UPDATE` policy from memory.
4. Anonymous reads any Kitchen Profile → **zero rows**. Proves E1 discovers nothing.
5. Owner creates a second Kitchen Profile → **rejected** by the unique constraint (FR-009).
6. Owner creates a Kitchen Profile with `cook_id` set to Other → **rejected**.
7. Anyone deletes a Kitchen Profile → **rejected**. No policy exists.

**`analytics_events_rls_test.sql`**

1. Owner reads their own events → **zero rows**. Correct, and surprising enough to be worth a test.
2. Owner inserts an event with `person_id` set to Other → **rejected**.
3. Anonymous inserts `KitchenProfileCreated` → **rejected**. Only the two funnel events are open.
4. Anonymous inserts `SignInStarted` with a non-null `person_id` → **rejected**.
5. Deleting a person sets their events' `person_id` to null and **leaves the rows in place** —
   FR-039's unlink, and the proof that funnel counts survive a departure.
6. Anyone updates an existing event → **rejected**.

**Removal, end to end** — covered in `quickstart.md` because it spans the function, the database
and storage together, and is the one path where a database guarantee stops halfway.
