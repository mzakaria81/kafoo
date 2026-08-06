-- REVOKE the four table privileges no part of Kafoo uses, from the three Data API roles.
--
-- WHY THIS EXISTS. Measured against the live project on 2026-08-05 and confirmed again on
-- 2026-08-06: anon, authenticated and service_role each held TRUNCATE, REFERENCES, TRIGGER and
-- MAINTAIN on every table in public. Nothing granted them deliberately — they arrive by default
-- privilege, which is why every table had them and why the next table would have had them too.
-- They survived `..._grant_data_api_privileges.sql`, whose own comment argues against exactly this:
-- a grant wider than the policy set is a second line of defence thrown away for nothing.
--
-- TRUNCATE IS THE ONE THAT MATTERS, AND IT IS THE ONE RLS CANNOT HELP WITH. Row Level Security
-- filters rows; TRUNCATE does not read rows. There is no policy that can refuse it, narrow or
-- otherwise. A single statement empties a table, and the migration that added RLS to that table
-- would not have moved.
--
-- THIS IS DEFENCE IN DEPTH, NOT A CLOSED DOOR — say so plainly rather than dressing it up.
-- PostgREST does not expose TRUNCATE, so nothing reachable with a publishable key could have
-- called it. Removing it is worth doing because the privilege was there waiting for a surface that
-- reaches it, not because one exists today.
--
-- The other three are smaller and go for the same reason: REFERENCES lets a foreign key be pointed
-- at the table, TRIGGER lets code be attached to it, MAINTAIN allows VACUUM and ANALYZE. No Kafoo
-- caller does any of those as a Data API role.
--
-- SERVICE_ROLE LOSES THEM TOO, which is one role wider than the work package asked for. Its key
-- never reaches a phone, so the exposure is different in kind — but no Edge Function truncates,
-- references, triggers or maintains anything, and a test asserting "no Data API role holds these"
-- while one of them quietly did would be the sort of half-true assertion this repository keeps
-- finding. Restoring it is a one-line GRANT if a caller ever needs it.
--
-- REVERSIBILITY. Nothing is lost. Re-granting is `GRANT TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON
-- ALL TABLES IN SCHEMA public TO ...`, and no data is touched by this file.

REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN
  ON ALL TABLES IN SCHEMA public
  FROM anon, authenticated, service_role;

-- THE SECOND STATEMENT IS THE ONE THAT LASTS.
--
-- `ON ALL TABLES` is evaluated once, against the tables that exist right now. It says nothing about
-- the next table, which would inherit the same four privileges from the default privilege that
-- produced this situation in the first place — so revoking without this line fixes today and leaves
-- the tap running.
--
-- `FOR ROLE postgres` is named rather than left implicit. The default privilege belongs to the role
-- that granted it; `pg_default_acl` on both the live project and `scripts/local-db-bootstrap.sql`
-- shows `postgres` as the grantor. A bare ALTER DEFAULT PRIVILEGES would target whichever role
-- happens to apply the migration, and if that is ever not postgres it would create a second, empty
-- entry and silently leave the first one granting.
--
-- This does NOT contradict the "DO NOT add ALTER DEFAULT PRIVILEGES to this migration" note in
-- `..._grant_data_api_privileges.sql`. That rule exists so a future table cannot silently *inherit*
-- a privilege and skip review. This line removes an inheritance; the direction is the whole point,
-- and grants stay explicit per table exactly as that file requires.

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE TRUNCATE, REFERENCES, TRIGGER, MAINTAIN ON TABLES
  FROM anon, authenticated, service_role;

-- WHAT KEEPS THIS TRUE. `supabase/tests/data_api_grants_test.sql` enumerates every ordinary table
-- in public and turns red, naming the table and privilege, if any of the three roles holds any of
-- the four. That guard is dynamic, so a table added later is covered without anyone remembering to
-- add an assertion — and it was seen to fail before this migration existed, against a local
-- harness that now reproduces production's default privilege rather than being quieter than it.
