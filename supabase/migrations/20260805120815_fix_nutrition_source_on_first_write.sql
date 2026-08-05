-- Approving an estimate is not verifying it.
--
-- `derive_nutrition_source` decides who owns a Meal's calories and allergens, and it exists because
-- the client must not be believed on that question (T017). It promoted a figure to the Cook's own
-- whenever the value changed — correct for a correction, wrong for the write that puts a value
-- there in the first place.
--
-- A Cook cannot publish without approving every estimate, and approving writes the AI Assistant's
-- own number onto a column that held nothing. That read as a change, so EVERY published Meal came
-- out labelled as a figure a person had checked. A Customer avoiding gluten would have read a guess
-- as verified fact — the one direction docs/product/domain-model.md says this field must never fail
-- in, and the distinction `nutrition_source` exists to carry.
--
-- So the promotion now requires a value to REPLACE. The first write leaves the label as the AI
-- Assistant's; changing a stored figure still makes it the Cook's.
--
-- The known inaccuracy, chosen deliberately: a Cook who types their own figure as the very first
-- thing that column ever holds is recorded as an estimate. The database cannot tell that write
-- apart from an approval without believing the client about which act it was, and believing the
-- client is what this trigger exists to refuse. The error therefore runs toward calling a Cook's
-- figure an estimate rather than calling an estimate verified — the badge is over-applied rather
-- than missing, which is the safe direction for someone reading an allergen list.
--
-- The sharpest instance of that, worth naming rather than leaving to be discovered: the AI
-- Assistant proposes no allergens, the Cook adds a nut warning, and it is stored as an estimate.
-- The warning still reaches the Customer and still carries the badge; what is lost is that a person
-- put it there. Correcting a list that already had something in it — including emptying it — is
-- recorded as the Cook's, which is the direction that matters most.
--
-- Nothing is backfilled. Rows already written under the old rule say `cook` and there is no record
-- of which of them were approvals, so a backfill would be a guess about which Meals a person
-- actually checked. Cases 26 to 28 in supabase/tests/meals_rls_test.sql cover the behaviour from
-- here on.

CREATE OR REPLACE FUNCTION derive_nutrition_source() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  -- The two columns say "nothing here yet" differently, and the difference is not cosmetic.
  -- `calories` is nullable, so absence is NULL. `allergens` is `NOT NULL DEFAULT '{}'`, so a draft
  -- nobody has answered carries an empty array rather than a null — an `IS NOT NULL` test on it is
  -- always true and would have left the allergen half of this trigger behaving exactly as before,
  -- silently. Absence for allergens is therefore an empty list.
  IF (OLD.calories IS NOT NULL AND NEW.calories IS DISTINCT FROM OLD.calories)
     OR (cardinality(OLD.allergens) > 0 AND NEW.allergens IS DISTINCT FROM OLD.allergens) THEN
    NEW.nutrition_source := 'cook';
  END IF;

  RETURN NEW;
END;
$$;
