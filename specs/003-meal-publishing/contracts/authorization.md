# Contract — authorization

Every case below becomes a pgTAP assertion in `supabase/tests/meals_rls_test.sql`, **written and
seen to fail before the migration exists**. A negative test that passes on its first run has proven
nothing.

Notation: ✓ succeeds, ✗ returns zero rows or fails. "Zero rows" matters — an authorization *error*
confirms the row exists, which is itself a disclosure.

## `meals`

| # | Actor | Attempt | Expected |
|---|---|---|---|
| 1 | The owning Cook | Read own Meal at any status | ✓ all of them |
| 2 | Another signed-in person | Read a Meal with `status = 'draft'` | ✗ zero rows |
| 3 | Another signed-in person | Read a Meal with `status = 'unavailable'` | ✗ zero rows |
| 4 | Another signed-in person | Read a Meal with `status = 'published'` | ✓ |
| 5 | Nobody (`anon`, not signed in) | Read a Meal with `status = 'published'` | ✓ |
| 6 | Nobody (`anon`) | Read a Meal with `status = 'draft'` | ✗ zero rows |
| 7 | Another signed-in person | Update someone else's Meal | ✗ zero rows affected |
| 8 | **The owning Cook** | **Update `cook_id` to another person** | **✗ fails** |
| 9 | Another signed-in person | Insert a Meal with someone else's `cook_id` | ✗ fails |
| 10 | The owning Cook | Delete own Meal with `status = 'draft'` | ✓ |
| 11 | The owning Cook | Delete own Meal with `status = 'published'` | ✗ zero rows affected |
| 12 | The owning Cook | Delete own Meal with `status = 'archived'` | ✗ zero rows affected |
| 13 | Another signed-in person | Delete someone else's draft | ✗ zero rows affected |

**Case 8 is the one that fails when a policy is written from memory.** It needs `WITH CHECK` on the
`UPDATE` policy, not only `USING`. E1's contract called this out and it is the same mistake here,
one table later.

**Cases 5 and 6 are new to Kafoo.** This is the first use of the `anon` role, and the pair proves
the widening is exactly as wide as intended and no wider.

**Cases 11 and 12 protect a Customer who does not exist yet.** Nothing references a Meal today, so
deleting a published one would work fine. It is forbidden now because after E4 a deleted Meal takes
an Order's history with it, and a rule added later has to reconcile rows rather than prevent them.

## Lifecycle

| # | From | To | Expected |
|---|---|---|---|
| 14 | `draft` | `published` | ✓ |
| 15 | `published` | `unavailable` | ✓ |
| 16 | `unavailable` | `published` | ✓ |
| 17 | `published` | `archived` | ✓ |
| 18 | **`archived`** | **`published`** | **✗ fails** |
| 19 | `archived` | `unavailable` | ✗ fails |
| 20 | `draft` | `archived` | ✗ fails |
| 21 | any | a status not in the enum | ✗ fails |

**Case 18 is SC-010** — a retired Meal returns to offer in zero cases, by any route. It is enforced
by a trigger rather than by the UI, because "by any route" includes routes nobody has written yet.

## `nutrition_source` — the client cannot claim it

| # | Attempt | Expected |
|---|---|---|
| 22 | Update `calories`, send `nutrition_source: 'ai'` | Stored as `cook` — what changed decides, not what was claimed |
| 23 | Update `allergens`, send `nutrition_source: 'ai'` | Stored as `cook` |
| 24 | Update `title` only, leave nutrition untouched | `nutrition_source` unchanged |
| 25 | Insert with `nutrition_source: 'cook'` and AI-produced values | Stored as sent — insert is the Cook confirming; see note |

**Case 25 is a deliberate limit, not an oversight.** At insert there is no previous value to compare
against, so the database cannot tell an approved estimate from a Cook's own figure. The client
decides, and the client is trusted here because the Cook is the one confirming. What the trigger
guarantees is the *subsequent* case: nobody can later relabel a stored estimate as verified.

## `kitchen_profiles` — the widening

| # | Actor | Attempt | Expected |
|---|---|---|---|
| 26 | Nobody (`anon`) | Read a kitchen whose Cook has a `published` Meal | ✓ |
| 27 | Nobody (`anon`) | Read a kitchen whose Cook has only drafts | ✗ zero rows |
| 28 | Nobody (`anon`) | Read a kitchen whose Cook has only `unavailable` Meals | ✗ zero rows |
| 29 | Another signed-in person | Read a kitchen whose Cook has no Meals at all | ✗ zero rows |
| 30 | Anyone | Reach a Cook's phone number through a Meal or a kitchen | ✗ by any route |

**Cases 27 and 28 are the ones that will be "fixed" wrongly.** A kitchen that cannot be found looks
like a bug. It is FR-025 working: a kitchen is findable through food actually on offer, and a Cook
with everything taken off the menu is not open.

**Case 30 restates an E1 guarantee** because this feature adds a new route to a kitchen and every
new route is a new chance to leak the number. `auth.users` is not exposed through the data API, so
this holds by construction — assert it anyway, because "holds by construction" is a claim about
code that changes.

## `meal-photos` storage

| # | Actor | Attempt | Expected |
|---|---|---|---|
| 31 | The owning Cook | Write to `{own uid}/{meal_id}.jpg` | ✓ |
| 32 | Another Cook | Write to someone else's prefix | ✗ fails |
| 33 | Anyone | Read a photo | ✓ public |
| 34 | Another Cook | Delete someone else's photo | ✗ fails |

**Photos of unpublished Meals are publicly readable, and that is accepted.** The bucket is public,
so a photo is reachable by anyone who knows the exact path — a uuid inside a uuid. It is not
enumerable and it carries no personal data. Recorded because "the Meal is private but its photo is
not" is surprising enough to be mistaken for a bug later, and because if a Meal photo ever carries
something sensitive this decision must be revisited rather than inherited.
