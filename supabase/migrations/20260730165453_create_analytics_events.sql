CREATE TABLE analytics_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL,
  person_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  attributes  jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- A signed-in person may record their own activity only.
CREATE POLICY "person records own events"
  ON analytics_events FOR INSERT TO authenticated
  WITH CHECK (person_id = auth.uid());

-- Sign-in funnel events happen before there is a person to attribute them to.
-- Narrowed to the two pre-authentication events with person_id forced to null.
CREATE POLICY "anonymous records pre-sign-in funnel only"
  ON analytics_events FOR INSERT TO anon
  WITH CHECK (
    person_id IS NULL
    AND name IN ('SignInStarted', 'SignInFailed')
  );

-- No SELECT, UPDATE, or DELETE policies.
-- Reading is service-role only (FR-040). Events are write-once by design.
