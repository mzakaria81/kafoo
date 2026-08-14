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
set -euo pipefail

cd "$(dirname "$0")/.."

: "${SUPABASE_URL:?set SUPABASE_URL — see docs/ops/verifying-e1.md}"
: "${SUPABASE_PUBLISHABLE_KEY:?set SUPABASE_PUBLISHABLE_KEY — see docs/ops/verifying-e1.md}"

cd apps/mobile
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"

echo
echo "Built:"
ls -1 build/app/outputs/flutter-apk/*-release.apk
