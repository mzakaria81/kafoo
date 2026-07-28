#!/usr/bin/env bash
# Single source of truth for the Dart toolchain.
#
# Called by BOTH environment setups so they cannot drift apart:
#   .devcontainer/post-create.sh   (Codespaces)  — with --with-android
#   .claude/hooks/session-start.sh (web session) — without
#
# The only intended difference between the two environments is the Android SDK:
# it is needed to build a release candidate but adds minutes to a session start,
# so the web session skips it and installs it on demand.
#
# Idempotent. Progress goes to stderr so a caller can keep stdout clean for a
# hook's JSON output.

set -euo pipefail

WITH_ANDROID=0
[ "${1:-}" = "--with-android" ] && WITH_ANDROID=1

FLUTTER_DIR="${HOME}/flutter"
ANDROID_HOME="${ANDROID_HOME:-${HOME}/sdk/android}"
FLUTTER_CHANNEL="stable"

log() { printf '  %s\n' "$1" >&2; }

export PATH="${FLUTTER_DIR}/bin:${HOME}/.pub-cache/bin:${PATH}"

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
