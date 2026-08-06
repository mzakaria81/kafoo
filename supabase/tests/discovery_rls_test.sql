-- Authorization tests for discovery — every case in
-- specs/004-customer-discovery/contracts/authorization.md.
--
-- Written BEFORE the migration so they fail first, per constitution Principle III.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHY THIS FILE EXISTS EVEN THOUGH E3 ADDS NO POLICY.
--
-- E3 adds a new WAY OF ASKING — a ranking function — and every existing authorization test passes
-- whether or not that path leaks, because none of them travel it. A green suite is not evidence
-- about a route it does not take. That is the 2026-08-06 finding restated: five checks in this
-- repository were found incapable of failing, three of them because a different policy refused
-- first.
--
-- The specific way this suite could pass for the wrong reason: `search_meals` written
-- SECURITY DEFINER makes every Meal findable regardless of status, and cases 2-6 below would still
-- pass if the fixture only contained published Meals. So the fixture carries a Meal of EVERY
-- status, and case 12 asserts the security mode against the catalogue rather than inferring it from
-- behaviour.
--
-- THE EMBEDDING IS WRITTEN OUTSIDE THE COOK'S SESSION, ON PURPOSE. Cases 9-11 forbid a client
-- writing `meals.embedding` at all, because a client that supplies the vector can supply the one
-- nearest every query and rank its own Meal first for everything, permanently and invisibly. So the
-- fixture sets embeddings with authentication cleared, which is what `embed-meal` does with a
-- service-role key.
-- ────────────────────────────────────────────────────────────────────────────────────────────────

BEGIN;
SELECT plan(27);

SELECT tests.create_supabase_user('cook@discovery.kafoo');
SELECT tests.create_supabase_user('other@discovery.kafoo');
SELECT tests.create_supabase_user('closed@discovery.kafoo');

-- Three kitchens. `closed` exists to prove a kitchen with nothing on offer is unreachable, and its
-- area is spelled the same neighbourhood a different way from `cook`'s — the two are one area and
-- a Customer must not be blind to either because of a spelling (FR-022a).
SELECT tests.authenticate_as('cook@discovery.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('cook@discovery.kafoo'), 'مطبخ فاطمة', 'بطبخ من زمان', 'المهندسين', 'توصيل قريب');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('other@discovery.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('other@discovery.kafoo'), 'مطبخ تاني', 'أكل بيتي', 'الدقى', 'استلام');
SELECT tests.clear_authentication();

SELECT tests.authenticate_as('closed@discovery.kafoo');
INSERT INTO public.kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('closed@discovery.kafoo'), 'مطبخ مقفول', 'لسه ببدأ', 'مهندسين', 'توصيل');
SELECT tests.clear_authentication();

-- One Meal at every status for the first Cook. A fixture of published Meals only is how cases 2-6
-- pass without the function ever refusing anything.
SELECT tests.authenticate_as('cook@discovery.kafoo');
INSERT INTO public.meals
  (id, cook_id, title, description, price, cuisine, category, status, ingredients)
VALUES
  ('dddddddd-0000-4000-8000-000000000001', tests.user_id('cook@discovery.kafoo'),
   'كشري', 'عدس ومكرونة وأرز', 35.00, 'egyptian', 'main', 'published', ARRAY['عدس','مكرونة']),
  ('dddddddd-0000-4000-8000-000000000002', tests.user_id('cook@discovery.kafoo'),
   'ملوخية', 'ملوخية بالفراخ', 55.00, 'egyptian', 'main', 'draft', ARRAY['ملوخية']),
  ('dddddddd-0000-4000-8000-000000000003', tests.user_id('cook@discovery.kafoo'),
   'محشي', 'ورق عنب', 60.00, 'egyptian', 'main', 'unavailable', ARRAY['أرز']),
  ('dddddddd-0000-4000-8000-000000000004', tests.user_id('cook@discovery.kafoo'),
   'رقاق', 'رقاق باللحمة', 80.00, 'egyptian', 'main', 'archived', ARRAY['لحمة']);
