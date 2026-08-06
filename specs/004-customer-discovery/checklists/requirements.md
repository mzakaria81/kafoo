# Specification Quality Checklist: Customer Discovery

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-06
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

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`

**On "No [NEEDS CLARIFICATION] markers remain":** three genuine open decisions exist and are
recorded in an **Open questions** section rather than as inline markers. They are the founder's to
answer, not an implementer's, and two of them (what a shared link reveals; whether a Customer may
search for a Cook by name) touch personal data, which Kafoo's rules route to the founder by
definition. The specification is complete and buildable without them: **Open question 1 gates only
making anything shareable**, question 2 is excluded from scope by an explicit assumption, and
question 3 is bounded by FR-024, which forbids the dangerous answer regardless of how the question
is finally settled.

**On "Requirements are testable":** FR-021 (a Meal is withheld when an exclusion cannot be
established) and FR-005 (discovery reflects the current moment) are the two most likely to be
implemented in a way that passes an optimistic test. Both need a negative test that has been seen to
fail before the behaviour exists, per the constitution and the 2026-08-06 finding that five separate
checks in this repository were incapable of failing.

**On measurability:** SC-002 and SC-003 carry percentages that are already evidenced rather than
aspirational — `docs/ops/spike-discovery-embeddings.md` measured cross-language retrieval at 4 of 4
at rank 1, and top-five relevance at 14 of 19. SC-003 is set at 80% deliberately *below* what the
spike achieved on a small corpus, because the spike also records that its corpus was written by one
author and is not evidence about four hundred real Meals.
