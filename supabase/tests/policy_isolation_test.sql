-- Assertions built so that the policy under test is the ONLY thing standing.
--
-- WHY THIS FILE EXISTS.
--
-- PostgreSQL applies `SELECT` policies to the rows an `UPDATE` or `DELETE` touches. A row you
-- cannot see is a row you cannot change — so on a table with narrow read policies, a "stranger
-- cannot write this" assertion passes whether or not the write policy does anything at all. The
-- read policy refuses first and the policy the assertion is named after is never consulted.
--
-- That is not a hypothetical. `scripts/mutate-policies.py` found three assertions in this
-- repository that pass for that reason, recorded in `docs/ops/policy-assertion-coverage.md`:
--
--   another signed-in person cannot delete a Cook's draft
--   owner cannot reassign cook_id to another person (WITH CHECK)
--   non-owner cannot write another Cook's address form
--
-- One of them had a comment above it predicting exactly this, written while kitchens were still
-- private and warning that the day they became publicly readable the assertion would stop covering
-- what its name says. E2 shipped that day. Nobody re-read the comment. **A warning in the right
-- place is not a control**; an assertion that has been seen to fail is.
--
-- The originals are kept, renamed to say what they actually exercise. This file adds the ones that
-- bite.
--
-- HOW ISOLATION IS ACHIEVED, AND THE RULE THAT GOES WITH IT.
--
-- Where a read policy would mask the write policy, this file CREATES an extra permissive SELECT
-- policy inside the transaction, rather than weakening the real one. Both would work; only one is
-- safe to have in a committed file. A weakened predicate is a line somebody can copy into a
-- migration, and the whole point of this package is that weakening the thing under test is the
-- easiest way to turn an authorization test green. A `CREATE POLICY` named `zz_test_*` is
-- unmistakably scaffolding, and the transaction rolls it back.
--
-- **Never move one of these CREATE POLICY statements out of this file.** If you find one in
-- `supabase/migrations/`, that is an incident, not a refactor.
--
-- Run with: scripts/local-db.sh test

BEGIN;
SELECT plan(10);

SELECT tests.create_supabase_user('iso_owner@test.kafoo');
SELECT tests.create_supabase_user('iso_other@test.kafoo');

-- Both Cooks get a kitchen; the owner also gets a draft Meal to attack.
SELECT tests.authenticate_as('iso_owner@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms, address_form)
VALUES (tests.user_id('iso_owner@test.kafoo'), 'مطبخ أم علي', 'أكل بيتي', 'المعادي', 'توصيل', 'feminine');
INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category)
VALUES ('dddddddd-0000-4000-8000-000000000001', tests.user_id('iso_owner@test.kafoo'),
        'محشي', 'محشي كرنب', 60.00, 'egyptian', 'main');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('iso_other@test.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('iso_other@test.kafoo'), 'مطبخ تاني', 'برضه أكل بيتي', 'الدقي', 'استلام');
SELECT tests.clear_authentication();

-- ── 1. The meals DELETE policy's ownership half ─────────────────────────────────────────────────
--
-- `another signed-in person cannot delete a Cook's draft` in meals_rls_test.sql passes with
-- `cook_id = auth.uid()` removed from the DELETE policy, because the stranger cannot SELECT the
-- draft and so the DELETE matches no rows. Give them sight of it and the DELETE policy is the only
-- guard left.

CREATE POLICY "zz_test_sees_every_meal" ON public.meals
  FOR SELECT TO authenticated USING (true);

SELECT tests.authenticate_as('iso_other@test.kafoo');

-- Sight is what this scaffolding buys, and it is worth asserting rather than assuming: if the
-- stranger still cannot see the draft, the assertion below would pass for the old reason and this
-- whole case would be theatre.
SELECT is(
  (SELECT COUNT(*)::int FROM public.meals
    WHERE id = 'dddddddd-0000-4000-8000-000000000001'),
  1,
  'the scaffolding really does let a stranger read the draft'
);

DELETE FROM public.meals WHERE id = 'dddddddd-0000-4000-8000-000000000001';

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals
    WHERE id = 'dddddddd-0000-4000-8000-000000000001'),
  1,
  'a stranger who can SEE a draft still cannot delete it'
);

