# Implementation Plan: Meal Publishing

**Branch**: `003-meal-publishing` | **Date**: 2026-07-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-meal-publishing/spec.md`

## Summary

A Cook publishes a Meal through a conversation. The AI Assistant reads what they said and the photo
they took, and proposes ingredients, calories, allergens, a cuisine, a category and a description.
The Cook approves each one, and only then does anything get written.

The technical shape follows from one constraint the specification could not see: **a model provider
key cannot live in a Flutter binary.** Every model call therefore happens in an Edge Function, and
the Dart-side `AiProvider` becomes an adapter that calls that function rather than a vendor. This
keeps ADR-0005's promise — feature code depends on an interface, swapping vendors is a config
change — while moving the credential somewhere it can be rotated. It also gives the AI Assistant a
structural inability to write: the function that talks to the model holds no service-role key and
has no write path, so the only thing that ever writes a Meal is the Cook's own session, carrying
the Cook's own identity.

That is the design. Everything else here is consequence.

## Technical Context

**Language/Version**: Dart 3.6+ / Flutter 3.27+ (app, packages); TypeScript on Deno (Edge Functions)

**Primary Dependencies**: `supabase_flutter` ^2.9, `speech_to_text` ^7.4, `image_picker` ^1.1,
`flutter_riverpod` + `riverpod_generator` (**new — see Complexity Tracking**)

**Storage**: Supabase Postgres (`meals`, extending `kitchen_profiles` policies), Supabase Storage
(`meal-photos` bucket)

**Testing**: `dart test` (domain, ai), `flutter test` (mobile, ui), pgTAP via `supabase test db`,
`deno test` for Edge Functions, golden cases in `packages/ai/test/goldens/`

**Target Platform**: Android and iOS (ADR-0006); the web build target exists for development only
(ADR-0008)

**Project Type**: Mobile app + managed backend

**Performance Goals**: Meal publish < 3s (constitution). Voice round-trip < 2s. The AI estimate is
**not** inside the publish budget — FR-030 puts it in the conversation — but it is inside the voice
budget, and a vision call is the slowest thing Kafoo has ever done.

**Constraints**: Streaming required for conversational responses. Every model call declares a
`model_tier`. Prompts are files, never string literals. Egyptian Arabic is the source locale.

**Scale/Scope**: Friends-and-family. One new table, one new bucket, one new Edge Function, one new
conversation, roughly six screens.

**NEEDS CLARIFICATION**: Which model provider, and at what cost per published Meal. Resolved in
[research.md](research.md) §1 as a decision the founder must take — it is recurring spend, which is
a stop-and-ask trigger.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v1.1.0).

| # | Gate | Status | Notes |
|---|------|--------|-------|
| I | **User trust** | PASS | No synthetic Meals — seed data stays empty and `verify.sh`'s synthetic-content check already enforces it. FR-015 forbids AI imagery as a Meal photo. No fee exists in E2, so FR-021's "price is the whole cost" is trivially satisfiable and must stay so when E4 adds charges. |
| II | **AI suggests, humans approve** | PASS | Enforced structurally, not by convention: the Edge Function that calls the model holds no service-role key and performs no writes. Every write is the Cook's own session under RLS. `nutrition_source` is a column, not a UI flag, so an approved estimate stays an estimate in the data. |
| III | **Security by default** | PASS | `meals` enables RLS in the same migration, four per-operation policies, `USING` + `WITH CHECK` on `UPDATE`, deny-by-default. Lifecycle and ownership are `CHECK` constraints and foreign keys, not application validation. Negative tests written first. |
| IV | **Conversation first, Arabic first** | PASS | Seven values are gathered, which would be a seven-field form. FR-001 forbids it. One question at a time, and the AI Assistant exists precisely so most values are inferred rather than asked. |
| V | **Provider independence** | PASS — **amendment landed 2026-08-02** | All calls go through `AiProvider`. The adapter calls a Kafoo Edge Function rather than a vendor SDK, because the key cannot ship in the client. ADR-0005 Amendment 1 records this, fixes the configuration mechanism so switching vendors is one environment variable with no code diff, and names the provider (Claude Haiku 4.5). Written **before** the Edge Function, not after — building on a decision record known to be wrong is how one becomes fiction. |
| VI | **Canonical vocabulary** | PASS | Names reserved in `docs/product/event-model.md`: `MealDrafted`, `MealPublished`, `MealUpdated`, `MealArchived`, plus `ConversationStepCompleted` with `kind: meal`. None invented here. |
| VII | **Documentation separation** | PASS | `spec.md` names no framework, storage engine, provider or policy. Verified by grep at spec time. |
| — | **Performance budgets** | **AT RISK** | Publishing stays under 3s because FR-030 moves estimation out of it. The estimate itself is a vision call inside a 2-second voice budget, and nothing in Kafoo has ever measured a model round-trip. Called out rather than assumed — see research.md §3. |
| — | **Privacy** | PASS | No new personal-data field. A Meal photo is the Cook's content, but it leaves Kafoo, so FR-029 discloses before use and allows refusal. Allergens describe food, not a person. No raw audio persisted — speech is transcribed on device exactly as in E1. |
| — | **Stop-and-ask triggers** | **THREE FIRED** | (1) Adds screens — the conversation, the drafts list, the Meal view. (2) Touches pricing — a Meal carries a price. (3) Recurring spend on a model provider. All three were surfaced in the specification and the first two answered; the provider decision remains for the founder. |

**Verification**: `./scripts/verify.sh` must pass before this feature's PR opens.

### Post-design re-check

Re-run after Phase 1. Three things to look at specifically, because they are where this design is
most likely to have drifted:

1. **Did the `analyze-meal` function stay write-free?** The moment it gains a service-role key to
   "just cache the estimate", Principle II is decoration.
2. **Did the widening `kitchen_profiles` policy land in the same migration as `meals`?** If not,
   kitchens with Meals on offer are silently unreachable and every test still passes.
3. **Is `nutrition_source` written from the client's claim, or from what actually happened?** A
   Cook-edited value marked `ai` is a lie the database will keep telling.

## Project Structure

### Documentation (this feature)

```text
specs/003-meal-publishing/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── authorization.md
│   └── analyze-meal.md
└── tasks.md             # Phase 2 — NOT created by /speckit-plan
```

### Source Code (repository root)

```text
apps/mobile/lib/features/meal/
├── presentation/        # conversation, summary, drafts list, meal view, edit
├── application/         # controllers, Riverpod providers, approval state
└── data/                # meal_repository.dart — the only layer touching Supabase

