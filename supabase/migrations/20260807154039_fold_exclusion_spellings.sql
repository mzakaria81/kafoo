-- An exclusion stops depending on two people spelling a word the same way.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHAT WAS BROKEN, MEASURED BEFORE IT WAS FIXED.
--
-- The Customer's side is `ExclusionVocabulary` in packages/domain/lib/exclusion.dart, which lists
-- the ways each food is WRITTEN. The Cook's side is the predicate below, which matched those forms
-- as substrings of what a Cook typed. Neither side folded anything, so the two agreed only where
-- somebody had hand-enumerated the same ة/ه, أ/ا/إ and ي/ى variant on BOTH sides.
--
-- packages/domain/test/exclusion_spelling_coverage_test.dart walks every listed form against every
-- plausible Cook spelling of the same word. Measured 2026-08-07, before this migration:
--
--     156 plausible spellings checked, 13 reached no form of their own exclusion
--     مكرونه (gluten) · عجينه · شعريه · بسطرمه (meat) · قشده (dairy) · جندوفلى · كاليمارى
--
-- and separately, ONE TATWEEL DEFEATED ALL 93 FORMS: `لحـمة` contains no listed form of anything,
-- so a Cook who stretched one word served meat to a Customer who excluded it.
--
-- THE TATWEEL RESULT IS WHY THIS IS A MIGRATION RATHER THAN SEVEN MORE WORDS IN A LIST. The
-- spelling misses could have been enumerated away; a stretched letter cannot, because it can sit at
-- any position in any word. Enumeration closes today's thirteen and leaves the class open.
--
-- The failure is SILENT UNDER-EXCLUSION. SC-005 says an excluded food appears zero times, and a
-- Customer excluding a food is usually doing it for a dietary, religious or health reason. Nothing
-- errors, nothing logs, and the Customer is served the thing they asked not to see.
--
-- IT IS A TWO-SIDED CHANGE AND BOTH SIDES LAND TOGETHER. `fold_arabic` here, `foldArabic` in
-- packages/domain/lib/exclusion.dart, and the same folding in supabase/functions/discover/parse.ts.
-- If they stop agreeing, a Customer's word is recognised on one side and matches nothing on the
-- other — which is the failure this file exists to remove, arriving by a different route. The three
-- carry the same pinned cases in their own suites for exactly that reason.
-- ────────────────────────────────────────────────────────────────────────────────────────────────

