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

**On "No [NEEDS CLARIFICATION] markers remain":** three open decisions were raised and **all three
were answered by the founder on 2026-08-06**. They are recorded in Clarifications and carried into
requirements: FR-027a to FR-027c (what a shared reference reveals, closing ADR-0008's second open
dependency), the Deliberately out of scope section (no search for a Cook by name), and FR-024a to
FR-024c (an empty area names the areas that are not empty and lets the Customer choose).

Two of those answers were narrowed against what Kafoo actually holds rather than accepted as
proposed, and the narrowing is the substance:

- A proposal to show a Cook's **first name** and a **rating** in a shared reference was declined.
  Kafoo stores no personal name for a Cook — only a Kitchen Profile display name the Cook chose —
  so showing one would create a new category of personal data, and a rating shown before Reviews
  exist is a fabricated measurement rather than an empty field. FR-027b and FR-027c exist to make
  both refusals testable rather than remembered.
- A proposal to offer nearby areas **with distances** ("Mohandessin, 2 km") was narrowed to naming
  the areas without distances. Kafoo holds no coordinates for any area and, by the same session's
  decision, no location for any Customer. FR-024b forbids the distance; FR-024c forbids implying
  that a kitchen in another area will deliver, because delivery terms are words rather than a
  radius.

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
