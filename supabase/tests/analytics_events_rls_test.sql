-- Authorization tests for analytics_events.
-- Written BEFORE the migration so they fail first, per constitution Principle III.
-- Run with: supabase test db

BEGIN;
SELECT plan(6);

-- Create two test users.
SELECT tests.create_supabase_user('person@test.kafoo');
SELECT tests.create_supabase_user('other@test.kafoo');

-- Seed one event as person.
SELECT tests.authenticate_as('person@test.kafoo');

INSERT INTO public.analytics_events (name, person_id)
VALUES (
  'SignInCompleted',
  (SELECT id FROM auth.users WHERE email = 'person@test.kafoo')
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
       (SELECT id FROM auth.users WHERE email = 'other@test.kafoo')
     ) $$,
  'person cannot attribute an event to someone else'
);

SELECT tests.clear_authentication();

-- 3. Anonymous inserts a non-funnel event → rejected.
SELECT tests.authenticate_as_anon();

SELECT throws_ok(
  $$ INSERT INTO public.analytics_events (name, person_id)
     VALUES ('KitchenProfileCreated', NULL) $$,
  'anonymous cannot insert non-funnel events'
);

SELECT tests.clear_authentication();

-- 4. Anonymous inserts SignInStarted with a non-null person_id → rejected.
SELECT tests.authenticate_as_anon();

SELECT throws_ok(
  $$ INSERT INTO public.analytics_events (name, person_id)
     VALUES (
       'SignInStarted',
       (SELECT id FROM auth.users WHERE email = 'person@test.kafoo')
     ) $$,
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

-- 6. Anyone updates an existing event → rejected (events are write-once).
SELECT tests.authenticate_as('other@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.analytics_events SET name = 'hacked' WHERE name = 'SignInCompleted' $$,
  'no one can update an existing event'
);

SELECT tests.clear_authentication();

SELECT finish();
ROLLBACK;
