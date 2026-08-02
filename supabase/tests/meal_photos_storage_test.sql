-- Storage tests for the meal-photos bucket — cases 31-34 of
-- specs/003-meal-publishing/contracts/authorization.md.
--
-- Written BEFORE the migration so they fail first.
--
-- A note on case 33, which is not what it looks like. "Anyone reads a photo" is true, and it is the
-- bucket's `public` flag that makes it true — object URLs on a public bucket bypass policy checks
-- entirely. It is NOT a public SELECT policy, and adding one would reopen the enumeration hole
-- closed on kitchen-photos in 20260802065138: photos live one folder per Cook, so enumerating the
-- bucket returns the Cook roster and every Cook's account id. The assertion below therefore checks
-- the flag that actually serves the photo, not a policy that would serve the roster with it.
--
-- Accepted and recorded: a photo attached to an unpublished Meal is reachable by anyone who knows
-- its exact path — a uuid inside a uuid. It is not enumerable and it carries no personal data. If a
-- Meal photo ever carries something sensitive, this decision must be revisited rather than
-- inherited.
--
-- Run with: supabase test db

-- A second thing that is not what it looks like: **case 34 cannot be tested behaviourally through
-- SQL at all.** Supabase installs `storage.protect_delete()`, which refuses every direct DELETE
-- from `storage.objects` regardless of who is asking and regardless of RLS — "Use the Storage API
-- instead". The first version of this suite asserted that another Cook's DELETE removed nothing,
-- and it errored rather than passing, because nobody's DELETE removes anything here.
--
-- That guard is a stronger guarantee than the one the contract asked for, so it is asserted
-- directly. The owner-scoped DELETE policy still matters for the route the guard does not cover —
-- the Storage API, which this harness does not speak — so it is checked structurally instead, by
-- reading the policy back out of the catalog. A structural check is weaker than a behavioural one
-- and is named as such rather than dressed up: it catches a policy someone widens, and it would
-- not catch a policy that is correct and ineffective.

BEGIN;
SELECT plan(6);

SELECT tests.create_supabase_user('cook_a@test.kafoo');
SELECT tests.create_supabase_user('cook_b@test.kafoo');

-- 31. The owning Cook writes to their own prefix.
SELECT tests.authenticate_as('cook_a@test.kafoo');

INSERT INTO storage.objects (bucket_id, name, owner)
VALUES (
  'meal-photos',
  tests.user_id('cook_a@test.kafoo')::text || '/cccccccc-0000-4000-8000-000000000001.jpg',
  tests.user_id('cook_a@test.kafoo')
);

SELECT tests.clear_authentication();

SELECT is(
  (SELECT COUNT(*)::int FROM storage.objects
    WHERE bucket_id = 'meal-photos'
      AND name = tests.user_id('cook_a@test.kafoo')::text || '/cccccccc-0000-4000-8000-000000000001.jpg'),
  1,
  'a Cook uploads a photo under their own prefix'
);

-- 32. Another Cook writes under someone else's prefix → refused.
--     The path carries the Meal id, so this is also what stops one Cook's photo overwriting
--     another's — a flat {uid}/ layout would only need the right filename.
SELECT tests.authenticate_as('cook_b@test.kafoo');

SELECT throws_ok(
  format(
    $$ INSERT INTO storage.objects (bucket_id, name, owner)
       VALUES ('meal-photos', %L, %L) $$,
    tests.user_id('cook_a@test.kafoo')::text || '/cccccccc-0000-4000-8000-000000000002.jpg',
    tests.user_id('cook_b@test.kafoo')
  ),
  '42501',
  NULL,
  'a Cook cannot write into another Cook''s photo folder'
);

SELECT tests.clear_authentication();

-- 33. The bucket is public, which is what serves a Meal's photo to a Customer who is not signed in.
--     Asserted on the flag rather than through a policy, deliberately — see the header.
SELECT is(
  (SELECT public FROM storage.buckets WHERE id = 'meal-photos'),
  true,
  'the bucket is public, so a Meal on offer shows its photo to anyone with the path'
);

-- 34a. Another Cook deletes someone else's photo → refused outright.
--      42501 here is storage.protect_delete(), not RLS. Every direct DELETE is refused, so the
--      contract's requirement holds by a mechanism broader than the one it named.
SELECT tests.authenticate_as('cook_b@test.kafoo');

SELECT throws_ok(
  format(
    $$ DELETE FROM storage.objects
         WHERE bucket_id = 'meal-photos' AND name = %L $$,
    tests.user_id('cook_a@test.kafoo')::text || '/cccccccc-0000-4000-8000-000000000001.jpg'
  ),
  '42501',
  NULL,
  'a Cook cannot delete another Cook''s photo'
);

SELECT tests.clear_authentication();

-- 34b. And the photo is still there afterwards, which is the thing that actually matters. A
--      refusal that still removed the row would satisfy the assertion above and lose the file.
SELECT is(
  (SELECT COUNT(*)::int FROM storage.objects
    WHERE bucket_id = 'meal-photos'
      AND name = tests.user_id('cook_a@test.kafoo')::text || '/cccccccc-0000-4000-8000-000000000001.jpg'),
  1,
  'the photo survives the attempt'
);

-- 34c. The DELETE policy is owner-scoped, checked in the catalog rather than by behaviour.
--      This is the guard for the Storage API path, which protect_delete() does not sit in front of
--      and which this harness cannot exercise. Structural, and therefore weaker: it catches
--      somebody widening the predicate, which is the realistic failure, and it would not catch a
--      predicate that reads correctly and does not work.
SELECT ok(
  (SELECT qual LIKE '%auth.uid()%'
     FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'owner deletes meal photo'),
  'the meal-photos DELETE policy is scoped to the caller''s own folder'
);

SELECT finish();
ROLLBACK;
