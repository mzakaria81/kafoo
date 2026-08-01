#!/usr/bin/env bash
# Single source of truth for the toolchain.
#
# Called by BOTH environment setups so they cannot drift apart:
#   .devcontainer/post-create.sh   (Codespaces)  — with --with-android
#   .claude/hooks/session-start.sh (web session) — without
#
# The only intended difference between the two environments is the Android SDK:
# it is needed to build a release candidate but adds minutes to a session start,
# so the web session skips it and installs it on demand.
#
# Installs: Flutter/Dart, melos, Deno, the Supabase CLI, the opencode CLI, and
# optionally the Android SDK. Deno and opencode are cheap (seconds) and both
# were missing in the session that built E1, which cost that session the ability
# to run the Edge Function tests at all — see docs/HANDOFF.md.
#
# Idempotent. Progress goes to stderr so a caller can keep stdout clean for a
# hook's JSON output.

set -euo pipefail

WITH_ANDROID=0
[ "${1:-}" = "--with-android" ] && WITH_ANDROID=1

FLUTTER_DIR="${HOME}/flutter"
ANDROID_HOME="${ANDROID_HOME:-${HOME}/sdk/android}"
DENO_INSTALL="${DENO_INSTALL:-${HOME}/.deno}"
FLUTTER_CHANNEL="stable"

log() { printf '  %s\n' "$1" >&2; }

export PATH="${FLUTTER_DIR}/bin:${HOME}/.pub-cache/bin:${DENO_INSTALL}/bin:${PATH}"

# --- Flutter (brings Dart) --------------------------------------------------
if [ -x "${FLUTTER_DIR}/bin/dart" ]; then
  log "flutter: already present"
else
  # snap is unavailable in these containers, so install from git.
  log "flutter: cloning ${FLUTTER_CHANNEL} (a few minutes on a cold container)"
  git clone --depth 1 -b "${FLUTTER_CHANNEL}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}" >&2 2>&1
fi
# Flutter refuses to run from a directory git considers unsafe, which is what a
# root-owned clone looks like.
git config --global --add safe.directory "${FLUTTER_DIR}" || true
log "dart: $(dart --version 2>&1 | head -1)"

# --- melos ------------------------------------------------------------------
if command -v melos >/dev/null 2>&1; then
  log "melos: already present"
else
  log "melos: activating"
  dart pub global activate melos >&2 2>&1
fi

# --- Deno -------------------------------------------------------------------
# Edge Functions are Deno (.claude/rules/supabase.md). Without it the function
# and its contract tests cannot even be type-checked, which is how three
# TypeScript errors survived review in E1: the tests had been written with Dart
# method names (verifyOTP, uploadBinary) and nothing had ever parsed the file.
if command -v deno >/dev/null 2>&1; then
  log "deno: already present"
else
  log "deno: installing"
  # -y so it never waits for input; the installer edits shell rc files, and the
  # PATH that matters is exported above and persisted by the caller.
  curl -fsSL https://deno.land/install.sh \
    | DENO_INSTALL="${DENO_INSTALL}" sh -s -- -y >&2 2>&1
fi
log "deno: $(deno --version 2>&1 | head -1)"

# --- Supabase CLI -----------------------------------------------------------
# `supabase start`, `supabase db reset`, `supabase migration new` and the E1
# authorization suites in docs/ops/verifying-e1.md all shell out to this.
#
# It used to be installed only by .devcontainer/post-create.sh, so a web session
# got every other tool and not this one — precisely the drift this file exists
# to prevent, and it went unnoticed because verifying-e1.md tells the reader to
# run post-create.sh, which is not what a web session runs.
#
# Pinned to the version .github/workflows/deploy.yml resolves, so a migration
# that applies locally applies in CI. Installed from npm rather than the release
# tarball: no sudo and no /usr/local/bin, which a web session may not be able to
# write to, and it is the same source CI already uses.
#
# Keep this equal to SUPABASE_CLI_VERSION in .github/workflows/deploy.yml. The
# previous value there, 2.66.2, was never published to npm — only 2.66.0 and
# 2.66.1 exist — so `npx supabase@2.66.2` could only ever fail. Nobody saw it
# because that job is gated on the Supabase secrets being present.
SUPABASE_CLI_VERSION="2.111.0"
if [ "$(supabase --version 2>/dev/null || true)" = "${SUPABASE_CLI_VERSION}" ]; then
  log "supabase cli: already present (${SUPABASE_CLI_VERSION})"
else
  log "supabase cli: installing ${SUPABASE_CLI_VERSION}"
  npm install -g "supabase@${SUPABASE_CLI_VERSION}" >&2 2>&1 \
    || log "supabase cli: install failed — migrations and 'supabase start' unavailable"
fi

# --- opencode CLI -----------------------------------------------------------
# Required by the `opencode-delegate` skill (CLAUDE.md, "Delegating
# implementation work"). Installed from npm rather than opencode.ai/install:
# the agent proxy resolves registry.npmjs.org directly, while the vendor
# installer's version lookup fails behind it.
#
# INSTALLING IS NOT AUTHENTICATING. Credentials live in
# ~/.local/share/opencode/auth.json, outside the repository, so an ephemeral
# container starts with none and no file here can change that. Run
# `opencode auth login` once per container before delegating.
if command -v opencode >/dev/null 2>&1; then
  log "opencode: already present ($(opencode --version 2>&1 | tail -1))"
else
  log "opencode: installing"
  npm install -g opencode-ai >&2 2>&1 || log "opencode: install failed — delegation unavailable this session"
fi

# Signing in. `opencode auth login` is interactive and writes auth.json, which
# does not survive an ephemeral container. OPENCODE_API_KEY does the same job
# with no interaction: opencode reads it directly for the OpenCode Go and Zen
# providers, so a session with it set is signed in before it starts.
#
# Set it in the cloud environment's Environment variables (claude.ai/code →
# the cloud icon above the message box → the gear on your environment), NOT in
# this repository. Never echoed here — only its presence is reported.
if [ -n "${OPENCODE_API_KEY:-}" ]; then
  log "opencode: signed in via OPENCODE_API_KEY"
else
  log "opencode: NO credentials — set OPENCODE_API_KEY in the environment, or"
  log "          run 'opencode auth login' for this container only"
fi

# --- Android SDK (opt-in) ---------------------------------------------------
if [ "${WITH_ANDROID}" = "1" ]; then
  if [ -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
    log "android sdk: already present"
  else
    log "android sdk: installing"
    mkdir -p "${ANDROID_HOME}/cmdline-tools"
    curl -fsSL -o /tmp/cmdline.zip \
      https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    unzip -q /tmp/cmdline.zip -d "${ANDROID_HOME}/cmdline-tools"
    mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest"
    rm /tmp/cmdline.zip
  fi
  export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0" >/dev/null 2>&1 || \
    log "android sdk: sdkmanager reported errors — run it manually to see them"
  flutter config --android-sdk "${ANDROID_HOME}" >/dev/null 2>&1 || true
fi

# --- Workspace --------------------------------------------------------------
# scripts/verify.sh runs `melos run analyze`, which needs resolved packages.
log "workspace: bootstrapping"
melos bootstrap >&2 2>&1

log "toolchain ready"
