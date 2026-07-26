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

log "Project env file"
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo "created .env from .env.example — fill it in (git-ignored)"
fi

log "Gate check"
./scripts/verify.sh || echo "verify.sh reported failures — see output above"

cat <<'EOF'

============================================================
Setup complete. Two interactive logins remain — neither can
be baked into this image, because both are per-user and
credential-bearing:

  claude          then /login   → subscription sign-in
  opencode auth login           → /connect → OpenCode Go

Do NOT set ANTHROPIC_API_KEY. If it is set, Claude Code bills
the Anthropic API per token instead of using your subscription.

Supabase credentials come from Codespaces secrets
(SUPABASE_PROJECT_REF_DEV, SUPABASE_ACCESS_TOKEN), configured
in repo Settings > Secrets and variables > Codespaces.
============================================================
EOF
