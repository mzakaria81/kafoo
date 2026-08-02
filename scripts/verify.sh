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
  # No --delete-conflicting-outputs: build_runner removed the flag and now only
  # warns that it was ignored. Kept working by accident, which is how a dead
  # flag survives long enough for someone to copy it somewhere it does matter.
  melos exec --depends-on=build_runner -- \
    dart run build_runner build >/dev/null 2>&1 \
    && git diff --quiet -- "*.g.dart" "*.freezed.dart"'

# Edge Functions are Deno and are never compiled by the Dart toolchain, so
# nothing else in this gate would ever read them. Type-checking is the cheapest
# real check available without Docker: it catches a function that would fail on
# its first invocation in production. It caught three in E1 — contract tests
# written with Dart method names on a JS client, in a file nothing had parsed.
#
# `deno check` reaches the network for remote imports; a sandbox without one
# skips rather than fails, since an offline machine is not a broken change.
#
# READS THE FILESYSTEM, NOT `git ls-files`. It listed tracked files until 2026-08-02, which meant a
# function written but not yet staged was invisible: the gate printed ok and the author reasonably
# concluded their new code type-checked. That is the identical defect fixed in the check immediately
# below, diagnosed correctly and written up at length there — and this one, six lines away, was left
# alone for another day. A lesson applied at one call site and not its neighbours reads as fixed
# while still failing, so when the next such bug is found, sweep for siblings before calling it done.
run "edge functions" bash -c '
  files=$(find supabase/functions -name "*.ts" -type f 2>/dev/null | sort)
  [ -n "${files}" ] || { echo "   no edge functions yet — skipping"; exit 0; }
  command -v deno >/dev/null || {
    echo "   deno not on PATH — skipping (run scripts/install-toolchain.sh)"; exit 0; }
  # shellcheck disable=SC2086
  out=$(deno check ${files} 2>&1) || {
    case "${out}" in
      *"error sending request"*|*"Import .* failed"*|*"connection"*|*"dns error"*)
        echo "   no network for remote imports — skipping"; exit 0 ;;
      *) printf "%s\n" "${out}" >&2; exit 1 ;;
    esac
  }
  exit 0'

# Edge Function unit tests. `deno check` proves a function would parse; these prove it behaves.
#
# The registry suite in particular is what keeps ADR-0005 Amendment 1 honest — a half-added
# provider or a silent fallback to the wrong one would pass every other check in this gate.
#
# NAMING IS LOAD-BEARING HERE, and this is where the convention is written down:
#
#   *_test.ts   unit. No network, no database, no local stack. Runs in this gate on every commit.
#   *.test.ts   integration. Needs `supabase start`. Runs by hand, and never here.
#
# delete-account/index.test.ts is the second kind — it creates real auth users against a local
# stack and cannot pass without Docker. Sweeping both kinds into the gate makes it fail on every
# machine that has no Docker, which is every CI runner we use and the session container too.
#
# Network-dependent for the same reason as the check above (jsr imports), and skipped rather than
# failed for the same reason.
#
# Reads the filesystem, not `git ls-files`. The other checks here list tracked files, which means a
# test written but not yet staged is invisible to them — the gate says "skipping", prints ok, and
# the author reasonably concludes their new suite passed. Caught exactly that way on 2026-08-02
# with ten registry tests sitting unstaged on disk. A gate that silently ignores uncommitted work
# is worse than one that has not been written, because it answers.
run "edge function tests" bash -c '
  files=$(find supabase/functions -name "*_test.ts" -type f 2>/dev/null | sort)
  [ -n "${files}" ] || { echo "   no edge function unit tests yet — skipping"; exit 0; }
  command -v deno >/dev/null || {
    echo "   deno not on PATH — skipping (run scripts/install-toolchain.sh)"; exit 0; }
  # shellcheck disable=SC2086
  out=$(deno test --quiet --allow-env ${files} 2>&1) || {
    case "${out}" in
      *"error sending request"*|*"connection"*|*"dns error"*)
        echo "   no network for remote imports — skipping"; exit 0 ;;
      *) printf "%s\n" "${out}" >&2; exit 1 ;;
    esac
  }
  exit 0'

# Credentials belong in the environment, never in the repository. Two are live
# in this project and both are rotate-everything incidents if committed:
# OPENCODE_API_KEY (delegation) and SUPABASE_SERVICE_ROLE_KEY (bypasses RLS
# entirely, so a leak defeats every policy in supabase/migrations at once).
#
# Placeholder-looking values are allowed so documentation can show the shape.
run "no committed credentials" bash -c '
  hits=$(git ls-files -z | xargs -0 grep -nIE \
    "(OPENCODE_API_KEY|SUPABASE_SERVICE_ROLE_KEY)[[:space:]]*[=:][[:space:]]*.?[A-Za-z0-9_.-]{16,}" \
    2>/dev/null \
    | grep -viE "your|example|placeholder|dummy|redacted|xxxx|<|\\$\\{|\\$[A-Z]" || true)
  [ -z "${hits}" ] || { echo "   a real-looking credential is tracked by git:" >&2
                        printf "%s\n" "${hits}" >&2
                        echo "   move it to the environment and rotate it" >&2
                        exit 1; }'

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
# supabase/tests/ is excluded: RLS tests legitimately insert fixtures to prove
# policies work. The ban targets migrations and functions, not test files.
run "no synthetic content" bash -c '
  hits=$(grep -rinE "INSERT[[:space:]]+INTO[[:space:]]+(public\.)?(cooks|meals|reviews|kitchen_profiles)" \
    supabase/migrations/ supabase/functions/ 2>/dev/null || true)
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

# ADR-0005 Amendment 1: switching model providers must be a configuration change with no code
# diff at all. That claim is only true while a model name lives in exactly two places — the Edge
# Function's provider registry, and an environment variable.
#
# A hardcoded model id anywhere else is the whole mechanism quietly failing: the code still works,
# the switch still looks like config, and one call site keeps talking to the old vendor. Cheaper to
# catch here than to discover during a dialect bake-off.
#
# decisions/, docs/ and specs/ are excluded — naming a model is what those files are for.
run "model config seam" bash -c '
  registry=supabase/functions/_shared/ai/registry.ts
  hits=$(grep -rinE "(claude-[a-z0-9]+-[0-9]|gpt-[0-9]+(\.[0-9]+)?(-[a-z]+)?|gemini-[0-9]+(\.[0-9]+)?-[a-z]+)" \
    --include="*.dart" --include="*.ts" --include="*.md" \
    apps packages prompts supabase/functions 2>/dev/null \
    | grep -v "^${registry}:" || true)
  if [ -n "$hits" ]; then
    echo "$hits"
    echo "   A model name belongs in ${registry} or an environment variable, nowhere else."
    echo "   See decisions/0005-... Amendment 1."
    exit 1
  fi'

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