SELECT tests.clear_authentication();

-- The second Cook has one Meal on offer, so their kitchen is discoverable.
SELECT tests.authenticate_as('other@discovery.kafoo');
INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category, status)
VALUES ('dddddddd-0000-4000-8000-000000000005', tests.user_id('other@discovery.kafoo'),
        'فتة', 'فتة لحمة', 100.00, 'egyptian', 'main', 'published');
UPDATE public.meals SET ingredients = ARRAY['عيش','لحمة']
  WHERE id = 'dddddddd-0000-4000-8000-000000000005';
SELECT tests.clear_authentication();

-- The third Cook has only a draft, so their kitchen has never opened.
SELECT tests.authenticate_as('closed@discovery.kafoo');
INSERT INTO public.meals (id, cook_id, title, description, price, cuisine, category, status)
VALUES ('dddddddd-0000-4000-8000-000000000006', tests.user_id('closed@discovery.kafoo'),
        'بسبوسة', 'بسبوسة بالقشطة', 40.00, 'egyptian', 'main', 'draft');
SELECT tests.clear_authentication();

-- Vectors, written with no session — the service-role path, never a client's.
UPDATE public.meals SET embedding = array_fill(0.1::real, ARRAY[768])::vector;

-- A query vector. Ranking is not what this suite tests; visibility is.
--
-- A psql variable rather than a temp view: a view created here belongs to the owner, and the anon
-- role cannot read it — so every assertion below failed with "permission denied for view" instead
-- of exercising a policy. Worth noting rather than just fixing, because a suite that cannot even
-- reach its subject is indistinguishable from one whose subject refuses it.
\set qv '(array_fill(0.1::real, ARRAY[768])::vector)'

-- The user ids are captured HERE, as the owner, because tests.user_id() reads auth.users and no
-- client role may. Calling it inside a role-scoped assertion fails with "permission denied for
-- table users" — which aborts the transaction and turns every later case into a cascade, hiding
-- whatever they would have said.
SELECT tests.user_id('cook@discovery.kafoo')   AS cook_uid,
       tests.user_id('other@discovery.kafoo')  AS other_uid,
       tests.user_id('closed@discovery.kafoo') AS closed_uid
\gset

-- FROM HERE ON, EVERY ASSERTION IS MADE UNDER A ROLE, NEVER UNDER THE OWNER.
--
-- tests.clear_authentication() returns to the table owner, which BYPASSES RLS — seed.sql says so
-- in terms, and the first version of this file made its anon assertions in that state. They would
-- have passed against any policy at all, including none, which is precisely the class of defect
-- this suite exists to catch. It is used below only to build fixtures.
SELECT tests.authenticate_as_anon();

-- ── Search refuses exactly what reading refuses ────────────────────────────────────────────────

-- 1. Nobody signed in reaches a published Meal through search.
--    If this is wrong every refusal below proves nothing, because an empty result is not a refusal.
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status = 'published'),
  2,
  'anon reaches both published Meals through search'
);

-- 2-4. The three statuses that are not on offer.
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status = 'draft'),
  0, 'anon reaches zero drafts through search');

SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status = 'unavailable'),
  0, 'anon reaches zero unavailable Meals through search');

SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status = 'archived'),
  0, 'anon reaches zero archived Meals through search');

-- 5. Another signed-in person cannot reach someone else's draft.
SELECT tests.clear_authentication();
SELECT tests.authenticate_as('other@discovery.kafoo');
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status <> 'published'),
  0, 'a signed-in Customer reaches nothing that is not on offer');
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- 6. The owning Cook does not reach their OWN draft through search.
--    They can read it — that is meals_rls_test case 1, unchanged — but discovery shows what is on
--    offer, and a draft appearing here would mean the function returns rows on a different rule
--    from the one it advertises. The Cook's drafts have their own screen.
SELECT tests.clear_authentication();
SELECT tests.authenticate_as('cook@discovery.kafoo');
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv) WHERE status <> 'published'),
  0, 'a Cook does not reach their own drafts through discovery');
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- 7-8. A kitchen is reachable exactly while it has a Meal on offer.
SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
     WHERE cook_id = :'cook_uid'),
  1, 'anon reaches a kitchen whose Cook has a Meal on offer');

