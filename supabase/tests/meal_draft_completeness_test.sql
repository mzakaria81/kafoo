-- A draft is a saved intention, not a finished Meal awaiting a button.
--
-- US1 asks a Cook seven things by conversation and persists as it goes (T034), so an abandoned
-- conversation leaves a draft rather than nothing (T043, and the story's own independent test:
-- "abandon halfway and find a draft, not an offer"). That is only possible if a row can exist
-- before every answer does.
--
-- The original `meals` migration declared title, description, price, cuisine and category all
-- NOT NULL, which made the earliest possible row the LAST moment of the conversation. These
-- assertions move the requirement off the columns and onto the transition: incomplete while
-- `draft`, complete to become anything else.
--
-- WRITTEN BEFORE THE MIGRATION AND SEEN TO FAIL, which is what makes them worth having. Cases 1-4
-- fail against the original schema with a not-null violation.

BEGIN;
SELECT plan(8);

SELECT tests.create_supabase_user('cook_draft@test.kafoo');
SELECT tests.authenticate_as('cook_draft@test.kafoo');

INSERT INTO kitchen_profiles (cook_id, display_name, story, area, delivery_terms)
VALUES (tests.user_id('cook_draft@test.kafoo'), 'مطبخ التجربة', 'أكل بيتي', 'المعادي', 'استلام');

-- 1. The very first thing a Cook says is what they cooked. Nothing else is known yet.
SELECT lives_ok(
  format(
    $$ INSERT INTO meals (id, cook_id, title)
       VALUES ('dddddddd-0000-4000-8000-000000000001', %L, 'كشري') $$,
    tests.user_id('cook_draft@test.kafoo')
  ),
  'a draft exists after the first answer, with only a title'
);

-- 2. It is a draft, because that is the default and nothing else was asked for.
SELECT is(
  (SELECT status FROM meals WHERE id = 'dddddddd-0000-4000-8000-000000000001'),
  'draft',
  'a Meal with almost nothing in it is a draft'
);

-- 3. The conversation continues and fills a field in. Still incomplete, still storable.
SELECT lives_ok(
  $$ UPDATE meals SET description = 'كشري بالعدس والحمص'
       WHERE id = 'dddddddd-0000-4000-8000-000000000001' $$,
  'a draft takes another answer without needing the rest'
);

-- 4. The Cook walks away here. What survives is a draft, which is the whole point.
SELECT is(
  (SELECT count(*)::int FROM meals
     WHERE id = 'dddddddd-0000-4000-8000-000000000001' AND status = 'draft'),
  1,
  'an abandoned conversation leaves a draft behind'
);

-- 5. THE OTHER HALF OF THE RULE. An incomplete Meal must not reach a Customer. Moving the
--    requirement off the columns is only safe if the transition enforces it instead — otherwise
--    this migration trades a usability problem for a Meal on offer with no price.
SELECT throws_ok(
  $$ UPDATE meals SET status = 'published'
       WHERE id = 'dddddddd-0000-4000-8000-000000000001' $$,
  'P0001',
  NULL,
  'an incomplete draft cannot go on offer'
);

-- 6. It is still a draft afterwards. A refused transition must change nothing.
SELECT is(
  (SELECT status FROM meals WHERE id = 'dddddddd-0000-4000-8000-000000000001'),
  'draft',
  'a refused publish leaves the Meal where it was'
);

-- 7. Complete it, and it goes on offer.
SELECT lives_ok(
  $$ UPDATE meals
       SET price = 75.00, cuisine = 'egyptian', category = 'main', status = 'published'
       WHERE id = 'dddddddd-0000-4000-8000-000000000001' $$,
  'a complete draft goes on offer'
);

-- 8. A published Meal cannot then have a required field taken away. The constraint has to hold on
--    every write, not only on the transition that first satisfied it — otherwise a Meal on offer
--    can be emptied out afterwards and the Customer sees a price-less listing.
SELECT throws_ok(
  $$ UPDATE meals SET price = NULL
       WHERE id = 'dddddddd-0000-4000-8000-000000000001' $$,
  'P0001',
  NULL,
  'a Meal on offer cannot have its price removed'
);

SELECT finish();
ROLLBACK;
