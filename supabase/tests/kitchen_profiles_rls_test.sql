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
  tests.user_id('owner@test.kafoo'),
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
  WHERE cook_id = tests.user_id('owner@test.kafoo');

SELECT is(
  (SELECT display_name FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('owner@test.kafoo')),
  NULL,
  'other cannot update owner kitchen profile (reads null because no SELECT access)'
);

SELECT tests.clear_authentication();

-- 3. Owner tries to set cook_id to Other → rejected.
--
-- READ THIS BEFORE RELYING ON IT. The comment here used to say "rejected by WITH CHECK — this is
-- the critical test: USING alone is not enough". Mutation-tested on 2026-08-02 and that is not what
-- the test detects: with the policy weakened to `WITH CHECK (true)`, this assertion still passed.
--
-- What actually refuses the reassign today is the SELECT policy. Postgres applies it to the *new*
-- row, and a row whose cook_id is someone else is not one this Cook may see, so the update is
-- refused with 42501. Measured both ways: SELECT policy present -> 42501; SELECT policy dropped and
-- WITH CHECK (true) -> the reassign succeeds silently.
--
-- So WITH CHECK is redundant *while* kitchens are private, and becomes the only guard the moment
-- they are not. FR-030 makes a kitchen publicly discoverable once its Cook has a published Meal
-- (E2), which broadens the SELECT policy — and on that day this test stops covering the thing its
-- name suggests. Whoever writes that migration must add an assertion that fails with
-- `WITH CHECK (true)` in place, because this one will not.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.kitchen_profiles
       SET cook_id = tests.user_id('other@test.kafoo')
       WHERE cook_id = tests.user_id('owner@test.kafoo') $$,
  '42501',
  NULL,
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
       tests.user_id('owner@test.kafoo'),
       'مطبخ تاني',
       'قصة تانية',
       'حدائق القبة',
       'شرط التوصيل'
     ) $$,
  '23505',
  NULL,
  'owner cannot create a second kitchen profile (UNIQUE cook_id)'
);

SELECT tests.clear_authentication();

-- 6. Owner creates a Kitchen Profile with cook_id = Other → rejected by WITH CHECK.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ INSERT INTO public.kitchen_profiles
       (cook_id, display_name, story, area, delivery_terms)
     VALUES (
       tests.user_id('other@test.kafoo'),
       'مطبخ مزيف',
       'قصة مزيفة',
       'منطقة ما',
       'شرط ما'
     ) $$,
  '42501',
  NULL,
  'owner cannot create kitchen profile for another person (WITH CHECK)'
);

SELECT tests.clear_authentication();

-- 7. Anyone tries to DELETE a Kitchen Profile → nothing is deleted (no DELETE policy).
--
-- Asserted as survival of the row, not as an exception. A DELETE that RLS filters removes zero rows
-- and raises nothing: the row is simply not visible to the statement, and deleting nothing is not an
-- error. The original throws_ok could never have passed — and it would have gone on reporting red
-- while the property it cared about was in fact holding, which is the worst of both.
SELECT tests.authenticate_as('owner@test.kafoo');

DELETE FROM public.kitchen_profiles
  WHERE cook_id = tests.user_id('owner@test.kafoo');

SELECT tests.clear_authentication();

-- Counted with authentication cleared, so this sees the table as it really is rather than through
-- the owner's own SELECT policy.
SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('owner@test.kafoo')),
  1,
  'no one can delete a kitchen profile directly'
);

SELECT finish();
ROLLBACK;
