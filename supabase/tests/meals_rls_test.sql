-- Authorization tests for meals — cases 1-13 and 22-25 of
-- specs/003-meal-publishing/contracts/authorization.md.
--
-- Written BEFORE the migration so they fail first, per constitution Principle III. A negative test
-- that passes on its first run has proven nothing.
--
-- Run with: supabase test db (locally), or by the Authorization workflow against the pull
-- request's preview branch.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- READ THIS BEFORE TRUSTING CASE 8.
--
-- kitchen_profiles_rls_test.sql case 3 carries a warning addressed to whoever wrote this file: the
-- reassign test there is refused by the SELECT policy rather than by WITH CHECK, so it keeps
-- passing with `WITH CHECK (true)` in place, and it stops covering what its name claims the moment
-- E2 makes kitchens publicly readable.
--
-- Two things follow for meals, and both are handled below rather than inherited.
--
-- 1. The reassign is attempted on a PUBLISHED Meal. A draft reassigned to someone else would be
--    invisible to the actor under the "cook reads own meals" policy, and Postgres would refuse the
--    update for that reason alone — which is the exact accident that made E1's test hollow. A
--    published Meal stays readable through the public policy after the reassign, so the SELECT
--    layer cannot mask anything.
--
-- 2. Even then, WITH CHECK is not what fires. `enforce_meal_lifecycle` is a BEFORE UPDATE trigger
--    and Postgres runs it before evaluating WITH CHECK, so the trigger raises P0001 first and the
--    policy is never consulted. data-model.md duplicates the cook_id rule across both layers on
--    purpose, and this is the cost of that decision: neither layer can be mutation-tested through
--    the other.
--
--    Case 8 therefore asserts the refusal as it actually happens, and case 8b isolates the policy
--    by disabling the trigger for the length of one statement inside a transaction that rolls back.
--    8b is the assertion that goes red when someone writes `WITH CHECK (true)`. If you weaken the
--    policy and only case 8 stays green, that is this comment being right, not the suite being
--    broken.
-- ────────────────────────────────────────────────────────────────────────────────────────────────

BEGIN;
SELECT plan(23);

SELECT tests.create_supabase_user('owner@test.kafoo');
SELECT tests.create_supabase_user('other@test.kafoo');

-- Both Cooks own a Kitchen Profile. Without one for `other`, the FR-017 trigger would refuse their
-- inserts and case 9 would pass for a reason that has nothing to do with authorization.
SELECT tests.authenticate_as('owner@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('owner@test.kafoo'), 'مطبخ الأم', 'بنعمل أكل بيتي بحب', 'مدينة نصر', 'توصيل في نفس الحي');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('other@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('other@test.kafoo'), 'مطبخ تاني', 'بنعمل أكل كمان', 'حدائق القبة', 'توصيل للجيران');
SELECT tests.clear_authentication();

-- One Meal of the owner's at each status. Fixed ids so later cases can name a row rather than
-- depend on insertion order.
SELECT tests.authenticate_as('owner@test.kafoo');

INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category, status, ingredients, calories, allergens)
VALUES
  ('aaaaaaaa-0000-4000-8000-000000000001', tests.user_id('owner@test.kafoo'),
   'كشري', 'كشري بالعدس والحمص', 75.00, 'egyptian', 'main', 'draft',
   ARRAY['عدس','رز','مكرونة'], 850, ARRAY['جلوتين']),
  ('aaaaaaaa-0000-4000-8000-000000000002', tests.user_id('owner@test.kafoo'),
   'ملوخية', 'ملوخية بالفراخ', 120.00, 'egyptian', 'main', 'published',
   ARRAY['ملوخية','فراخ'], 600, ARRAY[]::text[]),
  ('aaaaaaaa-0000-4000-8000-000000000003', tests.user_id('owner@test.kafoo'),
   'محشي', 'محشي كرنب', 90.00, 'egyptian', 'main', 'unavailable',
   ARRAY['كرنب','رز'], 500, ARRAY[]::text[]),
  ('aaaaaaaa-0000-4000-8000-000000000004', tests.user_id('owner@test.kafoo'),
   'رقاق', 'رقاق باللحمة', 150.00, 'egyptian', 'main', 'archived',
   ARRAY['رقاق','لحمة'], 900, ARRAY['جلوتين','ألبان']);

SELECT tests.clear_authentication();

-- 1. The owning Cook reads every Meal of theirs, at any status.
--    If this is wrong the other seventeen assertions prove nothing.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals),
  4,
  'the owning Cook reads their own Meals at every status'
);

