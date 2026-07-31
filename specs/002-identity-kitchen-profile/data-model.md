# Phase 1 — Data model

Two tables and one bucket. Shapes are indicative; the migrations are the truth, and their filenames
come from `supabase migration new` rather than being written by hand.

Every rule below that *could* be enforced in application code is enforced in the database instead.
That is not thoroughness for its own sake — it is the difference between a rule and a habit.

---

## Person — not Kafoo's table

A Person is a row in `auth.users`. Kafoo does not create, copy, or mirror it.

| Field | Where it lives | Notes |
|---|---|---|
| `id` | `auth.users.id` | The identity. Every Kafoo row referencing a person references this. |
| phone number | `auth.users.phone` | A credential, not the identity (FR-025). Changing it is FR-026. |
| email address | `auth.users.email` | Optional, attached from inside the account (FR-007). |
| email decline count | `auth.users.raw_user_meta_data` | Drives FR-029's cap. |

**Kafoo never stores a phone number.** FR-020 says only the person may read theirs, and the surest
way to honour that is never to hold a second copy. `auth.users` is not exposed through the data
API, so a number is reachable only through its owner's session.

**On the decline count**: user metadata is writable by the person it belongs to, so it is not
trustworthy for a security decision. It is not being used for one — it caps a prompt. Anyone who
edits it to avoid being asked has achieved exactly what declining achieves. It lives here because
it costs no table and disappears with the account automatically.

---

## `kitchen_profiles`

```sql
CREATE TABLE kitchen_profiles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cook_id         uuid NOT NULL UNIQUE
                    REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text NOT NULL CHECK (length(trim(display_name)) > 0),
  story           text NOT NULL CHECK (length(trim(story)) > 0),
  area            text NOT NULL CHECK (length(trim(area)) > 0),
  delivery_terms  text NOT NULL CHECK (length(trim(delivery_terms)) > 0),
  photo_path      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE kitchen_profiles ENABLE ROW LEVEL SECURITY;
```

**`UNIQUE` on `cook_id` is FR-009.** "A person owns at most one Kitchen Profile" is a constraint,
not a check-then-insert — which would race with itself the moment a Cook double-taps.

**`ON DELETE CASCADE` is part of FR-032.** Removing the account removes the Kitchen Profile, and
the database does it rather than the Edge Function remembering to.

**`photo_path` is nullable** because FR-011 requires a photo but the spec's edge cases require a
failed photo not to lose the conversation. A Cook finishes without one and adds it after. Requiring
it in SQL would turn a slow upload into a lost Kitchen Profile.

### Policies

```sql
-- Read: only the owner. There is deliberately no public policy — see below.
CREATE POLICY "cook reads own kitchen profile"
  ON kitchen_profiles FOR SELECT TO authenticated
  USING (cook_id = auth.uid());

CREATE POLICY "cook creates own kitchen profile"
  ON kitchen_profiles FOR INSERT TO authenticated
  WITH CHECK (cook_id = auth.uid());

CREATE POLICY "cook updates own kitchen profile"
  ON kitchen_profiles FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (cook_id = auth.uid());
```

**Both `USING` and `WITH CHECK` on `UPDATE`.** Without `WITH CHECK`, a Cook could set `cook_id` to
somebody else and hand their kitchen away — which FR-010 forbids and `.claude/rules/supabase.md`
calls out by name.

**No `DELETE` policy at all.** A Cook does not delete their Kitchen Profile independently; it goes
when the account goes, through the cascade. Deny-by-default means the absence of the policy is the
enforcement.

### The missing policy is deliberate — and E2 must add it

There is **no public `SELECT` policy**. Nobody who is not the owner can read a Kitchen Profile, so
nothing is discoverable. That is exactly right today: FR-030 makes discoverability depend on the
Cook having a published Meal, and `meals` does not exist.

> **For E2**: the migration that creates `meals` must also add the widening policy below. Without
> it, Kafoo will have Meals that nobody can find a kitchen for, and the failure is silent — queries
> return zero rows rather than erroring.
>
> ```sql
> CREATE POLICY "anyone reads a kitchen with food on offer"
>   ON kitchen_profiles FOR SELECT
>   USING (EXISTS (SELECT 1 FROM meals
>                  WHERE meals.cook_id = kitchen_profiles.cook_id
>                    AND meals.status = 'published'));
> ```
>
> FR-031 — that a Customer who already ordered can still read the kitchen — becomes reachable in E4
> when Orders exist, as a second policy predicated on holding an Order. It cannot be written before
> then, and writing it against a table that does not exist is not possible.

---

## `analytics_events`

```sql
CREATE TABLE analytics_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL,
  person_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  attributes  jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
```

**`ON DELETE SET NULL` is FR-039, and the choice over `CASCADE` matters.** Unlinking satisfies
"removed or permanently unlinked" while keeping the counts: after someone leaves, "how many people
gave up at question three" is still answerable, and nothing says who they were. `CASCADE` would
remove the person *and* silently corrupt every historical funnel they appeared in — a number that
changes retroactively is worse than no number.

