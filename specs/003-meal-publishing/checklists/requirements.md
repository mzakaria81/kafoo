# Specification Quality Checklist: Meal Publishing

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-31
**Updated**: 2026-07-31, after the clarification session
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

All 16 items pass. The specification is ready for `/speckit-plan`.

### What the clarification session changed

Three questions were answered on 2026-07-31, and each pulled more with it than the question asked:

| Answer | What it added |
|---|---|
| Price covers the whole Meal | FR-021 amended; FR-031 added so calories describe the same unit as the price; noted that an Order in E4 is for a whole Meal |
| The AI Assistant sees the photo | FR-029 (disclosure before use, refusable), FR-030 (estimate during the conversation so confirming stays inside the 3-second budget), SC-014, two edge cases |
| A draft lives until the Cook deletes it | FR-032, FR-033, FR-034; a new "Draft Meal" entity; SC-012 and SC-013; US1 scenarios 3, 7 and 8 |

**Requirements grew from 28 to 34, success criteria from 11 to 14.** That is the cost of the
answers, not scope creep — each new requirement traces to one of the three.

### Two things introduced by the answers, flagged rather than buried

1. **A drafts surface is new.** "Until the Cook deletes it" is unenforceable by a Cook who cannot
   see their drafts, so FR-033 requires somewhere to see and delete them. Adding a surface is a
   stop-and-ask trigger under `CLAUDE.md`; it is recorded here because it follows necessarily from
   the answer given rather than from a design preference.
2. **A fourth open question was opened, not closed.** Drafts that live forever accumulate silently.
   Whether a Cook is shown that pile is a surface question, not a rule question, so it does not
   block planning — but it should not be discovered by a Cook with fourteen abandoned Meals.

### Divergence from E1, deliberate

E1's Kitchen Profile conversation stored **nothing** before confirmation, and the spec made a
feature of it. This one keeps a draft. The divergence is intentional — a Meal carries more work and
is more expensive to lose — but it means the two conversations in Kafoo now behave differently at
the same moment, and anyone reading only one will guess wrong about the other.

### Verification against the constitution

- **Principle I (trust)** — FR-015 forbids AI food photography; FR-021 forbids a charge not visible
  before confirmation; no fee exists in this feature.
- **Principle II (AI suggests, humans approve)** — FR-009 to FR-013 and the whole of User Story 2.
  An approved estimate stays an estimate, which is the part most easily lost.
- **Principle III (security by default)** — expressed in product terms in FR-022 to FR-026 and
  FR-032, and in User Story 3. The enforcement mechanism belongs in `plan.md`, deliberately not
  stated here.
- **Principle IV (conversation first, Egyptian Arabic first)** — FR-001 forbids the form outright;
  FR-007 and SC-009 make language and direction testable. A Meal has more fields than a Kitchen
  Profile, so this is where the rule is most likely to be quietly abandoned.
- **Principle VI (events)** — FR-027 and FR-028. Names are already reserved in
  `docs/product/event-model.md` and are not restated here, per the instruction not to copy event
  lists between documents.
- **Principle VII (separation of concerns)** — no framework, storage, model-provider or
  authorization mechanism named anywhere in the spec.

### Carried into planning

- The migration creating Meals must also widen who can read a Kitchen Profile, or kitchens with
  Meals on offer become silently unreachable. Written out ready in
  `specs/002-identity-kitchen-profile/data-model.md`.
- FR-030 exists because a vision call is slow. Planning must confirm the 3-second publish budget
  survives, and that estimating during the conversation does not simply move the wait somewhere
  more annoying.
