-- Let `embed-meal` store a vector, and NOTHING else.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHY THIS EXISTS AT ALL. ADR-0011 grants one exception to the rule that a function reaching a model
-- provider holds no write credential: `embed-meal` produces a Meal's embedding and must store it.
--
-- The exception shipped on 2026-08-07 enforced by a Python check that reads the function's source
-- and asserts it writes only `meals.embedding`. ai-boundary-reviewer then demonstrated four ways
-- past that check by running them — a payload extracted into a variable, a table name in a variable,
-- the same function rewritten in `.js`, and the admin auth surface — and one of those four was
-- literally "the AI publishes a Meal".
--
-- SO THE PROPERTY MOVES INTO POSTGRES, where it is not a matter of what the source looks like.
-- After this migration, `service_role` can write that one column and the database refuses the rest.
-- Measured before writing it:
--
--     UPDATE meals SET embedding = ...   as service_role -> succeeds
--     UPDATE meals SET status = ...      as service_role -> ERROR: permission denied for table meals
--     SELECT title FROM meals            as service_role -> ERROR: permission denied for table meals
--
-- The Python check stays. It is now a legible statement of intent and a second line of defence,
-- which is what a source-reading check is good for, rather than the only thing standing between the
-- model layer and `meals.status`.
-- ────────────────────────────────────────────────────────────────────────────────────────────────
--
-- WHY A COLUMN GRANT WORKS HERE AND FAILED IN THE PREVIOUS MIGRATION. `20260806231625` records that
-- a column-level REVOKE cannot carve a hole in a table-level GRANT — measured, and the reason the
-- embedding write protection is a trigger rather than a privilege. This is the opposite direction:
-- `service_role` holds NO table-level privilege on `meals`, so a column-level grant is additive and
-- is the whole of what it gets.
--
-- `SELECT (id, cook_id)` is not generosity. Postgres requires SELECT on every column named in a
-- WHERE clause, and the update is scoped `WHERE id = ... AND cook_id = ...` so the function can
-- never touch a row the caller does not own. Two columns, both of which the marketplace already
-- shows to anonymous visitors.
--
-- `has_table_privilege('service_role','meals','SELECT')` stays FALSE — column grants do not satisfy
-- it — so the assertion in data_api_grants_test.sql that predates this migration keeps its meaning
-- rather than being quietly retired.

GRANT SELECT (id, cook_id) ON public.meals TO service_role;
GRANT UPDATE (embedding) ON public.meals TO service_role;

COMMENT ON COLUMN public.meals.embedding IS
  'A machine representation of title and description. Not a claim, shown to nobody, and never '
  'written by a client — see protect_meal_embedding. NULL means unsearchable, not lost. '
  'service_role may UPDATE this column and no other; ADR-0011.';
