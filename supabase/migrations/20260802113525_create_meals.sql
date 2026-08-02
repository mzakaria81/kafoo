-- The meals table, its ownership rules, and the kitchen_profiles policy E1 left written out.
--
-- ONE FILE ON PURPOSE. The widening SELECT policy on kitchen_profiles is at the foot of this
-- migration rather than in a follow-up, because without it Kafoo has Meals on offer whose kitchens
-- nobody can reach — and that failure is silent. A missing policy returns zero rows rather than
-- erroring, so every suite in the repository stays green while the product is broken.
--
-- Layout, in order: table, indexes, RLS, policies, triggers, storage, then the widening.

CREATE TABLE meals (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ON DELETE CASCADE, and docs/product/domain-model.md says RESTRICT.
  --
  -- The document is right about the end state and wrong about today. RESTRICT protects a Meal that
  -- an Order points at, and no Order exists. What does exist is E1's promise (FR-032) that removing
  -- an account removes everything belonging to it — and RESTRICT would break that promise for the
  -- only case there is.
  --
  -- E4 MUST CHANGE THIS TO RESTRICT in the migration that creates orders. Until then the schema and
  -- the domain document disagree deliberately, and this comment is the record of it.
  cook_id           uuid NOT NULL
                      REFERENCES auth.users(id) ON DELETE CASCADE,

  title             text NOT NULL CHECK (length(trim(title)) > 0),
  description       text NOT NULL CHECK (length(trim(description)) > 0),

  -- numeric, never a float. Money in a binary float is a defect waiting for a decimal that does not
  -- divide, and "the price is the whole cost" is only checkable while the stored number is exactly
  -- the number the Cook typed and the Customer is shown.
  price             numeric(10,2) NOT NULL CHECK (price > 0),

  cuisine           text NOT NULL CHECK (length(trim(cuisine)) > 0),
  category          text NOT NULL CHECK (length(trim(category)) > 0),

  status            text NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft','published','unavailable','archived')),

  ingredients       text[] NOT NULL DEFAULT '{}',

  -- Nullable because the AI Assistant may be unreachable (FR-014) or refused (FR-029) and the Cook
  -- must still be able to offer their food. Bounded because a model that returns 190,000 must not
  -- have it stored — this is the last line of the schema-validation defence, not the first.
  calories          integer CHECK (calories IS NULL OR (calories > 0 AND calories < 20000)),

  allergens         text[] NOT NULL DEFAULT '{}',

  -- Defaults to the pessimistic answer: a figure is an estimate unless something proves otherwise.
  -- Derived on UPDATE by derive_nutrition_source below — never taken from a client's claim.
  nutrition_source  text NOT NULL DEFAULT 'ai'
                      CHECK (nutrition_source IN ('ai','cook')),

  photo_path        text,

  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  -- When it FIRST went on offer. Separate from updated_at because a Meal taken off the menu and put
  -- back has not been republished, and conflating the two loses the moment MealPublished measures.
  published_at      timestamptz
);

-- No UNIQUE on anything. A Cook may offer the same dish twice; Kafoo is not the judge of that.

-- cook_id is the predicate of two policies, so an unindexed column would make every policy
-- evaluation a sequential scan.
CREATE INDEX meals_cook_id_idx ON meals (cook_id);

-- Serves the widening policy's EXISTS at the foot of this file, which is evaluated once per
-- kitchen row on every public read. Partial, because it only ever asks about published Meals.
CREATE INDEX meals_published_cook_id_idx ON meals (cook_id) WHERE status = 'published';

ALTER TABLE meals ENABLE ROW LEVEL SECURITY;

-- ── Policies, one per operation ─────────────────────────────────────────────────────────────────

-- The owner sees everything of theirs, at every status — including drafts, which no one else can
-- see at all.
CREATE POLICY "cook reads own meals"
  ON meals FOR SELECT TO authenticated
  USING (cook_id = auth.uid());

-- FR-024. The first use of the anon role in Kafoo, and deliberately narrow: status = 'published'
-- and nothing else. A Meal on offer is readable without signing in; everything else is not.
CREATE POLICY "anyone reads a published meal"
  ON meals FOR SELECT TO anon, authenticated
  USING (status = 'published');

CREATE POLICY "cook creates own meals"
  ON meals FOR INSERT TO authenticated
  WITH CHECK (cook_id = auth.uid());

-- BOTH USING AND WITH CHECK. Without WITH CHECK a Cook could set cook_id to someone else and hand
-- over a Meal, which FR-016 forbids.
--
-- Note for anyone verifying this: the lifecycle trigger below refuses the same reassign, and being
-- a BEFORE UPDATE trigger it runs first, so breaking this line does not turn the obvious test red.
-- meals_rls_test.sql case 8b disables that trigger for one statement precisely so this policy can
-- be mutation-tested on its own. Weaken this to WITH CHECK (true) and 8b must fail.
CREATE POLICY "cook updates own meals"
  ON meals FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (cook_id = auth.uid());

-- Drafts only. Nothing that has been on offer is deletable by anyone — archiving is what that is
-- for, and after E4 a deleted Meal would take a Customer's order history with it.
CREATE POLICY "cook deletes own drafts"
  ON meals FOR DELETE TO authenticated
  USING (cook_id = auth.uid() AND status = 'draft');

-- ── The lifecycle is a constraint, not a convention ──────────────────────────────────────────────

