---

description: "Task list for E1 — Identity and Kitchen Profile"
---

# Tasks: Identity and Kitchen Profile

**Input**: Design documents from `specs/002-identity-kitchen-profile/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Authorization tests are **mandatory**, not optional. The constitution requires a negative
test proving a non-owner reads zero rows for every new table, written *before* the policy. Widget
and flow tests follow the same rule only where a requirement is otherwise unprovable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on incomplete work
- **[Story]**: Which user story the task serves

## A note on ordering

Spec order is not implementation order here, and the deviation is deliberate.

User Stories 1, 2 and 3 are all P1. **US3 — only the owner can reach what belongs to them — is
built first**, because it is the story that creates the tables, and every other story writes into
them. Building sign-in first would mean a signed-in person with nowhere to put anything; building
the conversation first would mean storing a Kitchen Profile before the policy protecting it exists.

That also puts the negative tests before the migration they test, which is what the constitution
requires and what makes them worth writing: a test that passes the first time you run it has
proven nothing.

---

## Phase 1: Setup

- [ ] T001 Add `supabase_flutter` to `apps/mobile/pubspec.yaml` — the first production dependency Kafoo has taken
- [ ] T002 [P] Add `speech_to_text` to `apps/mobile/pubspec.yaml` for on-device recognition (research.md §3)
- [ ] T003 Initialise the Supabase client at startup in `apps/mobile/lib/main.dart`, reading URL and publishable key from `--dart-define`, never from a committed file
- [ ] T004 [P] Add the `kitchen-photos` storage bucket and local auth settings to `supabase/config.toml`, including test phone numbers so local sign-in needs no real message
- [ ] T005 Run `melos bootstrap` and confirm `./scripts/verify.sh` still passes before any behaviour changes

---

## Phase 2: Foundational

Blocking prerequisites. Every user story depends on these.

- [ ] T006 Create the analytics helper in `apps/mobile/lib/features/analytics/emit_event.dart` — one function taking an event name and attributes, writing to `analytics_events`, failing silently so a measurement outage never breaks a Cook's flow
- [ ] T007 [P] Add a Dart constant per event name in `apps/mobile/lib/features/analytics/event_names.dart`, copied from `docs/product/event-model.md` — no event name is invented at a call site
- [ ] T008 [P] Create `apps/mobile/lib/features/` and the `identity/` and `kitchen_profile/` subdirectories per plan.md's structure decision
- [ ] T009 Add an assertion to `apps/mobile/lib/features/analytics/emit_event.dart` rejecting any attribute value that is free text a person typed or spoke — FR-037's "which step, never what was said", enforced in code rather than in review

---

## Phase 3: User Story 3 — Only the owner can reach what belongs to them (P1)

**Goal**: Kafoo's promise that a person's information is unreadable by anyone else stops being an
assertion and becomes a test that runs on every future change.

**Independent test**: Signed in as one person, attempt to read and change another person's
information by every route. Every attempt returns nothing and changes nothing — automatically, on
every commit.

### Tests first — these must fail before the migrations exist

- [ ] T010 [P] [US3] Write the `kitchen_profiles` negative tests in `supabase/tests/kitchen_profiles_rls_test.sql` covering all seven cases in `contracts/authorization.md` — most importantly that a Cook cannot reassign `cook_id` to another person, which is the `WITH CHECK` case that fails when the policy is written from memory
- [ ] T011 [P] [US3] Write the `analytics_events` negative tests in `supabase/tests/analytics_events_rls_test.sql` covering all six cases, including that a person reads **zero** of their own events and that deleting a person leaves their event rows in place with `person_id` null
- [ ] T012 [US3] Run `supabase test db` and confirm both suites **fail**. A suite that passes here is testing nothing and must be fixed before proceeding

### Then the schema that makes them pass

- [ ] T013 [US3] Create the migration with `supabase migration new create_kitchen_profiles` — never hand-write the timestamp — containing the table, `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, and the three policies from data-model.md, all in one file
- [ ] T014 [US3] Create the migration with `supabase migration new create_analytics_events` containing the table, RLS enablement, and both insert policies, in one file
- [ ] T015 [US3] Add the storage policies for `kitchen-photos` — public read, write and delete restricted to the `{auth.uid()}/` prefix
- [ ] T016 [US3] Run `supabase db reset && supabase test db` and confirm both suites now **pass**
- [ ] T017 [US3] Confirm `./scripts/verify.sh`'s RLS coverage check now inspects a real table rather than announcing it has nothing to look at — the check has never run against real schema, so a silent skip here would hide everything

