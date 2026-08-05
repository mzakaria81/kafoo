-- GRANT-level assertions for the Data API roles.
--
-- Written AFTER the migration it tests, because the migration is the thing that must exist first
-- for production to work. The migration was derived from the policy set; this file proves the
-- derivation is correct and complete.
--
-- Run with: scripts/local-db.sh test
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- READ THIS BEFORE ADDING A TABLE.
--
-- The guard assertion at the foot of this file enumerates every ordinary table in public and
-- asserts each one grants at least one of SELECT/INSERT/UPDATE/DELETE to anon or authenticated.
-- A table added later with no grant turns this red and names the offending table.
--
-- If you create a new table, add its GRANT to the migration above and add the matching positive
-- assertions below. Do NOT add the table to the guard query — it reads pg_class dynamically.

BEGIN;
SELECT plan(23);

-- ── Positive: every cell of the matrix is present ───────────────────────────────────────────────

-- meals: anon gets SELECT only (published Meals are publicly readable).
SELECT ok(
  has_table_privilege('anon', 'public.meals', 'SELECT'),
  'anon can SELECT from meals');

-- meals: authenticated gets the full CRUD set (Cook owns their Meals).
SELECT ok(
  has_table_privilege('authenticated', 'public.meals', 'SELECT'),
  'authenticated can SELECT from meals');
SELECT ok(
  has_table_privilege('authenticated', 'public.meals', 'INSERT'),
  'authenticated can INSERT into meals');
SELECT ok(
  has_table_privilege('authenticated', 'public.meals', 'UPDATE'),
  'authenticated can UPDATE meals');
SELECT ok(
  has_table_privilege('authenticated', 'public.meals', 'DELETE'),
  'authenticated can DELETE from meals');

-- kitchen_profiles: anon gets SELECT (discoverable when a Cook has a published Meal).
SELECT ok(
  has_table_privilege('anon', 'public.kitchen_profiles', 'SELECT'),
  'anon can SELECT from kitchen_profiles');

-- kitchen_profiles: authenticated gets SELECT, INSERT, UPDATE (Cook owns their profile).
SELECT ok(
  has_table_privilege('authenticated', 'public.kitchen_profiles', 'SELECT'),
  'authenticated can SELECT from kitchen_profiles');
SELECT ok(
  has_table_privilege('authenticated', 'public.kitchen_profiles', 'INSERT'),
  'authenticated can INSERT into kitchen_profiles');
SELECT ok(
  has_table_privilege('authenticated', 'public.kitchen_profiles', 'UPDATE'),
  'authenticated can UPDATE kitchen_profiles');

-- analytics_events: anon and authenticated can INSERT (events are write-once).
SELECT ok(
  has_table_privilege('anon', 'public.analytics_events', 'INSERT'),
  'anon can INSERT into analytics_events');
SELECT ok(
  has_table_privilege('authenticated', 'public.analytics_events', 'INSERT'),
  'authenticated can INSERT into analytics_events');

-- analytics_events: service_role can INSERT (delete-account Edge Function writes AccountRemoved).
SELECT ok(
  has_table_privilege('service_role', 'public.analytics_events', 'INSERT'),
  'service_role can INSERT into analytics_events');

-- ── Negative: privileges deliberately withheld are absent ───────────────────────────────────────

-- anon must not write Meals — only read published ones.
SELECT ok(
  NOT has_table_privilege('anon', 'public.meals', 'INSERT'),
  'anon cannot INSERT into meals');
SELECT ok(
  NOT has_table_privilege('anon', 'public.meals', 'UPDATE'),
  'anon cannot UPDATE meals');
SELECT ok(
  NOT has_table_privilege('anon', 'public.meals', 'DELETE'),
  'anon cannot DELETE from meals');

-- anon must not read analytics_events — events are write-once, never surfaced.
SELECT ok(
  NOT has_table_privilege('anon', 'public.analytics_events', 'SELECT'),
  'anon cannot SELECT from analytics_events');

-- Write-once is enforced at the GRANT layer, not only by the absence of a policy. These four are
-- the assertions that keep it that way: an author who adds a SELECT or UPDATE policy to
-- analytics_events, or a DELETE policy to kitchen_profiles, has to come here and argue for the
-- grant as well. The RLS suites for those two tables grant these privileges to themselves inside
-- their own rolled-back transaction, which is why the policy layer is still covered.
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.analytics_events', 'SELECT'),
  'authenticated cannot SELECT from analytics_events');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.analytics_events', 'UPDATE'),
  'authenticated cannot UPDATE analytics_events');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.analytics_events', 'DELETE'),
  'authenticated cannot DELETE from analytics_events');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kitchen_profiles', 'DELETE'),
  'authenticated cannot DELETE from kitchen_profiles');

-- service_role must not read Meals — no Edge Function needs it.
SELECT ok(
  NOT has_table_privilege('service_role', 'public.meals', 'SELECT'),
  'service_role cannot SELECT from meals');

-- service_role must not delete analytics_events — events are write-once, even for service_role.
SELECT ok(
  NOT has_table_privilege('service_role', 'public.analytics_events', 'DELETE'),
  'service_role cannot DELETE from analytics_events');

-- ── Guard: every table in public must have at least one grant ───────────────────────────────────
--
-- Enumerates every ordinary table and asserts each one grants SELECT, INSERT, UPDATE or DELETE
-- to anon or authenticated. A table added later with no grant turns this red and names the
-- offending table.

SELECT is(
  (SELECT string_agg(table_name, ', ' ORDER BY table_name)
   FROM (
     SELECT c.relname AS table_name
     FROM pg_class c
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relkind = 'r'
       AND NOT (
         has_table_privilege('anon', c.oid, 'SELECT')
         OR has_table_privilege('anon', c.oid, 'INSERT')
         OR has_table_privilege('anon', c.oid, 'UPDATE')
         OR has_table_privilege('anon', c.oid, 'DELETE')
         OR has_table_privilege('authenticated', c.oid, 'SELECT')
         OR has_table_privilege('authenticated', c.oid, 'INSERT')
         OR has_table_privilege('authenticated', c.oid, 'UPDATE')
         OR has_table_privilege('authenticated', c.oid, 'DELETE')
       )
   ) missing
  ),
  NULL,
  'every table in public grants at least one CRUD privilege to anon or authenticated');

SELECT finish();
ROLLBACK;
