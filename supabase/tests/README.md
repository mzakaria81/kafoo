# RLS tests

Every new table gets a test here proving a **non-owner reads zero rows**. Write the negative test
first — a policy nobody tested is a policy that does not work.

## Running them

```bash
supabase start
supabase db reset     # applies migrations, then seed.sql
supabase test db
```

`supabase db reset` is what installs the harness. `supabase/seed.sql` creates the pgTAP extension
and the `tests` schema these files depend on: `create_supabase_user`, `authenticate_as`,
`authenticate_as_anon`, `clear_authentication`. Running `supabase test db` against a database that
has not been reset fails on the first statement with "schema tests does not exist".

**These suites only run locally.** Seeds do not run against a deployed project, so a deployed
database has no `tests` schema and cannot execute them. That is deliberate — helpers that create
auth users have no business in production. To check a deployed project, read `pg_policies` and
compare the definitions against the contract; to check that the policies *behave*, use a local
database or a Supabase preview branch.

## How they prove anything

Each file is wrapped in `BEGIN … ROLLBACK`, so a run leaves nothing behind — the users and rows it
creates disappear with the transaction.

What makes the assertions meaningful is `tests.authenticate_as`, which switches the Postgres role to
`authenticated` and sets `request.jwt.claims`. RLS applies from that point because the connection is
no longer acting as the table owner. An assertion made after `tests.clear_authentication()` runs as
the owner and **bypasses RLS entirely** — it proves nothing about a policy. Pair every assertion
with the identity it is meant to be made under.

## Seeing them fail

A suite that has only ever been seen green is weak evidence: a test asserting nothing looks exactly
like a test whose policy is correct. Break a policy on purpose, watch the right assertion go red,
then `supabase db reset`. `docs/ops/verifying-e1.md` §5 walks it.

`scripts/verify.sh` enforces that a migration creating a table also enables RLS in the same file,
and `.claude/hooks/check-rls.sh` blocks the write before it is committed. Neither checks that the
policy is *correct*; that is what these tests are for.

See `.claude/rules/supabase.md` for the policy shape and `.claude/agents/rls-reviewer.md` for the
review checklist.
