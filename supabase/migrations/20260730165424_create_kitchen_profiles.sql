CREATE TABLE kitchen_profiles (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cook_id         uuid NOT NULL UNIQUE
                    REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    text NOT NULL CHECK (length(trim(display_name)) > 0),
  story           text NOT NULL CHECK (length(trim(story)) > 0),
  area            text NOT NULL CHECK (length(trim(area)) > 0),
  delivery_terms  text NOT NULL CHECK (length(trim(delivery_terms)) > 0),
  photo_path      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE kitchen_profiles ENABLE ROW LEVEL SECURITY;

-- Owner reads own Kitchen Profile only. No public policy in E1.
-- E2 must add the widening policy when the meals table exists (see data-model.md).
CREATE POLICY "cook reads own kitchen profile"
  ON kitchen_profiles FOR SELECT TO authenticated
  USING (cook_id = auth.uid());

CREATE POLICY "cook creates own kitchen profile"
  ON kitchen_profiles FOR INSERT TO authenticated
  WITH CHECK (cook_id = auth.uid());

-- Both USING and WITH CHECK are required on UPDATE.
-- Without WITH CHECK, a Cook could reassign cook_id to another person (FR-010).
CREATE POLICY "cook updates own kitchen profile"
  ON kitchen_profiles FOR UPDATE TO authenticated
  USING (cook_id = auth.uid())
  WITH CHECK (cook_id = auth.uid());

-- No DELETE policy. A Kitchen Profile is removed by ON DELETE CASCADE when the account goes.
-- Deny-by-default means the absence of a policy IS the enforcement.
