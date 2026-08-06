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
SELECT plan(28);

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

-- ── Negative: the four privileges nothing in Kafoo uses ─────────────────────────────────────────
--
-- TRUNCATE, REFERENCES, TRIGGER and MAINTAIN were held by anon, authenticated and service_role on
-- every table in public, measured against the live project on 2026-08-05 and again on 2026-08-06.
-- They arrive by default privilege rather than by anyone granting them, which is why every table
-- had them and why a table created tomorrow would have had them too.
--
-- TRUNCATE is the one that matters. **It ignores RLS entirely** — there is no policy that can
-- refuse it, because policies filter rows and TRUNCATE does not read rows. A single statement
-- empties a table. The others are smaller: REFERENCES lets a foreign key be pointed at a table,
-- TRIGGER lets code be attached to it, MAINTAIN allows VACUUM and ANALYZE.
--
-- **This is defence in depth, not a closed door.** PostgREST does not expose TRUNCATE, so nothing
-- reachable with an anon key could have called it. It is revoked because it is exactly the "grant
-- wider than the policy set" the grants migration argues against in its own comment — and it
-- survived that migration.
--
-- service_role keeps nothing here either. Its key never reaches a phone, so the exposure is
-- different in kind; but no Edge Function truncates, references, triggers or maintains anything,
-- and a privilege no caller needs is a privilege to remove.

SELECT ok(
  NOT has_table_privilege('anon', 'public.meals', 'TRUNCATE'),
  'anon cannot TRUNCATE meals');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.meals', 'TRUNCATE'),
  'authenticated cannot TRUNCATE meals');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kitchen_profiles', 'TRUNCATE'),
  'authenticated cannot TRUNCATE kitchen_profiles');
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.analytics_events', 'TRUNCATE'),
  'authenticated cannot TRUNCATE analytics_events');

-- ── Guard: no role holds a privilege Kafoo does not use ─────────────────────────────────────────
--
-- Dynamic, like the guard below it, and for the same reason: the four assertions above name three
-- tables, and the next table added will not be in that list. This one enumerates every ordinary
-- table in public and names any that still hands one of the four to any Data API role.
--
-- It is also what makes the revoke durable. `REVOKE ... ON ALL TABLES` fixes the tables that exist
-- when it runs and says nothing about the next one, which inherits by default privilege. This
-- assertion is the thing that notices.
--
-- AND IT IS WHY THIS READS pg_class RATHER THAN A LIST OF TABLE NAMES. Production carries a second
-- default privilege, owned by `supabase_admin`, that grants all four privileges plus full CRUD —
-- and `postgres` is not a member of `supabase_admin`, so no migration of ours can revoke it. It
-- applies only to tables `supabase_admin` itself creates, which is none of Kafoo's; but if a
-- platform feature ever creates one, this assertion sees it, because it asks what a table HOLDS and
-- never who made it. See `docs/ops/local-database.md`.

SELECT is(
  (SELECT string_agg(DISTINCT c.relname || ' (' || r.rolname || ': ' || p.priv || ')', ', ')
   FROM pg_class c
   JOIN pg_namespace n ON n.oid = c.relnamespace
   CROSS JOIN (SELECT unnest(ARRAY['anon', 'authenticated', 'service_role']) AS rolname) r
   CROSS JOIN (SELECT unnest(ARRAY['TRUNCATE', 'REFERENCES', 'TRIGGER', 'MAINTAIN']) AS priv) p
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND has_table_privilege(r.rolname, c.oid, p.priv)
  ),
  NULL,
  'no Data API role holds TRUNCATE, REFERENCES, TRIGGER or MAINTAIN on any table in public');

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