DROP POLICY "zz_test_sees_every_meal" ON public.meals;

-- ── 2. The kitchen_profiles UPDATE policy's WITH CHECK ──────────────────────────────────────────
--
-- `owner cannot reassign cook_id to another person (WITH CHECK)` names the WITH CHECK and exercises
-- the SELECT policies: after the reassign the row stops being visible to its updater, and that is
-- what raises 42501. With the row visible either way, WITH CHECK is the only thing that can refuse.

CREATE POLICY "zz_test_sees_every_kitchen" ON public.kitchen_profiles
  FOR SELECT TO authenticated USING (true);

SELECT tests.authenticate_as('iso_owner@test.kafoo');

SELECT throws_ok(
  $$ UPDATE public.kitchen_profiles
       SET cook_id = tests.user_id('iso_other@test.kafoo')
     WHERE cook_id = tests.user_id('iso_owner@test.kafoo') $$,
  '42501',
  NULL,
  'the UPDATE policy WITH CHECK refuses a reassign on its own, with the row still visible'
);

SELECT tests.clear_authentication();

DROP POLICY "zz_test_sees_every_kitchen" ON public.kitchen_profiles;

-- ── 3. Kitchen photos: a stranger cannot write into another Cook's folder ───────────────────────
--
-- meal-photos has this assertion; kitchen-photos never did. The mutation sweep initially reported
-- the kitchen-photos INSERT policy as covered, which was an artefact of weakening whole policies —
-- doing so removes `bucket_id = 'kitchen-photos'`, and the now table-wide policy permitted the
-- meal-photos row that the meal-photos assertion was watching.

-- The filename is deliberately not the one the owner uploads below. Reusing it would mean that
-- under the very mutation this case exists to catch — the stranger's INSERT succeeding — the
-- owner's later upload hits a unique violation and ABORTS the suite, so four later assertions stop
-- running rather than reporting. An aborted suite reads as silence, and silence is what the
-- mutation harness cannot distinguish from coverage.
SELECT tests.authenticate_as('iso_other@test.kafoo');

SELECT throws_ok(
  format(
    $$ INSERT INTO storage.objects (bucket_id, name, owner)
       VALUES ('kitchen-photos', %L, %L) $$,
    tests.user_id('iso_owner@test.kafoo')::text || '/planted.jpg',
    tests.user_id('iso_other@test.kafoo')
  ),
  '42501',
  NULL,
  'a Cook cannot write into another Cook''s kitchen-photos folder'
);

SELECT tests.clear_authentication();

-- ── 4 and 5. Storage reads are owner-scoped, on both buckets ────────────────────────────────────
--
-- The kitchen-photos SELECT policy is the one that closed the Cook-roster enumeration hole in
-- 20260802065138. That migration was verified with real anonymous HTTP requests against a preview
-- branch and the before/after is recorded in its comment — good evidence, and none of it runs
-- again. This is the part that runs again.
--
-- Object URLs on a public bucket bypass policy checks entirely, so a Customer still sees a photo
-- they have the path for. What these assert is that the *table* does not answer for a stranger,
-- which is what the enumeration endpoint reads.

SELECT tests.authenticate_as('iso_owner@test.kafoo');
INSERT INTO storage.objects (bucket_id, name, owner)
VALUES ('kitchen-photos', tests.user_id('iso_owner@test.kafoo')::text || '/kitchen.jpg',
        tests.user_id('iso_owner@test.kafoo'));
INSERT INTO storage.objects (bucket_id, name, owner)
VALUES ('meal-photos',
        tests.user_id('iso_owner@test.kafoo')::text || '/dddddddd-0000-4000-8000-000000000001.jpg',
        tests.user_id('iso_owner@test.kafoo'));
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('iso_other@test.kafoo');

SELECT is(
  (SELECT COUNT(*)::int FROM storage.objects WHERE bucket_id = 'kitchen-photos'),
  0,
  'a Cook reads nothing in another Cook''s kitchen-photos folder'
);

SELECT is(
  (SELECT COUNT(*)::int FROM storage.objects WHERE bucket_id = 'meal-photos'),
  0,
  'a Cook reads nothing in another Cook''s meal-photos folder'
);

