# The local database

Kafoo's authorization suites run against a real Postgres started inside whatever container or
machine you are on. No Docker, no Supabase project, no secrets, no cost.

```bash
./scripts/local-db.sh test          # start if needed, apply migrations + seed, run every suite
./scripts/local-db.sh test supabase/tests/meals_rls_test.sql
./scripts/local-db.sh psql          # interactive shell on the same database
./scripts/local-db.sh stop          # tear the cluster down
```

## Why this exists

The constitution requires a negative test to be **seen to fail** before the policy it tests exists.
A suite that has only ever been green may be incapable of red, and the only way to know is to watch
it go red on purpose.

For most of this project that was impossible locally. `supabase test db` needs the Docker daemon,
the session container has none, and the recorded workaround was to push the test in its own commit
and read the pull request's CI — one extra push and a round trip for every red. E2's T014 and T020
both carry that note.

**Docker was never the requirement. Postgres was.** The distribution packages provide a full server;
`supabase start` uses Docker to run Postgres *plus* Auth, PostgREST, Storage and the rest. The
suites only ever needed the first one.

Being able to see red locally is not a convenience. It is the difference between following the
constitution's sequence and approximating it.

## How it was built

Four things, and the order matters:

**1. Postgres of the right major version.** Read from `supabase/config.toml`, never hardcoded. The
first version of this harness ran on Postgres 16 while `config.toml` pinned 17, so every local run
exercised the migrations against a different major version than the one they would be applied to —
the classic source of "it worked locally", and the same mistake `config.toml` itself records having
made in the opposite direction. Ubuntu ships one major version per release and it is usually not the
one Supabase runs, so `scripts/install-toolchain.sh` adds the PostgreSQL project's own apt
repository and installs `postgresql-<major>` and `postgresql-<major>-pgtap`.

**2. A cluster owned by an unprivileged user.** `initdb` refuses to run as root and the container is
root, so the script creates a `kafoopg` user and runs the cluster as that. It listens on a unix
socket only — nothing is exposed on a port.

**3. The Supabase objects the migrations reference.** `scripts/local-db-bootstrap.sql`: the `auth`,
`storage` and `extensions` schemas, the `anon` / `authenticated` / `service_role` roles, `auth.users`
cut down to the columns the seed actually writes, `auth.uid()` reading `request.jwt.claims`, and
`storage.objects` with `storage.foldername()`. It is deliberately minimal — the more of Supabase it
reimplements, the more confidently it can be wrong.

**4. Then the real migrations and the real seed**, unmodified, in order.

## What it proves, and what it does not

**Proves:** table shape, `CHECK` constraints, nullability, triggers, and every RLS policy as a SQL
predicate — which is what the suites assert.

**Does not prove:** that Supabase Auth issues the JWTs these policies read, that PostgREST exposes
what we think, or that the Storage service behaves as assumed. Those are stand-ins here.

Two of the stand-ins are where a wrong answer would come from, so they are worth knowing by name:

- **`auth.uid()`** reads `request.jwt.claims`, the same GUC PostgREST sets. The suites set it
  directly, so this is the real mechanism rather than an approximation.
- **The absent `DELETE` grant on `storage.objects`** stands in for Supabase routing deletion through
  its Storage API. This one was got wrong first in an instructive way: a `BEFORE DELETE` trigger
  raising `42501` was tried, and it never fired — RLS filters the other Cook's row out before any
  row-level trigger runs, so zero rows matched and the statement succeeded silently. **A row-scoped
  mechanism cannot produce a statement-level refusal.** Only running it showed the difference.

## The stand-in that was removed, and what it cost

**Table privileges used to be a stand-in here, and they were the wrong one.** The bootstrap granted
`ALL ON TABLES` to `anon`, `authenticated` and `service_role` through `ALTER DEFAULT PRIVILEGES`, on
the belief that Supabase does the same by default and that RLS is what actually restricts access.

Measured against the live project on 2026-08-05, the second half of that is true and the first half
is not. Every table there granted the API roles `TRUNCATE`, `REFERENCES`, `TRIGGER` and `MAINTAIN`
and none of `SELECT`, `INSERT`, `UPDATE` or `DELETE`, so every call through PostgREST came back
`42501 permission denied` — **the app could not read or write a single row in production**, for
E1's Kitchen Profiles as much as E2's Meals, while every suite in this directory was green.

That is the failure mode a stand-in has and a real system does not: **it can only ever make the
suite greener than reality.** Nothing inside a suite can audit the substitute the suite depends on,
so a substitute justified by an assumption rather than an observation will hide exactly the gap it
was supposed to model. This one was found by making a real call against the real deployment for an
unrelated reason — a latency measurement — not by any check that existed.

Table privileges are therefore no longer stood in for. They come from
`supabase/migrations/20260805180727_grant_data_api_privileges.sql`, the same place production gets
them, and `supabase/tests/data_api_grants_test.sql` fails if a table ever ships without them.

Sequences and functions still take blanket default grants, and that is not an oversight: nothing in
Kafoo's schema reaches a sequence or a public function through the API roles yet, so there is no
production evidence either way — and inventing a rule from no measurement is what produced the line
above.

### The same mistake, pointing the other way (2026-08-06)

Removing that line fixed the harness being *louder* than production. It left the harness **quieter**
than production, and that hid something too.

Production grants `TRUNCATE`, `REFERENCES`, `TRIGGER` and `MAINTAIN` to all three API roles on every
table, through a default privilege owned by `postgres`. The bootstrap granted none of them. So an
assertion that `anon` cannot `TRUNCATE` passed locally on the first run, before any migration
existed to make it true — a negative test that could not fail, which is the exact failure this
directory keeps turning up.

The bootstrap now reproduces that default privilege, and
`supabase/migrations/20260806063454_revoke_unused_table_privileges.sql` takes the four privileges
away again — including from the default, so the next table does not inherit them either. Delete that
migration and the guard in `data_api_grants_test.sql` goes red, naming every table, role and
privilege. That red was seen before the migration was written.

**The rule this leaves behind: a stand-in is wrong in both directions.** Granting something
production does not grant makes the suite greener than reality. *Withholding* something production
does grant makes a negative assertion unfalsifiable, which looks like coverage and is not. When you
add a role, a grant or a default privilege here, the question is not "is this enough for the tests
to pass" — it is "does this match what was measured against the live project, and on what date".

## Trusting it

It was validated rather than assumed. All existing suites pass with the same assertion count and the
same result as the last Supabase preview-branch run (54 at the time; 64 now with the draft
completeness suite). And it was shown capable of red using the mutation the workflow documents:
broadening the `kitchen_profiles` SELECT policy to `USING (true)` turns two assertions red, and a
clean rebuild returns to green.

If you add assertions, do the same. Break the thing on purpose, watch this fail, put it back.

## If it will not start

The script fails loudly rather than skipping when the pinned Postgres is missing, and tells you to
run `./scripts/install-toolchain.sh`. A gate that skips silently is worse than one that has not been
written, because it answers.
