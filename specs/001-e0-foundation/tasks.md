---
description: "Task list for E0 Foundation"
---

# Tasks: E0 Foundation

**Input**: Design documents from `specs/001-e0-foundation/`

**Handoff**: [docs/HANDOFF.md](../../docs/HANDOFF.md) — read first in a new session

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [quickstart.md](quickstart.md)

**Tests**: Included. The constitution requires a negative RLS test per table and a golden case per
AI behaviour, and the gate runs the suite — tests are not optional here.

**Organization**: Grouped by user story. Much of E0 is already delivered; completed tasks are
checked with the commit that delivered them, so this file records real state rather than a plan
detached from it.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no incomplete dependency
- **[Story]**: US1, US2, US3 per spec.md

## Path Conventions

Kafoo repository layout (see [plan.md](plan.md)): `apps/mobile/`, `packages/{domain,ai,ui}/`,
`supabase/{migrations,functions,tests}/`, `scripts/verify.sh`, `.github/workflows/`,
`.claude/agents/`.

## Constitution-Driven Task Requirements

Mandatory when triggered, per `.specify/memory/constitution.md` v1.0.0. None are triggered by the
remaining E0 tasks except where noted — E0 adds no table, no AI behaviour, and no new
user-facing string.

---

## Phase 1: Setup

**Purpose**: A workspace that resolves and a toolchain that runs.

- [x] T001 Create the Dart pub workspace root in `pubspec.yaml` with `workspace:` and the melos scripts — `b92365f`
- [x] T002 [P] Mark each package `resolution: workspace` in `apps/mobile/pubspec.yaml` and `packages/*/pubspec.yaml` — `b92365f`
- [x] T003 [P] Add shared analyzer configuration in `analysis_options.yaml`, included by every package — `fb16210`
- [x] T004 Add `melos bootstrap` to `.github/workflows/ci.yml` before the gate — `fb16210`
- [x] T005 [P] Ignore the IntelliJ files `melos bootstrap` generates in `.gitignore` — `9e0b0d1`

---

## Phase 2: Foundational

**Purpose**: The gate must enforce something before any story can claim to be verified. Blocking
for every story.

- [x] T006 Guard the Dart gate steps on the `workspace:` key in `scripts/verify.sh` so they cannot silently revert to skipping — `b92365f`
- [x] T007 Skip the codegen check unless a package depends on `build_runner`, in `scripts/verify.sh` — `fb16210`
- [x] T008 [P] Create `packages/domain/lib/result.dart` with `Result<T, E>`, `Success`, `Failure`, and `AppError` carrying an ARB key — `fb16210`
- [x] T009 [P] Create the `AiProvider` seam in `packages/ai/lib/src/provider/ai_provider.dart` per ADR-0005 — `fb16210`
- [x] T010 [P] Create `StubAiProvider` in `packages/ai/lib/src/provider/stub_provider.dart` so the provider-swap claim is testable — `fb16210`
- [x] T011 [P] Create design tokens in `packages/ui/lib/theme/tokens.dart`, including the 48dp tap-target floor — `fb16210`

---

## Phase 3: User Story 1 — A contributor can verify their own work (P1) 🎯 MVP

**Goal**: An empty environment reaches a verified change with no step that needs a person.

**Independent test**: Follow [quickstart.md](quickstart.md) from a clean clone; reach `PASS`
without consulting anyone.

### Tests for User Story 1

- [x] T012 [P] [US1] Assert the app defaults to Arabic and lays out RTL in `apps/mobile/test/app_test.dart` — `fb16210`
- [x] T013 [P] [US1] Assert `Result` carries values, errors, and switches exhaustively in `packages/domain/test/result_test.dart` — `fb16210`
- [x] T014 [P] [US1] Assert the stub returns canned replies and fails loudly on an unstubbed prompt in `packages/ai/test/stub_provider_test.dart` — `fb16210`
- [x] T015 [P] [US1] Assert the spacing scale ascends and meets the tap-target floor in `packages/ui/test/tokens_test.dart` — `fb16210`

### Implementation for User Story 1

