# Contract — `embed-meal` Edge Function

Gives a Meal the vector that makes it findable.

> **This is the only thing in Kafoo on an AI path that holds a service-role key and writes to the
> database.** Everything below exists to keep that narrow. It must be reviewed by
> `ai-boundary-reviewer` and `rls-reviewer` on the diff, not accepted from this document.

## Why it may write at all

Principle II exists so no claim a human reads enters the database without a human approving it. **An
embedding is not a claim.** It asserts nothing, is displayed to nobody, cannot be read back as text,
and is a machine representation of words a Cook already wrote and already published. Asking a Cook to
approve 768 floating-point numbers would be theatre, not consent.

## Why the Cook's own session may not write it instead

That would satisfy the letter of the rule and open a hole: a client that supplies the vector can
supply **the vector nearest every query**, and that Cook's Meal ranks first for everything — silently,
permanently, and invisibly to every existing test. Ranking manipulation is a trust failure in a
marketplace, and Principle I outranks the convenience of a narrower key.

## Shape

**Request**: a Meal id. Nothing else. No text, no vector.

**Response**: whether the Meal now has a vector.

**The request body carries no content, and that is the entire security property.** The function reads
the Meal's `title` and `description` **from the database**, embeds those, and writes back one column
for that one id. A caller can ask for a Meal to be embedded; it cannot influence what is embedded.

## Rules this function must not break

- **It writes `meals.embedding` and nothing else.** Not `status`, not `updated_at` as a side effect
  that reorders a Cook's menu, not a timestamp column added later for convenience. The moment it
  writes a second column, the argument above stops being true.
- **It embeds text read from the database**, never text from the request.
- **It never publishes, unpublishes, or changes a Meal's state.**
- **It refuses a Meal id that does not exist** without disclosing whether it exists — the same rule
  E1 applied to phone numbers.
- **Model calls go through the provider registry**, typed as a document rather than a query.
- **Vectors are normalised.** 768 dimensions is below the provider's native size.

## When it runs

| Trigger | Embed? |
|---|---|
| A Meal is published | **Yes** |
| A Meal's `title` or `description` changes | **Yes** |
| A Meal's price, photo, or status changes | **No** — the searchable words did not change |
| A Meal is taken off the menu or archived | **No** — visibility is RLS's job, not the index's |
| A Meal published before this feature exists | **Backfill**, once |

## Failure behaviour

**A Meal with no vector is invisible to search and still visible to browsing.** So every failure here
degrades to a Meal that is harder to find, never one that is lost, and never a Cook who cannot
publish.

| Failure | Response |
|---|---|
| The provider is unreachable | The Meal publishes anyway, with no vector. Publishing must not depend on a vendor being up. |
| The provider returns a malformed vector | Nothing is written. A wrong vector is worse than none — it ranks the Meal somewhere arbitrary rather than nowhere. |
| The Meal has no readable text | Nothing is written. Cannot happen against the current schema, which requires both, and is asserted anyway because schemas change. |
