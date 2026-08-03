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
