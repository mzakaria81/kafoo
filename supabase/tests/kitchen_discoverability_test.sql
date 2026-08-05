-- Discoverability contract for kitchen_profiles — cases 26-30 of
-- specs/003-meal-publishing/contracts/authorization.md.
--
-- THIS FILE FLIPPED IN E2, ON PURPOSE.
--
-- In E1 every count here was zero and that was correct: FR-025 makes a kitchen discoverable only
-- while its Cook has a Meal on offer, and `meals` did not exist. The previous version said so and
-- said the right way to make these numbers non-zero was to create the table and add the widening
-- policy. That is what happened. The assertions now run the other way.
--
-- READ THIS BEFORE "FIXING" A FAILURE HERE.
--
-- Cases 27 and 28 are the ones somebody will try to fix wrongly. A kitchen that cannot be found
-- looks like a bug and is not: a Cook whose Meals are all drafts has never opened, and a Cook who
-- has taken everything off the menu is closed. Neither is discoverable, and the fix for "my kitchen
-- disappeared" is to put a Meal back on the menu, never to widen this policy.
--
-- Case 26 is also the check that the widening policy landed at all. Its failure mode is silent —
-- a missing policy returns zero rows rather than erroring — so every other suite in this
-- repository would stay green while Kafoo shipped Meals whose kitchens nobody could reach.
--
-- Run with: supabase test db

BEGIN;
SELECT plan(10);

SELECT tests.create_supabase_user('open@test.kafoo');       -- has a Meal on offer
SELECT tests.create_supabase_user('drafting@test.kafoo');   -- has drafts only
SELECT tests.create_supabase_user('paused@test.kafoo');     -- has unavailable Meals only
SELECT tests.create_supabase_user('empty@test.kafoo');      -- has no Meals at all
SELECT tests.create_supabase_user('customer@test.kafoo');

-- A kitchen for each Cook. Same shape, different food, so the only thing that varies between them
-- is what is on the menu.
SELECT tests.authenticate_as('open@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('open@test.kafoo'), 'مطبخ الأم', 'بنعمل أكل بيتي بحب', 'مدينة نصر', 'توصيل في نفس الحي');
INSERT INTO public.meals (cook_id, title, description, price, cuisine, category, status)
VALUES (tests.user_id('open@test.kafoo'), 'كشري', 'كشري بالعدس والحمص', 75.00, 'egyptian', 'main', 'published');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('drafting@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('drafting@test.kafoo'), 'مطبخ لسه', 'لسه بنجهز', 'الدقي', 'هنشوف');
INSERT INTO public.meals (cook_id, title, description, price, cuisine, category, status)
VALUES (tests.user_id('drafting@test.kafoo'), 'ملوخية', 'ملوخية بالفراخ', 120.00, 'egyptian', 'main', 'draft');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('paused@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('paused@test.kafoo'), 'مطبخ مقفول', 'قافلين شوية', 'المعادي', 'توصيل قريب');
INSERT INTO public.meals (cook_id, title, description, price, cuisine, category, status)
VALUES (tests.user_id('paused@test.kafoo'), 'محشي', 'محشي كرنب', 90.00, 'egyptian', 'main', 'unavailable');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('empty@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('empty@test.kafoo'), 'مطبخ فاضي', 'لسه بندور', 'شبرا', 'مش محدد');
SELECT tests.clear_authentication();

-- 0. The Cook still reads their own kitchen. If the widening policy were written in a way that
--    replaced the owner policy rather than adding to it, this is what would catch it.
--
--    Scoped to their own row deliberately. An unscoped count here returns 2, not 1 — this Cook
--    reads their own closed kitchen AND the one kitchen that is open, because RLS policies are
--    OR-ed together and a Cook is also a person who can discover other kitchens. The first version
--    of this assertion counted every row and expected 1, which was a wrong test rather than a wrong
--    policy: it would have failed on the day a second Cook opened.
SELECT tests.authenticate_as('paused@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('paused@test.kafoo')),
  1,
  'a Cook with nothing on the menu still reads their own kitchen'
);

SELECT tests.clear_authentication();

-- 26. A signed-out person finds a kitchen whose Cook has food on offer.
--     E1's outstanding obligation, discharged.
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('open@test.kafoo')),
  1,
  'a signed-out person finds a kitchen with food on offer'
);

SELECT tests.clear_authentication();

-- 27. A kitchen whose Cook has only drafts is not open, and is not findable.
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('drafting@test.kafoo')),
  0,
  'a kitchen with only drafts has never opened, and nobody finds it'
);

