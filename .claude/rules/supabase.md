---
paths:
  - "supabase/**"
  - "**/*.sql"
---

# Supabase

## Precedence over the vendored Supabase skills

`.claude/skills/supabase`, `.claude/skills/supabase-postgres-best-practices` and
`.claude/skills/supabase-server` are third-party skills maintained by Supabase, vendored into this
repository on 2026-08-02 (`skills-lock.json` pins the versions). They are good general Postgres and
Supabase guidance and they do not know about Kafoo.

**Where they differ from this file, this file wins.** Two known differences:

- The RLS examples use `for all` policies. This file requires a policy **per operation**; a
  `FOR ALL` policy is not acceptable here even when its predicate is narrow.
- Their naming guidance stops at lowercase `snake_case`. Kafoo additionally requires plural table
  names and the glossary's vocabulary — `meals`, never `products`.

Neither is a reason to remove the skills. It is a reason not to treat them as the authority on a
question this repository has already answered.

## Legacy API keys — a real migration, not yet scheduled

The `supabase-server` skill states that `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are
legacy and will be deprecated in favour of publishable (`sb_publishable_…`) and secret
(`sb_secret_…`) keys, and it will propose migrating to the `@supabase/server` package on sight of
the old pattern.

Kafoo uses the legacy form in two places today — `supabase/functions/delete-account/index.ts` reads
`SUPABASE_SERVICE_ROLE_KEY`, and `apps/mobile/lib/main.dart` reads `SUPABASE_ANON_KEY`. The
environment already carries a `SUPABASE_PUBLISHABLE_KEY` alongside them.

**Do not migrate opportunistically.** Adopting `@supabase/server` is a new runtime dependency in the
Edge Function path and changes how inbound requests are authenticated — an ADR and a founder
decision, not a refactor to slip into an unrelated change. Until that decision exists, leave the
existing keys alone and do not rewrite a working function because a skill suggested it.

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
