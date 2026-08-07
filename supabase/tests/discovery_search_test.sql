-- Discovery's ranking function tells the truth about what it found.
--
-- Separate from discovery_rls_test.sql on purpose. That suite asks "may this person see it"; this
-- one asks "did we actually look". Both can be green while the feature is broken in the other's
-- direction, and on 2026-08-07 exactly that happened: every authorization assertion passed against
-- a search that returned nothing at all for a whole governorate.
--
-- WHAT THIS SUITE EXISTS TO CATCH. An approximate index (HNSW) visits a fixed number of candidates
-- and returns the nearest of those. Filter them afterwards and a narrow filter over a large corpus
-- returns an empty list while matching Meals plainly exist — silently, with no error, and in the
-- one direction a Customer cannot detect. FR-024 has Kafoo SAY the area is empty, so an empty
-- result is not an internal detail; it is a sentence Kafoo asserts to a person.
--
-- THE FIXTURE IS LARGE BECAUSE THE DEFECT NEEDS SCALE TO APPEAR. With a handful of Meals every
-- arrangement of the query is correct and this suite proves nothing. 2,000 is enough to exhaust the
-- default candidate list many times over while still building in a few seconds.

BEGIN;
SELECT plan(4);

SELECT tests.create_supabase_user('crowd@search.kafoo');
SELECT tests.create_supabase_user('quiet@search.kafoo');

SELECT tests.authenticate_as('crowd@search.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('crowd@search.kafoo'), 'مطبخ المهندسين', 'بطبخ من زمان', 'المهندسين', 'توصيل قريب');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('quiet@search.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('quiet@search.kafoo'), 'مطبخ أسوان', 'بطبخ من زمان', 'أسوان', 'توصيل قريب');
SELECT tests.clear_authentication();

-- Embeddings are written with authentication cleared, the way embed-meal does it: a Cook may not
-- write this column at all, which discovery_rls_test case 9 proves.
INSERT INTO public.meals (cook_id, title, description, price, cuisine, category, status,
                          ingredients, allergens, embedding, published_at)
SELECT tests.user_id('crowd@search.kafoo'), 'أكلة ' || g, 'وصف', 50, 'مصري', 'رئيسي', 'published',
       ARRAY['رز'], ARRAY[]::text[],
       (SELECT array_agg(random())::vector(768) FROM generate_series(1, 768)), now()
FROM generate_series(1, 2000) g;

INSERT INTO public.meals (cook_id, title, description, price, cuisine, category, status,
                          ingredients, allergens, embedding, published_at)
SELECT tests.user_id('quiet@search.kafoo'), 'كشري أسوان', 'وصف', 50, 'مصري', 'رئيسي', 'published',
       ARRAY['عدس'], ARRAY[]::text[],
       (SELECT array_agg(random())::vector(768) FROM generate_series(1, 768)), now();

ANALYZE public.meals;
ANALYZE public.kitchen_profiles;

-- A query vector deliberately unrelated to anything. The defect is about WHERE the search looked,
-- not what it liked, so the vector must not be chosen to help.
CREATE TEMP TABLE search_probe AS
SELECT (SELECT array_agg(0.5)::vector(768) FROM generate_series(1, 768)) AS v;
-- The probe belongs to the suite, not to the schema under test, so it needs granting to the roles
-- the assertions run as. Without this the first assertion that reads it fails with "permission
-- denied", which reads exactly like a policy refusing a Customer and is nothing of the kind.
GRANT SELECT ON search_probe TO anon, authenticated;

SELECT tests.authenticate_as_anon();

-- 1. The fixture is what the rest of the suite assumes. Asserted rather than trusted: if the bulk
--    insert silently failed, every assertion below would pass for the wrong reason.
SELECT is(
  (SELECT count(*)::int FROM public.meals WHERE status = 'published'),
  2001,
  'the fixture really does hold 2,001 Meals on offer — a small corpus cannot show this defect'
);

-- 2. THE DEFECT. One Meal in أسوان, two thousand elsewhere, and a Customer in أسوان must find it.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM search_probe), NULL, 'أسوان')),
  1,
  'a Meal in a quiet area is found even when a busy area holds two thousand — an empty answer here '
  'is Kafoo telling a Customer their governorate has no food in it'
);

-- 3. The same Meal, reached by the other spelling of its area. Kafoo must not be blind to a
--    neighbourhood because a Cook and a Customer spell it differently (FR-022a).
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM search_probe), NULL, 'اسوان')),
  1,
  'the same Meal is found by the undotted spelling — one area, however it is written'
);

-- 4. Narrowing is still narrowing. A search that quietly widened to the whole marketplace would
--    pass assertion 2 and be just as wrong, in the opposite direction.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM search_probe), NULL, 'الزمالك')),
  0,
  'an area with nothing on offer returns nothing — narrowing that widens is not narrowing'
);

SELECT * FROM finish();
ROLLBACK;
