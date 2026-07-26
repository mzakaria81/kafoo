#!/usr/bin/env bash
# Runs on codespace create AND on every rebuild.
#
# Codespaces keeps /workspaces across rebuilds and discards everything else, so
# anything installed here must be reinstalled here — that is the point of this
# file. Nothing in it is secret: credentials come from Codespaces secrets or an
# interactive login, never from the repository.
#
# Every step is idempotent so a rebuild is cheap and a partial failure can be
# retried by re-running this script.

set -euo pipefail

log() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

FLUTTER_DIR="${HOME}/flutter"
FLUTTER_CHANNEL="stable"

log "System packages"
sudo apt-get update -qq
# jq: required by .claude/hooks/check-rls.sh and scripts/verify.sh
# GNU grep is already the default on this image, so `grep -P` works as the
# RLS hook expects — no BSD-grep workaround needed here.
sudo apt-get install -y -qq jq unzip xz-utils >/dev/null

log "Flutter ${FLUTTER_CHANNEL}"
if [ -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "already present at ${FLUTTER_DIR}"
else
  # snap is unavailable in Codespaces containers, so install from git.
  git clone --depth 1 -b "${FLUTTER_CHANNEL}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${HOME}/.pub-cache/bin:${PATH}"
git config --global --add safe.directory "${FLUTTER_DIR}" || true
flutter --version || true

log "melos"
dart pub global activate melos >/dev/null

log "Supabase CLI"
if command -v supabase >/dev/null; then
  echo "already present: $(supabase --version 2>/dev/null || true)"
else
  curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
    | sudo tar -xz -C /usr/local/bin supabase
fi

log "Claude Code"
if command -v claude >/dev/null; then
  echo "already present: $(claude --version 2>/dev/null || true)"
else
  npm install -g @anthropic-ai/claude-code
fi

log "OpenCode"
if command -v opencode >/dev/null; then
  echo "already present: $(opencode --version 2>/dev/null || true)"
else
  npm install -g opencode-ai
fi

log "Agent authentication"
# Both blocks read Codespaces secrets, which arrive as environment variables.
# Nothing is written to the repository and no value is ever echoed.

# Claude Code: `claude setup-token` (run once, anywhere, on a Pro/Max/Team plan)
# mints a long-lived OAuth token. Stored as the CLAUDE_CODE_OAUTH_TOKEN
# Codespaces secret it is picked up automatically — no file to write.
if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  # Anthropic tokens are a single line. A narrow terminal soft-wraps them on
  # screen, and copying from that wrap can carry real newlines into the secret
  # — which GitHub stores happily and Claude Code then rejects. Strip any
  # whitespace and persist the clean value, since an export here would not
  # survive into the user's shell.
  _tok_clean=$(printf '%s' "${CLAUDE_CODE_OAUTH_TOKEN}" | tr -d '[:space:]')
  if [ "${_tok_clean}" != "${CLAUDE_CODE_OAUTH_TOKEN}" ]; then
    echo "Claude Code:  NOTE - CLAUDE_CODE_OAUTH_TOKEN contained whitespace or line"
    echo "              breaks (usually a wrapped copy/paste). Using a stripped copy."
    echo "              Fix the secret itself to silence this on the next rebuild."
    export CLAUDE_CODE_OAUTH_TOKEN="${_tok_clean}"
    printf 'export CLAUDE_CODE_OAUTH_TOKEN=%q\n' "${_tok_clean}" >> "${HOME}/.bashrc"
  fi
  # Length is a shape check only; the value itself is never printed.
  if [ "${#_tok_clean}" -lt 40 ]; then
    echo "Claude Code:  WARNING - token looks too short (${#_tok_clean} chars). It may"
    echo "              have been truncated on paste. Regenerate with 'claude setup-token'."
  else
    echo "Claude Code:  CLAUDE_CODE_OAUTH_TOKEN present — no interactive login needed"
  fi
  unset _tok_clean
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Claude Code:  WARNING - ANTHROPIC_API_KEY is set. Claude Code will bill the"
  echo "              Anthropic API per token instead of using the subscription."
  echo "              Remove it and use CLAUDE_CODE_OAUTH_TOKEN instead."
else
  echo "Claude Code:  no token found — run 'claude' then '/login' (see notes below)"
fi

# OpenCode has no documented env-var login for Zen/Go, so instead of guessing a
# schema we materialize the credentials file verbatim from a secret holding the
# contents of a known-good auth.json. An existing file is never overwritten.
OPENCODE_AUTH_DIR="${HOME}/.local/share/opencode"
if [ -n "${OPENCODE_AUTH_JSON:-}" ] && [ ! -f "${OPENCODE_AUTH_DIR}/auth.json" ]; then
  mkdir -p "${OPENCODE_AUTH_DIR}"
  printf '%s' "${OPENCODE_AUTH_JSON}" > "${OPENCODE_AUTH_DIR}/auth.json"
  chmod 600 "${OPENCODE_AUTH_DIR}/auth.json"
  if jq -e . "${OPENCODE_AUTH_DIR}/auth.json" >/dev/null 2>&1; then
    echo "OpenCode:     credentials restored from OPENCODE_AUTH_JSON"
  else
    echo "OpenCode:     WARNING - OPENCODE_AUTH_JSON is not valid JSON; removing it"
    rm -f "${OPENCODE_AUTH_DIR}/auth.json"
  fi
elif [ -f "${OPENCODE_AUTH_DIR}/auth.json" ]; then
  echo "OpenCode:     existing auth.json left untouched"
else
  echo "OpenCode:     no credentials found — run 'opencode auth login'"
fi

log "Project env file"
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo "created .env from .env.example — fill it in (git-ignored)"
fi

log "Gate check"
./scripts/verify.sh || echo "verify.sh reported failures — see output above"

cat <<'EOF'

============================================================
Setup complete.

Both agent logins can be automated with Codespaces secrets
(repo Settings > Secrets and variables > Codespaces). Set them
once and rebuilds need no interactive login:

  CLAUDE_CODE_OAUTH_TOKEN
      Generate once on any machine already signed in:
          claude setup-token
      Long-lived (about a year), tied to your Claude
      subscription. Revoke at claude.ai if it leaks.

  OPENCODE_AUTH_JSON
      OpenCode has no documented env-var login, so store the
      credentials file itself. After one successful
      `opencode auth login` on any machine:
          cat ~/.local/share/opencode/auth.json
      Paste the whole JSON as the secret value.

Without those secrets, log in interactively once per rebuild:
      claude                then /login
      opencode auth login   then /connect > OpenCode Go

Do NOT set ANTHROPIC_API_KEY. It takes priority over the
subscription token and bills the Anthropic API per token.

Supabase credentials also come from Codespaces secrets
(SUPABASE_PROJECT_REF_DEV, SUPABASE_ACCESS_TOKEN).
============================================================
EOF
