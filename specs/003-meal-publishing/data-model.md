# Phase 1 — Data model

One table, one bucket, and one policy added to a table E1 created. Shapes are indicative; the
migrations are the truth, and their filenames come from `supabase migration new`.

Every rule that *could* be enforced in application code is enforced in the database instead — the
same discipline E1 used, for the same reason: it is the difference between a rule and a habit.

---

## `meals`

```sql
CREATE TABLE meals (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cook_id           uuid NOT NULL
                      REFERENCES auth.users(id) ON DELETE CASCADE,
  title             text NOT NULL CHECK (length(trim(title)) > 0),
  description       text NOT NULL CHECK (length(trim(description)) > 0),
  price             numeric(10,2) NOT NULL CHECK (price > 0),
  cuisine           text NOT NULL,
  category          text NOT NULL,
  status            text NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft','published','unavailable','archived')),
  ingredients       text[] NOT NULL DEFAULT '{}',
  calories          integer CHECK (calories IS NULL OR (calories > 0 AND calories < 20000)),
  allergens         text[] NOT NULL DEFAULT '{}',
  nutrition_source  text NOT NULL DEFAULT 'ai'
                      CHECK (nutrition_source IN ('ai','cook')),
  photo_path        text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  published_at      timestamptz
);

ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
```

**`ON DELETE CASCADE`, not `RESTRICT`.** `docs/product/domain-model.md` specifies `RESTRICT` for
Meals, and that is right *once Orders exist* — a Meal referenced by an Order must not vanish under
it. Today nothing references a Meal, and E1's removal flow (FR-032) promises that removing an
account removes everything. `RESTRICT` would break that promise for the only case that exists.
**E4 must change this to `RESTRICT` in the migration that creates `orders`**, and until then the
domain document and the schema disagree on purpose. Recorded here rather than discovered there.

**No `UNIQUE` on anything.** A Cook may offer the same dish twice; the specification says Kafoo is
not the judge of that.

**`calories` is nullable and bounded.** Nullable because the AI Assistant may be unavailable
(FR-014) or refused (FR-029) and the Cook must still publish. Bounded because a model that returns
190,000 must not have it stored — the constraint is the last line of the schema-validation defence
in research.md §5, not the first.

**`price numeric(10,2)`, never a float.** Money in a binary float is a defect waiting for a decimal
that does not divide. `numeric` also makes the "no hidden fees" promise checkable, because the
stored number is exactly the number shown.

**`nutrition_source` defaults to `ai`.** The default is the pessimistic answer: an estimate is an
estimate unless something proves otherwise. See the trigger below — this column is the one place
where trusting the client would quietly destroy Principle II.

**`published_at` separate from `updated_at`.** A Meal taken off the menu and put back has not been
republished; it has been made available again. Conflating them loses the first-publish moment that
`MealPublished` measures.

### Policies

```sql
-- The owner sees everything of theirs, at any status.
CREATE POLICY "cook reads own meals"
  ON meals FOR SELECT TO authenticated
  USING (cook_id = auth.uid());

-- Anyone at all reads a Meal on offer — signed in or not (FR-024).
CREATE POLICY "anyone reads a published meal"
  ON meals FOR SELECT TO anon, authenticated
  USING (status = 'published');

CREATE POLICY "cook creates own meals"
  ON meals FOR INSERT TO authenticated
  WITH CHECK (cook_id = auth.uid());

CREATE POLICY "cook updates own meals"
  ON meals FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (cook_id = auth.uid());

CREATE POLICY "cook deletes own drafts"
  ON meals FOR DELETE TO authenticated
  USING (cook_id = auth.uid() AND status = 'draft');
```

**Both `USING` and `WITH CHECK` on `UPDATE`.** Without `WITH CHECK`, a Cook could set `cook_id` to
someone else and hand over a Meal — the transfer FR-016 forbids. This is the exact case E1's
authorization contract called out as the one that fails when a policy is written from memory.

**`DELETE` is restricted to drafts.** FR-033 lets a Cook delete a draft. Nothing lets anyone delete
a Meal that has been on offer — that is what archiving is for, and once Orders exist a deleted Meal
would take a Customer's history with it.

**The `anon` role appears for the first time in Kafoo.** FR-024 requires a Meal on offer to be
readable without signing in. That is deliberate and narrow: `status = 'published'` and nothing else.

### The lifecycle is a constraint, not a convention