SELECT is(
  (SELECT COUNT(*)::int FROM public.kitchen_profiles
     WHERE cook_id = :'closed_uid'),
  0, 'anon reaches zero kitchens whose Meals are all drafts');

-- ── The embedding column is not writable by a client ───────────────────────────────────────────
--
-- RLS does NOT give you these. `cook updates own meals` permits a Cook to update their own row,
-- and that includes this column. Left unprotected, case 9 passes trivially in the wrong direction.

-- 9. The owning Cook cannot write their own Meal's vector.
SELECT tests.clear_authentication();
SELECT tests.authenticate_as('cook@discovery.kafoo');
SELECT throws_ok(
  $$UPDATE public.meals SET embedding = array_fill(0.9::real, ARRAY[768])::vector
      WHERE id = 'dddddddd-0000-4000-8000-000000000001'$$,
  NULL,
  'the owning Cook cannot write meals.embedding'
);
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- 9b. And cannot reach around the trigger through a SECURITY DEFINER function.
--
--     This is the assertion that was missing, and the hole was real: SECURITY DEFINER rewrites
--     current_user to the function owner, so a trigger testing current_user alone waved the write
--     through. Demonstrated by rls-reviewer 2026-08-07. The definer function is created inside this
--     transaction and rolled back with it.
SELECT tests.clear_authentication();
CREATE FUNCTION public.zz_definer_probe(mid uuid) RETURNS void
  LANGUAGE sql SECURITY DEFINER AS
  $probe$ UPDATE public.meals SET embedding = array_fill(0.9::real, ARRAY[768])::vector
            WHERE id = mid $probe$;
GRANT EXECUTE ON FUNCTION public.zz_definer_probe(uuid) TO authenticated;

SELECT tests.authenticate_as('cook@discovery.kafoo');
SELECT throws_ok(
  $$SELECT public.zz_definer_probe('dddddddd-0000-4000-8000-000000000001')$$,
  '42501'
);
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- 10. Another signed-in person cannot write someone else's vector.
SELECT tests.clear_authentication();
SELECT tests.authenticate_as('other@discovery.kafoo');
SELECT lives_ok(
  $$UPDATE public.meals SET embedding = array_fill(0.9::real, ARRAY[768])::vector
      WHERE id = 'dddddddd-0000-4000-8000-000000000001'$$,
  'another person''s UPDATE of a vector touches no row'
);
SELECT is(
  (SELECT COUNT(*)::int FROM public.meals
     WHERE id = 'dddddddd-0000-4000-8000-000000000001'
       AND embedding <> array_fill(0.1::real, ARRAY[768])::vector),
  0, 'another signed-in person changed no vector');
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- 11. Nobody signed in changes a vector.
--     anon holds no UPDATE grant on meals at all, so this is refused a whole layer earlier than the
--     trigger — which is worth asserting AS a throw rather than as a no-op, because the two are
--     different guarantees and only one of them is being relied on here.
SELECT throws_ok(
  $$UPDATE public.meals SET embedding = array_fill(0.9::real, ARRAY[768])::vector$$,
  NULL,
  'anon cannot UPDATE meals at all'
);
SELECT is(
  (SELECT COUNT(*)::int FROM public.meals
     WHERE embedding <> array_fill(0.1::real, ARRAY[768])::vector),
  0, 'anon changed no vector');

-- ── The function runs as the caller ────────────────────────────────────────────────────────────

-- 12. Asserted against the catalogue, not inferred from behaviour. A SECURITY DEFINER function can
--     return correct-looking results in a test whose fixtures happen to be public, and the one-word
--     difference removes the entire authorization story.
SELECT is(
  (SELECT prosecdef FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'search_meals'),
  false,
  'search_meals is SECURITY INVOKER, so RLS applies as the caller'
);

