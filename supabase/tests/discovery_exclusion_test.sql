-- An exclusion is honoured exactly, or the feature has failed.
--
-- SC-005 is not a ranking target. An excluded food appearing ONCE is a failure — a Customer
-- excluding a food is usually doing so for dietary, religious or health reasons, so serving them
-- the opposite is a betrayal rather than a poor result.
--
-- WHY THIS IS A DATABASE PREDICATE AND NOT A PROMPT. Measured 2026-08-06: the phrase
-- `أكل من غير لحمة خالص` — food with no meat at all — matched by meaning against a corpus of meat
-- and meatless Meals returned MEAT DISHES. First correct answer at rank 6, precision@5 of 0.00.
-- The representation of "no meat" sits next to the representation of "meat", which is a property of
-- matching by meaning rather than a defect to be tuned away. See
-- docs/ops/spike-discovery-embeddings.md.
--
-- THE ASSERTIONS THAT MATTER MOST ARE THE ONES ABOUT WHAT IS NOT RETURNED, and they are the ones a
-- passing suite proves least. A predicate that excluded EVERYTHING would satisfy every
-- "must not appear" assertion here, so each is paired with an assertion that the Meals which should
-- survive did.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- EVERY ASSERTION HERE PASSED ON ITS FIRST RUN, so none of them had been seen to fail.
--
-- The predicate they test shipped with WP-013, which means "write the test and watch it go red" was
-- not available and something else had to stand in for it. Each clause was weakened in turn against
-- the live function and the suite re-run. Measured 2026-08-07:
--
--     clause weakened                              assertions that noticed
--     ─────────────────────────────────────────    ───────────────────────
--     "nothing was excluded" branch removed        1, 5
--     withhold-on-unknown removed                  4, 7, 9
--     allergens no longer read                     6
--     empty array no longer means "nothing"        8
--     % no longer escaped                          9
--     NOT EXISTS inverted to EXISTS                2, 3, 6, 7, 9
--
-- All nine are covered. `m.status = 'published'` is NOT covered by this suite and that is correct
-- rather than a gap — discovery_rls_test case 6 owns it, and duplicating it here would be a second
-- copy of a rule that already has an owner.
-- ────────────────────────────────────────────────────────────────────────────────────────────────

BEGIN;
SELECT plan(13);

SELECT tests.create_supabase_user('cook@exclusion.kafoo');

SELECT tests.authenticate_as('cook@exclusion.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('cook@exclusion.kafoo'), 'مطبخ الاختبار', 'بطبخ من زمان', 'المهندسين', 'توصيل قريب');
SELECT tests.clear_authentication();

-- Four Meals covering the cases the predicate must tell apart. Embeddings are written with
-- authentication cleared, the way embed-meal does it — a Cook may not write that column at all.
INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category, status,
                          ingredients, allergens, embedding, published_at)
VALUES
  -- Meat in the ingredients. Must never appear when meat is excluded.
  ('eeeeeeee-0000-4000-8000-000000000001', tests.user_id('cook@exclusion.kafoo'),
   'كفتة', 'وصف', 60, 'مصري', 'رئيسي', 'published',
   ARRAY['لحمة', 'بصل'], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now()),

  -- No meat anywhere. Must survive.
  ('eeeeeeee-0000-4000-8000-000000000002', tests.user_id('cook@exclusion.kafoo'),
   'كشري', 'وصف', 30, 'مصري', 'رئيسي', 'published',
   ARRAY['عدس', 'رز'], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now()),

  -- Nothing known about it at all. FR-021: WITHHELD, because an unknown is a possible yes.
  ('eeeeeeee-0000-4000-8000-000000000003', tests.user_id('cook@exclusion.kafoo'),
   'أكلة مجهولة', 'وصف', 40, 'مصري', 'رئيسي', 'published',
   ARRAY[]::text[], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now()),

  -- The excluded thing is recorded as an ALLERGEN rather than an ingredient. A predicate reading
  -- only one column would serve this to someone who asked not to see it.
  ('eeeeeeee-0000-4000-8000-000000000004', tests.user_id('cook@exclusion.kafoo'),
   'طاجن جمبري', 'وصف', 90, 'مصري', 'رئيسي', 'published',
   ARRAY['رز'], ARRAY['جمبري'],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now());

CREATE TEMP TABLE probe AS
SELECT (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)) AS v;
GRANT SELECT ON probe TO anon, authenticated;

SELECT tests.authenticate_as_anon();

-- 1. Baseline. Without an exclusion all four are on offer — so every "did not appear" assertion
--    below is about the exclusion and not about a Meal that was never reachable.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), NULL, NULL)),
  4,
  'all four Meals are reachable when nothing is excluded — the baseline the rest of this suite rests on'
);

-- 2. SC-005. The excluded food does not appear. Zero occurrences, not few.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['لحمة'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000001'),
  0,
  'a Meal whose ingredients contain the excluded food NEVER appears — once is a failure of the feature'
);

-- 3. The other half of SC-005. A predicate that excluded everything would pass assertion 2 and be
--    useless; this is what stops that reading.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['لحمة'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000002'),
  1,
  'a Meal with none of the excluded food still appears — excluding everything is not honouring an exclusion'
);

-- 4. FR-021. An unknown is a possible yes.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['لحمة'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000003'),
  0,
  'a Meal with no ingredients and no allergens recorded is WITHHELD, not shown — an unknown is a possible yes'
);

-- 5. The same Meal is shown when nothing is excluded. Withholding is a consequence of the
--    exclusion, never a property of the Meal.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), NULL, NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000003'),
  1,
  'the Meal nobody described is shown when nothing was excluded — it is withheld by the ask, not hidden'
);

