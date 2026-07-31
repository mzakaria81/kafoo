-- Discoverability contract for kitchen_profiles (US4, FR-019, FR-030).
--
-- READ THIS BEFORE "FIXING" A FAILURE HERE.
--
-- Every count below is expected to be ZERO, and that is correct in E1, not a
-- bug. FR-030 makes a kitchen discoverable only while its Cook has a published
-- Meal, and `meals` does not exist yet. The right way to make these numbers
-- non-zero is to create `meals` in E2 and add the widening SELECT policy that
-- data-model.md has already written out — never to add a public policy here.
--
-- Run with: supabase test db

BEGIN;
SELECT plan(5);

SELECT tests.create_supabase_user('cook@test.kafoo');
SELECT tests.create_supabase_user('customer@test.kafoo');

SELECT tests.authenticate_as('cook@test.kafoo');

INSERT INTO public.kitchen_profiles
  (cook_id, display_name, story, area, delivery_terms)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'cook@test.kafoo'),
  'مطبخ الأم',
  'بنعمل أكل بيتي بحب',
  'مدينة نصر',
  'توصيل في نفس الحي'
);

SELECT tests.clear_authentication();

-- 1. The Cook can always read their own kitchen. If this is zero, the owner
--    policy is broken and the other four assertions prove nothing.
SELECT tests.authenticate_as('cook@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  1,
  'the owning Cook reads their own kitchen'
);

SELECT tests.clear_authentication();

-- 2. A signed-in Customer browsing every kitchen finds none, because no Cook
--    has food on offer. Kafoo never shows a kitchen that cannot be ordered from.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  0,
  'a Customer discovers zero kitchens while no Meals exist'
);

SELECT tests.clear_authentication();

-- 3. Searching by a known display name is not a way around it. Discovery is
--    denied by the absence of a policy, not by the absence of a query.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
   WHERE display_name = 'مطبخ الأم'),
  0,
  'naming a kitchen exactly does not reveal it'
);

SELECT tests.clear_authentication();

-- 4. Nor is being signed out.
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  0,
  'a signed-out person discovers zero kitchens'
);

SELECT tests.clear_authentication();

-- 5. FR-020: a phone number is readable only by its owner. Kafoo never copies
--    it into a table of its own, so the only route to one is auth.users, and
--    that route is closed.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM auth.users
   WHERE email = 'cook@test.kafoo'),
  0,
  'a Customer cannot reach another person''s auth record, and so cannot reach their phone number'
);

SELECT tests.clear_authentication();

SELECT finish();
ROLLBACK;
