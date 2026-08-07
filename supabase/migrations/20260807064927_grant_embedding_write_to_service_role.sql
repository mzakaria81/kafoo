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
-- WHERE clause, and the update is scoped `WHERE id = ... AND cook_id = ...`.
--
-- WHAT IT COSTS, stated rather than glossed. An earlier draft of this comment said both columns are
-- "already shown to anonymous visitors". That is false in the way that matters: `anon` sees them
-- only for PUBLISHED Meals, and `service_role` has BYPASSRLS, so this grant enumerates every Meal
-- id and its Cook at every status — drafts and archived Meals included. Measured. Two identifier
-- columns, no words, no prices, and nothing a model's output can steer — but not "already public".
--
-- SELECT (embedding) IS DELIBERATELY NOT GRANTED, so `WHERE embedding IS NULL` is refused. The
-- first backfill will want exactly that and the quick fix is to grant it. Do not: it makes the whole
-- text-and-vector corpus readable with the service key as well. A backfill enumerates candidates as
-- the Cook or as postgres and hands ids to `embed-meal`. If you are here because a backfill failed,
-- this line is working.
--
-- ROW SCOPE IS STILL APPLICATION CODE, and the header above should not be read as saying otherwise.
-- The grant says WHICH COLUMN, never WHICH ROW: `service_role` can write a vector onto any Meal at
-- any status. `embed-meal` scopes it with `.eq('cook_id')`, and the read that precedes it runs under
-- the Cook's own RLS so a Meal that is not theirs returns null first.
--
-- `has_table_privilege('service_role','meals','SELECT')` stays FALSE — column grants do not satisfy
-- it — so the assertion in data_api_grants_test.sql that predates this migration keeps its meaning
-- rather than being quietly retired.

GRANT SELECT (id, cook_id) ON public.meals TO service_role;
GRANT UPDATE (embedding) ON public.meals TO service_role;

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- A COLUMN GRANT CONSTRAINS THE STATEMENT, NOT THE ROW THAT LANDS.
--
-- Any BEFORE UPDATE trigger added to `meals` later writes whatever it likes on service_role's behalf
-- during the permitted `UPDATE ... SET embedding`. rls-reviewer demonstrated it on 2026-08-07: with
-- a plausible derived-field trigger installed, service_role's embedding write also set
-- `title` and `status = 'archived'`. No error, and no assertion anywhere went red.
--
-- That is not hypothetical — `meals` already carries three BEFORE UPDATE triggers, and
-- `enforce_meal_lifecycle` already writes `updated_at` on service_role's behalf today. The mechanism
-- was known; its generality was not, and it defeats this migration's whole claim that the property
-- now lives in Postgres rather than in what the source looks like.
--
-- So the rule is stated rather than inferred from a grant. AFTER, so that a rogue BEFORE trigger
-- whose name sorts later cannot get in front of it.
CREATE FUNCTION public.service_role_writes_only_embedding()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  -- Same guarded read as protect_meal_embedding: the GUC is EMPTY rather than absent once a session
  -- has cleared it, and ''::jsonb raises.
  claim_role text := (
    SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  );
BEGIN
  IF claim_role = 'service_role'
     OR (claim_role IS NULL AND current_user = 'service_role') THEN
    -- `updated_at` is excluded because an existing lifecycle trigger sets it on every update
    -- regardless of who is writing. Nothing reads it for ordering.
    IF to_jsonb(NEW) - 'embedding' - 'updated_at'
       IS DISTINCT FROM to_jsonb(OLD) - 'embedding' - 'updated_at' THEN
      RAISE EXCEPTION 'service_role may change meals.embedding and nothing else'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER service_role_writes_only_embedding
  AFTER UPDATE ON public.meals
  FOR EACH ROW EXECUTE FUNCTION public.service_role_writes_only_embedding();

COMMENT ON COLUMN public.meals.embedding IS
  'A machine representation of title and description. Not a claim, shown to nobody, and never '
  'written by a client — see protect_meal_embedding. NULL means unsearchable, not lost. '
  'service_role may UPDATE this column and no other; ADR-0011.';
