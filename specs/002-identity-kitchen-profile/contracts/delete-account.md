# Contract — `delete-account`

The only Edge Function in this feature. It exists because deleting an `auth.users` row needs the
service role, and a service-role key must never reach a phone.

## Interface

```
POST /functions/v1/delete-account
Authorization: Bearer <the caller's access token>
```

**No request body. No parameters. No path segments.**

That is the design, not an omission. The constitution requires an Edge Function to read identity
from the JWT and never from a client-supplied `user_id`. A function that takes no input **cannot be
made to delete the wrong person**, however it is called, by anyone, ever. There is no input
validation section below because there is nothing to validate — which is a stronger guarantee than
any amount of checking.

## Responses

| Status | Meaning |
|---|---|
| `204` | Removed. The token is now worthless. |
| `401` | No token, or not a valid one. Nothing happened. |
| `500` | Something failed part-way. See ordering below — the account still exists. |

No response body on success. There is nothing to say and nobody left to say it to.

## What it does, in this order

Order matters, because a failure part-way through must leave a person who can try again rather than
a half-erased one.

1. **Verify the token** and take `user_id` from it. Never from anywhere else.
2. **Delete the storage objects** under `kitchen-photos/{user_id}/`. Storage has no foreign key, so
   this is the one step nothing else will do.
3. **Delete the `auth.users` row.** The database then cascades: the Kitchen Profile is deleted,
   and `analytics_events.person_id` is set to null while the rows remain.
4. **Return 204.**

**Storage goes first on purpose.** If step 2 fails, nothing has been destroyed and the person
retries. If the order were reversed and step 2 failed, the account would be gone while orphaned
photos remained in a public bucket — unreferenced, unreachable through Kafoo, and belonging to
someone who has just asked to be forgotten. Orphaned files in a public bucket are the worst
available outcome, so the step that can fail goes where failing is harmless.

**Steps 3's consequences are the database's, not the function's.** The function does not delete the
Kitchen Profile and does not touch `analytics_events`. Those follow from the foreign keys in
`data-model.md`. Code that duplicated them would be a second place for the rule to live, and
eventually a second place for it to be wrong.

## What it must never do

- **Never accept a `user_id`** in a body, a query string, or a header. If a future change adds one,
  that change is the bug.
- **Never soft-delete.** FR-033 requires the same phone number to produce a new person afterwards,
  which a flag cannot do — the number would still be attached to the old row. Apple's guideline
  says the same thing from the other direction: deactivation does not satisfy the requirement.
- **Never ask why.** FR-034. No reason field, no retention offer, no "are you sure?" beyond the one
  confirmation the client already showed.
- **Never emit `AccountRemoved` with the person attached.** The event records that a removal
  happened. Attaching the identity of someone who just asked to be forgotten would undo the point
  of the function inside the function.

## Tests

1. Called with no token → `401`, and the account still exists.
2. Called with a **valid token belonging to someone else's session** → deletes **that** caller, not
   anyone named in any part of the request. The proof that identity comes from the JWT.
3. Called by a person with a Kitchen Profile and a photo → account, profile and photo all gone.
4. After removal, that person's `analytics_events` rows **still exist** with `person_id` null.
   FR-039's unlink, and the counts survive.
5. After removal, signing in with the same phone number produces a person with **no** Kitchen
   Profile. FR-033.
6. Storage deletion fails → `500`, and the account still exists and is still usable.
