#!/usr/bin/env bash
# Builds the Android release APKs, with the two --dart-define values the app
# cannot start without.
#
# THIS SCRIPT EXISTS BECAUSE A BUILD WITHOUT THEM LOOKS PERFECTLY FINE. On
# 2026-08-13 an APK built with a plain `flutter build apk --release` installed,
# launched, and showed a black screen that never responded — `main()` throws on
# an empty SUPABASE_URL before the first frame, which is the correct behaviour
# and an invisible one on a handset.
#
# LOCAL BUILDS ONLY. `.github/workflows/demo-apk.yml` is the path for anything a person installs:
# it refuses the production database outright, signs with the committed demo key so each build
# installs OVER the last one, and archives the APK where anyone can download it. This script exists
# for the case that workflow cannot serve — a build needed in the room, right now.
#
# Two differences from the workflow, both deliberate. It splits per ABI, because one 44 MB APK does
# not fit through a chat window and 24 MB does. And it signs with the machine's debug key, which
# means **an APK from here will not install over one from the workflow** — Android refuses an update
# signed by a different key. Uninstall first, and expect to lose whatever the app remembered.
#
# DEMO BY DEFAULT, PRODUCTION ONLY WHEN ASKED FOR (founder, 2026-08-13). An APK carries whichever
# database it was built against, so a build made "just to test" against production is a test against
# real Cooks' rows. Pass `production` as the first argument to mean it on purpose; the script then
# says so out loud, because the difference is invisible once the file is on a phone.
set -euo pipefail

cd "$(dirname "$0")/.."

target="${1:-demo}"
case "$target" in
  demo)
    : "${DEMO_SUPABASE_URL:?set DEMO_SUPABASE_URL — see docs/ops/demo-environment.md}"
    : "${DEMO_SUPABASE_PUBLISHABLE_KEY:?set DEMO_SUPABASE_PUBLISHABLE_KEY — see docs/ops/demo-environment.md}"
    url="$DEMO_SUPABASE_URL"; key="$DEMO_SUPABASE_PUBLISHABLE_KEY" ;;
  production)
    : "${SUPABASE_URL:?set SUPABASE_URL — see docs/ops/verifying-e1.md}"
    : "${SUPABASE_PUBLISHABLE_KEY:?set SUPABASE_PUBLISHABLE_KEY — see docs/ops/verifying-e1.md}"
    url="$SUPABASE_URL"; key="$SUPABASE_PUBLISHABLE_KEY" ;;
  *)
    echo "usage: $0 [demo|production]" >&2; exit 2 ;;
esac

echo "Building against: $target"

cd apps/mobile
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL="$url" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$key"

echo
echo "Built against $target:"
ls -1 build/app/outputs/flutter-apk/*-release.apk
