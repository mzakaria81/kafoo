#!/usr/bin/env bash
# SessionStart hook: inject the using-superpowers skill as session context.
#
# Adapted from obra/superpowers (MIT, Copyright (c) 2025 Jesse Vincent),
# hooks/session-start @3dcbd5c. Two changes from upstream, both because the
# skills are vendored into .claude/skills/ rather than installed as a plugin:
#   1. The skill is resolved from CLAUDE_PROJECT_DIR, not CLAUDE_PLUGIN_ROOT.
#   2. Output is pinned to the Claude Code format. Upstream branches on
#      CLAUDE_PLUGIN_ROOT to pick a format; that variable is unset here, so
#      the upstream fallback would emit a top-level `additionalContext` that
#      Claude Code does not read, silently doing nothing.
#
# See .claude/skills/_vendor-licenses/VENDORED.md for provenance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
SKILL_FILE="${PROJECT_DIR}/.claude/skills/using-superpowers/SKILL.md"

# A missing skill must not break session startup — exit quietly.
[ -f "$SKILL_FILE" ] || exit 0

skill_content=$(cat "$SKILL_FILE")

# Escape for JSON embedding. Each ${s//old/new} is a single C-level pass.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

escaped=$(escape_for_json "$skill_content")

session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${escaped}\n</EXTREMELY_IMPORTANT>"

# printf rather than a heredoc: bash 5.3+ hangs on heredocs here.
# See https://github.com/obra/superpowers/issues/571
printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$session_context"

exit 0
