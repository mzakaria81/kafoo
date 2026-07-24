#!/usr/bin/env bash
# One-time repo bootstrap. Run from the directory containing the generated files.
# Requires: gh (https://cli.github.com), authenticated via `gh auth login`.
# Your token stays on your machine.

set -euo pipefail

OWNER="mzakaria81"
REPO="kafoo"
VISIBILITY="private"   # change to --public only when you're ready

command -v gh >/dev/null || { echo "gh not installed: https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "run: gh auth login"; exit 1; }

# Sanity check: refuse to push if secrets are present
if [ -f .env ]; then
  echo "REFUSING: .env exists in this directory. Remove it or confirm .gitignore covers it."
  grep -q '^\.env$' .gitignore || { echo ".gitignore does not ignore .env — aborting."; exit 1; }
fi

chmod +x scripts/*.sh .claude/hooks/*.sh 2>/dev/null || true

git init -b main
git add .
git commit -m "Add Claude Code configuration and verification gate

CLAUDE.md, path-scoped rules, RLS-enforcing hook, ship-check skill,
rls-reviewer subagent, verify.sh gate, ADR template."

gh repo create "$OWNER/$REPO" --"$VISIBILITY" --source=. --remote=origin --push

echo ""
echo "Done: https://github.com/$OWNER/$REPO"
echo ""
echo "Next:"
echo "  1. cd into the repo and run: claude"
echo "  2. Run /context — confirm CLAUDE.md and business-rules.md appear under Memory files"
echo "  3. Run /doctor if they don't"
echo "  4. Set SUPABASE_PROJECT_REF and SUPABASE_ACCESS_TOKEN in your shell for .mcp.json"
