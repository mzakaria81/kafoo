#!/usr/bin/env bash
# SessionStart hook for Claude Code on the web.
#
# Installs what ./scripts/verify.sh needs. Without Dart and melos the gate
# skips five of its eight checks and still prints PASS — the exact failure E0
# existed to end, so a session that cannot run the gate properly is a session
# that will merge unverified work.
#
# The base image already provides jq, python3, node, java, git, and GNU grep
# (the RLS checks use `grep -P`), so this only installs the Dart toolchain.
#
# NOT installed: the Android SDK. It is only needed to build a release
# candidate, which is rare, and it adds several minutes to every session
# start. `.devcontainer/post-create.sh` installs it for Codespaces; here, run
# that script by hand on the rare session that needs a release build.
#
# stdout is left clean: another SessionStart hook emits JSON there, so all
# progress goes to stderr.

set -euo pipefail

log() { printf '  %s\n' "$1" >&2; }

# Local runs already have a toolchain; this is only for the remote environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="${HOME}/flutter"

# Shared with .devcontainer/post-create.sh so the two environments cannot drift.
# Without --with-android: the SDK is only needed for a release candidate and
# would add minutes to every session start.
"${CLAUDE_PROJECT_DIR:-.}/scripts/install-toolchain.sh"

# Persist for every command in this session, not just this hook.
{
  echo "export PATH=\"${FLUTTER_DIR}/bin:\${HOME}/.pub-cache/bin:\${PATH}\""
  echo "export FLUTTER_ROOT=\"${FLUTTER_DIR}\""
} >> "${CLAUDE_ENV_FILE}"

log "ready — ./scripts/verify.sh will run all eight checks"
