# Implementation Plan: Identity and Kitchen Profile

**Branch**: `claude/keystore-custody-strategy-sx3f02` | **Date**: 2026-07-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-identity-kitchen-profile/spec.md`

## Summary

Give Kafoo its first stored information, and with it the first proof that a person's information is
unreadable by anyone else. A person signs in with a phone number and a one-time code; they become a
Cook by having a conversation about their kitchen rather than filling in a form; they can leave and
take everything with them.

The approach has one organising idea: **put every rule where it cannot be bypassed, and prove it
with a test that runs on every future change.** Ownership is a row-level policy, not a check in
Dart. "At most one Kitchen Profile" is a unique constraint, not a lookup before insert. "Removal
reaches the analytics" is a foreign key, not a cleanup routine someone has to remember to call.
`FR-008` has been asserted since E0 with nothing stored to demonstrate it against; this feature is
where it stops being a claim.

Two things are deliberately absent. There is no AI Assistant, so nothing here depends on a model
provider. And there is no third-party analytics SDK, so the promise that leaving really means
leaving is something the database enforces rather than something an outside service's deletion
endpoint is trusted to do.

## Technical Context

**Language/Version**: Dart 3 (SDK `^3.6.0`), Flutter stable ≥3.27

**Primary Dependencies**: `supabase_flutter` — the first production dependency Kafoo has taken.
`speech_to_text` for on-device recognition. No state-management, routing, or dependency-injection
package: see [research.md](research.md) §7 for why each was considered and left out.

**Storage**: Supabase (Postgres). Two new tables — `kitchen_profiles`, `analytics_events` — plus
one storage bucket. Identity lives in `auth.users`, which Kafoo reads and never copies.

**Testing**: `flutter test` for widget and flow tests; `dart test` for `packages/domain`; pgTAP in
`supabase/tests/` for the authorization proofs. The negative tests are written **before** the
policies they check, per the constitution.

**Target Platform**: Android and iOS phones (ADR-0006). Mid-range Android is the device that
matters — it is what the Cooks have, and it is where on-device Arabic recognition is least certain.

**Project Type**: Mobile app plus shared packages in a Dart pub workspace, backed by Supabase.

**Performance Goals**: App launch <2s. Voice round-trip <2s — helped considerably by recognition
happening on the device rather than over an Egyptian mobile connection. No search or Meal publish
in this feature.

**Constraints**: Egyptian Arabic is the default locale, RTL throughout. `packages/domain` imports
neither Flutter nor `supabase_flutter`. Audio never leaves the phone. A phone number is never
copied into a Kafoo-owned table.

**Scale/Scope**: 2 tables, 1 Edge Function, 1 storage bucket, ~7 screens, 11 analytics events.
Single-maintainer project, friends-and-family scale at first release.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v1.1.0).

| # | Gate | Status | Notes |
|---|------|--------|-------|
| I | **User trust** | PASS | No synthetic content — the gate already rejects DML against `kitchen_profiles`. The two flows where dark patterns live are guarded explicitly: FR-029 caps the email invitation and stops it after declines; FR-034 forbids making leaving harder than joining. No charges exist in this feature. |
| II | **AI suggests, humans approve** | N/A | No AI in this feature, deliberately. Speech recognition is the platform's own, on-device, and is not a model call — no `AiProvider`, no prompt, no golden case. Nothing AI-derived reaches storage because nothing here is AI-derived. |
| III | **Security by default** | PASS | Both tables enable RLS in their creating migration. Per-operation policies, deny by default, `USING` + `WITH CHECK` on every `UPDATE`. Negative tests written first. Invariants are constraints: `UNIQUE (cook_id)` for FR-009, a foreign key for FR-039. The Edge Function reads identity from the JWT and takes no arguments. |
| IV | **Conversation first, Arabic first** | PASS | A Kitchen Profile has five details — past the four-field threshold — so it is a conversation asking one question at a time, and SC-006 makes that measurable. Arabic written first, `ar` the default locale, ARB parity gated, RTL asserted by test. |
| V | **Provider independence** | N/A | No model call anywhere in this feature. `packages/domain` holds the Kitchen Profile entity and its rules and imports neither Flutter nor Supabase — the boundary is enforced by the package split, not by intention. |
| VI | **Canonical vocabulary** | PASS | Tables are `kitchen_profiles`, columns `cook_id`. Events come from `docs/product/event-model.md` and none were invented here. The gate's vocabulary check covers the SQL and the Dart. |
| VII | **Documentation separation** | PASS | `spec.md` was swept mechanically for framework, storage and platform terms; the only match is the word "frameworks" inside the template's own scope guard. Every technical decision is in this file or `research.md`. |
| — | **Performance budgets** | PASS | Launch <2s is the only budget this feature can breach, and the absence of a state-management package and a routing package helps rather than hurts. On-device recognition keeps the voice round-trip off the network entirely. |
| — | **Privacy** | PASS | Two new personal-data categories, both answered. Phone number: FR-022 states the purpose, FR-020 the reader set, FR-032 makes retention real by giving an account a way to stop existing — and Kafoo never copies the number out of `auth.users`. Funnel data: FR-037 and FR-038 bound it to which step and forbid content and audio, FR-040 fixes readers and retention, FR-039 makes removal reach it. No raw audio is persisted, so no ADR is required. |
| — | **Stop-and-ask triggers** | PASS — **approval obtained** | This feature trips three triggers: it adds screens, it collects two new categories of personal data, and account removal was a scope increase. All three were put to the founder in `/speckit-clarify` on 2026-07-30 and decided there; the answers are recorded in the spec's Clarifications section. No trigger was resolved by assumption. |

**Verification**: `./scripts/verify.sh` must pass before this feature's PR opens. It will exercise
the RLS coverage check against a real table for the first time.

### Post-design re-check

Re-run after Phase 1. Two notes, recorded rather than quietly adjusted:

- **III** stays PASS, but design surfaced one part of removal the database cannot enforce: storage
  objects have no foreign key, so `delete-account` must remove the photo explicitly. That is the
  most forgettable step in the feature, and `quickstart.md` checks it directly.
- **VI** stays PASS, and the design added no event. Every one of the eleven comes from the registry.

## Project Structure

### Documentation (this feature)

```text
specs/002-identity-kitchen-profile/
├── plan.md               # This file
├── spec.md               # The product perspective
├── research.md           # Phase 0 — decisions and what was rejected
├── data-model.md         # Phase 1 — tables, policies, constraints
├── quickstart.md         # Phase 1 — how to prove it works
├── contracts/
│   ├── authorization.md  # Who may read and write what. The contract that matters most.
│   └── delete-account.md # The one Edge Function
├── checklists/
│   └── requirements.md   # Spec quality checklist
└── tasks.md              # /speckit-tasks output — not created here
```

### Source Code (repository root)

```text
apps/mobile/lib/
├── main.dart                           # Locale fixed to ar; RTL asserted by test
├── l10n/
│   ├── app_ar.arb                      # Written first. The source, not the translation.
│   └── app_en.arb
└── features/
    ├── identity/
    │   ├── sign_in_screen.dart          # Phone number. One field, nothing else.
    │   ├── code_screen.dart             # The one-time code
    │   ├── recovery_email_prompt.dart   # Offered once; FR-029 caps it
    │   └── remove_account_screen.dart   # No bargaining, one confirmation
    └── kitchen_profile/
        ├── conversation.dart            # One question at a time. The heart of the feature.
        ├── conversation_summary.dart    # Nothing is kept until this is confirmed
        └── kitchen_profile_screen.dart  # View and change

