# Feature Specification: E0 Foundation

**Feature Branch**: `claude/kapoor-dotfiles-setup-i702ir`

**Created**: 2026-07-28

**Status**: Partially delivered — see Delivery Status

**Input**: User description: "E0 Foundation — the workspace, governance, and release path that every later epic depends on."

> **Scope guard — Constitution Principle VII (Documentation Separation of Concerns).**
> This document is the **product** perspective: WHAT the system does and WHY. It MUST remain
> technology-agnostic.
>
> - NO frameworks, libraries, or architecture patterns. NO implementation details.
> - NO technical terminology except canonical domain terms (Customer, Cook, Kitchen Profile,
>   Meal, Order, Review, Conversation, AI Assistant — never buyer, vendor, product, listing,
>   chatbot). See Principle VI.
> - All HOW belongs in `plan.md`. **Technical detail found here is a blocker for merge**, and
>   review MUST explicitly verify technology-agnosticism.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A contributor can verify their own work (Priority: P1)

Someone joining Kafoo — or returning to a machine that was wiped — gets from a fresh start to a
change they have personally verified, without asking anyone how. The rules the project holds
itself to are applied to their work automatically, and give the same answer on their machine as
they will give when the change is proposed to the team.

**Why this priority**: Every other epic is built by someone in this position. If verification
depends on knowledge one person holds, the project's stated rules are aspirations rather than
constraints, and quality becomes a function of who happened to review.

**Independent Test**: Start from nothing but the project's stored contents, make a trivial
change, and confirm it can be verified end to end with no undocumented step and no person
consulted. Delivers value even if nothing else in this epic exists.

**Acceptance Scenarios**:

1. **Given** a contributor with an empty working environment, **When** they follow only what the
   project itself records, **Then** they reach a state where they can verify a change, with no
   step requiring another person.
2. **Given** a change that breaks a project rule, **When** the contributor verifies it locally,
   **Then** it is reported as failing, and it fails for the same reason when proposed to the team.
3. **Given** a change that respects every rule, **When** it is verified, **Then** it passes both
   locally and when proposed, with no disagreement between the two.
4. **Given** an environment that is destroyed and recreated, **When** the contributor returns,
   **Then** the setup is restored without repeating manual work.

---

### User Story 2 - A release reaches a Cook's phone by a repeatable path (Priority: P1)

A verified change can be turned into something a Cook can install, by a path that produces the
same result every time, records what was released, and requires a person to decide it goes out.

**Why this priority**: Kafoo is used on a phone. Until a release path exists, verified work
reaches nobody and the product's value is unrealised regardless of quality. A release also cannot
be withdrawn once people have it, which makes the human decision point a requirement rather than
a nicety.

**Independent Test**: Take a verified change, produce a release candidate from it, and confirm
the candidate is reproducible, attributable to that exact recorded state, and cannot reach the
public without a recorded human decision.

**Acceptance Scenarios**:

1. **Given** a verified change, **When** a release candidate is produced, **Then** it is built by
   the same steps every time, with no manual intervention.
2. **Given** a release candidate, **When** it is examined later, **Then** it can be traced to the
   exact recorded state of the work it came from.
3. **Given** a release candidate is ready, **When** no person has approved it, **Then** it does
   not reach the public.
4. **Given** a Cook reports the app failing, **When** the failure is investigated, **Then** it can
   be located in the work that produced that release rather than guessed at.
5. **Given** a release is being prepared, **When** the material shown publicly is reviewed,
   **Then** no Cook, Meal, or Review depicted is invented, and the text reads in Egyptian Arabic
   first.
6. **Given** a release is being prepared, **When** the charges a Customer would pay are reviewed,
   **Then** every one of them is visible before confirmation, and withdrawing a pending Order is
   no harder than placing it.

---

### User Story 3 - The rules are written down and enforced (Priority: P2)

Every rule the project claims to hold has a written definition someone can read without having
been present when it was decided, and — where it can be checked mechanically — a check that
applies it.

**Why this priority**: A rule that exists only in a reviewer's memory is applied inconsistently
and lost when that person is unavailable. Writing rules down is what lets the other two stories
be verified rather than trusted.

**Independent Test**: Pick any rule the project states, and confirm both that its full definition
is recorded and that a change violating it is rejected without a person noticing.

**Acceptance Scenarios**:

1. **Given** a rule the project states, **When** someone looks for its definition, **Then** they
   find it recorded, with the reasoning behind it.
2. **Given** a decision that constrains future work, **When** someone asks why, **Then** the
   options rejected and the accepted costs are recorded, not only the conclusion.
3. **Given** a change using a non-canonical word for a domain concept, **When** it is verified,
   **Then** it is rejected.
4. **Given** stored information belonging to one person, **When** anyone else attempts to read
   it, **Then** they receive nothing — and this holds independently of the application's own
   checks.
5. **Given** a change that would store an invented Cook, Meal, or Review, **When** it is verified,
   **Then** it is rejected before it can reach anyone.

---

### Edge Cases

- A rule is written down but no check exists for it. The gap must be visible rather than
  presenting as compliance.