- [x] T016 [US1] Create the Flutter entry point with locale pinned to `ar` in `apps/mobile/lib/main.dart` — `fb16210`
- [x] T017 [P] [US1] Create `apps/mobile/lib/l10n/app_ar.arb` with Arabic written first — `fb16210`
- [x] T018 [P] [US1] Create `apps/mobile/lib/l10n/app_en.arb` with identical keys — `fb16210`
- [x] T019 [US1] Declare the Codespaces environment in `.devcontainer/devcontainer.json` and `.devcontainer/post-create.sh` so a rebuild needs no manual setup — `dfff741`
- [x] T020 [US1] Write the setup and verification walkthrough in `specs/001-e0-foundation/quickstart.md` — this commit

**Checkpoint**: US1 delivered. `./scripts/verify.sh` passes locally with all seven checks
running; confirmed against the real toolchain, not inferred from CI.

---

## Phase 4: User Story 3 — The rules are written down and enforced (P2)

**Goal**: Every stated rule has a recorded definition and, where mechanical, a check.

**Independent test**: Pick any stated rule; find its definition, then watch a violating change be
rejected without a person noticing.

Sequenced before US2 despite lower priority: US2's release checklist cites these rules, so
writing them first avoids citing documents that do not exist — the exact failure E0 was created
to fix.

### Implementation for User Story 3

- [x] T021 [P] [US3] Write the canonical vocabulary with reasoning per banned synonym in `docs/vision/glossary.md` — `40213fa`
- [x] T022 [P] [US3] Write entity relationships, lifecycles, and ten database-enforced invariants in `docs/product/domain-model.md` — `40213fa`
- [x] T023 [P] [US3] Record the provider-abstraction decision, its rejected options and revisit trigger, in `decisions/0005-route-all-model-calls-through-a-provider-abstraction.md` — `40213fa`
- [x] T024 [P] [US3] Add the conversational-flow review agent in `.claude/agents/conversation-designer.md` — `7c10119`
- [x] T025 [P] [US3] Add the provider and human-approval boundary agent in `.claude/agents/ai-boundary-reviewer.md` — `7c10119`
- [x] T026 [P] [US3] Add the Arabic-first localization agent in `.claude/agents/localization-reviewer.md` — `7c10119`
- [x] T027 [P] [US3] Add the product-fatal trust agent in `.claude/agents/trust-reviewer.md` — `7c10119`
- [x] T028 [P] [US3] Add the accessibility agent in `.claude/agents/accessibility-reviewer.md` — `7c10119`
- [x] T029 [US3] Add the synthetic-content check rejecting DML against `cooks`, `meals`, `reviews`, `kitchen_profiles` in `scripts/verify.sh` — `fcba2cb`
- [ ] T030 [US3] Add a gate check asserting every rule named in `CLAUDE.md` resolves to a file that exists, in `scripts/verify.sh` — closes the "rule written but no check" edge case in spec.md

**Checkpoint**: US3 mostly delivered. FR-008 stays unproven until E1 creates the first table —
recorded in spec.md Delivery Status rather than assumed.

---

## Phase 5: User Story 2 — A release reaches a Cook's phone (P1)

**Goal**: A verified change becomes something a Cook can install, reproducibly, with a person
deciding it ships.

**Independent test**: Take a verified commit, produce a release candidate, confirm it is
reproducible, traceable to that commit, and cannot reach the public without a recorded decision.

**Unblocked**: T031 is done — `android/` and `ios/` exist and a release bundle builds end to
end. What remains is custody and configuration, not code.

### Implementation for User Story 2

