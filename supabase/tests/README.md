# RLS tests

Every new table gets a test here proving a **non-owner reads zero rows**. Write the negative test
first — a policy nobody tested is a policy that does not work.

## Running them

```bash
./scripts/local-db.sh test                              # every suite
./scripts/local-db.sh test supabase/tests/meals_rls_test.sql   # just one
./scripts/local-db.sh psql                              # a shell on the same database
./scripts/local-db.sh stop                              # tear it down
```

That starts a real Postgres of the major version `supabase/config.toml` pins, applies every
migration and `seed.sql`, and runs the suites against the result. **No Docker.** It was believed for
some time that these suites could not run in a container without the Docker daemon; Docker was never
the requirement, Postgres was, and `./scripts/install-toolchain.sh` installs it.

`supabase start && supabase db reset && supabase test db` still works where the Docker daemon exists
and is the closest thing to the real project. Both apply the same migrations and the same seed.

`supabase db reset` — or the harness — is what installs the fixtures. `supabase/seed.sql` creates the pgTAP extension
and the `tests` schema these files depend on: `create_supabase_user`, `authenticate_as`,
`authenticate_as_anon`, `clear_authentication`. Running `supabase test db` against a database that
has not been reset fails on the first statement with "schema tests does not exist".

`tests.user_id('someone@test.kafoo')` resolves a fixture's id. Do **not** replace it with
`SELECT id FROM auth.users WHERE email = …`: no Supabase project grants `anon` or `authenticated`
any access to `auth.users`, so that read fails the moment a suite is acting as one of them. It is how
these suites were originally written and one of the reasons they had never run.

**Where they run.** Locally via `scripts/local-db.sh`, and in CI on every pull request that touches
`supabase/` — the `Authorization` workflow builds the same Postgres in the runner and runs the same
script. One definition of passing, and the same one you get on your own machine.

They used to run against a Supabase preview branch built per pull request. That was real Supabase —
real Auth, real PostgREST, real Storage — and it was also a billed project per pull request, and it
put a build-and-wait cycle between writing a negative test and seeing it fail. The local harness
gives that answer in seconds and costs nothing.

**What the local harness cannot tell you** is written at the top of `scripts/local-db-bootstrap.sql`:
it stands in for `auth.uid()`, the API roles, and the storage service, so it proves the schema, the
constraints, the triggers and the policies as SQL, and not that Supabase's own services behave as
assumed around them. That is a real gap. Weigh it before shipping anything whose safety rests on
Supabase behaviour rather than on a policy predicate.

**Never against production.** Seeds do not run there, so production has no `tests` schema and cannot
execute them — deliberate, since helpers that create auth users have no business in a live database.
To check production, read `pg_policies` and compare against the contract.

## The mutation check runs itself now

`meals_rls_test.sql` ends with an assertion that weakens the `UPDATE` policy to `WITH CHECK (true)`,
disables the trigger that would otherwise answer first, and proves the reassign then **succeeds**.
That is case 8b's sensitivity, measured on every commit instead of remembered from an exercise
somebody did once.

Two reasons it lives in the suite rather than in a runbook. A manual mutation is only true on the
day it is performed, and a policy rewritten later is covered by nobody's memory of it. And on this
project the manual version is not reachable anyway: **Supabase pushes only new migration files to a
preview branch**, so editing the migration that created a policy changes nothing on the database
the suites actually run against.

Copy the shape when you add an assertion whose failure mode is "quietly stops testing anything".

## Confirm they can fail

These suites passed for the first time on 2026-08-02, and a suite that has only ever been green may
be incapable of red. They were mutation-tested: adding
`CREATE POLICY … ON kitchen_profiles FOR SELECT TO authenticated USING (true)` — a real data breach —
turns `kitchen_profiles_rls_test.sql` red. Do the same before trusting any assertion you add here.

That exercise also found that test 3 does not detect what its name suggested; see the comment above
it. Weakening `WITH CHECK` alone leaves the suite green, because the SELECT policy independently
refuses the reassign today. It will stop doing so when FR-030 makes kitchens publicly discoverable.

**E2 inherited that trap and handled it explicitly.** `meals_rls_test.sql` case 8 attempts the
reassign on a *published* Meal, so the SELECT layer cannot mask the result — but the BEFORE UPDATE
trigger still answers before `WITH CHECK` is evaluated, because that is the order Postgres runs them
in. Case 8b therefore disables the trigger for one statement and asserts `42501`, isolating the
policy. **8b is the mutation target for the `meals` UPDATE policy**: write `WITH CHECK (true)` and
8b must go red while 8 stays green. Anywhere a rule is deliberately enforced twice, expect to need
an assertion per layer — one assertion cannot mutation-test both.

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
