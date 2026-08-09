#!/usr/bin/env bash
# Which review agents must look at a diff.
#
# The briefs in .claude/agents/ each say when they apply, in prose, in their
# `description` frontmatter ("Use PROACTIVELY whenever a migration ... changes").
# Prose is the right form for a human and for a model choosing a tool. It is the
# wrong form for CI, where "which reviewer runs" must not be a judgement call: a
# migration landing without rls-reviewer reading it is the one outcome the whole
# review setup exists to prevent, and a model that skips it on a busy diff fails
# silently and looks identical to a clean run.
#
# So this file is the machine-readable half of those descriptions. It maps changed
# paths to reviewer names and nothing else. If you add a brief, add a row here; if
# the two disagree, the brief is the intent and this is the bug.
#
# Usage:
#   scripts/select-reviewers.sh <file-with-changed-paths>   # one path per line
#   git diff --name-only origin/main... | scripts/select-reviewers.sh -
#   scripts/select-reviewers.sh --self-test
#
# Prints one reviewer name per line, deduplicated, stable order. Exits 0 with no
# output when a diff touches nothing any reviewer covers — that is a real answer,
# not an error.

set -uo pipefail

# path regex -> reviewer. Order here is the order findings get reported in, which
# is severity order: authorization first, then the AI boundary, then trust, then
# the presentation-layer reviewers.
#
# Each row's regex is deliberately wider than the brief's prose. A reviewer reading
# a file it turns out not to care about costs a paragraph saying so; a reviewer that
# never ran costs whatever it would have caught.
match_rls() {
  grep -qE '^supabase/(migrations|functions|tests)/|\.sql$'
}

match_ai_boundary() {
  grep -qE '^(packages/ai/|prompts/|supabase/functions/)|^scripts/generate-prompts\.ts$'
}

# Trust is the widest net on purpose. Its rules are product-fatal (synthetic
# Reviews, AI food photography, hidden fees, dark patterns, privacy overreach), and
# the paths that carry them are not confined to one directory — a hidden fee is as
# likely to appear in a Dart widget as in a migration. Matching on vocabulary as
# well as location is how a pricing change in an unexpected place still gets read.
#
# CI configuration is excluded from the vocabulary half, because there the words are
# about the pipeline rather than the product. `.github/workflows/review.yml` matched
# on "review" and summoned trust-reviewer to read a workflow file containing no
# Review, no price and no personal data — observed on the first real run. Left alone
# it teaches the reviewer's output to be ignored, which is the expensive failure: a
# net that cries wolf is one nobody reads on the day it is right.
#
# The exclusion is by location and applies only to the vocabulary net. A workflow
# that genuinely touches release or deploy still reaches release-engineer through
# its own path row, which matches on location and is unaffected.
match_trust() {
  grep -v '^\.github/' \
    | grep -qiE '^supabase/(migrations|seed)|review|rating|price|pricing|fee|payment|payout|refund|cancel|seed|demo|allergy|allergen|dietary|consent|personal'
}

match_localization() {
  grep -qE '\.arb$|/l10n/'
}

match_accessibility() {
  grep -qE '^packages/ui/|^apps/mobile/lib/.*/presentation/.*\.dart$|^apps/web/'
}

match_conversation() {
  grep -qE '/conversation/|_step\.dart$|^prompts/'
}

match_release() {
  grep -qE '^\.github/workflows/deploy\.yml$|^apps/mobile/pubspec\.yaml$|^apps/mobile/(android|ios)/|^apps/web/wrangler'
}

REVIEWERS="rls:match_rls
ai-boundary:match_ai_boundary
trust:match_trust
localization:match_localization
accessibility:match_accessibility
conversation:match_conversation
release:match_release"

# The brief file each row names, so a typo in a reviewer name fails here rather
# than in the Actions log as a model politely inventing a reviewer that does not
# exist.
brief_for() {
  case "$1" in
    rls) echo ".claude/agents/rls-reviewer.md" ;;
    ai-boundary) echo ".claude/agents/ai-boundary-reviewer.md" ;;
    trust) echo ".claude/agents/trust-reviewer.md" ;;
    localization) echo ".claude/agents/localization-reviewer.md" ;;
    accessibility) echo ".claude/agents/accessibility-reviewer.md" ;;
    conversation) echo ".claude/agents/conversation-designer.md" ;;
    release) echo ".claude/agents/release-engineer.md" ;;
    *) return 1 ;;
  esac
}

