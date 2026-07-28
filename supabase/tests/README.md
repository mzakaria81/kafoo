# RLS tests

Every new table gets a test here proving a **non-owner reads zero rows**. Write the negative test
first — a policy nobody tested is a policy that does not work.

`scripts/verify.sh` enforces that a migration creating a table also enables RLS in the same file,
and `.claude/hooks/check-rls.sh` blocks the write before it is committed. Neither of those checks
that the policy is *correct*; that is what these tests are for.

See `.claude/rules/supabase.md` for the policy shape and `.claude/agents/rls-reviewer.md` for the
review checklist.
