-- The vector stops leaving the database.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHAT THIS COSTS TODAY, MEASURED RATHER THAN SUSPECTED.
--
-- `search_meals` returned `SETOF public.meals`, so every result carried its 768-float `embedding`.
-- `discover` returns what the database gave it, and the Customer's app parses fourteen columns and
-- has never read that one — `CookMeal.fromRow` does not mention it, and the column's own comment
-- says it is "shown to nobody".
--
-- Measured against the demo database on 2026-08-08, corpus of 1,013 Meals, 20 samples
-- (docs/ops/measuring-discovery.md):
--
--     search_meals, whole rows      581 ms   505 KB per search
--     search_meals, ids only        168 ms     2 KB per search
--     end to end, what a Customer waits    1112 ms median
--
-- Same scan, same rows, same round trip. The 415 ms between those two lines is serialising and
-- shipping a column nobody reads, on every search, by every Customer, over an Egyptian mobile
-- network. It is a third of the wait and it does NOT grow with the marketplace — 78× the corpus
-- moved the scan itself by about 2 ms.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHY THE FUNCTION AND NOT THE CALLER.
--
-- The one-line version of this fix is `?select=<columns>` on the RPC call inside `discover`, and it
-- would have produced the same measurement today. It was not taken, for two reasons.
--
-- It duplicates a column list across a language boundary. The Customer's app already carries one —
-- `DiscoveryRepository._mealColumns` — which is why BROWSE never had this problem and SEARCH did.
-- A second list in TypeScript would have to be kept in step with a Dart constant by memory, and the
-- failure mode is a column added to `meals` that appears when browsing and is missing when
-- searching. That is a bug nobody would look for.
--
-- And it leaves the door open. A function returning the vector can have the vector taken from it
-- again by the next caller — an admin screen, a second client, a debugging endpoint written in a
-- hurry. Returning a row type that has no `embedding` in it means there is nothing to select, in
-- every caller that will ever exist. `discovery_search_test.sql` assertion 5 asserts the absent
-- column rather than a response size, for the same reason: size is the symptom.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- DROP AND RECREATE, WHICH IS NOT OPTIONAL AND TAKES THE GRANTS WITH IT.
--
-- Postgres will not `CREATE OR REPLACE` a function whose return type changes, so this drops it —
-- and DROP takes the EXECUTE grants and the comment with it. Both are restored at the foot of this
-- file. `data_api_grants_test.sql` and `discovery_rls_test.sql` case 15 are what notice if they are
-- not: a dropped grant makes search fail closed for every Customer, which is loud, and a dropped
-- SECURITY INVOKER makes it fail OPEN, which is silent and is the whole reason that assertion reads
-- the catalogue instead of the results.
--
-- NO POLICY CHANGES AND NO NEW TABLE, so there is no new ownership question. `meals` keeps its four
-- per-operation policies. What must be re-proven is that this function still gains no authority of
-- its own, and that is what the existing suites do.
--
-- THE BODY IS CARRIED FORWARD FROM 20260807154039, NOT FROM THE MIGRATION THAT CREATED IT.
--
-- Stated because the first draft of this file got it wrong and the suites caught it: the body was
-- copied from 20260806231625, which silently reverted `fold_arabic` on both sides of the exclusion
-- match and the empty `search_path` pin. Nine assertions across discovery_exclusion_test.sql and
-- discovery_exclusion_sweep_test.sql went red — every one of them an excluded food reappearing in
-- a Customer's results, which is the failure `.claude/rules/business-rules.md` treats as a betrayal
-- rather than a ranking miss.
--
-- A DROP AND CREATE REWRITES THE WHOLE BODY, so it inherits nothing from the definition it
-- replaces. `CREATE OR REPLACE` in an earlier migration has exactly the same property. Anyone
-- changing this function again must start from the LATEST definition — which is this file until
-- something supersedes it — and not from the one that reads like the original.
--
-- Below the signature it is otherwise unchanged. Filter first in a MATERIALIZED CTE, then rank
-- exactly. Read the note in 20260806231625_add_meal_embeddings.sql before touching that
-- arrangement — it returns the right answer slowly on purpose, and the fast arrangement returns an
-- empty list to a Customer whose governorate has food in it.

DROP FUNCTION IF EXISTS public.search_meals(vector, text[], text);