```sql
CREATE FUNCTION enforce_meal_lifecycle() RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'archived' AND NEW.status <> 'archived' THEN
    RAISE EXCEPTION 'a retired Meal cannot return to offer';
  END IF;
  IF OLD.status = 'draft' AND NEW.status IN ('unavailable','archived') THEN
    RAISE EXCEPTION 'a draft goes on offer before it goes anywhere else';
  END IF;
  IF NEW.cook_id <> OLD.cook_id THEN
    RAISE EXCEPTION 'a Meal cannot change Cooks';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

FR-018 and FR-016 in SQL. The `cook_id` check duplicates the policy's `WITH CHECK` on purpose:
policies protect against a hostile client, constraints protect against Kafoo's own code, and the
two failure modes are different.

### `nutrition_source` cannot be claimed by the client

The one place where believing the client destroys the principle. A client that writes
`nutrition_source: 'cook'` over an untouched AI estimate turns a guess into an apparent
verification, and nothing downstream can tell.

```sql
-- Set nutrition_source from what actually changed, never from what the client asserts.
CREATE FUNCTION derive_nutrition_source() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND (NEW.calories IS DISTINCT FROM OLD.calories
          OR NEW.allergens IS DISTINCT FROM OLD.allergens) THEN
    NEW.nutrition_source := 'cook';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

A Cook who changes the number owns the number. A Cook who approves without changing it leaves an
estimate labelled as one — which is FR-011 and the whole of User Story 2, expressed where it cannot
be bypassed.

---

## `kitchen_profiles` — the policy E1 wrote out and left

E1 shipped with no public read on `kitchen_profiles`, deliberately, because discoverability follows
from having food on offer and there was none. The policy was written out ready in
`specs/002-identity-kitchen-profile/data-model.md`.

```sql
CREATE POLICY "anyone reads a kitchen with food on offer"
  ON kitchen_profiles FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM meals
                 WHERE meals.cook_id = kitchen_profiles.cook_id
                   AND meals.status = 'published'));
```

**This MUST be in the same migration file as `meals`.** Not the next one, not a follow-up. Without
it Kafoo has Meals on offer whose kitchens nobody can reach, and the failure is silent — queries
return zero rows rather than erroring, so every test passes and the product is broken.

`supabase/tests/kitchen_discoverability_test.sql` already exists and currently asserts that nobody
finds any kitchen. It flips in this feature. Its header says so.

---

## `meal-photos` bucket

Public read, writes confined to the owner's prefix — the same shape as `kitchen-photos` in E1.

| | |
|---|---|
| Path | `meal-photos/{auth.uid()}/{meal_id}.jpg` |
| Read | Public. A Meal on offer shows its photo to anyone. |
| Write / delete | `{auth.uid()}/` prefix only. |

**The photo path includes the Meal id** so a Cook with several Meals cannot overwrite one photo with
another, which the flat `{uid}/` layout in E1 would have allowed once a person owns more than one
thing.

---

## Entities in `packages/domain/`

No Flutter, no Supabase. Entities before behaviour, per the build sequence in `CLAUDE.md`.

| Type | Holds |
|---|---|
| `Meal` | The entity and its invariants. `canTransitionTo(status)` is domain logic and is unit-testable without a database. |
| `MealStatus` | The lifecycle enum. |
| `NutritionSource` | `ai` \| `cook`. A type rather than a string, so a call site cannot invent a third. |
| `MealStep` | The question sequence as data — what a Meal must say about itself, not a property of any screen. Same pattern as `conversation_step.dart` in E1. |
| `MealAnalysis` | What the AI Assistant proposed, before approval. Deliberately a separate type from `Meal`: a suggestion is not a Meal, and giving them the same type is how one becomes the other without anyone deciding. |

`MealAnalysis` being its own type is the domain-layer expression of Principle II. It cannot be
persisted, because the repository takes a `Meal`.

---

## Traceability

| Requirement | Enforced by | Would be wrong as |
|---|---|---|
| FR-016 non-transferable | `WITH CHECK` + lifecycle trigger | An application check |
| FR-017 needs a Kitchen Profile | See below | — |
| FR-018 lifecycle | `CHECK` + trigger | A switch statement in Dart |
| FR-021 price is whole cost | `numeric(10,2)`, `> 0` | A float |
| FR-022 owner-only change | `UPDATE` policy | Hiding the button |
| FR-023 unpublished invisible | Absence of a policy | A `WHERE` clause |
| FR-024 published public | `anon` `SELECT` policy | An API route |
| FR-025 kitchen findable | The widening policy above | A `visible` column |
| FR-011 source recorded truthfully | `derive_nutrition_source` trigger | The client's claim |
| FR-032 drafts owner-only | `status`-aware policies | — |

**FR-017 has no database enforcement, and that is a gap worth naming.** "A Meal cannot exist without
a Kitchen Profile" would need a foreign key to `kitchen_profiles` or a trigger checking one exists.
The plan is a trigger; the alternative — `cook_id` referencing `kitchen_profiles.cook_id` — is
tempting and wrong, because it makes a Meal belong to a Kitchen Profile rather than to a Cook, and
FR-016 says a Meal belongs to a Cook permanently.
