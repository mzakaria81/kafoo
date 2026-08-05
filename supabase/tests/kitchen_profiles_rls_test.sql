-- Authorization tests for kitchen_profiles.
-- Written BEFORE the migration so they fail first, per constitution Principle III.
-- Run with: supabase test db

BEGIN;
SELECT plan(11);

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

-- 8. Owner sets their own address form (grammatical verb form, not demographic).
SELECT tests.authenticate_as('owner@test.kafoo');

UPDATE public.kitchen_profiles
  SET address_form = 'feminine'
  WHERE cook_id = tests.user_id('owner@test.kafoo');

SELECT is(
  (SELECT address_form FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('owner@test.kafoo')),
  'feminine',
  'owner sets their own address form'
);

SELECT tests.clear_authentication();

-- 9. A non-owner cannot write another Cook's address form — while the kitchen is closed.
--
-- READ THIS BEFORE TRUSTING IT. It does not detect what its name suggests, and it is kept only
-- because the closed-kitchen case is worth pinning too.
--
-- Mutation-tested on 2026-08-05: with the UPDATE policy weakened to `USING (true) WITH CHECK
-- (true)`, this assertion still passed. What refuses the write here is the SELECT policy — this
-- fixture's Cook has no Meal on offer, so the row is invisible to the attacker and the UPDATE
-- never reaches the UPDATE policy at all. Exactly the trap case 3 above warns about, arriving on
-- schedule now that E2 has made kitchens with food on offer publicly readable.
--
-- The assertion that does bite lives in kitchen_discoverability_test.sql, case 33, where the
-- kitchen IS discoverable and the attacker really can see the row. If you are changing the UPDATE
-- policy, that is the test to watch, not this one.
--
-- Asserted with authentication cleared regardless, because a zero-rows-affected UPDATE under RLS
-- looks identical to a successful one if you only read back as the attacker.
SELECT tests.authenticate_as('other@test.kafoo');

UPDATE public.kitchen_profiles
  SET address_form = 'masculine'
  WHERE cook_id = tests.user_id('owner@test.kafoo');

SELECT tests.clear_authentication();

SELECT is(
  (SELECT address_form FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('owner@test.kafoo')),
  'feminine',
  'non-owner cannot write another Cook''s address form'
);

-- 10. An invalid address_form value is rejected by CHECK.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.kitchen_profiles
       SET address_form = 'polite'
       WHERE cook_id = tests.user_id('owner@test.kafoo') $$,
  '23514',
  NULL,
  'invalid address_form value is rejected by CHECK'
);

SELECT tests.clear_authentication();

-- 11. Unset address_form is legal — nullable, no default.
SELECT tests.authenticate_as('other@test.kafoo');

INSERT INTO public.kitchen_profiles
  (cook_id, display_name, story, area, delivery_terms)
VALUES (
  tests.user_id('other@test.kafoo'),
  'مطبخ تاني',
  'قصة تانية',
  'حدائق القبة',
  'شرط التوصيل'
);

SELECT is(
  (SELECT address_form FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('other@test.kafoo')),
  NULL,
  'unset address_form is legal and reads NULL'
);

SELECT tests.clear_authentication();

SELECT finish();
ROLLBACK;
