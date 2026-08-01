-- Local test harness. Runs on `supabase db reset`; never on `supabase db push`.
--
-- E1's authorization tests call pgTAP (`plan`, `is`, `throws_ok`, `finish`) and four helpers in a
-- `tests` schema. Neither existed anywhere in this repository, so `supabase test db` failed at the
-- first statement — which is part of why those suites had never been seen to run.
--
-- The helpers are vendored rather than pulled from database.dev on purpose: a test harness that
-- needs the network to start is a test harness that fails in CI for reasons unrelated to the code.
--
-- Nothing here reaches a deployed project. Seed files are local-only, and installing user-creating
-- helpers into production would be a footgun left lying around.

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS tests;

-- Create a person the way Supabase Auth would, so foreign keys to auth.users resolve.
--
-- The argument is the email address, because the suites look users up by it
-- (`SELECT id FROM auth.users WHERE email = 'owner@test.kafoo'`).
CREATE OR REPLACE FUNCTION tests.create_supabase_user(email text)
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
    uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', email,
    'not-a-real-password-hash', now(),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
    '', '', '', ''
  );
  RETURN uid;
END;
$$;

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
