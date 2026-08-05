-- GRANT the Data API roles the table privileges they need to read and write through PostgREST.
--
-- WHY THIS EXISTS. Measured against the live project on 2026-08-05: anon, authenticated and
-- service_role each held TRUNCATE, REFERENCES, TRIGGER and MAINTAIN on every table in public, and
-- none of SELECT, INSERT, UPDATE or DELETE. Every PostgREST call returned 42501 "permission denied"
-- — the app could not read or write a single row in production. RLS is the inner gate; GRANT is the
-- outer one, and the outer gate was shut.
--
-- DELIBERATELY NARROWER THAN THE SUPABASE CONVENTION of `GRANT ALL ... TO anon, authenticated,
-- service_role`. A grant wider than the policy set is a second line of defence thrown away for
-- nothing: if anon holds DELETE at the table level but no DELETE policy exists, the statement still
-- removes zero rows — but the privilege is there, waiting for a policy author to accidentally open
-- it. Kafoo already applies this reasoning to credentials elsewhere (the service-role key must never
-- reach a phone), and the same discipline belongs at the database layer.
--
-- THE COST OF THIS CHOICE. A future table or Edge Function that needs a privilege will fail with a
-- confusing 42501 until someone adds a GRANT line here. That failure is legible rather than
-- mysterious because `supabase/tests/data_api_grants_test.sql` asserts the matrix for every table
-- in public, and turns red if a new table ships without one. The test is what makes the gap visible
-- instead of silent.
--
-- DO NOT add `ALTER DEFAULT PRIVILEGES` to this migration. Grants must be explicit per table so
-- that a future table cannot silently inherit them and skip review. The test above is the guard
-- against exactly that mistake.
--
-- DO NOT widen a grant to match a future policy without adding a matching assertion to the test.
-- A privilege granted but untested is a privilege nobody can prove is intentional.

-- ── meals ───────────────────────────────────────────────────────────────────────────────────────
-- Policies: SELECT (anon, authenticated), INSERT/UPDATE/DELETE (authenticated).
-- service_role has no policy on meals and no caller that reaches it.

GRANT SELECT ON public.meals TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.meals TO authenticated;

-- ── kitchen_profiles ────────────────────────────────────────────────────────────────────────────
-- Policies: SELECT (anon, authenticated), INSERT/UPDATE (authenticated).
-- No DELETE policy — a Kitchen Profile is removed by ON DELETE CASCADE when the account goes.
-- So no DELETE grant either: the refusal happens one layer earlier and cannot be reopened by a
-- policy written later.
-- service_role has no policy on kitchen_profiles and no caller that reaches it.

GRANT SELECT ON public.kitchen_profiles TO anon;
GRANT SELECT, INSERT, UPDATE ON public.kitchen_profiles TO authenticated;

-- ── analytics_events ────────────────────────────────────────────────────────────────────────────
-- Policies: INSERT (anon for pre-sign-in funnel only, authenticated for own events).
-- No SELECT, UPDATE or DELETE policies — events are write-once by design, so INSERT is the only
-- privilege any role gets.
--
-- service_role gets INSERT because supabase/functions/delete-account/index.ts writes an
-- AccountRemoved event with the service-role client (bare .insert(), no .select()).
-- Nothing else uses service_role on this table.

GRANT INSERT ON public.analytics_events TO anon;
GRANT INSERT ON public.analytics_events TO authenticated;
GRANT INSERT ON public.analytics_events TO service_role;

-- ── A NOTE FOR WHOEVER FINDS AN RLS SUITE ISSUING ITS OWN GRANT ─────────────────────────────────
--
-- Three privileges above were briefly granted wider — DELETE on kitchen_profiles, SELECT and UPDATE
-- on analytics_events — because without them the existing RLS suites fail: they assert "the row
-- survives" and "zero rows come back", and with no grant the statement raises 42501 before RLS is
-- consulted at all. That is a real loss of coverage. A DELETE policy written wrongly on
-- kitchen_profiles tomorrow would not be caught, because the GRANT layer refuses first.
--
-- The answer is not to widen production. `supabase/tests/kitchen_profiles_rls_test.sql` and
-- `analytics_events_rls_test.sql` now issue those grants themselves, inside the transaction they
-- already roll back, so the policy layer is exercised in the test and nothing is granted in a
-- deployed database. Keep it that way: a privilege that exists only to make an assertion reachable
-- belongs in the assertion's transaction, not in a migration.
