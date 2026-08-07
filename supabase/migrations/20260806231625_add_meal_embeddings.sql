-- Discovery's foundation: a Meal findable by meaning, and an area findable however it is spelled.
--
-- ONE FILE ON PURPOSE, same reasoning as the migration that created `meals`. The column, the index,
-- the write protection, the area normalisation and the ranking function are one change: any of them
-- landing without the others produces a database that works and a feature that is either unfindable
-- or unsafe.
--
-- NO NEW TABLE, SO NO NEW OWNERSHIP QUESTION, AND NO NEW POLICY. `meals` keeps its four
-- per-operation policies and `kitchen_profiles` keeps E2's widening SELECT. Discovery is a
-- different way of asking the question E2 already answered — see
-- specs/004-customer-discovery/research.md §2.
--
-- The proof obligation sits on this migration anyway, because every existing authorization test
-- passes whether or not the new path leaks: none of them travel it.
-- supabase/tests/discovery_rls_test.sql was written first and seen to fail.

CREATE EXTENSION IF NOT EXISTS vector;

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- The vector
-- ────────────────────────────────────────────────────────────────────────────────────────────────
--
-- 768 DIMENSIONS, AND THE NUMBER IS LOAD-BEARING. Measured 2026-08-06 against pgvector 0.8.6 on
-- the Postgres major version config.toml pins:
--
--     vector(768)   HNSW index -> CREATE INDEX
--     vector(2000)  HNSW index -> CREATE INDEX
--     vector(3072)  HNSW index -> ERROR: column cannot have more than 2000 dimensions
--
-- 3072 is the provider's DEFAULT output size, so it is what an implementation lands on by not
-- choosing. It would produce a column that works perfectly and cannot be indexed: correct answers,
-- sequential scans, no error anywhere, and a problem that only appears at a scale where it is
-- expensive to fix. docs/ops/spike-discovery-embeddings.md measured that 768 also loses almost
-- nothing in quality — 1536 moves MRR by 0.026.
--
-- NULLABLE, AND THE NULLABILITY IS A RULE RATHER THAN A DEFAULT. A Meal with no vector is invisible
-- to search and still visible to browsing. That makes an incomplete backfill, an unreachable
-- provider, or a failed embedding produce a Meal that is HARDER TO FIND — never one that is lost,
-- and never a Cook who cannot publish because a model provider is down.
ALTER TABLE public.meals ADD COLUMN embedding vector(768);

COMMENT ON COLUMN public.meals.embedding IS
  'A machine representation of title and description. Not a claim, shown to nobody, and never '
  'written by a client — see protect_meal_embedding below. NULL means unsearchable, not lost.';

-- CREATED NOW, UNUSED NOW, AND NOT DEAD WEIGHT. Cosine distance, matching how the vectors are
-- normalised before they are stored.
--
-- This comment said "the index the ranking function needs" and contradicted the note above
-- `search_meals`, which explains why the function deliberately does not use it. An index whose own
-- comment says it is required is the setup for somebody either dropping it as unused or rearranging
-- the function to satisfy this line — and that rearrangement is the defect the function's note
-- describes. Read that note before touching either.
--
-- It is deferred capacity: exact ranking fits the budget until roughly 180,000 Meals, and this is
-- what makes the day after that a design change rather than a migration.
CREATE INDEX meals_embedding_hnsw ON public.meals
  USING hnsw (embedding vector_cosine_ops);

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- Nothing but Kafoo writes a vector
-- ────────────────────────────────────────────────────────────────────────────────────────────────
--
-- WHY THIS IS A TRIGGER AND NOT A COLUMN PRIVILEGE. The obvious form is
-- `REVOKE UPDATE (embedding) ON meals FROM authenticated`, and it does not work: E2 granted UPDATE
-- at TABLE level, and Postgres does not let a column-level revoke carve a hole in a table-level
-- grant. Measured rather than assumed —
--
--     GRANT UPDATE ON t TO r;  REVOKE UPDATE (b) ON t FROM r;
--     has_column_privilege(r, t, 'b', 'UPDATE') -> still true
--
-- The alternative was to revoke the table grant and re-grant every column except this one, which
-- works and quietly breaks the next migration that adds a column and forgets to grant it. A trigger
-- is self-maintaining and fails loudly, which is the trade this repository prefers.
--
-- WHAT IT PREVENTS, and it is not hypothetical: a client that can supply the vector can supply the
-- one nearest every query, and that Cook's Meal ranks first for everything — permanently,
-- invisibly, and against every other Cook. Ranking manipulation is a trust failure in a
-- marketplace, and Principle I outranks the convenience of a narrower guard.
--
-- RLS does NOT give you this. `cook updates own meals` permits a Cook to update their own row, and
-- that includes this column.
--
-- IT TESTS THE JWT CLAIM FIRST, BECAUSE current_user ALONE IS BYPASSABLE. Demonstrated by
-- rls-reviewer on 2026-08-07: a Cook's direct UPDATE is refused, and the identical UPDATE routed
-- through any postgres-owned SECURITY DEFINER function executable by `authenticated` succeeds —
-- the trigger sees current_user = 'postgres' and waves it through. This table already carries a
-- SECURITY DEFINER trigger, so the pattern is live rather than hypothetical, and the next definer
-- RPC that copies or reseeds a Meal would carry a client's vector through in silence.
--
-- PostgREST sets `request.jwt.claims` as a transaction-local GUC and SECURITY DEFINER does not
-- reset it, so the claim survives the frame that rewrites current_user. The current_user branch is
-- KEPT rather than replaced: under the publishable-key scheme the app already uses, an anonymous
-- request may carry no claims at all, and an allowlist with no claim to read must still refuse.
CREATE OR REPLACE FUNCTION public.protect_meal_embedding()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  -- nullif and a guarded cast, because the GUC is EMPTY rather than absent once a session has
  -- cleared it, and ''::jsonb raises "invalid input syntax for type json" — which would make this
  -- trigger throw on every write to meals rather than on the one it exists to refuse.
  claim_role text := (
    SELECT nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  );