-- ── A Meal without a vector is browsable but not searchable ────────────────────────────────────

-- 13. The nullability rule from data-model.md, made real. An incomplete backfill or an unreachable
--     provider must produce a Meal that is HARDER TO FIND, never one that is lost.
SELECT tests.clear_authentication();
UPDATE public.meals SET embedding = NULL
  WHERE id = 'dddddddd-0000-4000-8000-000000000005';
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv)
     WHERE id = 'dddddddd-0000-4000-8000-000000000005'),
  0, 'a Meal with no vector is invisible to search');

SELECT is(
  (SELECT COUNT(*)::int FROM public.meals
     WHERE id = 'dddddddd-0000-4000-8000-000000000005'),
  1, 'a Meal with no vector is still visible to browsing');

SELECT tests.clear_authentication();
UPDATE public.meals SET embedding = array_fill(0.1::real, ARRAY[768])::vector
  WHERE id = 'dddddddd-0000-4000-8000-000000000005';
SELECT tests.clear_authentication();
SELECT tests.authenticate_as_anon();

-- ── Area matching ignores spelling, never meaning ──────────────────────────────────────────────

-- 14-15. FR-022a. 'المهندسين' and 'مهندسين' are one area written two ways; a Customer naming
--        either must reach both kitchens. The `closed` kitchen wrote the second spelling.
SELECT is(
  (SELECT public.normalise_area('المهندسين') = public.normalise_area('مهندسين')),
  true, 'a definite article does not make two areas');

SELECT is(
  (SELECT public.normalise_area('الدقي') = public.normalise_area('الدقى')),
  true, 'final ya and alef maqsura do not make two areas');

-- 15b-15d. The three cases the function's comments name and no assertion covered until
--           2026-08-07. ة mapped to itself, so العجوزة and العجوزه were two areas and مصر الجديدة
--           could never reach its own alias; and the trim the comment described was absent.
SELECT is(
  (SELECT public.normalise_area('العجوزة') = public.normalise_area('العجوزه')),
  true, 'ta marbuta and ha do not make two areas');

SELECT is(
  (SELECT public.normalise_area('مصر الجديدة') = public.normalise_area('هليوبوليس')),
  true, 'a place with a second name is reachable by both');

SELECT is(
  (SELECT public.normalise_area(' المهندسين ') = public.normalise_area('المهندسين')),
  true, 'surrounding whitespace does not make two areas');

-- 16. And it must NOT merge two different neighbourhoods. A tolerance loose enough to catch a typo
--     is loose enough to match a different place, and that failure is invisible.
SELECT is(
  (SELECT public.normalise_area('المهندسين') = public.normalise_area('الدقي')),
  false, 'two different neighbourhoods stay different');

-- 17. Narrowing by an area a Cook wrote reaches that Cook's Meals.
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv, NULL, 'مهندسين')),
  1, 'naming an area reaches the kitchen that wrote it, however it was spelled');

-- 18. An area nobody wrote returns NOTHING rather than everything. FR-024: Kafoo says the area is
--     empty; it never silently widens.
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv, NULL, 'أسوان')),
  0, 'an area no Cook wrote returns zero rows, never the whole marketplace');

-- 22-23. Exclusion edge cases. Both failed in the SAFE direction — over-exclusion — which is
--         exactly why neither would have been reported by anyone.
SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv, ARRAY[]::text[])),
  (SELECT COUNT(*)::int FROM public.search_meals(:qv)),
  'excluding nothing is the same as passing no exclusions');

SELECT is(
  (SELECT COUNT(*)::int FROM public.search_meals(:qv, ARRAY['%'])),
  (SELECT COUNT(*)::int FROM public.search_meals(:qv)),
  'a literal percent is a character, not a wildcard that empties the marketplace');

SELECT * FROM finish();
ROLLBACK;
