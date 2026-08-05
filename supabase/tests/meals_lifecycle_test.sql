-- Lifecycle tests for meals — cases 14-21 of
-- specs/003-meal-publishing/contracts/authorization.md.
--
-- Written BEFORE the migration so they fail first.
--
-- `draft → published → unavailable → archived`, one-way except `published ⇄ unavailable`. The rule
-- lives in a trigger rather than in the app because "by any route" has to include routes nobody has
-- written yet — an admin tool, a repair script, a future Edge Function.
--
-- CASE 18 IS SC-010 and is the one that matters: a retired Meal returns to offer in zero cases.
-- Once Orders exist, a Meal coming back from retirement drags a Customer's history with it.
--
-- Run with: supabase test db

BEGIN;
SELECT plan(9);

SELECT tests.create_supabase_user('cook@test.kafoo');

SELECT tests.authenticate_as('cook@test.kafoo');

INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('cook@test.kafoo'), 'مطبخ الأم', 'بنعمل أكل بيتي بحب', 'مدينة نصر', 'توصيل في نفس الحي');

INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category, status)
VALUES
  ('bbbbbbbb-0000-4000-8000-000000000001', tests.user_id('cook@test.kafoo'),
   'كشري', 'كشري بالعدس', 75.00, 'egyptian', 'main', 'draft'),
  ('bbbbbbbb-0000-4000-8000-000000000002', tests.user_id('cook@test.kafoo'),
   'ملوخية', 'ملوخية بالفراخ', 120.00, 'egyptian', 'main', 'archived'),
  ('bbbbbbbb-0000-4000-8000-000000000003', tests.user_id('cook@test.kafoo'),
   'محشي', 'محشي كرنب', 90.00, 'egyptian', 'main', 'draft');

-- 14. draft → published. The one thing a draft can do.
UPDATE public.meals SET status = 'published'
  WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001';

SELECT is(
  (SELECT status FROM public.meals WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  'published',
  'a draft goes on offer'
);

-- 15. published → unavailable. Off the menu, not deleted.
UPDATE public.meals SET status = 'unavailable'
  WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001';

SELECT is(
  (SELECT status FROM public.meals WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  'unavailable',
  'a Cook takes a Meal off the menu'
);

-- 16. unavailable → published. And back. This pair is the difference between a menu and a list.
UPDATE public.meals SET status = 'published'
  WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001';

SELECT is(
  (SELECT status FROM public.meals WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  'published',
  'a Cook puts a Meal back on the menu'
);

-- 17. published → archived. Retirement is reachable from the menu.
UPDATE public.meals SET status = 'archived'
  WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001';

SELECT is(
  (SELECT status FROM public.meals WHERE id = 'bbbbbbbb-0000-4000-8000-000000000001'),
  'archived',
  'a Cook retires a Meal that was on offer'
);

-- 18. archived → published. SC-010. The assertion this file exists for.
SELECT throws_ok(
  $$ UPDATE public.meals SET status = 'published'
       WHERE id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'P0001',
  NULL,
  'a retired Meal never returns to offer'
);

-- 19. archived → unavailable. The same rule by a quieter route — "not retired, just paused" is
--     how a retired Meal would come back if only the obvious transition were blocked.
SELECT throws_ok(
  $$ UPDATE public.meals SET status = 'unavailable'
       WHERE id = 'bbbbbbbb-0000-4000-8000-000000000002' $$,
  'P0001',
  NULL,
  'a retired Meal cannot be moved to unavailable either'
);

-- 20. draft → archived. Nothing is taken off a menu it was never on. A draft the Cook is done
--     with is deleted, which is what the DELETE policy allows.
SELECT throws_ok(
  $$ UPDATE public.meals SET status = 'archived'
       WHERE id = 'bbbbbbbb-0000-4000-8000-000000000003' $$,
  'P0001',
  NULL,
  'a draft cannot be retired — it goes on offer first, or it is deleted'
);

-- 21. A status outside the four. Refused by the CHECK constraint, not by the trigger: an
--     unrecognised value must be impossible to store even if the trigger is ever changed.
SELECT throws_ok(
  $$ UPDATE public.meals SET status = 'hidden'
       WHERE id = 'bbbbbbbb-0000-4000-8000-000000000003' $$,
  '23514',
  NULL,
  'a status outside the lifecycle cannot be stored at all'
);

-- 21b. The rule that decides what the publishing flow has to collect before it can
--      offer anything: a Meal cannot leave draft without cuisine and category, and
--      those are the two values the AI Assistant supplies rather than the Cook.
--
--      This is asserted here rather than discovered in the app because the app's
--      own tests run against a fake repository, which has no triggers and would
--      happily "publish" a Meal the database refuses. That gap is what makes a
--      green suite and a broken product possible at the same time.
INSERT INTO public.meals (id, cook_id, title, description, price, status)
VALUES ('bbbbbbbb-0000-4000-8000-000000000004', tests.user_id('cook@test.kafoo'),
        'بانيه', 'بانيه فراخ مقرمش', 85.00, 'draft');

SELECT throws_ok(
  $$ UPDATE public.meals SET status = 'published'
       WHERE id = 'bbbbbbbb-0000-4000-8000-000000000004' $$,
  'P0001',
  'a Meal that is not a draft must have title, description, price, cuisine and category',
  'a Meal cannot go on offer without the cuisine and category the AI Assistant supplies'
);

SELECT tests.clear_authentication();

SELECT finish();
ROLLBACK;
