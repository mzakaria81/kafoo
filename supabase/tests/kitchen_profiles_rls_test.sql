-- Authorization tests for kitchen_profiles.
-- Written BEFORE the migration so they fail first, per constitution Principle III.
-- Run with: supabase test db

BEGIN;
SELECT plan(7);

-- Create two test users.
SELECT tests.create_supabase_user('owner@test.kafoo');
SELECT tests.create_supabase_user('other@test.kafoo');

-- Seed one Kitchen Profile as owner.
SELECT tests.authenticate_as('owner@test.kafoo');

INSERT INTO public.kitchen_profiles
  (cook_id, display_name, story, area, delivery_terms)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo'),
  'مطبخ الأم',
  'بنعمل أكل بيتي بحب',
  'مدينة نصر',
  'توصيل في نفس الحي'
);

SELECT tests.clear_authentication();

-- 1. Other reads Owner's Kitchen Profile → zero rows, no error.
SELECT tests.authenticate_as('other@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  0,
  'other cannot read owner kitchen profile'
);

SELECT tests.clear_authentication();

-- 2. Other updates Owner's Kitchen Profile → zero rows affected; row unchanged.
SELECT tests.authenticate_as('other@test.kafoo');

UPDATE public.kitchen_profiles
  SET display_name = 'hacked'
  WHERE cook_id = (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo');

SELECT is(
  (SELECT display_name FROM public.kitchen_profiles
   WHERE cook_id = (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo')),
  NULL,
  'other cannot update owner kitchen profile (reads null because no SELECT access)'
);

SELECT tests.clear_authentication();

-- 3. Owner tries to set cook_id to Other → rejected by WITH CHECK.
-- This is the critical test: USING alone is not enough.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.kitchen_profiles
       SET cook_id = (SELECT id FROM auth.users WHERE email = 'other@test.kafoo')
       WHERE cook_id = (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo') $$,
  'owner cannot reassign cook_id to another person (WITH CHECK)'
);

SELECT tests.clear_authentication();

-- 4. Anonymous reads any Kitchen Profile → zero rows (E1 discovers nothing).
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  0,
  'anonymous cannot read any kitchen profile'
);

SELECT tests.clear_authentication();

-- 5. Owner tries to create a second Kitchen Profile → rejected by UNIQUE (cook_id).
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ INSERT INTO public.kitchen_profiles
       (cook_id, display_name, story, area, delivery_terms)
     VALUES (
       (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo'),
       'مطبخ تاني',
       'قصة تانية',
       'حدائق القبة',
       'شرط التوصيل'
     ) $$,
  'owner cannot create a second kitchen profile (UNIQUE cook_id)'
);

SELECT tests.clear_authentication();

-- 6. Owner creates a Kitchen Profile with cook_id = Other → rejected by WITH CHECK.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ INSERT INTO public.kitchen_profiles
       (cook_id, display_name, story, area, delivery_terms)
     VALUES (
       (SELECT id FROM auth.users WHERE email = 'other@test.kafoo'),
       'مطبخ مزيف',
       'قصة مزيفة',
       'منطقة ما',
       'شرط ما'
     ) $$,
  'owner cannot create kitchen profile for another person (WITH CHECK)'
);

SELECT tests.clear_authentication();

-- 7. Anyone tries to DELETE a Kitchen Profile → rejected (no DELETE policy).
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ DELETE FROM public.kitchen_profiles
       WHERE cook_id = (SELECT id FROM auth.users WHERE email = 'owner@test.kafoo') $$,
  'no one can delete a kitchen profile directly'
);

SELECT tests.clear_authentication();

SELECT finish();
ROLLBACK;