SELECT tests.clear_authentication();

-- ── 6 and 7. Storage updates are owner-scoped, on both buckets ──────────────────────────────────
--
-- Same masking as case 1: without sight of the row a stranger's UPDATE matches nothing, so the
-- UPDATE policy is never reached. The scaffolding gives them sight.
--
-- These policies carry no `WITH CHECK`, and that is correct rather than an omission: PostgreSQL
-- uses the `USING` expression as the check when `WITH CHECK` is absent, so the folder scoping
-- applies to the new row too. `.claude/rules/supabase.md` warns about omitting WITH CHECK on
-- UPDATE — that warning is about policies whose two halves must differ. Do not "fix" these by
-- adding a redundant clause.

CREATE POLICY "zz_test_sees_every_object" ON storage.objects
  FOR SELECT TO authenticated USING (true);

SELECT tests.authenticate_as('iso_other@test.kafoo');

UPDATE storage.objects
   SET owner = tests.user_id('iso_other@test.kafoo')
 WHERE name = tests.user_id('iso_owner@test.kafoo')::text || '/kitchen.jpg';

UPDATE storage.objects
   SET owner = tests.user_id('iso_other@test.kafoo')
 WHERE name = tests.user_id('iso_owner@test.kafoo')::text
              || '/dddddddd-0000-4000-8000-000000000001.jpg';

SELECT tests.clear_authentication();

-- Read back by exact name, never by bucket. A bucket-wide subquery returns more than one row the
-- moment a mutation lets a stranger's upload through, and "more than one row returned by a
-- subquery" aborts the transaction — so the assertions below would stop RUNNING rather than fail,
-- and scripts/mutate-policies.py would report them as unmeasured instead of as coverage. A suite
-- has to survive the mutation it exists to catch.
SELECT is(
  (SELECT owner FROM storage.objects
    WHERE name = tests.user_id('iso_owner@test.kafoo')::text || '/kitchen.jpg'),
  tests.user_id('iso_owner@test.kafoo'),
  'a Cook who can SEE another Cook''s kitchen photo still cannot change it'
);

SELECT is(
  (SELECT owner FROM storage.objects
    WHERE name = tests.user_id('iso_owner@test.kafoo')::text
                 || '/dddddddd-0000-4000-8000-000000000001.jpg'),
  tests.user_id('iso_owner@test.kafoo'),
  'a Cook who can SEE another Cook''s meal photo still cannot change it'
);

DROP POLICY "zz_test_sees_every_object" ON storage.objects;

-- ── 8. The kitchen-photos DELETE policy, structurally ───────────────────────────────────────────
--
-- `storage.protect_delete()` refuses every direct DELETE from storage.objects whoever asks, so this
-- cannot be tested behaviourally through SQL — the same reason meal_photos_storage_test.sql checks
-- its twin by reading the catalog. Structural is weaker and is named as such: it catches somebody
-- widening the predicate, which is the realistic failure, and would not catch a predicate that
-- reads correctly and does not work.

SELECT ok(
  (SELECT qual LIKE '%auth.uid()%'
     FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'owner deletes kitchen photo'),
  'the kitchen-photos DELETE policy is scoped to the caller''s own folder'
);

-- ── 9. Every storage policy stays scoped to one bucket ──────────────────────────────────────────
--
-- The last eight clauses the mutation sweep could not cover, closed structurally because they
-- cannot be closed behaviourally. Dropping `bucket_id = 'kitchen-photos'` from a policy widens it
-- to both buckets and changes nothing observable — the two buckets carry identical owner-scoped
-- predicates, so the union permits exactly what it permitted before. There is no behaviour to
-- assert on.
--
-- It stops being harmless the day a third bucket exists with a different rule, and on that day the
-- widened policy would quietly govern it. This is the assertion that notices, and it is the honest
-- shape for the problem: a check on the predicate's text, because the predicate's effect is
-- currently unobservable.

SELECT is(
  (SELECT string_agg(policyname, ', ' ORDER BY policyname)
     FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND COALESCE(qual, with_check) NOT LIKE '%bucket_id%'),
  NULL,
  'every storage.objects policy names the bucket it governs'
);

SELECT finish();
ROLLBACK;