SELECT tests.clear_authentication();

-- 2. Another signed-in person reads a draft → zero rows.
SELECT tests.authenticate_as('other@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE status = 'draft'),
  0,
  'another signed-in person reads zero drafts'
);

SELECT tests.clear_authentication();

-- 3. Another signed-in person reads an unavailable Meal → zero rows.
--    A Meal off the menu is off the menu for everyone but its Cook.
SELECT tests.authenticate_as('other@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE status = 'unavailable'),
  0,
  'another signed-in person reads zero unavailable Meals'
);

SELECT tests.clear_authentication();

-- 4. Another signed-in person reads a published Meal → visible.
SELECT tests.authenticate_as('other@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE status = 'published'),
  1,
  'another signed-in person reads a Meal on offer'
);

SELECT tests.clear_authentication();

-- 5. A signed-out visitor reads a published Meal → visible.
--    The first use of the anon role in Kafoo (FR-024).
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE status = 'published'),
  1,
  'a signed-out person reads a Meal on offer'
);

SELECT tests.clear_authentication();

-- 6. The other half of the same pair: the widening is exactly as wide as intended.
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE status <> 'published'),
  0,
  'a signed-out person reads nothing that is not on offer'
);

SELECT tests.clear_authentication();

-- 7. Another signed-in person updates someone else's Meal → nothing changes.
--    Attempted on the PUBLISHED Meal, which they can read. An update they could not even see
--    would tell us nothing about the UPDATE policy.
SELECT tests.authenticate_as('other@test.kafoo');

UPDATE public.meals
  SET title = 'hacked', price = 1.00
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT title FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002'),
  'ملوخية',
  'another signed-in person cannot change a Meal they can read'
);

-- 8. The owning Cook reassigns cook_id → refused.
--    P0001 is enforce_meal_lifecycle. See the header: the BEFORE UPDATE trigger runs ahead of
--    WITH CHECK, so this is the mechanism that actually answers. Case 8b covers the policy.
SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.meals
       SET cook_id = tests.user_id('other@test.kafoo')
       WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002' $$,
  'P0001',
  NULL,
  'a Cook cannot hand a Meal to someone else (FR-016)'
);

SELECT tests.clear_authentication();

-- 8b. The same attempt with the trigger out of the way, so the UPDATE policy is the only thing
--     left standing. 42501 is WITH CHECK refusing the new row.
--
--     THIS IS THE MUTATION TARGET. Replace the policy's WITH CHECK with `true` and this assertion
--     must go red. If it does not, the policy is decoration and the trigger is carrying it alone.
--
--     Safe because the whole file runs inside a transaction that rolls back, and because
--     clear_authentication returns the session to the table owner.
ALTER TABLE public.meals DISABLE TRIGGER enforce_meal_lifecycle_trigger;

SELECT tests.authenticate_as('owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.meals
       SET cook_id = tests.user_id('other@test.kafoo')
       WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002' $$,
  '42501',
  NULL,
  'the UPDATE policy refuses the reassign on its own, without the trigger'
);

SELECT tests.clear_authentication();

ALTER TABLE public.meals ENABLE TRIGGER enforce_meal_lifecycle_trigger;

-- 9. Another signed-in person inserts a Meal owned by someone else → refused by WITH CHECK.
--    `other` owns a Kitchen Profile and so does `owner`, so the FR-017 trigger passes and the
--    INSERT policy is what answers.
SELECT tests.authenticate_as('other@test.kafoo');

SELECT throws_ok(
  $$ INSERT INTO public.meals (cook_id, title, description, price, cuisine, category)
     VALUES (tests.user_id('owner@test.kafoo'), 'مزيف', 'أكل مش بتاعي', 10.00, 'egyptian', 'main') $$,
  '42501',
  NULL,
  'nobody can create a Meal in another Cook''s name'
);

SELECT tests.clear_authentication();

-- ── nutrition_source: what changed decides, not what the client claims ──────────────────────────

SELECT tests.authenticate_as('owner@test.kafoo');

INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category, status, calories, allergens, nutrition_source)
VALUES
  ('aaaaaaaa-0000-4000-8000-000000000010', tests.user_id('owner@test.kafoo'),
   'بشاميل', 'مكرونة بشاميل', 130.00, 'egyptian', 'main', 'published', 700, ARRAY['جلوتين','ألبان'], 'ai'),
  ('aaaaaaaa-0000-4000-8000-000000000011', tests.user_id('owner@test.kafoo'),
   'فتة', 'فتة باللحمة', 160.00, 'egyptian', 'main', 'published', 800, ARRAY['جلوتين'], 'ai'),
  ('aaaaaaaa-0000-4000-8000-000000000012', tests.user_id('owner@test.kafoo'),
   'سلطة', 'سلطة خضرا', 40.00, 'egyptian', 'salad', 'published', 120, ARRAY[]::text[], 'ai');

-- 22. The Cook corrects the calories while claiming the figure is still the AI Assistant's.
--     A guess relabelled as a verification is the failure this trigger exists to prevent.
UPDATE public.meals
  SET calories = 950, nutrition_source = 'ai'
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000010';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000010'),
  'cook',
  'changing the calories makes the figure the Cook''s, whatever the client claimed'
);

-- 23. The same for allergens, which is the one where being wrong hurts someone.
UPDATE public.meals
  SET allergens = ARRAY['جلوتين','مكسرات'], nutrition_source = 'ai'
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000011';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000011'),
  'cook',
  'changing the allergens makes the list the Cook''s, whatever the client claimed'
);

-- 24. An edit that does not touch nutrition leaves the label alone. Without this, every typo
--     correction would quietly promote an estimate.
UPDATE public.meals
  SET title = 'سلطة بلدي'
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000012';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000012'),
  'ai',
  'fixing a title does not turn an estimate into the Cook''s own figure'
);

-- 25. At INSERT the client is believed, deliberately. There is no previous value to compare
--     against, and the Cook is the one confirming. The guarantee is about every write after this.
INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category, calories, allergens, nutrition_source)
VALUES
  ('aaaaaaaa-0000-4000-8000-000000000013', tests.user_id('owner@test.kafoo'),
   'شوربة', 'شوربة عدس', 35.00, 'egyptian', 'soup', 300, ARRAY[]::text[], 'cook');

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000013'),
  'cook',
  'an insert is the Cook confirming, so the source is stored as sent'
);

-- 26. THE CASE THE TRIGGER USED TO GET BACKWARDS, and the reason it is written down here rather
--     than left to the app.
--
--     A Cook cannot publish without approving every estimate, and approving writes the AI
--     Assistant's own number onto a row that held nothing. To the first version of this trigger
--     that read as a change, so EVERY published Meal came out labelled as a figure a person had
--     verified. A Customer avoiding gluten would have read a guess as a checked fact, which is the
--     one direction docs/product/domain-model.md says this field must never fail in.
--
--     Approving is not verifying. Only a figure that REPLACES a stored one is the Cook's.
INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category)
VALUES
  ('aaaaaaaa-0000-4000-8000-000000000014', tests.user_id('owner@test.kafoo'),
   'ملوخية', 'ملوخية بالفراخ', 90.00, 'egyptian', 'main');

UPDATE public.meals
  SET calories = 800, allergens = ARRAY['جلوتين']
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000014';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000014'),
  'ai',
  'approving an estimate unchanged leaves the figure the AI Assistant''s'
);

-- 27. And the correction that follows it still promotes, so the fix above did not simply switch
--     the trigger off. This is the pair: 26 says approving is not verifying, 27 says correcting is.
UPDATE public.meals
  SET calories = 650
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000014';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000014'),
  'cook',
  'correcting a stored figure still makes it the Cook''s own'
);

-- 28. Allergens say "nothing here yet" differently from calories, and the difference nearly made
--     the fix above a no-op on the column where being wrong hurts someone.
--
--     `allergens` is `NOT NULL DEFAULT '{}'`, so a draft nobody has answered holds an empty array
--     rather than a null. A first version of the trigger tested `OLD.allergens IS NOT NULL`, which
--     is true for every row that has ever existed — the allergen half would have gone on promoting
--     exactly as before while the calorie half was fixed, and nothing would have said so. Absence
--     for this column is an empty list.
INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category)
VALUES
  ('aaaaaaaa-0000-4000-8000-000000000015', tests.user_id('owner@test.kafoo'),
   'رز باللبن', 'حلو بلدي', 30.00, 'egyptian', 'dessert');

UPDATE public.meals
  SET allergens = ARRAY['ألبان']
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000015';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000015'),
  'ai',
  'approving an allergen list onto an empty one leaves it the AI Assistant''s'
);

-- 29. And correcting a list that already said something still promotes — including emptying it,
--     which is the change a Cook makes when the AI Assistant warned about something that is not in
--     the food. That claim is the Cook's, and it must not read as a guess.
UPDATE public.meals
  SET allergens = ARRAY[]::text[]
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000015';

