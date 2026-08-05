-- Authorization tests for analytics_events.
-- Written BEFORE the migration so they fail first, per constitution Principle III.
-- Run with: supabase test db

BEGIN;
SELECT plan(7);

-- GRANTED HERE ON PURPOSE, AND ONLY HERE.
--
-- Production grants `authenticated` nothing but INSERT on this table
-- (`supabase/migrations/20260805180727_grant_data_api_privileges.sql`): events are write-once, so
-- SELECT and UPDATE are refused one layer below RLS. That is the stronger posture and it stays.
--
-- It also makes cases 1 and 6 below unable to test what they were written to test. "Zero rows come
-- back" and "no rows are updated" are claims about the POLICY layer, and with no grant the
-- statement raises 42501 before any policy is consulted — so a permissive SELECT policy added
-- tomorrow would not be caught here. Granting inside this transaction restores that coverage; the
-- ROLLBACK at the foot of the file is what keeps it out of any deployed database.
GRANT SELECT, UPDATE ON public.analytics_events TO authenticated;

-- Create two test users.
SELECT tests.create_supabase_user('person@test.kafoo');
SELECT tests.create_supabase_user('other@test.kafoo');

-- Seed one event as person.
SELECT tests.authenticate_as('person@test.kafoo');

INSERT INTO public.analytics_events (name, person_id)
VALUES (
  'SignInCompleted',
  tests.user_id('person@test.kafoo')
);

SELECT tests.clear_authentication();

-- 1. Owner reads their own events → zero rows (nobody reads through the app).
SELECT tests.authenticate_as('person@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.analytics_events),
  0,
  'person cannot read their own events (no SELECT policy)'
);

SELECT tests.clear_authentication();

-- 2. Owner inserts an event with person_id = Other → rejected.
SELECT tests.authenticate_as('person@test.kafoo');

SELECT throws_ok(
  $$ INSERT INTO public.analytics_events (name, person_id)
     VALUES (
       'SignInCompleted',
       tests.user_id('other@test.kafoo')
     ) $$,
  '42501',
  NULL,
  'person cannot attribute an event to someone else'
);

SELECT tests.clear_authentication();

-- 3. Anonymous inserts a non-funnel event → rejected.
SELECT tests.authenticate_as_anon();

SELECT throws_ok(
  $$ INSERT INTO public.analytics_events (name, person_id)
     VALUES ('KitchenProfileCreated', NULL) $$,
  '42501',
  NULL,
  'anonymous cannot insert non-funnel events'
);

SELECT tests.clear_authentication();

-- 4. Anonymous inserts SignInStarted with a non-null person_id → rejected.
SELECT tests.authenticate_as_anon();

SELECT throws_ok(
  $$ INSERT INTO public.analytics_events (name, person_id)
     VALUES (
       'SignInStarted',
       tests.user_id('person@test.kafoo')
     ) $$,
  '42501',
  NULL,
  'anonymous cannot insert a funnel event attributed to a person'
);

SELECT tests.clear_authentication();

-- 5. Deleting a person sets their events person_id to null and leaves rows in place (FR-039).
DELETE FROM auth.users WHERE email = 'person@test.kafoo';

SELECT is(
  (SELECT COUNT(*)::int FROM public.analytics_events WHERE name = 'SignInCompleted'),
  1,
  'events survive person deletion (ON DELETE SET NULL)'
);

SELECT is(
  (SELECT COUNT(*)::int FROM public.analytics_events
   WHERE name = 'SignInCompleted' AND person_id IS NULL),
  1,
  'person_id is null after person deletion'
);

-- 6. Anyone updates an existing event → nothing changes (events are write-once).
--
-- Asserted as the row being unchanged, not as an exception. With no UPDATE policy the statement
-- matches zero rows and raises nothing; RLS makes the row invisible rather than making the write an
-- error. Write-once still holds — it is enforced by absence, and absence is silent.
SELECT tests.authenticate_as('other@test.kafoo');

UPDATE public.analytics_events SET name = 'hacked' WHERE name = 'SignInCompleted';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.analytics_events WHERE name = 'hacked'),
  0,
  'no one can update an existing event'
);

SELECT finish();
ROLLBACK;
