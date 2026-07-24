---
name: ship-check
description: Run before opening a PR or declaring a task complete. Verifies the Kafoo definition of done — tests, RLS coverage, localization, AI evals, analytics, domain docs. Use when the user says "done", "ready to ship", "open a PR", or "/ship-check".
allowed-tools: Bash, Read, Grep, Glob
---

# Ship check

Do not report "done" until every item below is verified. Verified means you ran the check and read
the output, not that it looks probably fine.

## 1. Gate

```bash
./scripts/verify.sh
```

If it fails, fix it. Do not report the failure as a caveat and move on.

## 2. RLS coverage

```bash
git diff --name-only main...HEAD -- supabase/migrations/
```

For each changed migration:
- Every `CREATE TABLE` has a matching `ENABLE ROW LEVEL SECURITY` in the same file
- Policies are per-operation, not `FOR ALL USING (true)`
- Every `FOR UPDATE` policy has both `USING` and `WITH CHECK`
- A negative test exists in `supabase/tests/` proving a non-owner reads zero rows

If any table is missing a negative test, write it now.

## 3. Localization

```bash
git diff main...HEAD -- '*.dart' | grep -nE "Text\(\s*['\"]" || echo "no hardcoded Text strings"
```

Every new user-facing string has an entry in both the `ar` and `en` ARB files. The Arabic entry must
be conversational Egyptian, not Modern Standard Arabic. If you could not write natural Egyptian
Arabic for a string, flag it for founder review — do not ship English-only.

Check RTL: new layout code uses `EdgeInsetsDirectional` and `start`/`end`, never `left`/`right`.

## 4. AI changes

If anything under `packages/ai/` or `prompts/` changed:
- The prompt file's `version` was bumped and `last_evaluated` updated
- Golden cases run and pass, including the dialect and adversarial cases
- No provider SDK is imported outside `packages/ai/lib/provider/`
- No path exists where AI output reaches the database without human approval

## 5. Analytics

If the change touches a tracked business action (publish, order, review, search, recommendation),
the canonical event is emitted with the exact PascalCase name from CLAUDE.md. Not a new name, not a
variant.

## 6. Domain docs

If entities, lifecycles, or ownership changed, `docs/product/domain-model.md` is updated in the same
commit. If vocabulary changed, `docs/vision/glossary.md` too.

## 7. Vocabulary

```bash
git diff main...HEAD | grep -inE '\b(product|vendor|seller|buyer|listing|chef|restaurant|store|chatbot)\b' || echo "clean"
```

Any hit that refers to a Kafoo domain concept is a bug. Rename it.

## 8. Principles

Answer these honestly before reporting done:

- Did this add a form field or screen that a conversation could have replaced?
- Did this add a setting that solves a real user problem, or one that avoids a decision?
- Would a non-technical Cairo home cook understand this flow without help?
- Does anything here trade user trust for growth or convenience?

If the answer to any of these is uncomfortable, say so in the summary rather than hiding it.

## Output

Report as a checklist with pass/fail per item and the actual command output for anything that
failed. Do not summarize a failure as a warning.