SELECT is(
  (SELECT nutrition_source FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000015'),
  'cook',
  'clearing an allergen list the Cook disagrees with is the Cook''s own answer'
);

SELECT tests.clear_authentication();

-- ── deletion: drafts only ───────────────────────────────────────────────────────────────────────

-- 10. The owning Cook deletes their own draft → gone.
SELECT tests.authenticate_as('owner@test.kafoo');

DELETE FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000001';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000001'),
  0,
  'a Cook deletes their own draft'
);

-- 11. The owning Cook deletes a Meal that has been on offer → nothing happens.
--     Forbidden now, before Orders exist, because a rule added after E4 would have to reconcile
--     rows rather than prevent them.
SELECT tests.authenticate_as('owner@test.kafoo');

DELETE FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000002'),
  1,
  'nobody deletes a Meal that has been on offer — archiving is what that is for'
);

-- 12. Nor a retired one, which order history will point at.
SELECT tests.authenticate_as('owner@test.kafoo');

DELETE FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000004';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000004'),
  1,
  'nobody deletes a retired Meal'
);

-- 13. Another signed-in person deletes someone else's draft → nothing happens.
--
-- READ THIS BEFORE TRUSTING IT. Mutation-tested 2026-08-06: with `cook_id = auth.uid()` removed
-- from the DELETE policy this assertion still passes, because the stranger cannot SELECT the draft
-- and PostgreSQL applies SELECT policies to the rows a DELETE touches — so the DELETE matches
-- nothing and the DELETE policy is never consulted. It pins the outcome, which is worth having, and
-- it does not test what its old name claimed.
--
-- The assertion that bites is `a stranger who can SEE a draft still cannot delete it` in
-- policy_isolation_test.sql. If you are changing the DELETE policy, watch that one.
SELECT tests.authenticate_as('owner@test.kafoo');

INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category)
VALUES ('aaaaaaaa-0000-4000-8000-000000000020', tests.user_id('owner@test.kafoo'),
        'مسقعة', 'مسقعة بالبتنجان', 80.00, 'egyptian', 'main');

SELECT tests.clear_authentication();

SELECT tests.authenticate_as('other@test.kafoo');

DELETE FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000020';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000020'),
  1,
  'a stranger''s delete of an unseen draft removes nothing (SELECT policy, not DELETE)'
);

-- ── Is case 8b capable of failing? ───────────────────────────────────────────────────────────────

-- The mutation check, run on every commit rather than by hand once.
--
-- docs/ops/verifying-e1.md §5 describes doing this manually: weaken the policy, watch the assertion
-- go red, put it back. That is the right idea and a bad place to keep it, for two reasons. It is
-- only true on the day somebody does it — a policy rewritten six months from now is covered by
-- nobody's memory of an exercise. And on this project it is not even reachable by hand: Supabase
-- pushes only NEW migration files to a preview branch, so editing the migration that created the
-- policy changes nothing on the database the suites run against.
--
-- So the weakening happens here, inside the transaction that rolls back. It weakens WITH CHECK to
-- `true`, disables the trigger that would otherwise answer first, and asserts the reassign now
-- SUCCEEDS. That is the proof that case 8b is load-bearing: the two guards are off and the thing
-- they prevent happens. If this assertion ever fails, something else is refusing the reassign, case
-- 8b is measuring that other thing instead, and both assertions need rethinking.
--
-- LAST IN THE FILE ON PURPOSE. Everything above runs against the real policy; nothing after this
-- point could be trusted. The DDL is transactional and the outer ROLLBACK restores it.
DROP POLICY "cook updates own meals" ON public.meals;

CREATE POLICY "cook updates own meals"
  ON public.meals FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (true);

ALTER TABLE public.meals DISABLE TRIGGER enforce_meal_lifecycle_trigger;

SELECT tests.authenticate_as('owner@test.kafoo');

UPDATE public.meals
  SET cook_id = tests.user_id('other@test.kafoo')
  WHERE id = 'aaaaaaaa-0000-4000-8000-000000000012';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT cook_id FROM public.meals WHERE id = 'aaaaaaaa-0000-4000-8000-000000000012'),
  tests.user_id('other@test.kafoo'),
  'with WITH CHECK weakened to true, the reassign succeeds — so case 8b can fail, and is worth trusting'
);

SELECT finish();
ROLLBACK;