agent_name_for() {
  case "$1" in
    conversation) echo "conversation-designer" ;;
    release) echo "release-engineer" ;;
    *) echo "$1-reviewer" ;;
  esac
}

select_reviewers() {
  local paths="$1" key fn
  while IFS=: read -r key fn; do
    [ -n "$key" ] || continue
    if printf '%s\n' "$paths" | "$fn"; then
      agent_name_for "$key"
    fi
  done <<< "$REVIEWERS"
}

self_test() {
  local failed=0
  check() {
    local label="$1" input="$2" expected="$3"
    local got
    got="$(select_reviewers "$input" | tr '\n' ' ' | sed 's/ $//')"
    if [ "$got" = "$expected" ]; then
      echo "ok   $label"
    else
      echo "FAIL $label"
      echo "     expected: [$expected]"
      echo "     got:      [$got]"
      failed=1
    fi
  }

  # A migration is the case that must never be missed. It reaches rls-reviewer and
  # trust-reviewer both, because a new table is also a new place to store personal
  # data.
  check "migration" \
    "supabase/migrations/20260807120000_create_orders.sql" \
    "rls-reviewer trust-reviewer"

  # An Edge Function is the AI boundary and an authorization surface at once —
  # ADR-0005 Amendment 1 put the vendor call there precisely because it is the
  # place that holds a credential and must hold no write path.
  check "edge function" \
    "supabase/functions/analyze-meal/index.ts" \
    "rls-reviewer ai-boundary-reviewer"

  # ARB files are the localization reviewer's whole job, and nothing else's.
  check "arb only" \
    "apps/mobile/lib/l10n/app_ar.arb" \
    "localization-reviewer"

  # A prompt change is both an AI-boundary question and a conversation-design one.
  check "prompt" \
    "prompts/meal-analysis.md" \
    "ai-boundary-reviewer conversation-designer"

  # Vocabulary matching, not location: a price field in a Dart widget still reaches
  # trust-reviewer. This is the row most likely to rot, so it is tested directly.
  check "pricing in a widget" \
    "apps/mobile/lib/features/orders/presentation/price_summary.dart" \
    "trust-reviewer accessibility-reviewer"

  # A diff nobody covers returns nothing and exits 0. Not an error.
  check "uncovered" \
    "README.md" \
    ""

  # The vocabulary net does not read CI configuration. This workflow file contains
  # the word "review" and nothing a trust reviewer exists to catch.
  check "workflow filename does not summon trust" \
    ".github/workflows/review.yml" \
    ""

  # ...but a workflow that is genuinely about releasing still reaches the release
  # reviewer, because that row matches on location rather than vocabulary.
  check "deploy workflow still reaches release" \
    ".github/workflows/deploy.yml" \
    "release-engineer"

  # The exclusion is scoped to .github/. A pricing change anywhere else is still
  # caught by the same word.
  check "pricing outside .github still caught" \
    "packages/domain/lib/price.dart" \
    "trust-reviewer"

  # A realistic multi-file feature diff: every reviewer that should see it does.
  check "feature diff" \
    "$(printf '%s\n' \
      "supabase/migrations/20260807_create_reviews.sql" \
      "packages/ai/lib/src/provider/ai_provider.dart" \
      "apps/mobile/lib/l10n/app_ar.arb" \
      "apps/mobile/lib/features/conversation/presentation/voice_button.dart")" \
    "rls-reviewer ai-boundary-reviewer trust-reviewer localization-reviewer accessibility-reviewer conversation-designer"

  # Every reviewer this script can emit must have a brief on disk. Catches the
  # rename that leaves CI asking for an agent nobody defines.
  local key fn name brief
  while IFS=: read -r key fn; do
    [ -n "$key" ] || continue
    name="$(agent_name_for "$key")"
    brief="$(brief_for "$key")"
    if [ ! -f "$brief" ]; then
      echo "FAIL brief missing for $name: $brief"
      failed=1
    else
      echo "ok   brief exists for $name"
    fi
  done <<< "$REVIEWERS"

  [ "$failed" -eq 0 ] && echo "" && echo "select-reviewers: all checks passed"
  return "$failed"
}

case "${1:-}" in
  --self-test) self_test ;;
  -)  select_reviewers "$(cat)" ;;
  "") echo "usage: $0 <file-with-changed-paths> | - | --self-test" >&2; exit 2 ;;
  *)  [ -f "$1" ] || { echo "no such file: $1" >&2; exit 2; }
      select_reviewers "$(cat "$1")" ;;
esac
