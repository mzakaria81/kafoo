# Implementation Plan: E0 Foundation

**Branch**: `claude/kapoor-dotfiles-setup-i702ir` | **Date**: 2026-07-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-e0-foundation/spec.md`

## Summary

Give Kafoo a workspace that verifies itself, rules that are written down and mechanically
enforced, and a repeatable path from a verified change to an installable release. US1 and US3 are
delivered; US2 is not, and its blocker is that `apps/mobile` has no platform projects to build.

The approach throughout: make the gate the single definition of passing, run it identically in
both places, and have every check state plainly when it has nothing to inspect — so a green
result never means "nothing was looked at".

## Technical Context

**Language/Version**: Dart 3.12.2 (SDK constraint `^3.6.0`), Flutter stable

**Primary Dependencies**: melos 8.2.2 for the workspace; `test` and `flutter_test` for tests. No
production third-party dependencies yet — deliberately, until a feature needs one.

**Storage**: Supabase (Postgres) — configured but empty. No migrations exist.

**Testing**: `dart test` for pure-Dart packages, `flutter test` for Flutter packages, dispatched
by `melos exec` filtered on `--no-flutter` / `--flutter`.

**Target Platform**: Android and iOS phones. A web administrative surface is out of scope here.

**Project Type**: Mobile app plus shared packages in a Dart pub workspace.

**Performance Goals**: App launch <2s, voice round-trip <2s, meal publish <3s, cached search <1s.
Not measurable yet — no feature exercises them.

**Constraints**: Egyptian Arabic is the default locale and RTL is mandatory. `packages/domain`
must import neither Flutter nor Supabase. All model calls route through `packages/ai`.

**Scale/Scope**: 4 workspace packages, 7 gate checks, 7 review agents. Single-maintainer project.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v1.0.0).

| # | Gate | Status | Notes |
|---|------|--------|-------|
| I | **User trust** | PASS | No synthetic content ships; a gate check now rejects DML against `cooks`, `meals`, `reviews`, `kitchen_profiles` in migrations. No charges or cancellation flows exist yet, so the fee and dark-pattern rules are carried into the release checklist rather than exercised. |
| II | **AI suggests, humans approve** | PASS | No AI write path exists. The `AiProvider` seam is defined but implemented only by a stub. The release path applies the same shape: the pipeline builds, a person decides to submit. |
| III | **Security by default** | N/A — carried | No tables exist, so there is no RLS to enforce. The hook and the coverage check are in place and fire on the first migration. FR-008 is explicitly unproven and recorded as such. |
| IV | **Conversation first, Arabic first** | PASS | No forms; no flows at all yet. `ar` is the app's fixed locale and a test asserts both the locale and RTL. ARB parity is gated. |
| V | **Provider independence** | PASS | `AiProvider` is the only seam; `StubAiProvider` exists so the swap claim is testable. `packages/domain` imports neither Flutter nor Supabase. |
| VI | **Canonical vocabulary** | PASS | Gate check rejects banned synonyms in Dart, SQL, and TypeScript. It caught `vendor` in this project's own comments during E0, and the comments were changed rather than the check. |
| VII | **Documentation separation** | PASS | `spec.md` was swept mechanically for framework, storage, and pipeline terms; no matches. All technical detail is in this file. |
| — | **Performance budgets** | N/A | Nothing to measure. Release builds must measure them before submission — recorded in the release checklist. |
| — | **Privacy** | PASS | No personal data collected. The release checklist carries the allergy-data constraints and the raw-audio ADR requirement forward. |
| — | **Stop-and-ask triggers** | PASS | E0 adds no screen, no form field, no money path, no personal-data category, and no unapproved AI action. Scaffolding, so no approval gate was required. |

**Verification**: `./scripts/verify.sh` passes — confirmed locally with the real toolchain, with
all seven checks running rather than skipping.

## Project Structure

### Documentation (this feature)

```text
specs/001-e0-foundation/
├── plan.md              # This file
├── spec.md              # The product perspective
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # /speckit-tasks output — not created here
```

### Source Code (repository root)

```text
apps/
└── mobile/                    # Customer and Cook in one binary
    ├── lib/
    │   ├── main.dart          # Locale fixed to ar; RTL asserted by test
    │   └── l10n/              # app_ar.arb (source), app_en.arb (translation)
    └── test/

packages/
├── domain/                    # Entities + pure logic. No Flutter, no Supabase.
│   └── lib/result.dart        # Result<T, AppError>
├── ai/                        # The only package that may hold a provider SDK
│   └── lib/src/provider/
│       ├── ai_provider.dart   # The seam (ADR-0005)
│       └── stub_provider.dart # Makes the swap claim testable
└── ui/                        # Design system
    └── lib/theme/tokens.dart  # Spacing, colors, 48dp tap-target floor

supabase/
├── config.toml                # Local stack on the devcontainer's forwarded ports
├── migrations/                # Empty — the first migration belongs to E1
└── tests/                     # RLS negative tests

scripts/verify.sh              # The gate. One definition of passing.
.github/workflows/ci.yml       # Runs the gate on push and PR
.github/workflows/deploy.yml   # Backend deploy + Android release candidate
.claude/agents/                # Seven review agents
```

**Structure Decision**: A Dart pub workspace with `apps/*` and `packages/*`, matching the repo map
already documented in `CLAUDE.md`. Chosen over a single package because `packages/domain`'s
prohibition on Flutter and Supabase imports is only meaningfully enforceable across a real package
boundary — inside one package it would be a convention rather than a constraint.

## Phase 0 findings

Recorded in [research.md](research.md). The decisions that shaped this plan:

1. **Melos 7+ requires Dart pub workspaces.** `melos.yaml` alone is not a workspace. Found by CI
   failing with "Your current directory does not appear to be within a Melos workspace".
2. **Skip-guards must key on something that will still exist.** They originally keyed on
   `melos.yaml`; removing that file would have silently reverted the gate to skipping the checks
   it had just started running.
3. **The formatter changed in Dart 3.7.** Constructs were kept short and unambiguous to survive
   tall-style formatting, since the formatter could not be run in the authoring environment.
4. **`hashFiles()` at job level runs before checkout.** It always yields `''`, silently skipping
   the job it guards.

## Phase 1 design

- [data-model.md](data-model.md) — E0 introduces no domain entities. Records why, and points at
  `docs/product/domain-model.md` as the real model.
- [quickstart.md](quickstart.md) — how to bring an empty environment to a verified change, which
  is US1's acceptance test made runnable.
- No `contracts/` directory. E0 exposes no external interface: no API, no CLI beyond the gate
  script, no published package. The gate's exit code is its only contract, documented in
  quickstart.

## Post-design constitution re-check

No gate changed status after Phase 1. The design adds no entity, no interface, and no data, so
Principles I–VII hold exactly as assessed above. Principle III remains the one carried forward
unproven, tracked as FR-008 rather than quietly assumed.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified

No violations. Two deliberate deviations worth recording, since they are costs rather than
violations:

| Deviation | Why needed | Simpler alternative rejected because |
|---|---|---|
| Four packages before any feature exists | `packages/domain`'s import prohibition is a real constraint only across a package boundary | A single package would make the boundary a naming convention, unenforceable by the analyzer, and the constitution treats that boundary as structural |
| `--fatal-infos` on analysis | A lint the project chose to enable is a lint it means | Warnings-only would let enabled lints accumulate as ignored noise, which is how a standard quietly stops being one |
