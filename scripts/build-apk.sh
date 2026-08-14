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
# Split per ABI: one 44 MB APK becomes three of about 22 MB, and arm64-v8a is
# the one nearly every current Android phone wants.
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