BEGIN
  IF (claim_role IS NOT NULL AND claim_role <> 'service_role')
     OR (claim_role IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
    IF TG_OP = 'INSERT' AND NEW.embedding IS NOT NULL THEN
      RAISE EXCEPTION 'meals.embedding is written by Kafoo, not by a client'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    -- The comparison is written out and the operator schema-qualified, because
    -- `IS DISTINCT FROM` resolves the vector `=` operator through search_path — which this
    -- function deliberately empties. Left implicit it raises
    -- "operator does not exist: public.vector = public.vector" and the trigger fails OPEN on
    -- every write, which is the direction that matters.
    IF TG_OP = 'UPDATE' AND (
         (NEW.embedding IS NULL) <> (OLD.embedding IS NULL)
         OR (NEW.embedding IS NOT NULL AND OLD.embedding IS NOT NULL
             AND NEW.embedding OPERATOR(public.<>) OLD.embedding)
       ) THEN
      RAISE EXCEPTION 'meals.embedding is written by Kafoo, not by a client'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER protect_meal_embedding
  BEFORE INSERT OR UPDATE ON public.meals
  FOR EACH ROW EXECUTE FUNCTION public.protect_meal_embedding();

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- An area, however it is spelled
-- ────────────────────────────────────────────────────────────────────────────────────────────────
--
-- `kitchen_profiles.area` is free text a Cook wrote about their own kitchen. It is not validated,
-- standardised, or drawn from a list, and it never will be — it is one of exactly five public
-- details, and adding structure to it is a change to that rule rather than a schema tweak.
--
-- Two Cooks writing the same neighbourhood disagree on spelling in ways Arabic makes routine, and
-- none of them are ambiguous to a human reader: الدقي/الدقى, المهندسين/مهندسين, العجوزه/العجوزة,
-- إمبابة/امبابة.
--
-- IN SQL AND NOWHERE ELSE. Writing this in Dart for the Customer's side and SQL for the Cook's side
-- would be one rule in two languages, which is exactly the drift ADR-0008 Amendment 1 names as the
-- cost of a second front-end — arriving inside a single feature rather than across two surfaces.
--
-- IMMUTABLE because the expression index below depends on it. CEILING WORTH KNOWING: changing this
-- function does NOT recompute that index. Postgres keeps the old values and the index quietly
-- disagrees with the function. Any migration touching this function must REINDEX in the same file.
CREATE OR REPLACE FUNCTION public.normalise_area(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
STRICT
SET search_path = ''
AS $$
  SELECT
    -- The alias list lives here rather than in a table. A table would be a NEW table needing RLS in
    -- this same migration, for a handful of rows nobody writes at runtime — and a list that changes
    -- through a reviewed migration beats one that changes through an INSERT.
    --
    -- It handles places with a genuine SECOND NAME, which no normalisation reaches: مصر الجديدة and
    -- هليوبوليس and Heliopolis are one place under three names, not three spellings of one.
    CASE folded
      WHEN 'مصر الجديده' THEN 'heliopolis'
      WHEN 'هليوبوليس'   THEN 'heliopolis'
      WHEN 'heliopolis'  THEN 'heliopolis'
      WHEN 'معادي'       THEN 'maadi'
      WHEN 'maadi'       THEN 'maadi'
      ELSE folded
    END
  FROM (
    SELECT
      -- Collapse whitespace, then strip a leading definite article. Order matters: the article is
      -- only recognisable once the string is trimmed.
      regexp_replace(
        regexp_replace(
          -- Unify the letters Arabic writes more than one way, strip the diacritics most typing
          -- omits, and remove tatweel. Latin is case-folded so "Maadi" and "maadi" are one area.
          translate(
            -- COLLATE "C" pins the case mapping, which is what makes IMMUTABLE honest. lower()
            -- otherwise resolves collation from its argument — measured, lower('MAADI' COLLATE
            -- "tr-x-icu") is 'maadı', which misses the alias below. The expression index stores
            -- values computed at build time and Postgres will not recompute them, so an ICU or
            -- glibc bump would silently make the index disagree with the function and a kitchen
            -- would stop being findable by area. Pinning it removes the whole class.
            --
            -- btrim and the whitespace collapse were DESCRIBED in the comment below and absent
            -- from the body until 2026-08-07: normalise_area(' المهندسين') did not equal
            -- normalise_area('المهندسين'), because the anchor never reached the article past a
            -- leading space. An area typed by a Customer arrives from speech and is not trimmed
            -- for us.
            regexp_replace(btrim(lower(value COLLATE "C")), '[[:space:]]+', ' ', 'g'),
            -- ة maps to ه. It mapped to ITSELF until 2026-08-07 — an identity entry that made
            -- العجوزة and العجوزه two different areas, and put مصر الجديدة permanently out of
            -- reach of the heliopolis alias below. Both are named in this file's own comments as
            -- the cases the function exists to solve, and neither had an assertion.
            'أإآٱىة',
            'اااايه'
          ),
          '[ً-ْـ]', '', 'g'
        ),
        '^(ال|el-|el |al-|al )', '', 'i'
      )
    AS folded
  ) t
$$;

COMMENT ON FUNCTION public.normalise_area(text) IS
  'Compares two ways of writing one area. Governs SPELLING, never meaning: two different '
  'neighbourhoods must stay different. Changing this requires a REINDEX of kitchen_profiles_area_norm.';

-- An expression index rather than a stored column, so a Kitchen Profile gains no field and its
-- public face stays at exactly five details. A Cook's own words are never rewritten.
CREATE INDEX kitchen_profiles_area_norm ON public.kitchen_profiles
  (public.normalise_area(area));

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- The ranking function
-- ────────────────────────────────────────────────────────────────────────────────────────────────
--
-- SECURITY INVOKER, AND THAT ONE WORD IS THE WHOLE AUTHORIZATION STORY. As DEFINER this function
-- would make every Meal findable regardless of status, and no existing test would notice because
-- none of them travel this path. discovery_rls_test.sql case 12 asserts the mode against the
-- catalogue rather than inferring it from behaviour, precisely because a DEFINER function returns
-- correct-looking results against a fixture that happens to be public.
--
-- RLS decides what is visible; this ranks only what survived. Discovery gains no authority of its
-- own.
--
-- THIS COMMENT USED TO SAY THE OPPOSITE OF WHAT IT NOW SAYS, and the correction is the point.
-- It read: "ORDER BY is placed so the HNSW index can be used. Written the other way — filtering in
-- an outer query the planner cannot push into — Postgres computes every distance and returns THE
-- RIGHT ANSWER SLOWLY." Every clause of that is true. What it missed is that the arrangement it
-- recommended returns THE WRONG ANSWER QUICKLY, and the wrong answer is an empty list. See the
-- measurement above the body.
--
-- Slow and right beats fast and empty, at the sizes Kafoo will see for years. Check the plan
-- directly when changing this — correctness of results on a small fixture is not evidence either
-- way, which is how the original arrangement survived review.
CREATE OR REPLACE FUNCTION public.search_meals(
  query_embedding vector(768),
  exclude_terms text[] DEFAULT NULL,
  area_query text DEFAULT NULL
)
RETURNS SETOF public.meals
LANGUAGE sql
STABLE
SECURITY INVOKER
PARALLEL SAFE
-- FILTER FIRST, RANK SECOND. THE ORDER IS THE CORRECTNESS ARGUMENT, NOT A PERFORMANCE CHOICE.
--
-- An HNSW scan visits hnsw.ef_search candidates — 40 by default — and returns them in distance
-- order. Filter those candidates AFTERWARDS and a narrow filter over a large corpus returns NOTHING
-- while matching Meals plainly exist, because the global nearest neighbours were all somewhere else.
--
-- Measured 2026-08-07, 5,000 published Meals in one area and 1 in أسوان:
--     genuinely on offer in أسوان                          1
--     HNSW then post-filter                                0   ← what a Customer was told
--     HNSW then post-filter, hnsw.iterative_scan=strict    0   ← reached 4,991 rows, still missed it
--     filter first, then order exactly                     1   in 0.19 ms
--
-- THIS MATTERS BECAUSE OF WHAT KAFOO PROMISES. FR-024 says Kafoo tells a Customer their area is
-- empty, and FR-024a then offers them the areas that are not. Both statements are untrue if "empty"
-- can mean "the index stopped looking", and the Customer has no way to tell the difference.
--
-- A NOTE HERE PREVIOUSLY BLAMED THE PARAMETERISED PLAN and said the same query worked outside the
-- function. Re-measured with EXPLAIN: it does not. It fails identically written out, so the
-- function was never the variable — post-filtering was. `hnsw.iterative_scan` widened the scan and
-- did not close the hole, so it is gone rather than kept for looking directionally right.
--
-- THE COST OF BEING EXACT, MEASURED RATHER THAN FEARED. The MATERIALIZED CTE narrows first, so the
-- ranking sorts only what survived. With a narrowing filter it is faster than the index path. With
-- NO filter it sorts the whole corpus: 27 ms at 5,001 Meals, against a one-second budget for search.
-- Linear, so the budget is reached somewhere near 180,000 Meals.
--
-- SO THE HNSW INDEX IS CURRENTLY UNUSED BY THIS FUNCTION, and that is deliberate. It is kept for
-- the corpus size that needs it, and taking it then is a one-line change guarded by a measurement.
-- Taking it now buys 26 ms and costs the ability to answer "is there anything in أسوان" truthfully.
AS $$
  WITH candidate AS MATERIALIZED (
  SELECT m.*
  FROM public.meals m
  WHERE
    -- ON OFFER, AND THIS LINE IS NOT REDUNDANT WITH RLS.
    --
    -- RLS is the FLOOR, not the ceiling: it stops a Customer reaching someone else's draft, and it
    -- deliberately lets the owning Cook read their own. Without this predicate a Cook searching
    -- discovery found their own unpublished drafts among the results — caught by
    -- discovery_rls_test case 6, which is the case that exists because it sounded redundant.
    -- Discovery shows what is on offer; the Cook's drafts have their own screen.
    m.status = 'published'

    -- A Meal with no vector is unsearchable. See the column comment: the failure mode of a missing
    -- embedding is a Meal that is harder to find, never one that is lost.
    AND m.embedding IS NOT NULL

    -- Exclusions are a PREDICATE, never a phrase handed to a model. Measured 2026-08-06: asking for
    -- food with no meat by meaning returned meat dishes at precision@5 of 0.00. A Customer
    -- excluding a food is usually doing so for dietary, religious or health reasons, so being wrong
    -- here is a betrayal rather than a poor result.
    --
    -- A Meal whose ingredients and allergens are BOTH empty is WITHHELD, not shown: an unknown is
    -- treated as a possible yes. This hides Meals that are perfectly fine, and that is the correct
    -- direction to be wrong in.
    AND (
      -- NULL and '{}' must mean the same thing. They did not: an empty array fell through to the
      -- withhold-on-unknown branch and removed every Meal whose ingredients and allergens are both
      -- empty, so a Customer who excluded NOTHING lost Meals.
      exclude_terms IS NULL
      OR cardinality(exclude_terms) = 0
      OR (
        (cardinality(m.ingredients) > 0 OR cardinality(m.allergens) > 0)
        AND NOT EXISTS (
          SELECT 1 FROM unnest(exclude_terms) AS term
          WHERE EXISTS (
            SELECT 1 FROM unnest(m.ingredients || m.allergens) AS item
            -- The term is escaped. Unescaped, a literal % in a Customer's phrase is a wildcard —
            -- measured, ARRAY['%'] excluded every Meal in the marketplace. It fails in the safe
            -- direction, which is exactly why nobody would have noticed.
            WHERE item ILIKE '%' || replace(replace(replace(term, '\', '\\'), '%', '\%'), '_', '\_') || '%'
          )
        )
      )
    )

    -- Narrowing by area matches the Cook's own words after normalisation, so a spelling never hides
    -- a kitchen. An area nobody wrote returns NOTHING rather than everything — FR-024 forbids the
    -- silent widening, and returning the whole marketplace is the silent widening.
    AND (
      area_query IS NULL
      OR EXISTS (
        SELECT 1 FROM public.kitchen_profiles k
        WHERE k.cook_id = m.cook_id
          AND public.normalise_area(k.area) = public.normalise_area(area_query)
      )
    )
  )
  SELECT * FROM candidate
  ORDER BY embedding <=> query_embedding
  LIMIT 50;
$$;

COMMENT ON FUNCTION public.search_meals(vector, text[], text) IS
  'Ranks the Meals the CALLER may see. SECURITY INVOKER — making this DEFINER makes every Meal '
  'findable regardless of status and no existing authorization test would notice.';

GRANT EXECUTE ON FUNCTION public.search_meals(vector, text[], text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.normalise_area(text) TO anon, authenticated;