packages/domain/lib/
├── kitchen_profile.dart                # Entity + rules. No Flutter, no Supabase.
└── conversation_step.dart              # The question sequence as data, not as widgets

packages/ui/lib/                         # Existing design system, extended as needed

supabase/
├── migrations/
│   ├── <ts>_create_kitchen_profiles.sql   # Table + RLS + policies, one file
│   └── <ts>_create_analytics_events.sql   # Table + RLS + policies, one file
├── functions/delete-account/index.ts      # Service role. No arguments.
└── tests/
    ├── kitchen_profiles_rls_test.sql      # Written before the policies
    └── analytics_events_rls_test.sql
```

**Structure Decision**: features live under `apps/mobile/lib/features/<feature>/`, which is the
first time this repo has needed a convention below `lib/`. Chosen over layer-first
(`screens/`, `models/`, `services/`) because a feature is the unit that gets added, reviewed and
removed, and layer-first directories grow into piles that no longer tell you what the app does.

The Kitchen Profile entity and the question sequence sit in `packages/domain` rather than in the
app, because the sequence is a domain rule — what a kitchen must say about itself — and not a
property of any screen. Keeping it there also means the constitution's ban on `supabase_flutter` in
`packages/domain` is enforced by the package boundary rather than by remembering.

## Phase 0 findings

Full reasoning in [research.md](research.md). The five that shaped this plan:

1. **`auth.users` is the Person.** Kafoo stores no phone number of its own, which makes FR-020 true
   by construction rather than by policy — you cannot leak from a table you never wrote to.
2. **Speech recognition happens on the device.** Audio never leaves the phone, so the constitution's
   "transcribed and discarded" rule needs no enforcement and no ADR. It also keeps E1 entirely clear
   of ADR-0005. The risk is `ar-EG` availability on real Egyptian handsets, which must be spiked.
3. **`delete-account` takes no arguments.** It reads the person from the JWT. A function with no
   input cannot be tricked into deleting the wrong person.
4. **Measurement lives in Postgres, not a third party.** FR-039's promise that removal reaches the
   analytics is then a foreign key the gate can test, rather than an API call taken on trust.
   `ON DELETE SET NULL` rather than `CASCADE`, so funnel counts survive while the person does not.
5. **E1 ships no public read policy on `kitchen_profiles`.** FR-030 derives discoverability from
   published Meals, and `meals` does not exist yet. Deny-by-default is both the achievable
   behaviour and the correct one — but E2 must widen it, and that is recorded in `data-model.md`
   where E2 will look.

## Complexity Tracking

No constitutional violations to justify. The table is kept, empty, because its emptiness is the
claim: this feature adds two tables, one function, no new abstraction layer, and no package that a
Flutter project usually takes by habit rather than by need.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

## What this plan does not decide

Stated so they are not mistaken for oversights:

- **The SMS provider is configuration**, not architecture. Twilio Verify is the starting point; the
  choice is reversible without touching Kafoo's code, and the real cost into Egyptian networks has
  to be measured before it is committed to.
- **The dormancy policy for recycled numbers** stays deferred, per the spec. The modelling that
  makes it addable later is in place.
- **A person-assisted way back** for a Cook who loses their number is an open question in the spec
  and stays open. It is a support process before it is a feature, and building the wrong one would
  create the takeover route it is meant to prevent.
