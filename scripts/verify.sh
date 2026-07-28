#!/usr/bin/env bash
# The gate. Everything that must be true before a PR opens.
# Same script runs locally and in CI — one definition of "passing", not two.

set -uo pipefail

FAILED=0
run() {
  local label="$1"; shift
  echo ""
  echo "── $label"
  if "$@"; then
    echo "   ok"
  else
    echo "   FAILED: $label"
    FAILED=1
  fi
}

echo "kafoo verify"

# Dart/Flutter steps skip cleanly until the workspace is scaffolded, the same
# way "localization parity" skips before the ARB files exist. They activate on
# the `workspace:` key in the root pubspec.yaml, which is what makes this a Dart
# pub workspace and therefore a Melos workspace — no second definition of
# "passing".
run "format"        bash -c '
  command -v dart >/dev/null || { echo "   dart not on PATH — skipping"; exit 0; }
  git ls-files -z "*.dart" | grep -qz . || { echo "   no dart files yet — skipping"; exit 0; }
  dart format --set-exit-if-changed --output=none .'
run "analyze"       bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  melos run analyze'
run "tests"         bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  melos run test'
run "codegen drift" bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  grep -rqE "^[[:space:]]+build_runner:" --include=pubspec.yaml . || {
    echo "   no package uses build_runner yet — skipping"; exit 0; }
  melos exec --depends-on=build_runner -- \
    dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1 \
    && git diff --quiet -- "*.g.dart" "*.freezed.dart"'

# Every migration that creates a table must enable RLS in the same file.
run "rls coverage" bash -c '
  bad=0
  for f in supabase/migrations/*.sql; do
    [ -e "$f" ] || continue
    tables=$(grep -ioP "CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?(public\.)?\K[a-z_][a-z0-9_]*" "$f" || true)
    for t in $tables; do
      grep -iqP "ALTER\s+TABLE\s+(public\.)?${t}\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY" "$f" || {
        echo "   no RLS for table \"$t\" in $f"; bad=1; }
    done
  done
  exit $bad'

# The constitution forbids synthetic Reviews, Cooks, and Meals — including for
# seeding. Migrations reach production unattended, so catch DML against those
# tables here rather than trusting review.
run "no synthetic content" bash -c '
  hits=$(grep -rinE "INSERT[[:space:]]+INTO[[:space:]]+(public\.)?(cooks|meals|reviews|kitchen_profiles)" \
    supabase/ 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "$hits"
    echo "   Synthetic Cooks, Meals, or Reviews are product-fatal (Constitution I)."
    exit 1
  fi'

# Non-canonical vocabulary leaking into code or SQL.
run "vocabulary" bash -c '
  hits=$(grep -rinE "\b(vendors?|sellers?|buyers?|listings?|menu_items?|chatbots?)\b" \
    --include="*.dart" --include="*.sql" --include="*.ts" \
    apps packages supabase 2>/dev/null || true)
  if [ -n "$hits" ]; then echo "$hits"; exit 1; fi'

# Every user-facing string must exist in the Egyptian Arabic ARB, not just English.
run "localization parity" bash -c '
  ar=apps/mobile/lib/l10n/app_ar.arb
  en=apps/mobile/lib/l10n/app_en.arb
  [ -f "$ar" ] && [ -f "$en" ] || { echo "   arb files not present yet — skipping"; exit 0; }
  missing=$(comm -13 \
    <(jq -r "keys[]" "$ar" | grep -v "^@" | sort) \
    <(jq -r "keys[]" "$en" | grep -v "^@" | sort))
  if [ -n "$missing" ]; then echo "   missing Arabic keys:"; echo "$missing"; exit 1; fi'

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL — do not open a PR"
fi
exit "$FAILED"
