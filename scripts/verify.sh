#!/usr/bin/env bash
# The gate. Everything that must be true before a PR opens.
# Same script runs locally and in CI — one definition of "passing", not two.

set -uo pipefail

# ANCHOR TO THE REPOSITORY ROOT. Every check below uses a relative path, so running this from any
# other directory reports failures that are about the working directory rather than about the code
# — three of them on 2026-08-07, from a `cd apps/mobile` that persisted in a shell.
#
# That is the harmless direction. The dangerous one happened the same week: a leaked `cd` made
# `./scripts/verify.sh` resolve to nothing, the invocation was piped to `tail`, and the exit status
# belonged to `tail` — so the gate "passed" without running and two real failures were committed.
# A gate that depends on where it is called from is a gate that can report the wrong answer.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

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

# A skipped check prints "ok". On a laptop without the toolchain that is a
# kindness; in CI it is indistinguishable from a check that ran and passed, and
# that is exactly how three Deno checks reported ok on every pull request from the
# day they were written while never once type-checking the only code in Kafoo that
# talks to a model provider. Nobody was told. The gate said PASS.
#
# So skipping stays allowed locally and is fatal in CI. GitHub Actions sets CI=true.
skip_or_fail() {
  if [ -n "${CI:-}" ]; then
    echo "   $1 — and in CI a skip is a check reporting ok without running"
    return 1
  fi
  echo "   $1 — skipping"
  return 0
}
export -f skip_or_fail


# Dart/Flutter steps skip cleanly until the workspace is scaffolded, the same
# way "localization parity" skips before the ARB files exist. They activate on
# the `workspace:` key in the root pubspec.yaml, which is what makes this a Dart
# pub workspace and therefore a Melos workspace — no second definition of
# "passing".
run "format"        bash -c '
  command -v dart >/dev/null || { echo "   dart not on PATH — skipping"; exit 0; }
  git ls-files -z "*.dart" | grep -qz . || { echo "   no dart files yet — skipping"; exit 0; }
  dart format --set-exit-if-changed --output=none .'
# MUST run before "analyze" and "tests", because they cannot compile without what
# it produces. `*.g.dart` is in .gitignore, so a clean checkout has none of it —
# and CI is always a clean checkout.
#
# This step used to run AFTER both, and passed anyway for as long as nothing in
# the app actually needed generated code to compile. The first `@riverpod`
# controller ended that on 2026-08-05: every local run was green because stale
# generated files were lying around on disk, and CI failed on a checkout that had
# none. A gate whose steps run in an order the build cannot survive is a gate that
# only tests the machine it last ran on.
#
# The old name was "codegen drift" and it asserted `git diff --quiet -- "*.g.dart"`.
# Generated Dart is gitignored, so git had nothing to diff and that assertion could
# never fail — it reported ok on every run since it was written, including runs
# where build_runner produced nothing at all. The comment beneath the localization
# check describes this exact trap for gen-l10n; it was sitting one step above,
# unread. What is worth checking is that generation SUCCEEDS, so that is what this
# checks now.
run "codegen"       bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  grep -rqE "^[[:space:]]+build_runner:" --include=pubspec.yaml . || {
    echo "   no package uses build_runner yet — skipping"; exit 0; }
  # No --delete-conflicting-outputs: build_runner removed the flag and now only
  # warns that it was ignored. Kept working by accident, which is how a dead
  # flag survives long enough for someone to copy it somewhere it does matter.
  melos exec --depends-on=build_runner -- dart run build_runner build >/dev/null 2>&1 || {
    echo "   build_runner failed — the generated code the app imports was not produced"
    exit 1; }
  # Any generated file somebody DID commit must still match what generation makes.
  # Nothing matches this today; it is here so that the day one does, it is covered.
  git diff --quiet -- "*.g.dart" "*.freezed.dart"'
run "analyze"       bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  melos run analyze'
run "tests"         bash -c '
  grep -q "^workspace:" pubspec.yaml 2>/dev/null || {
    echo "   no melos workspace yet — skipping"; exit 0; }
  melos run test'