**Checkpoint**: the ownership rules exist and are proven. Every later story writes into protected
tables.

---

## Phase 4: User Story 1 — A person signs in with their phone number (P1)

**Goal**: A person becomes known to Kafoo with a phone number and a code, and nothing else.

**Independent test**: Sign in on a clean device, force-quit, reopen — still signed in. Sign in on a
second device with the same number — same person, not a new one.

- [ ] T018 [P] [US1] Add the sign-in strings to `apps/mobile/lib/l10n/app_ar.arb` in conversational Egyptian, written first, then their translations to `app_en.arb`
- [ ] T019 [US1] Build the phone-number screen in `apps/mobile/lib/features/identity/sign_in_screen.dart` — one field, no password, no role choice, no email. Emit `SignInStarted`
- [ ] T020 [US1] Build the code screen in `apps/mobile/lib/features/identity/code_screen.dart`, distinguishing a wrong code from an expired one in the message (FR-004), and allowing a new code without restarting
- [ ] T021 [US1] Emit `SignInCompleted` with `first_time`, and `SignInFailed` with `reason`, from the code screen
- [ ] T022 [US1] Emit `AccountCreated` on a first-ever sign-in — a core constitutional event, so it must not be missed
- [ ] T023 [US1] Handle the rate-limit refusal (FR-005) with a message stating when the person may try again, and confirm Supabase's own limits are configured to match rather than contradicting the message
- [ ] T024 [US1] Handle lost connectivity so a person is never left believing they are signed in when they are not (US1 scenario 5)
- [ ] T025 [US1] Route to the signed-in or signed-out surface from `auth.onAuthStateChange` in `apps/mobile/lib/main.dart` — a stream and a builder, no state-management package (research.md §7)
- [ ] T026 [P] [US1] Add a widget test in `apps/mobile/test/` asserting the sign-in screen asks for exactly one thing and never mentions email (SC-009)
- [ ] T027 [US1] Confirm on a device that returning after a force-quit restores the session without a new code

**Checkpoint**: a person can be recognised. Everything else assumes this.

---

## Phase 5: User Story 2 — A Cook creates a Kitchen Profile by talking (P1)

**Goal**: Five details gathered one question at a time, in Egyptian Arabic, by voice or typing, and
nothing kept until the Cook confirms.

**Independent test**: Complete the conversation using voice only, confirm, and find the Kitchen
Profile exactly as confirmed. Separately abandon halfway and find nothing stored.

