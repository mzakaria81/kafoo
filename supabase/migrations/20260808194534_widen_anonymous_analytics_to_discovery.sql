-- Discovery happens without an account, so its events must reach the table without one.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHAT WAS ACTUALLY BROKEN, AND FOR HOW LONG.
--
-- `anonymous records pre-sign-in funnel only` allowed exactly two event names — `SignInStarted` and
-- `SignInFailed`. Written in E1, and correct in E1: those were the only two things that could
-- happen before somebody was known to Kafoo.
--
-- E3 then built discovery on the premise that it works SIGNED OUT. That premise is the whole reason
-- a shared WhatsApp link is worth anything and the entire basis of the Customer web surface, where
-- nobody is ever signed in. Its three events — `SearchPerformed`, `SearchFailed`,
-- `RecommendationAccepted` — were emitted by anonymous callers against a policy naming neither of
-- them, rejected with 42501, and swallowed: `emitEvent` catches everything on purpose, because a
-- measurement outage must never interrupt a Customer.
--
-- So the whole of E3 recorded NO SEARCHES AT ALL for the case E3 was built for, the app worked, the
-- web worked, and the gate stayed green. `analytics_events_rls_test.sql` case 3 passed throughout —
-- it asserts an anonymous caller cannot insert a non-funnel event, which was a true description of
-- E1's world and never stopped being one.
--
-- Found on 2026-08-08 while deciding what analytics cannot be recovered later. It is in
-- `docs/product/business-questions.md` with the rest of that decision, because the lesson outlives
-- the fix: a silent failure that is correct by design is the hardest kind to see.
--
-- ────────────────────────────────────────────────────────────────────────────────────────────────
-- WHY THE POLICY IS REPLACED RATHER THAN A SECOND ONE ADDED.
--
-- Postgres ORs permissive policies together, so a second policy would work — and would leave two
-- statements about what an anonymous caller may record, in two places, disagreeing the first time
-- either changed. One policy, one list.
--
-- THE LIST IS STILL A LIST, AND THAT IS THE POINT. Widening it to "any event" would be this defect
-- in the other direction: an anonymous caller inventing a Cook publishing a Meal, or a person being
-- created, into the table product decisions are read off. What is added here is exactly the set a
-- person with no account can genuinely cause — they can search, be told nothing answered, and open
-- a Meal. Nothing else.
--
-- `person_id IS NULL` is unchanged and is the half that matters most. An anonymous caller must not
-- be able to write activity onto a real person's row, which would be worse than recording nothing.
--
-- NO NEW TABLE AND NO NEW COLUMN, so there is no new ownership question. `analytics_events` keeps
-- its insert-only posture: no SELECT, UPDATE or DELETE policy exists, reading is service-role only
-- (FR-040), and the grants from 20260805180727 are untouched.
--
-- Cases 7 to 11 of `analytics_events_rls_test.sql` were written before this file and seen to fail
-- against it with 42501 — the exact error a Customer's search was dying of in production.

DROP POLICY IF EXISTS "anonymous records pre-sign-in funnel only" ON public.analytics_events;

CREATE POLICY "anonymous records what a person with no account can do"
  ON public.analytics_events FOR INSERT TO anon
  WITH CHECK (
    person_id IS NULL
    AND name IN (
      -- Sign-in, which happens before there is a person to attribute it to.
      'SignInStarted',
      'SignInFailed',
      -- Discovery, which happens whether or not there is ever going to be one.
      'SearchPerformed',
      'SearchFailed',
      'RecommendationAccepted',
      'MealOpened'
    )
  );

COMMENT ON TABLE public.analytics_events IS
  'Write-once product measurement. Anonymous callers may record sign-in and discovery only, '
  'always with a null person_id. Reading is service-role only. Never contains anything a person '
  'typed or said — see docs/product/event-model.md.';