-- 6. Allergens count. `meals.allergens` is frequently an AI estimate, which is exactly why it must
--    be read here and exactly why the interface may never call the result safe.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['جمبري'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000004'),
  0,
  'an excluded food recorded as an allergen rather than an ingredient is still excluded'
);

-- 7. FR-020. An exclusion is never relaxed to fill the screen. Excluding every food in the fixture
--    must return nothing rather than falling back to showing something.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals(
     (SELECT v FROM probe), ARRAY['لحمة', 'عدس', 'رز'], NULL)),
  0,
  'when everything is excluded the answer is nothing — an exclusion is never relaxed to fill the screen'
);

-- 8. An empty array means the Customer excluded NOTHING. It read as "exclude the unknown" once, and
--    silently removed every Meal whose ingredients and allergens were both empty.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY[]::text[], NULL)),
  4,
  'an empty exclusion list is the same as no exclusion at all — not an exclusion of everything unknown'
);

-- 9. A literal % is a character, not a wildcard. Unescaped it excluded every Meal in the
--    marketplace, which fails in the safe direction and is exactly why nobody would notice.
--
--    THREE, NOT FOUR, and the difference is the feature rather than a rounding of it. This call
--    asks for an exclusion, so the Meal with nothing recorded about it is withheld by assertion 4's
--    rule. Written expecting four, this assertion failed — and it was the assertion that was wrong.
--    An unknown is a possible yes even when the excluded term is a character nobody can match.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['%'], NULL)),
  3,
  'a percent sign in an exclusion is a character a Customer typed, not a pattern that matches every Meal'
);

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- 10–13. A Cook's spelling is not a second vocabulary.
--
-- Added 2026-08-07 with 20260807154039_fold_exclusion_spellings.sql. Before it, both sides listed
-- the ways each food is WRITTEN and agreed only where somebody had enumerated the same variant
-- twice. Measured by packages/domain/test/exclusion_spelling_coverage_test.dart: 13 of 156
-- plausible Cook spellings reached nothing, and ONE TATWEEL DEFEATED ALL 93 FORMS.
--
-- SEEN TO FAIL: with `fold_arabic` removed from both sides of the ILIKE, assertions 10, 11 and 12
-- go red and 13 stays green. That is the right shape — 13 is the "still shown" half, and a
-- predicate that excluded everything would pass the first three on its own.
--
-- The Meal below is the failure said plainly: a Cook wrote `لحمه`, the Customer excluded `لحم`, and
-- the Meal was served.
-- ────────────────────────────────────────────────────────────────────────────────────────────────

SELECT tests.clear_authentication();

INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category, status,
                          ingredients, allergens, embedding, published_at)
VALUES
  -- ة written as ه, which is how half of Egypt types it. `بسطرمه` and not `لحمه`, and the
  -- difference is the whole assertion: the vocabulary lists `لحم`, which is a substring of
  -- `لحمه مفرومة` whether or not anything folds. Written that way first, this assertion passed with
  -- the folding removed — it was testing the substring match, not the fold. `بسطرمة` is listed with
  -- a ة, so the Cook's ه is reached only by folding, and it is one of the thirteen spellings the
  -- measurement found escaping.
  ('eeeeeeee-0000-4000-8000-000000000005', tests.user_id('cook@exclusion.kafoo'),
   'سندوتش بسطرمة', 'وصف', 55, 'مصري', 'رئيسي', 'published',
   ARRAY['بسطرمه', 'بصل'], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now()),

  -- A stretched letter. Nothing in the vocabulary reached this at all.
  ('eeeeeeee-0000-4000-8000-000000000006', tests.user_id('cook@exclusion.kafoo'),
   'رقاق', 'وصف', 70, 'مصري', 'رئيسي', 'published',
   ARRAY['لحـمة مفرومة'], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now()),

  -- The Customer's side of the same coin: the Cook spelled it the listed way, and the term arriving
  -- from a Customer who typed it differently must still match.
  ('eeeeeeee-0000-4000-8000-000000000007', tests.user_id('cook@exclusion.kafoo'),
   'مكرونة بشاميل', 'وصف', 65, 'مصري', 'رئيسي', 'published',
   ARRAY['مكرونة', 'لبن'], ARRAY[]::text[],
   (SELECT array_agg(0.1)::vector(768) FROM generate_series(1, 768)), now());

SELECT tests.authenticate_as_anon();

-- 10. The Cook's ة written as ه.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['بسطرمة'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000005'),
  0,
  'a Cook writing بسطرمه is reached by an exclusion that names بسطرمة — a spelling is not a second food'
);

-- 11. A tatweel inside the Cook's word.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['لحم'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000006'),
  0,
  'a stretched letter in the Cook''s ingredient does not defeat the exclusion'
);

-- 12. The Customer's spelling, against the Cook's. `مكرونه` is what a Customer types; `مكرونة` is
--     what this Cook wrote, and it is the form the vocabulary lists.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['مكرونه'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000007'),
  0,
  'a term spelled the Customer''s way still matches the Cook''s spelling of the same word'
);

-- 13. And the other half, again: folding must not start excluding food nobody excluded. Two
--     different foods stay two different foods — `لحم` does not reach a Meal made of pasta.
SELECT is(
  (SELECT count(*)::int FROM public.search_meals((SELECT v FROM probe), ARRAY['لحم'], NULL)
   WHERE id = 'eeeeeeee-0000-4000-8000-000000000007'),
  1,
  'folding governs spelling and never meaning — the pasta Meal survives a meat exclusion'
);

SELECT * FROM finish();
ROLLBACK;