SELECT tests.clear_authentication();

-- 28. Nor one whose Meals are all off the menu.
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('paused@test.kafoo')),
  0,
  'a kitchen with everything taken off the menu is closed, and nobody finds it'
);

SELECT tests.clear_authentication();

-- 29. Nor one with no Meals at all — and being signed in is not a way around it.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
    WHERE cook_id = tests.user_id('empty@test.kafoo')),
  0,
  'a signed-in Customer does not find a kitchen with no Meals'
);

SELECT tests.clear_authentication();

-- 29b. The whole surface at once. Counting every kitchen a Customer can reach is what would catch
--      a widening policy that is broader than its predicate looks — three of these four kitchens
--      must be invisible, and asserting them one at a time would not notice a fifth appearing.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles),
  1,
  'exactly one kitchen is discoverable, and it is the one with food on offer'
);

SELECT tests.clear_authentication();

-- 30. FR-020, restated because this feature adds a new route to a kitchen and every new route is a
--     new chance to leak the number. It holds by construction — auth.users is not exposed through
--     the data API — and "holds by construction" is a claim about code that changes.
--
--     Asserted as a refusal (42501), not as an empty result: no Supabase project grants
--     authenticated any access to auth.users at all, so the Customer is turned away at the door
--     rather than shown an empty room.
SELECT tests.authenticate_as('customer@test.kafoo');

SELECT throws_ok(
  $$ SELECT COUNT(*)::int FROM auth.users WHERE email = 'open@test.kafoo' $$,
  '42501',
  NULL,
  'finding a kitchen through a Meal does not lead to the Cook''s phone number'
);

SELECT tests.clear_authentication();

-- 31. An anonymous visitor reads the address form on an open kitchen.
--     Deliberate: Customer-facing strings that describe a Cook need the Cook's form, so the form
--     rides the existing discovery SELECT — not a new hole, and not owner-only.
SELECT tests.authenticate_as('open@test.kafoo');

UPDATE public.kitchen_profiles
  SET address_form = 'feminine'
  WHERE cook_id = tests.user_id('open@test.kafoo');

SELECT tests.clear_authentication();

SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT address_form FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('open@test.kafoo')),
  'feminine',
  'an anonymous visitor reads the address form on an open kitchen'
);

SELECT tests.clear_authentication();

-- 32. The address form is invisible on a kitchen that is not discoverable.
--     Proves the exposure is scoped to the existing discovery rule, not a new public read.
SELECT tests.authenticate_as('paused@test.kafoo');

UPDATE public.kitchen_profiles
  SET address_form = 'masculine'
  WHERE cook_id = tests.user_id('paused@test.kafoo');

SELECT tests.clear_authentication();

SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('paused@test.kafoo')),
  0,
  'address form is not readable on a kitchen that is not discoverable'
);

SELECT tests.clear_authentication();

-- 33. A Customer who can SEE an open kitchen still cannot WRITE its address form.
--
-- THIS IS THE CASE THE ADDRESS FORM ACTUALLY NEEDS, and it has to live here rather than in
-- kitchen_profiles_rls_test.sql. That file's equivalent assertion passes for the wrong reason:
-- its fixture kitchen has no Meal on offer, so the attacker cannot see the row at all and the
-- UPDATE is refused by the SELECT policy before the UPDATE policy is ever consulted. Measured on
-- 2026-08-05 — with the UPDATE policy weakened to `USING (true) WITH CHECK (true)`, that
-- assertion still passed. It is the exact trap case 3 of that file warns about, arriving on
-- schedule now that E2 has made kitchens publicly readable.
--
-- Here the kitchen IS discoverable, so the Customer genuinely can read the row, and the only
-- thing standing between them and writing it is the UPDATE policy. Weaken that policy and this
-- goes red. Verified both ways before it was committed.
SELECT tests.authenticate_as('customer@test.kafoo');

UPDATE public.kitchen_profiles
  SET address_form = 'masculine'
  WHERE cook_id = tests.user_id('open@test.kafoo');

SELECT tests.clear_authentication();

-- Read back with authentication cleared: a zero-rows-affected UPDATE under RLS is indistinguishable
-- from a successful one if you only look through the attacker's own policies.
SELECT is(
  (SELECT address_form FROM public.kitchen_profiles
   WHERE cook_id = tests.user_id('open@test.kafoo')),
  'feminine',
  'a Customer who can see an open kitchen still cannot write its address form'
);

SELECT finish();
ROLLBACK;