- A verification passes because there is nothing to check yet. Emptiness must not be reported as
  correctness.
- The working environment is destroyed between sessions. Anything not deliberately preserved is
  lost, including notes someone assumed were saved.
- The ability to sign releases is lost. This can permanently prevent updating the app for people
  who already have it.
- A release is published and then found to be harmful. It cannot be recalled, only replaced,
  after a delay outside the team's control.
- Two releases are prepared at once, producing ambiguous ordering for people receiving updates.
- An outside reviewer rejects a submission for reasons unrelated to the work's quality.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A contributor MUST be able to bring an empty environment to a working state using
  only what the project records, with no step that depends on asking a person.
- **FR-002**: Verification MUST produce the same verdict for the contributor as for the team.
  There is one definition of passing, not two.
- **FR-003**: A change violating a project rule MUST be rejected before it becomes part of the
  shared work, not noticed afterwards.
- **FR-004**: Verification MUST report honestly when it has nothing to check, so emptiness is
  never mistaken for correctness.
- **FR-005**: Each domain concept MUST have exactly one recorded canonical name, and a change
  using another name for it MUST be rejected.
- **FR-006**: Every rule the project states MUST have a written definition, including its
  reasoning, readable by someone absent when it was decided.
- **FR-007**: Every decision constraining future work MUST record the options rejected, the costs
  accepted, and the condition that would justify revisiting it.
- **FR-008**: Information belonging to one person MUST be unreadable by anyone else, enforced
  independently of the application, and each such rule MUST be accompanied by evidence that a
  non-owner receives nothing.
- **FR-009**: A change that would store an invented Cook, Meal, or Review MUST be rejected
  automatically, including when introduced as example or starting data.
- **FR-010**: A release candidate MUST be produced by identical steps each time, from a single
  recorded state of the work.
- **FR-011**: A release candidate MUST remain traceable to the work that produced it after it has
  reached people, so a reported failure can be located rather than guessed at.
- **FR-012**: A release MUST NOT reach the public without a recorded decision by a person.
- **FR-013**: Material shown publicly alongside a release MUST contain no invented Cook, Meal, or
  Review, and no depiction of food presented as a real Meal that is not one.
- **FR-014**: Text shown publicly alongside a release MUST be available in Egyptian Arabic as the
  primary language, with English as the translation.
- **FR-015**: Before a release, every charge a Customer would pay MUST be confirmed visible ahead
  of their confirmation, and withdrawing a pending Order MUST be no harder than placing it.
- **FR-016**: The means of signing releases MUST be recoverable by more than one person, since
  losing it can permanently prevent updating the app.
- **FR-017**: Anything a contributor produces that must outlive their working session MUST be
  deliberately preserved, and it MUST be evident when something has not been.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A contributor starting from an empty environment reaches a verified change in under
  30 minutes, consulting no person.
- **SC-002**: 100% of violations of mechanically checkable rules are caught before the change
  joins the shared work, with none first identified by a human reviewer.
- **SC-003**: Zero steps between a verified change and a release candidate require knowledge held
  by only one person.
- **SC-004**: A failure reported by a Cook can be traced to the specific work that produced the
  release in 100% of cases.
- **SC-005**: No release reaches the public without a recorded human decision — zero exceptions.
- **SC-006**: Every stated rule has a recorded definition — zero rules whose definition cannot be
  found.
- **SC-007**: An environment destroyed and recreated is restored to a working state with zero
  manual reinstallation steps.

## Delivery Status

This epic is partially delivered. Recording that here keeps the spec honest rather than
describing delivered work as planned.

| Story | Status | Evidence |
|---|---|---|
| US1 — contributor verifies own work | Delivered | Verification runs and reports honestly, including when a check has nothing to inspect. Environment setup is recorded and restored automatically. |
| US3 — rules written down and enforced | Mostly delivered | Canonical vocabulary, the domain model, and the provider decision are recorded. Vocabulary, language, and synthetic-content checks reject violations. **FR-008 is unproven** — no stored information exists yet, so the ownership rule has never been exercised. |
| US2 — release reaches a Cook's phone | Not delivered | No release candidate can currently be produced; the phone project itself has not been generated. |

**Gaps carried forward**: FR-008 evidence awaits the first stored information (E1). FR-016 is
unaddressed — no signing material exists or is recoverable. FR-015 cannot be exercised until
Orders exist (E4). The separate administrative surface is not built.

## Assumptions

- A contributor has an internet connection and permission to obtain the project's contents. No
  offline setup path is required.
- Working environments are disposable and recreated often, so anything not deliberately preserved
  is assumed lost. This is treated as normal rather than exceptional.
- Releases are prepared for phones. A separate administrative audience exists but is out of scope
  for this epic.
- One person currently approves releases. The requirement is that approval is recorded and
  deliberate, not that a specific number of people are involved.
- An outside party reviews submissions and may reject them for reasons unrelated to quality. This
  is expected rather than treated as failure.
- Egyptian Arabic is the primary language for anything a Cook or Customer reads, including
  material shown publicly alongside a release.