-- FR-018 and FR-016 in SQL. The cook_id check duplicates the UPDATE policy's WITH CHECK on purpose:
-- a policy protects against a hostile client, a constraint protects against Kafoo's own code, and
-- the two failure modes are different.
CREATE FUNCTION enforce_meal_lifecycle() RETURNS trigger
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

CREATE TRIGGER enforce_meal_lifecycle_trigger
  BEFORE UPDATE ON meals
  FOR EACH ROW EXECUTE FUNCTION enforce_meal_lifecycle();

-- The same first-publish rule for a Meal that is created already on offer. Without this, a Meal
-- inserted straight to published would carry no published_at at all.
CREATE FUNCTION set_meal_published_at() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
    NEW.published_at := now();
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER set_meal_published_at_trigger
  BEFORE INSERT ON meals
  FOR EACH ROW EXECUTE FUNCTION set_meal_published_at();

-- ── nutrition_source cannot be claimed by the client ─────────────────────────────────────────────

-- The one place where believing the client destroys Principle II. A client that writes
-- nutrition_source = 'cook' over an untouched AI estimate turns a guess into an apparent
-- verification, and nothing downstream can tell the difference afterwards.
--
-- A Cook who changes the number owns the number. A Cook who approves without changing it leaves an
-- estimate labelled as one, which is the whole of User Story 2 expressed where it cannot be
-- bypassed.
--
-- INSERT is deliberately not covered. There is no previous value to compare against, so the
-- database cannot tell an approved estimate from the Cook's own figure, and the Cook is the one
-- confirming. What this guarantees is every write after that: nobody relabels a stored estimate.
CREATE FUNCTION derive_nutrition_source() RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.calories IS DISTINCT FROM OLD.calories
     OR NEW.allergens IS DISTINCT FROM OLD.allergens THEN
    NEW.nutrition_source := 'cook';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER derive_nutrition_source_trigger
  BEFORE UPDATE ON meals
  FOR EACH ROW EXECUTE FUNCTION derive_nutrition_source();

-- ── FR-017: a Meal needs a Cook who owns a Kitchen Profile ───────────────────────────────────────

-- A trigger, NOT a foreign key to kitchen_profiles.cook_id.
--
-- The foreign key is the tempting version and it is wrong: it would make a Meal belong to a Kitchen
-- Profile rather than to a Cook, and FR-016 says a Meal belongs to a Cook permanently. A Cook who
-- rebuilt their Kitchen Profile would lose their Meals with it.
--
-- SECURITY DEFINER, which is load-bearing twice over. As an invoker function it would read
-- kitchen_profiles through the caller's own RLS, so an insert naming another Cook would fail with
-- "no Kitchen Profile" — telling the caller something about a row they cannot see, and masking the
-- authorization refusal that should have answered. Definer rights make this trigger answer the
-- question it was asked and leave authorization to the policies.
CREATE FUNCTION require_kitchen_profile() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.kitchen_profiles WHERE cook_id = NEW.cook_id
  ) THEN
    RAISE EXCEPTION 'a Meal needs a Cook with a Kitchen Profile';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER require_kitchen_profile_trigger
  BEFORE INSERT ON meals
  FOR EACH ROW EXECUTE FUNCTION require_kitchen_profile();

-- ── meal-photos ──────────────────────────────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'meal-photos',
  'meal-photos',
  true,
  52428800,  -- 50 MiB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- READ THIS BEFORE ADDING A PUBLIC SELECT POLICY HERE.
--
-- data-model.md says this bucket's read is "public", and the authorization contract's case 33 says
-- anyone can read a photo. Both are satisfied, and NOT by a public SELECT policy: the bucket is
-- public, and object URLs on a public bucket bypass policy checks entirely. A photo is served to
-- anyone who has its path.
--
-- What a public SELECT policy would additionally do is make the Storage ENUMERATION endpoint answer
-- for anyone holding the publishable key, which ships inside the app. Photos live one folder per
-- Cook, so enumerating the bucket returns the Cook roster and every Cook's account id. That is the
-- hole closed on kitchen-photos in 20260802065138, measured on a preview branch, and this bucket
-- would reopen it under a different name. Those documents were written on 2026-07-31, before that
-- was known.
--
-- Owner-scoped read leaks nothing and keeps the four policies symmetrical, which matters because an
-- asymmetric set invites someone to "fix" it back.
CREATE POLICY "owner reads own meal photo"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Path is {auth.uid()}/{meal_id}.jpg. The Meal id is in the path so a Cook with several Meals
-- cannot overwrite one photo with another — the flat {uid}/ layout E1 used stops working the moment
-- a person owns more than one thing.
CREATE POLICY "owner uploads meal photo"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "owner updates meal photo"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "owner deletes meal photo"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── The widening E1 wrote out and left ───────────────────────────────────────────────────────────

-- FR-025. E1 shipped with no public read on kitchen_profiles, deliberately, because
-- discoverability follows from having food on offer and there was none.
--
-- This is the whole of Kafoo's discovery rule: a kitchen is findable exactly while its Cook has a
-- Meal on offer. A Cook whose Meals are all drafts has never opened; a Cook who has taken
-- everything off the menu is closed. Both are correctly invisible, and the fix for "my kitchen
-- disappeared" is to put a Meal back on the menu — never to widen this predicate.
--
-- The EXISTS reads meals under the caller's own RLS, so it resolves through the "anyone reads a
-- published meal" policy above and reveals nothing that policy does not already permit.
CREATE POLICY "anyone reads a kitchen with food on offer"
  ON kitchen_profiles FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM meals
                 WHERE meals.cook_id = kitchen_profiles.cook_id
                   AND meals.status = 'published'));