packages/domain/lib/
├── meal.dart            # entity, lifecycle, transition rules — no Flutter, no Supabase
├── meal_step.dart       # the question sequence as data
└── nutrition_source.dart

packages/ai/lib/src/provider/
└── edge_function_provider.dart   # AiProvider adapter calling Kafoo's own function

prompts/
├── meal-analysis.md     # ingredients, calories, allergens, cuisine, category
└── meal-description.md  # drafted description, Egyptian register

supabase/
├── migrations/          # meals + RLS + the widening kitchen_profiles policy, one file
├── functions/analyze-meal/
└── tests/               # meals_rls_test.sql, kitchen_discoverability_test.sql (exists, will flip)
```

**Structure Decision**: Follows the E1 layering exactly — `presentation/`, `application/`, `data/`
per feature, with `data/` the only layer that touches Supabase and `packages/domain/` free of both
Flutter and Supabase. The one addition is `application/` carrying real weight for the first time,
because this conversation has state E1's did not: a persisted draft, in-flight model calls, and
per-field approval.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| **Riverpod + `build_runner` enter the project** | `.claude/rules/dart.md` mandates Riverpod with code generation. E1 deliberately shipped without it and named the revisit condition: "when a screen needs state that is neither local nor auth". This feature is that condition — a draft that outlives the screen, model calls in flight, and approval state per field. | Continuing with E1's stream-and-builder means hand-rolling the same thing worse. The cost is real and worth naming: `verify.sh`'s codegen-drift check stops skipping, and every annotated change needs a generator run. |
| **`AiProvider` adapter calls a Kafoo Edge Function, not a vendor** | A provider key in a Flutter binary is extractable, and the constitution calls a hardcoded key a rotate-everything incident. The credential must sit server-side. | Calling the vendor from Dart would ship the key to every handset. Writing a second provider abstraction in TypeScript would mean two seams drifting apart, and ADR-0005 exists to prevent exactly that. **ADR-0005 must be amended** — it assumed the seam and the credential could live in the same place. |
| **A Meal has more fields than a Kitchen Profile** | Seven values, past the constitution's four-field stop-and-think threshold. | A form was rejected outright (FR-001). The mitigation is that the AI Assistant infers most of them, so the Cook is asked three or four things rather than seven. If the conversation ends up asking for all seven, the AI Assistant has failed and the design should be revisited rather than shipped. |

## What this plan does not decide

- ~~**Which model provider.**~~ **Decided 2026-08-02: Claude Haiku 4.5.** Priced first, and the
  pricing changed the question — every fast-tier candidate costs under a cent per published Meal, so
  the decision turned on adversarial robustness and photo handling rather than spend. Switching is
  one environment variable, by requirement rather than by luck. See ADR-0005 Amendment 1.
- **Whether estimates are cached.** `.claude/rules/ai.md` says cache nutrition estimates for
  identical Meal text. Worth doing, but it needs a cache-invalidation answer and is not required
  for correctness.
- **Search or discovery beyond a direct reference.** E3. A kitchen becomes readable here; finding
  one is a different feature.
- **Whether a Cook is shown drafts accumulating.** Open Question 4 in the spec. Changes a surface,
  not a rule.
