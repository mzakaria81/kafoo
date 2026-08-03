-- A draft is a saved intention, not a finished Meal awaiting a button.
--
-- The original meals migration required title, description, price, cuisine and category on every
-- row. That made the earliest possible row the last moment of the Meal conversation: a Cook who
-- walked away halfway left nothing behind. US1 persists as it goes, and an abandoned conversation
-- is required to leave a draft — which is only possible if a row can exist before every answer does.
--
-- The completeness requirement has not disappeared. It has moved off the columns and onto the
-- transition. A Meal may be incomplete while its status is draft, and must be complete to be
-- anything else — on insert already non-draft, on the draft-to-offer transition, and on every later
-- write to a non-draft row, so a Meal on offer cannot have a required field taken away afterwards.

-- Drop NOT NULL from the five conversation answers. The existing CHECK constraints stay: a CHECK
-- passes when its expression is NULL, so empty strings and non-positive prices are still refused
-- without blocking an absent value.
ALTER TABLE meals
  ALTER COLUMN title DROP NOT NULL,
  ALTER COLUMN description DROP NOT NULL,
  ALTER COLUMN price DROP NOT NULL,
  ALTER COLUMN cuisine DROP NOT NULL,
  ALTER COLUMN category DROP NOT NULL;

-- Completeness on every UPDATE of a non-draft row. Lives in enforce_meal_lifecycle because that
-- trigger already owns the status transitions; a third overlapping trigger would only duplicate it.
CREATE OR REPLACE FUNCTION enforce_meal_lifecycle() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.cook_id <> OLD.cook_id THEN
    RAISE EXCEPTION 'a Meal cannot change Cooks';
  END IF;

  IF OLD.status = 'archived' AND NEW.status <> 'archived' THEN
    RAISE EXCEPTION 'a retired Meal cannot return to offer';
  END IF;

  IF OLD.status = 'draft' AND NEW.status IN ('unavailable','archived') THEN
    RAISE EXCEPTION 'a draft goes on offer before it goes anywhere else';
  END IF;

  -- Incomplete is fine on a draft. Anything else on offer — or staying on offer — must carry every
  -- answer the conversation asked for. Without this check on every write, a published Meal could
  -- have its price emptied out and a Customer would see a Meal with no price.
  IF NEW.status <> 'draft'
     AND (NEW.title IS NULL
          OR NEW.description IS NULL
          OR NEW.price IS NULL
          OR NEW.cuisine IS NULL
          OR NEW.category IS NULL) THEN
    RAISE EXCEPTION
      'a Meal that is not a draft must have title, description, price, cuisine and category';
  END IF;

  -- The first-publish moment, derived rather than accepted from the client.
  --
  -- Set once and never overwritten: a Meal put back on the menu has been made available again, not
  -- republished. A client-supplied value would get exactly this case wrong, and MealPublished is
  -- measured against it.
  IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
    NEW.published_at := now();
  END IF;

  NEW.updated_at := now();

  RETURN NEW;
END;
$$;

-- The same completeness rule for a Meal that is created already non-draft. Without this, an INSERT
-- straight to published with a missing field would bypass the update-path check entirely.
CREATE OR REPLACE FUNCTION set_meal_published_at() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.status <> 'draft'
     AND (NEW.title IS NULL
          OR NEW.description IS NULL
          OR NEW.price IS NULL
          OR NEW.cuisine IS NULL
          OR NEW.category IS NULL) THEN
    RAISE EXCEPTION
      'a Meal that is not a draft must have title, description, price, cuisine and category';
  END IF;

  IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
    NEW.published_at := now();
  END IF;

  RETURN NEW;
END;
$$;
