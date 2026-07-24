#!/usr/bin/env bash
# Fires after Claude writes or edits a file.
# If a migration creates a table without enabling RLS, exit 2 so the message is
# fed back to Claude as a blocking error rather than a silent pass.
#
# This is the enforcement layer. CLAUDE.md is a request; a hook is a rule.
# Requires jq on PATH.

set -euo pipefail

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE" ]] && exit 0
[[ "$FILE" != *"supabase/migrations/"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# Tables created in this migration
CREATED=$(grep -ioP 'CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?(public\.)?\K[a-z_][a-z0-9_]*' "$FILE" || true)
[[ -z "$CREATED" ]] && exit 0

MISSING=()
while IFS= read -r TABLE; do
  [[ -z "$TABLE" ]] && continue
  if ! grep -iqP "ALTER\s+TABLE\s+(public\.)?${TABLE}\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY" "$FILE"; then
    MISSING+=("$TABLE")
  fi
done <<< "$CREATED"

if [[ ${#MISSING[@]} -gt 0 ]]; then
  {
    echo "BLOCKED: table(s) created without RLS in $(basename "$FILE"): ${MISSING[*]}"
    echo ""
    echo "Add to the SAME migration file, for each table:"
    echo "  ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;"
    echo "  CREATE POLICY ... FOR SELECT ..."
    echo "  CREATE POLICY ... FOR INSERT ... WITH CHECK ..."
    echo "  CREATE POLICY ... FOR UPDATE ... USING ... WITH CHECK ..."
    echo ""
    echo "Then add a negative test in supabase/tests/ proving a non-owner reads zero rows."
    echo "See .claude/rules/supabase.md."
  } >&2
  exit 2
fi

exit 0