CREATE FUNCTION public.search_meals(
  query_embedding vector(768),
  exclude_terms text[] DEFAULT NULL,
  area_query text DEFAULT NULL
)
-- Every column of `meals` except `embedding`. Enumerated rather than inherited, which is the point
-- of the change: adding a column to `meals` no longer adds it to a Customer's search response by
-- default. A new column that a screen needs is added here deliberately, and
-- `discovery_search_test.sql` assertion 6 is the list a Meal is actually rendered from.
RETURNS TABLE (
  id uuid,
  cook_id uuid,
  title text,
  description text,
  price numeric(10,2),
  cuisine text,
  category text,
  status text,
  ingredients text[],
  calories integer,
  allergens text[],
  nutrition_source text,
  photo_path text,
  created_at timestamptz,
  updated_at timestamptz,
  published_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
PARALLEL SAFE
-- CARRIED FORWARD FROM 20260807154039 AND NOT OPTIONAL. `<=>` and ILIKE resolve through
-- search_path, so a caller who could set it could shadow ILIKE with a function returning false and
-- switch off their own exclusion. Inert while this is SECURITY INVOKER; the day somebody makes it
-- DEFINER is the day it stops being inert, and that person has no reason to look here.
SET search_path = ''
AS $$
  WITH candidate AS MATERIALIZED (
  SELECT m.*
  FROM public.meals m
  WHERE
    -- ON OFFER, AND THIS LINE IS NOT REDUNDANT WITH RLS. RLS is the floor: it stops a Customer
    -- reaching someone else's draft, and it deliberately lets the owning Cook read their own.
    -- Without this predicate a Cook searching discovery found their own unpublished drafts among
    -- the results — discovery_rls_test case 6, which exists because it sounded redundant.
    m.status = 'published'

    -- A Meal with no vector is unsearchable. The failure mode of a missing embedding is a Meal that
    -- is harder to find, never one that is lost.
    AND m.embedding IS NOT NULL

    -- Exclusions are a PREDICATE, never a phrase handed to a model. A Meal whose ingredients and
    -- allergens are BOTH empty is WITHHELD: an unknown is treated as a possible yes, which hides
    -- Meals that are fine and is the correct direction to be wrong in.
    AND (
      exclude_terms IS NULL
      OR cardinality(exclude_terms) = 0
      OR (
        (cardinality(m.ingredients) > 0 OR cardinality(m.allergens) > 0)
        AND NOT EXISTS (
          SELECT 1 FROM unnest(exclude_terms) AS term
          WHERE EXISTS (
            SELECT 1 FROM unnest(m.ingredients || m.allergens) AS item
            -- BOTH SIDES FOLDED. Folding only the Cook's side would leave `مكرونه` typed by a
            -- Customer unmatched against `مكرونة` typed by a Cook.
            --
            -- Escaped AFTER folding, and the order is not arbitrary: folding cannot introduce a %
            -- or a _, but it can remove a character between one and its escape if it ran second.
            -- A literal % in a Customer's phrase is a character they typed; unescaped it excluded
            -- every Meal in the marketplace.
            WHERE public.fold_arabic(item) ILIKE '%' || replace(replace(replace(
                    public.fold_arabic(term), '\', '\\'), '%', '\%'), '_', '\_') || '%'
          )
        )
      )
    )

    -- An area nobody wrote returns NOTHING rather than everything — FR-024 forbids the silent
    -- widening, and returning the whole marketplace is the silent widening.
    AND (
      area_query IS NULL
      OR EXISTS (
        SELECT 1 FROM public.kitchen_profiles k
        WHERE k.cook_id = m.cook_id
          AND public.normalise_area(k.area) = public.normalise_area(area_query)
      )
    )
  )
  -- QUALIFIED WITH `candidate.`, and it has to be. RETURNS TABLE puts every output name into scope
  -- inside the body, so a bare `id` here is ambiguous against the output parameter of the same name
  -- and Postgres refuses the function. This is the one hazard the signature change introduces.
  SELECT
    candidate.id,
    candidate.cook_id,
    candidate.title,
    candidate.description,
    candidate.price,
    candidate.cuisine,
    candidate.category,
    candidate.status,
    candidate.ingredients,
    candidate.calories,
    candidate.allergens,
    candidate.nutrition_source,
    candidate.photo_path,
    candidate.created_at,
    candidate.updated_at,
    candidate.published_at
  FROM candidate
  -- Ranking still reads the vector. It simply never returns it.
  --
  -- THE OPERATOR IS SCHEMA-QUALIFIED BECAUSE search_path IS EMPTY. Left bare it raises
  -- "operator does not exist: public.vector <=> public.vector" and the function fails on every
  -- search. ILIKE needs no qualification: it is syntax for pg_catalog.~~*, always in scope.
  ORDER BY candidate.embedding OPERATOR(public.<=>) query_embedding
  LIMIT 50;
$$;

COMMENT ON FUNCTION public.search_meals(vector, text[], text) IS
  'Ranks the Meals the CALLER may see. SECURITY INVOKER — making this DEFINER makes every Meal '
  'findable regardless of status and no existing authorization test would notice. Returns every '
  'column of meals EXCEPT embedding: ranking reads the vector, nobody downloads it.';

-- Restored after the DROP above. Without these every search fails for every Customer.
GRANT EXECUTE ON FUNCTION public.search_meals(vector, text[], text) TO anon, authenticated;
