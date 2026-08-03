-- The smallest set of Supabase objects Kafoo's migrations actually reference.
--
-- Supabase provides these in every real project; a distribution Postgres does not. This file is a
-- STAND-IN, and naming that plainly matters more than the SQL does: a local suite passing against
-- these stubs proves the migrations' own logic, not that Supabase behaves this way. The
-- Authorization workflow, which runs against a real preview branch, is what proves the second
-- thing.
--
-- Everything here is derived from what `grep`ping supabase/migrations turned up, so it grows only
-- when a migration reaches for something new. Keeping it minimal is deliberate: the more of
-- Supabase this reimplements, the more confidently it can be wrong.

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS extensions;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

-- supabase/config.toml sets extra_search_path = ["public", "extensions"], which is how the suites
-- reach pgTAP's plan()/is()/throws_ok() unqualified. Without it every suite dies on its first
-- statement with "function plan(integer) does not exist" — which looks like a broken harness and is
-- actually a missing search path.
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET search_path = public, extensions', current_database());
END
$$;

-- gen_random_uuid() is expected unqualified by the migrations.
CREATE OR REPLACE FUNCTION public.gen_random_uuid() RETURNS uuid
  LANGUAGE sql AS $$ SELECT extensions.gen_random_uuid() $$;

-- The roles RLS policies are written against. NOLOGIN: nothing signs in as these here, the suites
-- reach them with SET LOCAL ROLE the same way PostgREST does.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public, extensions, auth, storage TO anon, authenticated, service_role;

-- Supabase grants the API roles table privileges by default, and RLS is what actually restricts
-- them. Without this every suite dies on "permission denied", which reads like a policy denying
-- access and is really the GRANT layer underneath it — the two are easy to confuse and only one of
-- them is what the suites are testing.
--
-- Set BEFORE the migrations run, so it applies to every table they create.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

-- Supabase's auth.users, cut down to the columns Kafoo's foreign keys and helpers touch.
-- Columns are exactly those tests.create_supabase_user in supabase/seed.sql writes, plus the keys
-- Kafoo's own migrations reference. Real auth.users has many more; adding them here would be
-- inventing a schema rather than standing in for one.
CREATE TABLE IF NOT EXISTS auth.users (
  id                     uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  instance_id            uuid,
  aud                    varchar(255),
  role                   varchar(255),
  email                  varchar(255) UNIQUE,
  phone                  text UNIQUE,
  encrypted_password     varchar(255),
  email_confirmed_at     timestamptz,
  raw_app_meta_data      jsonb,
  raw_user_meta_data     jsonb,
  confirmation_token     varchar(255),
  recovery_token         varchar(255),
  email_change_token_new varchar(255),
  email_change           varchar(255),
  last_sign_in_at        timestamptz,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

-- auth.uid() reads the request's JWT claims, which PostgREST sets per statement. The suites set
-- the same GUC directly, so this is the real mechanism rather than an approximation of it.
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
  LANGUAGE sql STABLE AS $$
    SELECT NULLIF(
      current_setting('request.jwt.claims', true)::json ->> 'sub',
      ''
    )::uuid
  $$;

CREATE OR REPLACE FUNCTION auth.role() RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
      current_setting('request.jwt.claims', true)::json ->> 'role',
      current_user
    )
  $$;

GRANT EXECUTE ON FUNCTION auth.uid(), auth.role() TO anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS storage.buckets (
  id                 text PRIMARY KEY,
  name               text NOT NULL,
  public             boolean NOT NULL DEFAULT false,
  file_size_limit    bigint,
  allowed_mime_types text[],
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS storage.objects (
  id         uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  bucket_id  text REFERENCES storage.buckets(id),
  name       text,
  owner      uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Splits an object name on '/', which is how every storage policy in this repository scopes a file
-- to its owner's folder.
CREATE OR REPLACE FUNCTION storage.foldername(name text) RETURNS text[]
  LANGUAGE sql IMMUTABLE AS $$ SELECT string_to_array(name, '/') $$;

GRANT EXECUTE ON FUNCTION storage.foldername(text) TO anon, authenticated, service_role;
-- DELETE is deliberately NOT granted, and this is the mechanism rather than a simplification.
--
-- Supabase routes object deletion through the Storage API, which acts with its own privileges, so
-- a client role holding a JWT cannot issue a direct DELETE at all — the statement is refused with
-- insufficient_privilege (42501) before RLS is consulted. meal_photos_storage_test.sql asserts that
-- code, and observed it on a real preview branch.
--
-- Worth recording how this was got wrong first, because the wrong version looked right: a BEFORE
-- DELETE trigger raising 42501 was tried, and it never fired. RLS filters the other Cook's row out
-- before any row-level trigger runs, so zero rows matched and the statement succeeded silently.
-- A row-scoped mechanism cannot produce a statement-level refusal, and only running it showed that.
GRANT SELECT, INSERT, UPDATE ON storage.objects TO authenticated, anon;
GRANT SELECT ON storage.buckets TO authenticated, anon;
