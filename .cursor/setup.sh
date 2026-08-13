#!/usr/bin/env bash
# Cloud Agent environment bootstrap for Kafoo.
#
# Runs as the `ubuntu` user (passwordless sudo available) after Cursor checks out
# the repository. Idempotent by design: it is the environment's `install` step,
# so it may run against a bare default image or a warm snapshot, more than once.
#
# What it prepares:
#   - a Node with native TypeScript support ahead of the runtime's bundled node
#     (apps/web tests run `node --test lib/*_test.ts` with no flags),
#   - Postgres 17 + pgTAP + pgvector for the RLS authorization suites, which run
#     against a real cluster with no Docker (scripts/local-db.sh),
#   - the Kafoo Dart/Flutter toolchain, Deno, the Supabase CLI, opencode, and a
#     bootstrapped Melos workspace (scripts/install-toolchain.sh),
#   - the Customer web surface's node dependencies (apps/web).
#
# The full gate — ./scripts/verify.sh — passes with every check running (no
# skips) once this completes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

log() { printf '  [kafoo-setup] %s\n' "$1" >&2; }

# --- Node: native TypeScript support must win over the runtime's node ---------
# apps/web's `web surface` gate check runs `node --test lib/*_test.ts` with no
# flags, which needs a Node that strips types by default (>= 22.18). The base
# image ships nvm with such a Node; the runtime otherwise prepends an older node.
# Put nvm's node first for THIS process, and persist it for every future shell.
NVM_NODE_BIN="$(ls -d "${HOME}"/.nvm/versions/node/v*/bin 2>/dev/null | sort -V | tail -1 || true)"
if [ -n "${NVM_NODE_BIN}" ]; then
  export PATH="${NVM_NODE_BIN}:${PATH}"
  log "node: $(node -v) at ${NVM_NODE_BIN}"
else
  log "node: no nvm node found — using $(command -v node || echo none)"
fi

# Persist the toolchain PATH for every future login shell (~/.bashrc is sourced).
if ! grep -q ">>> kafoo toolchain >>>" "${HOME}/.bashrc" 2>/dev/null; then
  cat >> "${HOME}/.bashrc" <<'RC'

# >>> kafoo toolchain >>>
# A Node with native TypeScript support must beat the runtime's bundled node,
# then the Kafoo toolchain (Flutter/Dart, Deno) goes on PATH.
KAFOO_NODE_BIN="$(ls -d "$HOME"/.nvm/versions/node/v*/bin 2>/dev/null | sort -V | tail -1)"
[ -n "$KAFOO_NODE_BIN" ] && export PATH="$KAFOO_NODE_BIN:$PATH"
export FLUTTER_ROOT="$HOME/flutter"
export PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$HOME/.deno/bin:$PATH"
# <<< kafoo toolchain <<<
RC
  log "persisted toolchain PATH to ~/.bashrc"
fi
export FLUTTER_ROOT="${HOME}/flutter"
export PATH="${HOME}/flutter/bin:${HOME}/.pub-cache/bin:${HOME}/.deno/bin:${PATH}"

# --- Postgres 17 + pgTAP + pgvector -------------------------------------------
# The authorization suites (scripts/local-db.sh) initialise a real cluster and
# run pgTAP — no Docker. install-toolchain.sh installs these only as root; here
# we have passwordless sudo, so install them if they are not already present.
# The major version is read from supabase/config.toml so it tracks the deployed DB.
PG_MAJOR="$(grep -E '^major_version[[:space:]]*=' supabase/config.toml | head -1 | tr -dc '0-9')"
PG_EXT="/usr/share/postgresql/${PG_MAJOR}/extension"
if [ -x "/usr/lib/postgresql/${PG_MAJOR}/bin/initdb" ] \
   && [ -f "${PG_EXT}/pgtap.control" ] && [ -f "${PG_EXT}/vector.control" ]; then
  log "postgres ${PG_MAJOR} + pgtap + pgvector: already present"
else
  log "postgres ${PG_MAJOR} + pgtap + pgvector: installing"
  . /etc/os-release
  if [ ! -f /etc/apt/sources.list.d/pgdg.list ]; then
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
      | sudo gpg --dearmor -o /usr/share/keyrings/pgdg.gpg
    echo "deb [signed-by=/usr/share/keyrings/pgdg.gpg] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" \
      | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null
  fi
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    "postgresql-${PG_MAJOR}" "postgresql-${PG_MAJOR}-pgtap" "postgresql-${PG_MAJOR}-pgvector"
fi

# --- Kafoo Dart/Flutter toolchain, Deno, Supabase CLI, opencode, Melos --------
# With nvm's node first on PATH, install-toolchain.sh's `npm install -g` targets
# a user-writable prefix, so the Supabase CLI and opencode install without root.
./scripts/install-toolchain.sh

# --- Customer web surface dependencies ----------------------------------------
( cd apps/web && npm ci )

log "kafoo cloud environment ready — run ./scripts/verify.sh for the full gate"