- [ ] T028 [P] [US2] Define the Kitchen Profile entity and its rules in `packages/domain/lib/kitchen_profile.dart` — no Flutter, no Supabase imports
- [ ] T029 [P] [US2] Define the question sequence as data in `packages/domain/lib/conversation_step.dart` — it is a domain rule about what a kitchen must say about itself, not a property of any screen
- [ ] T030 [P] [US2] Add a `dart test` in `packages/domain/test/` asserting the sequence yields exactly one unanswered question at a time (SC-006), provable without a widget
- [ ] T031 [P] [US2] Add the conversation strings to `app_ar.arb` in conversational Egyptian — not Modern Standard — then `app_en.arb`
- [ ] T032 [US2] Build the conversation in `apps/mobile/lib/features/kitchen_profile/conversation.dart`, holding answers **in memory only**, so an abandoned conversation leaves nothing by construction (FR-013, FR-015)
- [ ] T033 [US2] Wire on-device recognition with `ar-EG`, showing each spoken answer back before it is accepted (FR-012, and the spec's mis-transcription edge case)
- [ ] T034 [US2] Degrade to typing with a plain explanation when recognition is unavailable — the likeliest real-world failure, and it must not break the flow (research.md §3)
- [ ] T035 [US2] Build the summary in `apps/mobile/lib/features/kitchen_profile/conversation_summary.dart` where every answer is correctable in one action (SC-008) and nothing is written until confirmation
- [ ] T036 [US2] Write the Kitchen Profile on confirmation, and emit `KitchenProfileCreated`
- [ ] T037 [US2] Emit `ConversationStarted`, `ConversationStepCompleted` with `step`, and `ConversationCompleted`, all carrying `kind: kitchen_profile` and `input` — `ConversationStepCompleted` is the drop-off signal the whole funnel exists for
- [ ] T038 [US2] Upload the photo to `kitchen-photos/{uid}/`, and let a Cook finish without one if it fails rather than losing the conversation
- [ ] T039 [US2] Send a person who already owns a Kitchen Profile to their existing one instead of starting a second (FR-009 in the UI; the unique constraint is the real guard)
- [ ] T040 [P] [US2] Add a widget test asserting no screen in the conversation shows two unanswered questions
- [ ] T041 [P] [US2] Add a test asserting an abandoned conversation writes nothing

**Checkpoint**: a person can become a Cook. This is the MVP boundary.

---

## Phase 6: User Story 5 — A Cook changes their kitchen later (P2)

**Goal**: Any part correctable without recreating the whole thing.

**Independent test**: Change each part in turn; each change is visible immediately and nothing else moves.

- [ ] T042 [P] [US5] Add the edit strings to `app_ar.arb` and `app_en.arb`
- [ ] T043 [US5] Build view and edit in `apps/mobile/lib/features/kitchen_profile/kitchen_profile_screen.dart`, editing one detail at a time in keeping with the conversation rather than reverting to a five-field form
- [ ] T044 [US5] Keep the previous version visible until a change is confirmed (US5 scenario 2)

---

## Phase 7: User Story 4 — A Customer can see a Cook's kitchen (P2)

**Goal**: The public face is defined and its rule enforced — even though nothing is discoverable yet.

**Independent test**: With no Meals in existence, confirm no person can find any kitchen, while the
five public details render correctly for someone holding a direct reference.

- [ ] T045 [P] [US4] Build the public kitchen view rendering exactly the five details from FR-019 and nothing else — no phone number reachable by any route
- [ ] T046 [US4] Add a test confirming a non-owner finds **zero** kitchens, which is correct in E1 and must not be "fixed" by adding a public policy — that policy belongs to E2 and is written out ready in data-model.md
- [ ] T047 [US4] Add the derived-discoverability rule to `docs/product/domain-model.md` — a Kitchen Profile has no state of its own; it is discoverable while its Cook has a published Meal and readable to anyone holding a legitimate reference regardless (DoD item 6)

---

## Phase 8: User Story 7 — A person removes everything and leaves (P2)

**Goal**: Leaving is real, reachable, and no harder than joining.

**Independent test**: Create an account, Kitchen Profile and photo; remove; confirm all four
outcomes; sign in again with the same number and be a new person.

- [ ] T048 [P] [US7] Add the removal strings to `app_ar.arb` and `app_en.arb` — plain, no guilt, no retention offer
- [ ] T049 [US7] Write the `delete-account` Edge Function in `supabase/functions/delete-account/index.ts` taking **no arguments** and reading identity from the verified JWT, per `contracts/delete-account.md`
- [ ] T050 [US7] Delete storage objects **before** the auth row, so a partial failure leaves a usable account rather than orphaned photos in a public bucket belonging to someone who asked to be forgotten
- [ ] T051 [US7] Emit `AccountRemoved` **without** attaching the person — recording who asked to be forgotten inside the function that forgets them would defeat it
- [ ] T052 [US7] Build the removal screen in `apps/mobile/lib/features/identity/remove_account_screen.dart` — one confirmation, no bargaining, no reason field, abandonable part-way (FR-034, FR-035)
- [ ] T053 [US7] Place the entry point so it takes no more steps to reach than creating the account took (SC-011)
- [ ] T054 [P] [US7] Add Edge Function tests for all six cases in `contracts/delete-account.md`, including that a caller deletes **themselves** regardless of anything in the request
- [ ] T055 [US7] Verify end to end against `quickstart.md` §6 — all four outcomes, especially that the **photo is gone**, which is the only step no foreign key enforces

---

## Phase 9: User Story 6 — Adding a second way in, by choice (P3)

**Goal**: A safety net offered once, at the moment it makes sense, that never gets in the way.

**Independent test**: Register without ever seeing an email field; confirm a Kitchen Profile and be
offered once; decline repeatedly and stop being asked; accept and sign in by email to the same
identity.

- [ ] T056 [P] [US6] Add the invitation strings to `app_ar.arb` and `app_en.arb`, stating in one sentence that it is how you keep access if you lose your number
- [ ] T057 [US6] Build the prompt in `apps/mobile/lib/features/identity/recovery_email_prompt.dart`, shown after a Kitchen Profile is confirmed — never during registration (FR-028)
- [ ] T058 [US6] Store the decline count in user metadata and stop offering after the cap; a declined prompt withholds nothing (FR-029, SC-010)
- [ ] T059 [US6] Attach the email from inside the account via `updateUser`, so an address can never claim an identity it was not attached to from within (FR-007)
- [ ] T060 [US6] Add the email sign-in route reaching the same identity, never a second one
- [ ] T061 [US6] Emit `RecoveryEmailOffered`, `RecoveryEmailDeclined` with `times_declined`, and `RecoveryEmailAttached`
- [ ] T062 [P] [US6] Add a test asserting registration completes with zero email prompts (SC-009), and one asserting the prompt stops after the cap
- [ ] T063 [US6] Build change-of-number via `updateUser` and emit `PhoneNumberChanged` (FR-026) — the flow that makes a lost or recycled number recoverable rather than terminal

---

## Phase 10: Polish & Cross-Cutting

- [ ] T064 [P] Add the Person shape to `docs/product/domain-model.md` — identity independent of the phone number that proves it, one account holding both roles, owning a Kitchen Profile being what makes someone a Cook (DoD item 6)
- [ ] T065 [P] Move every E1 event in `docs/product/event-model.md` from `planned` to `active` — a `planned` event that is emitted is as misleading as an `active` one that is not
- [ ] T066 [P] Confirm every screen renders under RTL with `EdgeInsetsDirectional` and `start`/`end`, never `left`/`right` (SC-005)
- [ ] T067 [P] Confirm semantic labels and ≥48dp tap targets on every new screen — the `accessibility-reviewer` agent carries the checklist
- [ ] T068 Measure app launch against the <2s budget and record the number; it has never been measured, so the first figure is the baseline, whatever it says
- [ ] T069 Update `docs/HANDOFF.md` — the Database and Features rows both say "Nothing", which stops being true with this feature
- [ ] T070 Run `./scripts/verify.sh` and confirm it passes with the RLS check inspecting real tables (DoD item 1)

---

## Spikes — run alongside, not after

These do not block writing code. They block believing it works, and each can invalidate a decision
cheaply now and expensively later (research.md, Open risks).

- [ ] T071 [P] Spike `ar-EG` recognition on real mid-range Android handsets bought in Egypt. Emulators are not evidence. If it fails, cloud transcription becomes the right answer and needs an ADR for audio handling
- [ ] T072 [P] Spike message delivery to a real Egyptian number, including sender-ID registration. An unregistered sender is filtered **silently** — nothing errors, the code simply never arrives
- [ ] T073 [P] Measure real per-verification cost against expected sign-in volume, and put the figure to the founder. Every sign-in on a new device costs money, which makes T023's rate limit a spending control as much as a security one

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (1)** → nothing
- **Foundational (2)** → Setup; blocks every story
- **US3 (3)** → Foundational; **blocks every other story**, since it creates the tables
- **US1 (4)** → US3
- **US2 (5)** → US3, US1 — a Kitchen Profile needs a signed-in person to own it
- **US5 (6)**, **US4 (7)**, **US7 (8)** → US2
- **US6 (9)** → US2, because the invitation is triggered by confirming a Kitchen Profile
- **Polish (10)** → the stories it touches
- **Spikes (T071–T073)** → independent of all of it; start immediately

### Parallel opportunities

```bash
# After Foundational, the two test suites are independent:
T010  # kitchen_profiles negative tests
T011  # analytics_events negative tests

# ARB files are touched by one story at a time, so string tasks parallelise across stories
# only if the stories themselves are not being built concurrently. Within a story:
T028  # domain entity          packages/domain/
T029  # question sequence      packages/domain/
T031  # Arabic strings         apps/mobile/lib/l10n/

# The three spikes are fully independent of the code and of each other:
T071  T072  T073
```

**A warning on the ARB files**: every `[P]` string task writes to the same two files. They are
parallel *across* stories only when those stories are not being implemented at the same time.
Treat `app_ar.arb` as a shared resource, not a per-story one.

## Implementation Strategy

**MVP = Phases 1–5** (T001–T041). A person signs in, becomes a Cook by talking rather than filling
in a form, and ownership is proven by tests that run forever after. That is the whole thesis of E1:
the first stored information, and the first evidence the promise about it is kept.

**Then Phase 8 (removal) before anything else**, out of priority order. Apple's guideline 5.1.1
makes it a submission requirement, ADR-0006 routes iOS through TestFlight with external testers and
therefore Beta App Review, and removal is cheapest to build now — after Meals and Orders exist it
has to reconcile records a Cook needs to keep.

**Phases 6, 7 and 9 are genuinely deferrable.** US4 in particular delivers no visible behaviour in
E1, since nothing is discoverable until Meals exist; its value is the rule and the test.

**Do not defer the spikes.** They are last in the file and should be first in the week. Each can
invalidate a decision that is cheap to change now and expensive after the flow is built around it.
