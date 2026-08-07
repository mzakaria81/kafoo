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
    -- Diacritics and tatweel last: they are removed outright rather than mapped, and removing them
    -- first would let a stretched letter split a pair the translate below is meant to see.
    regexp_replace(
      translate(
        -- COLLATE "C" for the same reason normalise_area pins it: lower() otherwise resolves
        -- collation from its argument, and an ICU bump would change what this function returns.
        -- IMMUTABLE has to be true rather than merely declared.
        regexp_replace(btrim(lower(value COLLATE "C")), '[[:space:]]+', ' ', 'g'),
        'أإآٱىة',
        'اااايه'
      ),
      '[ً-ْـ]', '', 'g'
    )
$$;

COMMENT ON FUNCTION public.fold_arabic(text) IS
  'Compares two ways of writing one Arabic word. Governs SPELLING, never meaning. Must fold '
  'identically to foldArabic in packages/domain/lib/exclusion.dart and in discover/parse.ts.';

GRANT EXECUTE ON FUNCTION public.fold_arabic(text) TO anon, authenticated;

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
  ORDER BY embedding <=> query_embedding
  LIMIT 50;
$$;