- [x] T032 [US2] Add the Android release-candidate job building with `--obfuscate --split-debug-info` and archiving both artifacts in `.github/workflows/deploy.yml` — `fcba2cb`
- [x] T033 [US2] Move the release guards to step level, after checkout, since job-level `hashFiles()` runs against an empty workspace — `fcba2cb`
- [x] T034 [US2] Place `key.properties` where Gradle resolves it while keeping the keystore outside the working tree, in `.github/workflows/deploy.yml` — `fcba2cb`
- [x] T035 [US2] Derive the signed status from the built artifact rather than from secret presence, in `.github/workflows/deploy.yml` — `fcba2cb`
- [x] T036 [US2] Pin the Supabase CLI version so unreviewed code cannot run against production holding an account-scoped token — `fcba2cb`
- [x] T037 [US2] Write the release review agent and pre-submission checklist in `.claude/agents/release-engineer.md` — `fcba2cb`
- [x] T031 [US2] Generate the platform projects with `flutter create --platforms=android,ios --org com.kafoo` in `apps/mobile` — `5f49ce5`
- [x] T038 [US2] Configure release signing in `apps/mobile/android/app/build.gradle.kts` reading `rootProject.file('key.properties')`; replaced Flutter's debug-key default — `5f49ce5`
- [x] T048 [US2] Detect debug-signed bundles by certificate owner rather than by the presence of a signature block, in `.github/workflows/deploy.yml` — `3d28f53`
- [ ] T039 [P] [US2] Execute the custody plan in `docs/ops/release-custody.md` — register the two dedicated accounts, seal the trustee's recovery path, generate the upload key, then run the drill that actually closes FR-016. Decided 2026-07-29; nothing executed yet. The premise this task was written against was wrong: the upload key is resettable and the Apple certificate is regenerable — see the ADR-0006 amendment
- [ ] T040 [P] [US2] Add the four Android signing secrets to repository settings, per `.claude/agents/release-engineer.md`
- [ ] T041 [US2] Verify a real release candidate: confirm the bundle is signed, symbols are archived, and the build number is monotonic across two runs
- [ ] T042 [P] [US2] Write the store listing in Egyptian Arabic first with English as translation, and confirm no screenshot depicts an invented Cook, Meal, or Review — FR-013, FR-014

**Checkpoint**: US2 partially delivered. A release bundle builds end to end (41.9 MB, 3 symbol
files) and the pipeline was corrected against a real artifact rather than by inspection. What
remains is keystore custody (T039), which is a decision about where credentials live, and the
store listing (T042). Until T039/T040, every candidate is debug-signed and unpublishable — the
pipeline now says so explicitly instead of reporting success.

---

## Phase 6: Polish & Cross-Cutting

- [ ] T043 [P] Pin every GitHub Action to a commit SHA rather than a mutable tag in both workflows — a tag repoint runs attacker code in a job holding the signing identity
- [ ] T044 [P] Confirm branch protection on `main` requires a passing gate, or correct the comment in `.github/workflows/deploy.yml` claiming migrations stay behind human review
- [ ] T045 [P] Add `apps/admin` as a workspace member once the administrative surface is needed — deliberately deferred, see spec.md Assumptions
- [x] T047 [P] Add the Android SDK to `.devcontainer/post-create.sh` so a rebuild can still build a release — this commit
- [ ] T046 Run `/speckit-analyze` across spec, plan, and tasks to check they still agree

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)** → no dependencies
- **Foundational (Phase 2)** → depends on Setup; blocks every story
- **US1 (Phase 3)** → depends on Foundational
- **US3 (Phase 4)** → depends on Foundational; independent of US1
- **US2 (Phase 5)** → depends on Foundational; **T031 blocks T038–T042**
- **Polish (Phase 6)** → depends on the stories it touches

### Story dependencies

US1 and US3 are genuinely independent and were delivered in parallel. US2 depends on neither in
principle — but its checklist cites US3's documents, so US3 first avoids dangling references.

### Parallel opportunities

All `[P]` tasks within a phase touch different files. The remaining real parallelism:

```bash
# After T031 unblocks the platform projects:
T039  # keystore custody              (no repository file)
T040  # repository secrets            (no repository file)
T042  # store listing                 (no repository file)

# Independent of everything above:
T043  # pin actions to SHAs           .github/workflows/*
T044  # branch protection             repository settings
```

## Implementation Strategy

**Delivered**: US1 and US3. The gate enforces seven checks, verified locally against the real
toolchain rather than inferred from CI.

**Next**: T039 — decide where the upload keystore lives and how it is recovered. It is the only
remaining item with permanent consequences: a lost upload key means Kafoo can never update the
app for anyone who already installed it. Nothing has been generated yet, which is why it is still
cheap to get right.

**Deliberately deferred**: T045 (`apps/admin`) until an administrative surface is needed, and the
first migration until E1, because a table created now would have an ownership rule that has never
been exercised.
