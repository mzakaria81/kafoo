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

log "System packages"
sudo apt-get update -qq
# jq: required by .claude/hooks/check-rls.sh and scripts/verify.sh
# GNU grep is already the default on this image, so `grep -P` works as the
# RLS hook expects — no BSD-grep workaround needed here.
sudo apt-get install -y -qq jq unzip xz-utils >/dev/null

log "Toolchain"
# Shared with .claude/hooks/session-start.sh so Codespaces and a web session
# get the same Dart toolchain. --with-android adds the SDK, which Codespaces
# wants for release builds and a web session skips for speed.
./scripts/install-toolchain.sh --with-android
export PATH="${HOME}/flutter/bin:${HOME}/.pub-cache/bin:${HOME}/.deno/bin:${PATH}"
export ANDROID_HOME="${HOME}/sdk/android"

log "Persisting toolchain PATH"
if ! grep -q "Kafoo development toolchain" "${HOME}/.bashrc" 2>/dev/null; then
  cat >> "${HOME}/.bashrc" <<EOF

# Kafoo development toolchain
export PATH="\${HOME}/flutter/bin:\${HOME}/.pub-cache/bin:\${HOME}/.deno/bin:\${HOME}/sdk/android/cmdline-tools/latest/bin:\${HOME}/sdk/android/platform-tools:\${PATH}"
export FLUTTER_ROOT="\${HOME}/flutter"
export ANDROID_HOME="\${HOME}/sdk/android"
EOF
  echo "added to ~/.bashrc"
fi

# The Supabase CLI used to be installed here, from the release tarball at
# whatever `latest` happened to be. It now comes from scripts/install-toolchain.sh
# above, pinned to the version CI uses — so Codespaces, a web session and the
# deploy workflow all run the same CLI. Installing it here as well would
# reintroduce exactly the drift that script exists to prevent.

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

# OpenCode reads OPENCODE_AUTH_CONTENT before it reads auth.json, so that
# secret alone is a complete login — nothing to write. It is undocumented but
# present in packages/opencode/src/auth/index.ts, hence the file fallback below
# in case it is ever removed.
#
# auth.json is a map of provider ID to credential:
#   {"<provider>": {"type":"api","key":"..."}}
#   {"<provider>": {"type":"oauth","refresh":"...","access":"...","expires":0}}
#   {"<provider>": {"type":"wellknown","key":"...","token":"..."}}
OPENCODE_AUTH_DIR="${HOME}/.local/share/opencode"
if [ -n "${OPENCODE_AUTH_CONTENT:-}" ]; then
  if printf '%s' "${OPENCODE_AUTH_CONTENT}" | jq -e . >/dev/null 2>&1; then
    echo "OpenCode:     OPENCODE_AUTH_CONTENT present — read natively, no file needed"
  else
    echo "OpenCode:     WARNING - OPENCODE_AUTH_CONTENT is not valid JSON. OpenCode"
    echo "              ignores it silently, so this would look like a missing login."
  fi
elif [ -n "${OPENCODE_AUTH_JSON:-}" ] && [ ! -f "${OPENCODE_AUTH_DIR}/auth.json" ]; then
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

log "Claude Code plugins"
# Behavioural preferences, not project requirements. They are here because
# plugins install to the container's home directory, which a rebuild destroys —
# so without this they silently disappear and nobody notices why the output
# changed. Set KAFOO_SKIP_PLUGINS=1 to opt out of all of them, or delete the
# entry from the list below to drop just one.
#
#   caveman   — compresses output; drops articles and filler
#   ponytail  — biases toward the simplest solution that works: YAGNI,
#               standard library first, no unrequested abstractions
#
# ponytail's bias aligns with Simplicity, second in the constitution's priority
# order. It does NOT outrank User trust, which is first: an argument that
# something is simpler never justifies weakening RLS, skipping a negative test,
# or dropping an Arabic string. If a suggestion trades trust for brevity,
# the constitution wins.
install_claude_plugin() {
  local repo="$1" plugin="$2"
  claude plugin marketplace add "$repo" >/dev/null 2>&1 \
    && claude plugin install "$plugin" >/dev/null 2>&1 \
    && echo "  ${plugin} installed" \
    || echo "  ${plugin} skipped — run '/plugin marketplace add ${repo}' manually"
}

if [ "${KAFOO_SKIP_PLUGINS:-${KAFOO_SKIP_CAVEMAN:-0}}" = "1" ]; then
  echo "KAFOO_SKIP_PLUGINS set — skipping all plugins"
elif command -v claude >/dev/null 2>&1; then
  install_claude_plugin JuliusBrussee/caveman   caveman@caveman
  install_claude_plugin DietrichGebert/ponytail ponytail@ponytail
else
  echo "claude CLI not on PATH yet — install plugins manually after first login"
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

  OPENCODE_AUTH_CONTENT
      The whole auth.json as a single-line JSON string.
      OpenCode reads this before the file, so it is a complete
      login on its own. After one `opencode auth login` on any
      machine:
          jq -c . ~/.local/share/opencode/auth.json
      Paste that output as the secret value. Shape is
      provider ID -> credential, e.g.
          {"<provider>":{"type":"api","key":"..."}}

  OPENCODE_AUTH_JSON  (fallback)
      Same JSON, but written to disk as auth.json instead.
      Only needed if OPENCODE_AUTH_CONTENT ever stops working:
      it is undocumented, so it could change.

Without those secrets, log in interactively once per rebuild:
      claude                then /login
      opencode auth login   then /connect > OpenCode Go

Do NOT set ANTHROPIC_API_KEY. It takes priority over the
subscription token and bills the Anthropic API per token.

Supabase credentials also come from Codespaces secrets
(SUPABASE_PROJECT_REF, SUPABASE_ACCESS_TOKEN). .mcp.json reads
SUPABASE_PROJECT_REF; if it is unset the MCP server starts
and immediately exits, which looks like a broken server
rather than a missing variable.
============================================================
EOF