# The ARB files are the source of truth for every user-facing string; app_localizations*.dart is
# generated from them by `flutter gen-l10n` and is committed. A commit that edits an ARB without
# regenerating ships an app whose Arabic is stale — and there is no runtime error, just the old
# words, or a missing getter that only fails at build time on someone else's machine.
#
# THE CHECK ABOVE DOES NOT COVER THIS. "codegen drift" runs build_runner and diffs *.g.dart and
# *.freezed.dart; these files come from gen-l10n and match neither pattern. That gap produced a real
# defect on 2026-08-03: two ARB keys were committed without their generated Dart, the gate passed,
# and the drift only surfaced when an unrelated task happened to run the tests.
#
# Compares CONTENT against a snapshot rather than asking git, for the same reason the prompt bundle
# check does: git has no diff to show for a generated file it is not yet tracking.
run "localization codegen drift" bash -c '
  [ -f apps/mobile/l10n.yaml ] || { echo "   no l10n.yaml yet — skipping"; exit 0; }
  command -v flutter >/dev/null || { echo "   flutter not on PATH — skipping"; exit 0; }
  snapshot=$(mktemp -d)
  cp apps/mobile/lib/l10n/app_localizations*.dart "${snapshot}/" 2>/dev/null || true
  (cd apps/mobile && flutter gen-l10n >/dev/null 2>&1) || {
    echo "   flutter gen-l10n failed" >&2; rm -rf "${snapshot}"; exit 1; }
  drift=""
  for f in apps/mobile/lib/l10n/app_localizations*.dart; do
    [ -e "$f" ] || continue
    if ! cmp -s "$f" "${snapshot}/$(basename "$f")"; then drift="${drift} $(basename "$f")"; fi
  done
  rm -rf "${snapshot}"
  [ -z "${drift}" ] || { echo "   generated localizations are out of date:${drift}" >&2
                         echo "   Run: (cd apps/mobile && flutter gen-l10n) and commit the result" >&2
                         exit 1; }'

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
    skip_or_fail "deno not on PATH (run scripts/install-toolchain.sh)"; exit $?; }
  # shellcheck disable=SC2086
  out=$(deno check ${files} 2>&1) || {
    case "${out}" in
      *"error sending request"*|*"Import .* failed"*|*"connection"*|*"dns error"*)
        skip_or_fail "no network for remote imports"; exit $? ;;
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
#
# `scripts/` is swept alongside `supabase/functions/` because the register detector in
# replay-goldens.ts lives there and is the one piece of that script that can be wrong in silence.
# It was, until 2026-08-05: it held the pre-ADR-0010 answer for the Arabic word for Cook, and its
# marker test could not see a marker behind an Arabic conjunction. Neither shows up in a replay,
# because a replay only reports what the detector found.
#
# ────────────────────────────────────────────────────────────────────────────────────────────────
# THE FILENAME DECIDES WHETHER A SUITE RUNS HERE, AND THAT COST US THREE SUITES IN SILENCE.
#
# `*_test.ts` runs in the gate. `*.test.ts` does NOT — one character, no warning, and the check
# still prints ok. Found 2026-08-07: `discover/index.test.ts` and `embed-meal/index.test.ts` had
# never run in CI. That is WP-015's entire Edge Function suite, including the assertion that no
# word of a Customer's phrase comes back in a response — the FR-029 check, gating nothing. Both
# pass; both were renamed to `_test.ts` and now actually run.
#
# `delete-account/index.test.ts` keeps the dotted name ON PURPOSE and stays out. It is an
# integration suite that needs the local stack `supabase start` prints keys for, and it fails with
# "supabaseKey is required" anywhere else. So the two names now mean something:
#
#     index_test.ts   pure, runs in the gate
#     index.test.ts   needs a live stack, run by hand
#
# Written down because it was previously a convention nobody had stated, which is the same thing as
# an accident.
# ────────────────────────────────────────────────────────────────────────────────────────────────
run "edge function tests" bash -c '
  files=$(find supabase/functions scripts -name "*_test.ts" -type f 2>/dev/null | sort)
  [ -n "${files}" ] || { echo "   no edge function unit tests yet — skipping"; exit 0; }
  command -v deno >/dev/null || {
    skip_or_fail "deno not on PATH (run scripts/install-toolchain.sh)"; exit $?; }
  # shellcheck disable=SC2086
  out=$(deno test --quiet --allow-env --allow-read ${files} 2>&1) || {
    case "${out}" in
      *"error sending request"*|*"connection"*|*"dns error"*)
        skip_or_fail "no network for remote imports"; exit $? ;;
      *) printf "%s\n" "${out}" >&2; exit 1 ;;
    esac
  }
  exit 0'