Because FR-037 forbids content in an event, a row whose `person_id` is null identifies nobody. The
unlink is genuinely terminal, not pseudonymisation with a key sitting next to it.

**`name` is not a foreign key to an event registry.** The registry is a document, not a table.
Constraining it in SQL would mean a migration every time an event is added, which turns an ordinary
change into a schema change for no safety gained — a wrong name is caught in review, and a typo
produces an obviously empty series.

### Policies

```sql
-- A signed-in person may record their own activity, and nobody else's.
CREATE POLICY "person records own events"
  ON analytics_events FOR INSERT TO authenticated
  WITH CHECK (person_id = auth.uid());

-- Sign-in funnel events happen before there is anyone to attribute them to.
CREATE POLICY "anonymous records pre-sign-in funnel only"
  ON analytics_events FOR INSERT TO anon
  WITH CHECK (
    person_id IS NULL
    AND name IN ('SignInStarted', 'SignInFailed')
  );
```

**No `SELECT` policy for anyone.** FR-040 restricts reading to people running Kafoo, and they read
through the service role, not through the app. A Customer cannot read their own events, which is
correct: these exist to improve Kafoo, not to be shown back to anyone.

No `UPDATE` or `DELETE` policy either — an event is written once and never changed. The only thing
that ever modifies a row is the foreign key nulling `person_id`, which is the database acting, not
a policy.

**The anonymous insert is the one real trade-off in this design.** `SignInStarted` and
`SignInFailed` happen before anyone is authenticated, so they must be writable by `anon` or the
sign-in funnel — the thing most likely to reveal that Egyptian SMS delivery is failing — cannot be
measured at all. The policy narrows it as far as it goes: `person_id` must be null, so nobody can
attribute activity to another person, and `name` is restricted to those two events, so the table
cannot be used as general anonymous storage.

What remains is that an anonymous caller can insert rows nobody asked for. That is accepted
deliberately: the blast radius is noise in two counters, there is no read access to pair it with,
and the alternative — an Edge Function in front of two funnel events — is more moving parts than
the risk justifies. If it is ever abused, the fix is to move these two behind a function, and
nothing else changes.

---

## Storage

One bucket, `kitchen-photos`. Public read; write and delete restricted to the owner by path prefix.

```
kitchen-photos/{auth.uid()}/kitchen.jpg
```

Keying the path to the owner's id makes the ownership check a prefix comparison and removes any
need to look up who owns what.

Public read is honest rather than lazy: FR-019 makes the photo part of the deliberately public face
of a Kitchen Profile. The limitation is real and worth stating — anyone holding the URL can fetch
the object without an authorization check. **No private file may ever be placed in this bucket**,
however convenient it seems at the time.

**Storage has no foreign key, so nothing removes these automatically.** `delete-account` must
delete the objects explicitly. This is the only part of removal the database does not enforce,
which makes it both the easiest to forget and the one most worth testing directly.

---

## Invariants, and where each is enforced

| Requirement | Enforced by | Not by |
|---|---|---|
| FR-009 — at most one Kitchen Profile per person | `UNIQUE (cook_id)` | A lookup before insert, which races |
| FR-010 — a Kitchen Profile is never transferable | `WITH CHECK` on the `UPDATE` policy | Trusting the app not to send a different `cook_id` |
| FR-017 — only the owner may create or change | Per-operation RLS policies | An `if` in Dart |
| FR-018 — a refused read returns nothing, not an error | RLS returning zero rows | An error message that confirms the row exists |
| FR-020 — a phone number is readable only by its owner | Never storing it in a Kafoo table | A policy on a copy |
| FR-030 — discoverability follows published Meals | Absence of a public policy today; the E2 policy above | A `visible` column |
| FR-032 — removal takes the Kitchen Profile with it | `ON DELETE CASCADE` | Cleanup code in the Edge Function |
| FR-033 — removal is genuine, not deactivation | Deleting the `auth.users` row | A `deleted_at` flag |
| FR-039 — removal reaches the funnel data | `ON DELETE SET NULL` | A third party's deletion endpoint |

The right-hand column is the point. Every one of those alternatives works right up until somebody
writes a second code path, and then it does not, and nothing tells you.

---

## Domain documentation to update in the same commit

Definition of Done item 6. Both are domain rules that this feature establishes, and a rule living
only in a feature specification is a rule the next feature will not know about:

1. **`docs/product/domain-model.md`** gains the derived-discoverability rule — a Kitchen Profile
   has no state of its own; it is discoverable while its Cook has a published Meal, and readable to
   anyone holding a legitimate reference regardless.
2. **`docs/product/domain-model.md`** gains the Person shape: identity is independent of the phone
   number that proves it, one account holds both roles, and owning a Kitchen Profile is what makes
   someone a Cook.
