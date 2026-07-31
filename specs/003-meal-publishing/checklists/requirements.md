# Specification Quality Checklist: Meal Publishing

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-31
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [ ] No [NEEDS CLARIFICATION] markers remain
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

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`.

### Outstanding

**Three [NEEDS CLARIFICATION] markers remain**, all in "Open Questions". They were kept rather than
defaulted because each fails the "a reasonable default exists" test:

1. **What a price covers** — money is an explicit stop-and-ask trigger in `CLAUDE.md`. Guessing
   between per-portion and per-dish would silently fix what a Customer believes they are buying, and
   would propagate into Orders in E4.
2. **Whether the AI Assistant sees the photo** — sends a Cook's photograph to a model provider.
   Privacy and recurring cost, not a technical detail.
3. **Draft lifetime** — E1's conversation deliberately stored nothing before confirmation, but a
   Meal has a `draft` state, so the two precedents conflict. Either answer is defensible; picking
   one silently would contradict a rule set in the previous feature.

### Verification against the constitution

- **Principle I (trust)** — FR-015 forbids AI food photography; FR-021 forbids a charge not visible
  before confirmation; the Assumptions record that no fee exists in this feature.
- **Principle II (AI suggests, humans approve)** — FR-009, FR-010, FR-011, FR-012, FR-013, and the
  whole of User Story 2. An approved estimate stays an estimate, which is the part most easily lost.
- **Principle III (security by default)** — expressed in product terms in FR-022 to FR-026 and User
  Story 3. The enforcement mechanism belongs in `plan.md`, deliberately not stated here.
- **Principle IV (conversation first, Egyptian Arabic first)** — FR-001 forbids the form outright;
  FR-007 and SC-009 make the language and direction testable. A Meal has more fields than a Kitchen
  Profile, so this is the feature where the rule is most likely to be quietly abandoned.
- **Principle VI (events)** — FR-027 and FR-028. Names are already reserved in
  `docs/product/event-model.md` and are not restated here, per the instruction not to copy event
  lists between documents.
- **Principle VII (separation of concerns)** — no framework, storage, model-provider or
  authorization mechanism named anywhere in the spec.