-- The same letter rules as `normalise_area`, and deliberately NOT the same function.
--
-- `normalise_area` additionally strips a leading `ال` and maps second names — مصر الجديدة and
-- هليوبوليس are one place. Both are right for a neighbourhood and wrong for a food: `اللحمة` must
-- still contain `لحمة` by substring rather than by article-stripping, and there is no such thing as
-- an alias list for ingredients.
--
-- REUSING IT WOULD ALSO HAVE FORCED A REINDEX. `kitchen_profiles_area_norm` is an expression index
-- over `normalise_area`, and Postgres does not recompute an expression index when the function
-- changes — the index quietly keeps the old values and disagrees with the function, which is the
-- ceiling its own comment names. Nothing is indexed over `fold_arabic`, so this migration needs no
-- REINDEX. The day something is, changing this function does.
CREATE OR REPLACE FUNCTION public.fold_arabic(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
STRICT
SET search_path = ''
AS $$
  SELECT
    -- 4. Unify the letters Arabic writes more than one way. Per character, so it is order-free
    --    against the steps below.
    translate(
      -- 3. Collapse what is left, THEN trim. Trimming first strips only U+0020 — one-argument
      --    btrim is not whitespace-aware — so a leading tab survived the trim, became a space at
      --    the collapse, and stayed. `\tلحم` folded to ` لحم`, and the pattern `% لحم %` then
      --    matched no Cook's ingredient at all. Found by rls-reviewer 2026-08-07, measured, and
      --    the identical ordering bug in normalise_area is fixed below.
      btrim(
        -- 2. WHITESPACE, INCLUDING THE KIND THAT IS NOT ASCII. `[[:space:]]` under COLLATE "C" is
        --    ASCII-only, so a no-break space inside `عين الجمل` was never collapsed and walnut
        --    escaped a nut exclusion. That was also a live DIVERGENCE from the two sibling folds
        --    this function's own COMMENT says it must match: Dart's `\s` and JavaScript's `\s` are
        --    Unicode-aware and collapse all of these. Measured rather than reasoned about.
        --
        --    Reachable without anybody typing one: `meals.ingredients` is AI-extracted text from
        --    analyze-meal, and nothing between the model's output and the column touches it. A
        --    model emitting U+00A0 lands it verbatim, the Cook approves a string that renders
        --    identically to a normal one, and the exclusion fails with nothing logged.
        regexp_replace(
          -- 1. INVISIBLE MARKS GO FIRST AND GO ENTIRELY. Diacritics, tatweel, and the zero-width
          --    and directional characters beside it. FIRST rather than last, because U+FEFF counts
          --    as whitespace to Dart and JavaScript: collapsing before stripping would turn it into
          --    a space in two of the three folds and delete it in the third.
          --
          --    Tatweel was closed by the first version of this function and its invisible
          --    neighbours were not, which left the class half open — `ل‌حم` with a zero-width
          --    non-joiner renders identically to `لحم` on every screen in the product and defeated
          --    every meat exclusion. A Cook wanting to escape a filter needs one invisible
          --    character, and nobody reviewing their Meal could see it.
          regexp_replace(
            lower(value COLLATE "C"),
            U&'[\0640\064B-\065F\0670\06D6-\06ED\200B-\200F\061C\FEFF]', '', 'g'
          ),
          U&'[[:space:]\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+', ' ', 'g'
        )
      ),
      'أإآٱىة',
      'اااايه'
    )
$$;

COMMENT ON FUNCTION public.fold_arabic(text) IS
  'Compares two ways of writing one Arabic word. Governs SPELLING, never meaning. Must fold '
  'identically to foldArabic in packages/domain/lib/exclusion.dart and in discover/parse.ts.';

GRANT EXECUTE ON FUNCTION public.fold_arabic(text) TO anon, authenticated;

-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- normalise_area carries the same trim-before-collapse bug, and it is REACHABLE.
--
-- `btrim(lower(...))` strips U+0020 and nothing else, so a leading tab or newline survived the trim
-- and then became a leading space. That space sits in front of the `^(ال|el-|...)` anchor below, so
-- the definite article is never stripped:
--
--     normalise_area('المهندسين') = normalise_area(E'\tالمهندسين')   ->  false
--
-- A Cook whose area field carries a leading tab is unfindable by area — which is the exact case the
-- btrim was added on 2026-08-07 to fix, defeated by one character it does not cover. `area` is free
-- text a Cook typed and Kafoo never rewrites it, so this is not a hypothetical value.
--
-- Non-ASCII spaces are folded here for the same reason as above.
--
-- THE REINDEX BELOW IS MANDATORY AND THIS FUNCTION'S OWN COMMENT SAYS SO. `kitchen_profiles_area_norm`
-- is an expression index over these values; Postgres does not recompute one when the function
-- changes, so without it the index keeps the old strings and silently disagrees with the function
-- that built it. A kitchen would be findable through a sequential scan and invisible through the
-- index.
-- ────────────────────────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.normalise_area(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
STRICT
SET search_path = ''
AS $$
  SELECT
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
      regexp_replace(
        -- The article strip, now reached because the trim below actually trims.
        btrim(
          translate(
            regexp_replace(
              regexp_replace(
                lower(value COLLATE "C"),
                U&'[\0640\064B-\065F\0670\06D6-\06ED\200B-\200F\061C\FEFF]', '', 'g'
              ),
              U&'[[:space:]\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+', ' ', 'g'
            ),
            'أإآٱىة',
            'اااايه'
          )
        ),
        '^(ال|el-|el |al-|al )', '', 'i'
      )
    AS folded
  ) t
$$;

-- Not optional, and not a tidy-up. See the block above.
REINDEX INDEX public.kitchen_profiles_area_norm;

-- Republished whole rather than patched, because a SQL function has no partial form. Everything
-- outside the exclusion branch is unchanged from 20260806231625_add_meal_embeddings.sql, and the
-- reasoning there — filter first then rank, SECURITY INVOKER, status is not redundant with RLS —
-- still applies in full. Read that file's comments; they are not repeated here.
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
-- INERT TODAY, AND THAT IS WHY IT GOES IN TODAY. This was the only Kafoo-authored function in
-- `public` without it — found by rls-reviewer against pg_proc rather than by reading. It is not
-- exploitable while the function is SECURITY INVOKER and every table is schema-qualified, but
-- `<=>` and ILIKE resolve through search_path, so a caller who could set it could shadow ILIKE
-- with a function returning false and switch off their own exclusion. The comment above warns
-- that somebody may later make this DEFINER; that is the day it stops being inert, and the person
-- making that change has no reason to look here.
SET search_path = ''
AS $$
  WITH candidate AS MATERIALIZED (
  SELECT m.*
  FROM public.meals m
  WHERE
    m.status = 'published'
    AND m.embedding IS NOT NULL
    AND (
      exclude_terms IS NULL
      OR cardinality(exclude_terms) = 0
      OR (
        (cardinality(m.ingredients) > 0 OR cardinality(m.allergens) > 0)
        AND NOT EXISTS (
          SELECT 1 FROM unnest(exclude_terms) AS term
          WHERE EXISTS (
            SELECT 1 FROM unnest(m.ingredients || m.allergens) AS item
            -- BOTH SIDES FOLDED, which is the whole change. Folding only the Cook's side would
            -- leave `مكرونه` typed by a Customer unmatched against `مكرونة` typed by a Cook.
            --
            -- Escaped AFTER folding, and the order is not arbitrary: folding cannot introduce a %
            -- or a _, but it can remove a character between one and its escape if it ran second.
            -- The escape itself is unchanged — a literal % in a Customer's phrase is a character
            -- they typed, and unescaped it excluded every Meal in the marketplace.
            WHERE public.fold_arabic(item) ILIKE '%' || replace(replace(replace(
                    public.fold_arabic(term), '\', '\\'), '%', '\%'), '_', '\_') || '%'
          )
        )
      )
    )
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
  -- THE OPERATOR IS SCHEMA-QUALIFIED BECAUSE search_path IS EMPTY. Left bare it raises
  -- "operator does not exist: public.vector <=> public.vector" and the function fails on every
  -- search — the identical trap 20260806231625 documents above protect_meal_embedding for `<>`,
  -- met again here the moment the pin above went in. ILIKE needs no qualification: it is syntax
  -- for pg_catalog.~~*, and pg_catalog is always in scope.
  ORDER BY embedding OPERATOR(public.<=>) query_embedding
  LIMIT 50;
$$;
