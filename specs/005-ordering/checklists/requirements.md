# Specification Quality Checklist: Ordering

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-10
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [ ] No [NEEDS CLARIFICATION] markers remain — **three remain by design**: FR-018 (who marks an
      Order completed), FR-019 (collection or delivery), FR-020 (does an Order name a time). Each
      changes what gets built, each hits a stop-and-ask trigger in `CLAUDE.md` — a new category of
      personal data, and screens that do not yet exist — and none has a defensible default. They
      are the founder's to answer before `/speckit-plan`.
- [x] Requirements are testable and unambiguous — apart from the three above
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [ ] All functional requirements have clear acceptance criteria — FR-018, FR-019 and FR-020 have
      none until they are answered, and FR-019 in particular has no acceptance scenario because
      whether an address exists is undecided
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Kafoo-specific checks

- [x] Canonical vocabulary only — Customer, Cook, Kitchen Profile, Meal, Order, AI Assistant. No
      buyer, vendor, product, listing, chatbot, checkout, cart, or transaction
- [x] Principle I (trust) — no hidden fee is possible because no fee exists (FR-007); cancellation
      is held to the same ease as ordering (FR-022); no synthetic content of any kind
- [x] Principle II (AI suggests, humans approve) — FR-033 and FR-034 forbid the AI Assistant from
      touching an Order's state, and SC-012 counts occurrences at zero
- [x] Principle III (security by default) — SC-003, SC-004, SC-005, SC-009 and SC-015 are each
      stated as zero and each names an authorization boundary a negative test can prove
- [x] Principle IV (conversation first, Arabic first) — FR-010 requires a conversation rather than
      a form at the point where the fourth input would appear; FR-035 and SC-014 hold both surfaces
      to Egyptian Arabic
- [x] Principle VI (canonical events) — FR-036 uses the five Order event names already reserved in
      `docs/product/event-model.md` and renames none of them
- [x] Privacy — FR-028, FR-029 and SC-015 bound what crosses between Customer and Cook; FR-037
      keeps the Customer's words out of analytics, consistent with E3

## Notes

- The three outstanding clarifications block `/speckit-plan`, not this document. Everything else in
  the spec is stable and does not change whichever way they are answered, with one exception:
  answering FR-019 as "the Cook delivers" adds a personal-data field (a Customer address) and
  therefore adds requirements about why it is collected, how long it is kept and who can read it.
- FR-018 is the highest-consequence of the three despite looking the smallest. It decides, one epic
  early, whether a Cook can avoid being reviewed by never marking an Order complete.
