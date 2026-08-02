-- Local test harness. Runs on `supabase db reset`; never on `supabase db push`.
--
-- E1's authorization tests call pgTAP (`plan`, `is`, `throws_ok`, `finish`) and four helpers in a
-- `tests` schema. Neither existed anywhere in this repository, so `supabase test db` failed at the
-- first statement — which is part of why those suites had never been seen to run.
--
-- The helpers are vendored rather than pulled from database.dev on purpose: a test harness that
-- needs the network to start is a test harness that fails in CI for reasons unrelated to the code.
--
-- WHERE THIS RUNS. All three cases measured on 2026-08-02, after this comment had been wrong twice
-- in opposite directions:
--
--   Locally                    — yes, on `supabase db reset`.
--   Git-linked preview branch  — yes. Confirmed on branch coamyiukxwrsnvyyextf (pull request #16):
--                                `tests` schema present, pgTAP installed, all four helpers created.
--   Hand-created branch        — no. The `staging` branch got all three migrations and not this
--                                file, because a branch with no repository behind it has nothing to
--                                read the seed from.
--   Production                 — no. `supabase db push` applies migrations only.
--
-- Why it matters: a preview branch is a real, internet-facing Supabase project with its own URL and
-- anon key. This file installs a user-creating helper there, which is what the REVOKE at the foot of
-- the file is for.
--
-- Note for editing this file: Supabase pushes only *new* migration files on each commit to an open
-- pull request. Changing this seed and pushing does not re-run it — close and reopen the pull
-- request, or the branch keeps the previous version.

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS tests;

-- Fixture directory: which test person got which id.
--
-- The suites need a person's id while acting AS that person, and neither anon nor authenticated may
-- read auth.users in any Supabase project — that is one of the reasons the suites had never run.
-- Every id in here was minted by tests.create_supabase_user moments earlier, so exposing it to the
-- test roles reveals nothing they did not just create.
--
-- Deliberately a table and not a SECURITY DEFINER lookup over auth.users. A definer function would
-- answer for *any* address, including a real person's, which is a worse thing to leave lying around
-- than a list of fixtures. This holds only what the harness created.
--
-- No RLS, and that is not a breach of the same-migration rule in CLAUDE.md: this is not a migration
-- and this table never exists in production. seed.sql runs locally and on preview branches only, the
-- `tests` schema is absent from api.schemas so PostgREST does not expose it, and every row is
-- written and rolled back inside a suite's own transaction.
CREATE TABLE IF NOT EXISTS tests.registry (
  email text PRIMARY KEY,
  id    uuid NOT NULL
);

-- Create a person the way Supabase Auth would, so foreign keys to auth.users resolve.
--
-- The argument is the email address, because that is how the suites refer to their fixtures.
-- Named p_email, not email: a PL/pgSQL parameter sharing a name with a column of a table the body
-- writes to makes every mention of it ambiguous, and Postgres rejects the function at run time.
CREATE OR REPLACE FUNCTION tests.create_supabase_user(p_email text)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
  uid uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (
    id, instance_id, aud, role, email,
    encrypted_password, email_confirmed_at,
    created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', p_email,
    'not-a-real-password-hash', now(),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    '', '', '', ''
  );

  INSERT INTO tests.registry (email, id) VALUES (p_email, uid)
  ON CONFLICT (email) DO UPDATE SET id = EXCLUDED.id;

  RETURN uid;
END;
$$;

-- Resolve a fixture's id. This is what the suites call instead of reading auth.users.
CREATE OR REPLACE FUNCTION tests.user_id(email text)
RETURNS uuid
LANGUAGE sql
STABLE
AS $$ SELECT r.id FROM tests.registry r WHERE r.email = user_id.email $$;

-- Become that person for the rest of the transaction.
--
-- `set_config(..., true)` is transaction-local, which is what makes the suites' BEGIN/ROLLBACK
-- leave nothing behind. RLS applies from here on, because the role is no longer the owner.
CREATE OR REPLACE FUNCTION tests.authenticate_as(email text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  uid uuid;
BEGIN
  SELECT u.id INTO uid FROM auth.users u WHERE u.email = authenticate_as.email;

  IF uid IS NULL THEN
    RAISE EXCEPTION 'tests.authenticate_as: no user with email %. Call tests.create_supabase_user first.', email;
  END IF;

  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated', 'email', email)::text,
    true
  );
END;
$$;

-- Become a signed-out visitor. auth.uid() returns NULL from here.
CREATE OR REPLACE FUNCTION tests.authenticate_as_anon()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('role', 'anon', true);
  PERFORM set_config('request.jwt.claims', null, true);
END;
$$;

-- Back to the table owner, which bypasses RLS. Always pair this with an authenticate_as —
-- assertions made while still in this state prove nothing about policies.
CREATE OR REPLACE FUNCTION tests.clear_authentication()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', null, true);
END;
$$;

-- Lock down the one helper that writes.
--
-- This file now runs on preview branches, which are reachable from the internet with a published
-- anon key, so "only a test harness would call this" stops being an argument. tests.create_supabase_user
-- inserts straight into auth.users, bypassing sign-up, rate limiting and phone verification.
--
-- Three things already stop an end user reaching it: the `tests` schema is absent from
-- `api.schemas`, so PostgREST does not expose it; the function is SECURITY INVOKER; and neither
-- anon nor authenticated holds INSERT on auth.users. None of those was chosen to defend this
-- function, and any of them could change without anyone connecting the change to this file. Say it
-- directly instead of relying on three accidents.
--
-- Scoped to create_supabase_user ONLY. The other three helpers must stay callable by anon and
-- authenticated: every suite calls tests.clear_authentication() *while* acting as one of those
-- roles, so revoking them here would fail every authorization test in supabase/tests/.
--
-- Verified on branch coamyiukxwrsnvyyextf, 2026-08-02 — its first execution anywhere:
--   create_supabase_user   anon=false authenticated=false
--   authenticate_as        anon=true  authenticated=true
--   authenticate_as_anon   anon=true  authenticated=true
--   clear_authentication   anon=true  authenticated=true
-- and a PostgREST call to the tests schema returns 404.
REVOKE ALL ON FUNCTION tests.create_supabase_user(text) FROM PUBLIC, anon, authenticated;

-- EXECUTE alone is not enough, and reading it as though it were produced a wrong conclusion once.
-- Calling tests.foo() needs USAGE on the schema as well; a new schema grants USAGE to nobody. So
-- the three privileges above read as granted while every call raised "permission denied for schema
-- tests" — which is one of two reasons the suites in supabase/tests/ have never run.
--
-- Safe to grant: the `tests` schema is absent from api.schemas, so PostgREST does not expose it
-- (checked — an RPC call returns 404), and create_supabase_user stays revoked above.
GRANT USAGE ON SCHEMA tests TO anon, authenticated;

-- The fixture directory, for the same reason. Note what is NOT here: no grant on auth.users. The
-- quick way to make these suites run was to give the test roles read access to it, and that would
-- have loosened the exact database the suites exist to check — a green test bought that way proves
-- less than nothing.
GRANT SELECT ON tests.registry TO anon, authenticated;
GRANT EXECUTE ON FUNCTION tests.user_id(text) TO anon, authenticated;
