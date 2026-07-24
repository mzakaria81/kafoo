---
paths:
  - "supabase/**"
  - "**/*.sql"
---

# Supabase

## Migrations

Create with `supabase migration new <name>`. Never hand-write the timestamp prefix — collisions are
silent and painful.

Migrations are append-only once merged to `main`. To change a shipped migration, write a new one.

Every migration must be reversible in practice: if it drops or renames a column holding data, the
migration includes the backfill, and the PR description says what is lost.

`supabase db reset` is safe locally and forbidden against staging or production.

## Row Level Security — mandatory

**Every `CREATE TABLE` is followed by `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` in the same
migration file.** No exceptions, no "we'll add it later." A table shipped without RLS is a data
breach with a delay fuse.

Policies are written per operation (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) and per role. One
catch-all `FOR ALL USING (true)` policy defeats the entire mechanism.

Default posture is deny. Grant the narrowest predicate that makes the feature work.

Standard shape:

```sql
CREATE TABLE meals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cook_id uuid NOT NULL REFERENCES cooks(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','published','unavailable','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE meals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public reads published meals"
  ON meals FOR SELECT
  USING (status = 'published');

CREATE POLICY "cook reads own meals"
  ON meals FOR SELECT TO authenticated
  USING (cook_id = auth.uid());

CREATE POLICY "cook writes own meals"
  ON meals FOR INSERT TO authenticated
  WITH CHECK (cook_id = auth.uid());

CREATE POLICY "cook updates own meals"
  ON meals FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (cook_id = auth.uid());
```

Note both `USING` and `WITH CHECK` on `UPDATE`. Omitting `WITH CHECK` lets a Cook reassign a Meal to
someone else.

## RLS tests are not optional

Every new table gets a test in `supabase/tests/` proving a non-owner receives zero rows. Write the
negative test first. A policy nobody tested is a policy that does not work.

## Naming

Tables: plural, snake_case, no abbreviations — `meals`, `orders`, `kitchen_profiles`.
Columns: snake_case. Foreign keys: `<singular>_id`.
Match `docs/vision/glossary.md`. Never `products`, `vendors`, `stores`, `listings`.

## Every table has

`id uuid PRIMARY KEY`, `created_at timestamptz NOT NULL DEFAULT now()`,
`updated_at timestamptz NOT NULL DEFAULT now()` with a trigger, and an explicit owner column.

## Constraints belong in the database

Business invariants get `CHECK` constraints and foreign keys, not just Dart validation. "A Review
requires a completed Order" is enforced by SQL. Application-layer-only validation is a suggestion.

## Indexes

Add an index with the query that needs it, in the same migration. Foreign keys used in RLS
predicates are indexed — an unindexed `cook_id` makes every policy evaluation a sequential scan.

Vector columns for semantic search use `pgvector` with an HNSW index. Cross-language search
(`برجر` → Burger) is an embedding concern, not a `LIKE` query. Never implement search with `ILIKE`.

## Edge Functions

Deno. Validate every input with Zod at the boundary. Never trust a client-supplied `user_id` — read
it from the JWT. Never use the service-role key in a function reachable by an end user without an
explicit authorization check first.

Secrets come from environment variables. A hardcoded key in a function is a rotate-everything
incident.