# Prompt files live at the repository root and are not part of a deployed Edge Function bundle.
# scripts/generate-prompts.ts inlines them into supabase/functions/_shared/prompts.ts, which is
# committed. A prompt edit that is not regenerated is a deploy serving the old words — silent and
# wrong.
#
# `--check` COMPARES CONTENT. The first version of this check regenerated the file and asked
# `git diff` what had changed, which is the same shape as the Dart codegen check above and looks
# right. It reported ok while a prompt was edited and the bundle was stale, because git has no diff
# to show for a file it is not yet tracking. Content is the question; ask it directly.
run "prompt bundle drift" bash -c '
  command -v deno >/dev/null || {
    skip_or_fail "deno not on PATH (run scripts/install-toolchain.sh)"; exit $?; }
  ls prompts/*.md >/dev/null 2>&1 || {
    echo "   no prompts yet — skipping"; exit 0; }
  deno run --allow-read scripts/generate-prompts.ts --check >/dev/null'

# The exclusion vocabulary is compiled from Dart into TypeScript so there is one of it.
#
# `discover` parses a Customer's phrase server-side and the Customer web surface will need the same
# words. A hand-maintained second copy drifts, and the direction it drifts is an allergy recognised
# on one surface and not the other — which is the failure the whole exclusion design exists to
# prevent, arriving through a build step.
# The demo Cooks, kitchens and Meals a preview branch starts with. Source is supabase/demo-data.json,
# which the founder maintains; the SQL at the foot of supabase/seed.sql is compiled from it.
#
# Checked for the same reason the prompt bundle and the exclusion vocabulary are: an edit to the
# JSON that was never regenerated is a preview branch quietly seeded with the previous version, and
# nothing at run time would say so.
run "demo seed drift" bash -c '
  [ -f supabase/demo-data.json ] || { echo "   no demo data yet — skipping"; exit 0; }
  python3 scripts/generate-demo-seed.py --check'

run "exclusion vocabulary" python3 scripts/generate-exclusions.py --check

# Principle II, made mechanical rather than reviewed.
#
# A function that talks to a model must not also hold credentials that can write. delete-account
# legitimately holds the service role — it deletes auth users, which nothing else can. The rule is
# therefore not "no function names this variable" but "no function that reaches the model layer
# does", which is the property the constitution actually claims and the one a future AI function
# would quietly break.
#
# This lived briefly as a unit test that read its own source, which worked but bought one file of
# coverage at the price of giving every Edge Function test filesystem access. A grep here covers
# every function that will ever exist and needs no permission at all.
# Moved into a script on 2026-08-07, and made NARROWER rather than looser in the same change.
#
# It used to be four lines of grep here: any function importing the model layer must not name a
# write credential. `embed-meal` needs both — it calls a provider and stores the vector — so the
# blanket ban would have killed the feature, and editing the check to let it through would have been
# the one move the check exists to prevent.
#
# ADR-0011 records the founder's decision: one exception, for the single AI-derived value that
# "AI suggests, humans approve" cannot sensibly cover, and the exception carries constraints the old
# check never had. The script asserts embed-meal writes exactly `meals.embedding` and never inserts,
# deletes or calls an RPC — so adding a second column turns the gate red again. Mutation-tested
# four ways plus the un-allowlisted case.
run "ai write boundary" python3 scripts/check-ai-write-boundary.py

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

# WHICH DEPLOYED PROJECT THIS ENVIRONMENT POINTS AT.
#
# Credentials answer "may I", never "should this". On 2026-07-31 a session held a complete, valid
# set of credentials — project ref, URL, database password, service-role key — every one of which
# authenticated, for an entirely different product on the same account. The next command in that
# plan would have created users in a live unrelated system, and an earlier step would have dropped
# twenty tables. Two unrelated projects still sit on that account today.
#
# The check that catches it existed only as prose, in docs/ops/verifying-e1.md and docs/HANDOFF.md,
# so it ran when somebody happened to read that paragraph and not otherwise. Prose verification is a
# suggestion; the same check in the gate is a guarantee.
#
# No network call and no token. Fetching the project's detail record would answer the same question
# while copying that project's database password and JWT signing secret into the transcript — a
# read that returns secrets has published them. The identity comparison needs neither.
# Neither the expected nor the configured ref is ever printed, so a mismatch does not leak either.
run "supabase target" bash -c '
  expected=$(head -1 supabase/project-ref 2>/dev/null | tr -d "[:space:]")
  [ -n "${expected}" ] || { echo "   supabase/project-ref is missing or empty" >&2
                            echo "   it records the deployed project this repository belongs to" >&2
                            exit 1; }
  ref="${SUPABASE_PROJECT_REF:-}"; url="${SUPABASE_URL:-}"
  if [ -z "${ref}" ] && [ -z "${url}" ]; then
    # NOT A SKIP, and the difference is why this check went red on main from 2026-08-07.
    #
    # `skip_or_fail` is fatal in CI because a skipped check reporting ok is indistinguishable from
    # one that ran — the right rule, applied to the wrong thing here. This check has TWO parts, and
    # the first one has already run: `supabase/project-ref` exists and is not empty, asserted above
    # and just as meaningful on a build machine as anywhere else.
    #
    # The second part compares that against what the environment points at, and a CI runner points
    # at NOTHING. It holds no project ref, no URL, and deploys nothing — so there is no wrong
    # project for it to be aimed at, which is the entire failure this check exists to prevent.
    # Demanding a target from a machine that has none asserts a fact about the world rather than
    # about the change, and it made the gate red on every pull request until somebody supplied a
    # variable that would itself have been the risk.
    echo "   no project configured in this environment — nothing to compare, and nothing to aim wrong"
    exit 0
  fi
  bad=0
  [ -z "${ref}" ] || [ "${ref}" = "${expected}" ] || {
    echo "   SUPABASE_PROJECT_REF names a different project than supabase/project-ref" >&2; bad=1; }
  [ -z "${url}" ] || case "${url}" in (*"${expected}"*) ;; (*)
    echo "   SUPABASE_URL does not contain this project ref" >&2; bad=1 ;; esac
  [ "${bad}" -eq 0 ] || {
    echo "   this environment points at another project, and its credentials will authenticate" >&2
    echo "   List what the token can reach:" >&2
    echo "     curl -H \"Authorization: Bearer \$SUPABASE_ACCESS_TOKEN\" https://api.supabase.com/v1/projects" >&2
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

# The authorization suites themselves, not merely evidence that policies exist.
#
# "rls coverage" above reads migrations as text. It proves a table declares RLS; it cannot tell
# whether the policy admits a stranger, because nothing here connects to a database. Until
# 2026-08-07 that was the whole of the gate's authorization story, and the consequence arrived on
# schedule: E3's fourteen commits went green locally while CI could not apply the migration at all,
# because this machine happened to carry a pgvector package the toolchain installer never installed.
# Every assertion about who may read a Meal was absent from both runs, and the gate said PASS.
#
# So the gate runs them. A cluster that cannot be started is the one case worth skipping over — but
# a skip is only honest while the CI job still exists to cover it, and that is asserted rather than
# assumed. Delete the job and this stops being skippable anywhere.
run "authorization suites" bash -c '
  grep -q "local-db.sh test" .github/workflows/authorization.yml 2>/dev/null || {
    echo "   .github/workflows/authorization.yml no longer runs the suites, so skipping here" >&2
    echo "   would leave them running nowhere at all" >&2
    exit 1; }

  PG_MAJOR="$(grep -E "^major_version[[:space:]]*=" supabase/config.toml | head -1 | tr -dc "0-9")"
  ext="/usr/share/postgresql/${PG_MAJOR}/extension"

  # Each prerequisite is named on its own. A missing extension is not a missing Postgres, and
  # reporting it as one sends the reader to reinstall a database they already have.
  if [ ! -x "/usr/lib/postgresql/${PG_MAJOR}/bin/initdb" ]; then
    skip_or_fail "postgres ${PG_MAJOR} not installed" && exit 0 || exit 1
  fi
  for e in pgtap vector; do
    if [ ! -f "${ext}/${e}.control" ]; then
      skip_or_fail "${e} not installed for postgres ${PG_MAJOR}" && exit 0 || exit 1
    fi
  done

  # Postgres refuses to run as root and local-db.sh needs to initialise a cluster, so the step
  # wants privilege that the rest of the gate deliberately does not have. Acquired here, for this
  # one check, rather than by running the whole gate as root — which would move Flutter'"'"'s pub
  # cache and every generated file into root'"'"'s home.
  if [ "$(id -u)" -eq 0 ]; then
    ./scripts/local-db.sh test
  elif sudo -n true 2>/dev/null; then
    sudo -E ./scripts/local-db.sh test
  else
    skip_or_fail "the suites need root or passwordless sudo to start a cluster" && exit 0 || exit 1
  fi'

# The constitution forbids synthetic Reviews, Cooks, and Meals — including for
# seeding. Migrations reach production unattended, so catch DML against those
# tables here rather than trusting review.
# supabase/tests/ is excluded: RLS tests legitimately insert fixtures to prove
# policies work. The ban targets migrations and functions, not test files.
run "no synthetic content" bash -c '
  hits=$(grep -rinE "INSERT[[:space:]]+INTO[[:space:]]+(public\.)?(cooks|meals|reviews|kitchen_profiles)" \
    supabase/migrations/ supabase/functions/ 2>/dev/null || true)
  web=$(grep -rlniE "(fake|demo|sample|placeholder|lorem)[-_ ]?(cook|meal|kitchen|review)" \
    --include="*.ts" --include="*.tsx" --exclude-dir=node_modules --exclude-dir=.next \
    apps/web 2>/dev/null || true)
  hits="$hits$web"
  if [ -n "$hits" ]; then
    echo "$hits"
    echo "   Synthetic Cooks, Meals, or Reviews are product-fatal (Constitution I)."
    exit 1
  fi'

# Non-canonical vocabulary leaking into code or SQL.
#
# apps/web/ is swept too, and .tsx was added with it — the Customer web surface is a place
# user-facing words live, so a check that could not read it was a surface with no rules. node_modules
# is excluded because 355 npm packages are not Kafoo's vocabulary to police, and without the
# exclusion this check reports other people's code and drowns its own signal.
run "vocabulary" bash -c '
  hits=$(grep -rinE "\b(vendors?|sellers?|buyers?|listings?|menu_items?|chatbots?)\b" \
    --include="*.dart" --include="*.sql" --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.open-next \
    apps packages supabase 2>/dev/null || true)
  if [ -n "$hits" ]; then echo "$hits"; exit 1; fi'

# The Arabic word for Cook is الطباخ — founder decision, 2026-08-04 (ADR-0010). الكوك was in the
# prompts, in six golden fixtures and in two widget tests, and a model copies whichever word the
# prompt uses straight into text a Cook reads. The English vocabulary check above cannot see any of
# it, because every one of those occurrences is inside an Arabic string.
#
# docs/ is deliberately not swept. docs/ops/eval-meal-analysis.md is a transcript of what a model
# actually returned, and rewriting the record to match the decision would be falsifying the
# measurement this whole task exists to act on.
#
# register_markers.json is exempt for the same reason one level in: it is the list of words the
# register detector looks FOR, so the banned word is its content rather than its usage. A check
# that cannot describe what it forbids is a check nobody can maintain. The exemption is one named
# file, not a directory, so a second file cannot quietly inherit it.
run "arabic vocabulary" bash -c '
  hits=$(grep -rn "الكوك" \
    --include="*.dart" --include="*.sql" --include="*.ts" --include="*.tsx" --include="*.json" \
    --include="*.arb" --include="*.md" \
    --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.open-next \
    apps packages prompts supabase 2>/dev/null \
    | grep -v "^packages/ai/test/goldens/register_markers.json:" || true)
  if [ -n "$hits" ]; then
    echo "$hits"
    echo "   The Arabic for Cook is الطباخ, not الكوك — ADR-0010."
    exit 1
  fi'

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

# Every AppError's messageKey must actually resolve to a string.
#
# The parity check below compares the two ARB files against each other, so a key missing from BOTH
# is invisible to it — two files agreeing that a string does not exist is perfect parity. That is
# how `aiMealAnalysisInvalid` reached the tree: every other messageKey in the repository had an
# entry, this one did not, and the gate was green. What a Cook would have seen when a model reply
# failed validation is nothing at all.
#
# `.claude/rules/dart.md` requires every user-facing error to be localized and actionable. This is
# that rule, checked rather than remembered.
run "error keys are localized" bash -c '
  ar=apps/mobile/lib/l10n/app_ar.arb
  [ -f "$ar" ] || { echo "   arb files not present yet — skipping"; exit 0; }
  missing=""
  # The opening quote is matched as "." and the closing quote is simply left out of the pattern,
  # so nothing has to be stripped afterwards. An earlier version tried to strip it with `tr` and
  # silently reported every key in the repository as missing.
  keys=$(grep -rhoE "messageKey: .[A-Za-z0-9_]+" \
           --include="*.dart" apps packages 2>/dev/null \
         | grep -oE "[A-Za-z0-9_]+$" | sort -u)
  for k in $keys; do
    jq -e --arg k "$k" "has(\$k)" "$ar" >/dev/null 2>&1 || missing="${missing} ${k}"
  done
  [ -z "${missing}" ] || { echo "   messageKey with no Arabic string:${missing}" >&2
                           echo "   Add it to both ARB files, Arabic written first." >&2
                           exit 1; }'

# Every user-facing string must exist in the Egyptian Arabic ARB, not just English.
run "localization parity" bash -c '
  ar=apps/mobile/lib/l10n/app_ar.arb
  en=apps/mobile/lib/l10n/app_en.arb
  [ -f "$ar" ] && [ -f "$en" ] || { echo "   arb files not present yet — skipping"; exit 0; }
  python3 scripts/check-l10n-parity.py'

# The web surface's own checks — its type-check and its preview-cap assertions. Skipped with a
# LOUD notice when node_modules is absent rather than silently, because a check that reports
# success on having inspected nothing is the failure this gate keeps meeting.
run "web surface" bash -c '
  [ -f apps/web/package.json ] || { echo "   apps/web not present yet — skipping"; exit 0; }
  if [ ! -d apps/web/node_modules ]; then
    echo "   apps/web/node_modules absent — NOT CHECKED. Run: (cd apps/web && npm ci)"
    exit 0
  fi
  cd apps/web && npx tsc --noEmit && node --test lib/*.test.mjs > /dev/null'

# The Customer web surface carries its own ar/en messages rather than the app's ARB files, so the
# parity check above does not see them. Two locales that drift are how a Customer meets an English
# string on an Arabic-first surface — and ar is the SOURCE here, not the fallback.
run "web localization parity" bash -c '
  ar=apps/web/messages/ar.json
  en=apps/web/messages/en.json
  [ -f "$ar" ] && [ -f "$en" ] || { echo "   web messages not present yet — skipping"; exit 0; }
  python3 - <<"PY"
import json, sys
ar = json.load(open("apps/web/messages/ar.json", encoding="utf-8"))
en = json.load(open("apps/web/messages/en.json", encoding="utf-8"))
missing_en = sorted(set(ar) - set(en))
missing_ar = sorted(set(en) - set(ar))
bad = []
if missing_en: bad.append(f"missing from en.json: {missing_en}")
if missing_ar: bad.append(f"missing from ar.json: {missing_ar}")
import re
for key in sorted(set(ar) & set(en)):
    pa = set(re.findall(r"\{(\w+)\}", ar[key]))
    pe = set(re.findall(r"\{(\w+)\}", en[key]))
    if pa != pe:
        bad.append(f"{key}: placeholders {sorted(pa)} vs {sorted(pe)}")
if bad:
    for line in bad: print(f"   {line}")
    sys.exit(1)
print(f"   {len(ar)} web keys, placeholders match across ar/en")
PY'

# A hook that points at a file which is not there fails SILENTLY. Claude Code runs the command,
# the command is not found, and the session continues as though the hook had chosen to do nothing.
#
# That is not hypothetical: six caveman skills sat on this account for weeks describing a hook that
# had never been installed, and /caveman-stats answered with nothing at all rather than an error.
# The instruction was intact and the program it named was absent, which is indistinguishable from
# the assistant ignoring you.
#
# So the gate resolves every hook command in settings.json and checks the file exists. This is
# general on purpose — it covers check-rls.sh and the session-start scripts too, not only the
# vendored ones, and it will cover whatever is wired next without being edited.
run "session hooks resolve" bash -c '
  [ -f .claude/settings.json ] || { echo "   no settings.json — skipping"; exit 0; }
  command -v node >/dev/null || { echo "   node not on PATH — the .js hooks cannot run" >&2; exit 1; }
  python3 - <<"PY"
import json, os, re, sys

settings = json.load(open(".claude/settings.json"))
missing = []
checked = 0

for event, groups in (settings.get("hooks") or {}).items():
    for group in groups:
        for hook in group.get("hooks") or []:
            command = hook.get("command", "")
            # Pull out every path-looking token that anchors on the project dir. The commands are
            # a mix of bare paths and `node "<path>"`, so match the variable rather than parse a shell.
            for raw in re.findall(r"\$\{CLAUDE_PROJECT_DIR\}[^\"\s]*", command):
                path = raw.replace("${CLAUDE_PROJECT_DIR}", ".")
                checked += 1
                if not os.path.isfile(path):
                    missing.append(f"{event}: {path}")

if missing:
    print("   hook command points at a file that does not exist:", file=sys.stderr)
    for m in missing:
        print(f"     {m}", file=sys.stderr)
    print("   A missing hook does not error — it silently does nothing.", file=sys.stderr)
    sys.exit(1)

if checked == 0:
    print("   no project-dir hooks found in settings.json", file=sys.stderr)
    sys.exit(1)
PY'

# Work packages are how two sessions avoid building the same thing twice. The failure this catches
# is silent by construction: on 2026-08-05 two sessions each built the Cook's Meal list, and the
# only symptom until the merge was that both believed they owned it.
#
# The rules worth a gate are the ones a tired reader will not notice: an active package with no
# owner, two EXCLUSIVE packages running at once, a dependency cycle, and a model outside the
# opencode-go prefix — which is the billing boundary rather than a naming convention.
run "work packages" bash -c '
  [ -d coordination/packages ] || { echo "   no coordination/packages — skipping"; exit 0; }
  python3 scripts/validate-coordination.py'

# Which review agent reads which diff is decided by a path map in
# scripts/select-reviewers.sh, and the failure mode is the quiet one: rename a brief
# or move a directory, and the map stops matching. CI then dispatches nothing for
# that path and reports a clean run — a migration merging with no authorization
# review, looking exactly like a migration that passed one.
#
# The self-test covers both halves: the path rows still match the paths they were
# written for, and every reviewer the script can name still has a brief on disk.
run "review agent selection" bash -c '
  [ -f scripts/select-reviewers.sh ] || { echo "   no select-reviewers.sh — skipping"; exit 0; }
  ./scripts/select-reviewers.sh --self-test'

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL — do not open a PR"
fi
exit "$FAILED"
