# Specification Quality Checklist: Identity and Kitchen Profile

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-29
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

## Constitution-specific checks

Kafoo's constitution adds requirements the generic checklist does not cover. Checked explicitly
because Principle VII makes a technical leak into `spec.md` a merge blocker.

- [x] **Principle VI — canonical vocabulary.** Swept mechanically for `buyer`, `vendor`, `seller`,
      `consumer`, `client`, `chef`, `merchant`, `restaurant`, `store`, `shop`, `business`,
      `product`, `dish`, `listing`, `recipe`, `purchase`, `transaction`, `ticket`, `feedback`,
      `chatbot`, `bot`, `upload`, `delete`, `decline`. Remaining matches are the template's own
      scope-guard list (which names the banned terms in order to ban them), template-mandated
      "User Story" headings, and the verbs "store"/"stores" used to mean *keeping information*,
      not the banned noun. Two uses of "the product" meaning Kafoo were rewritten to "Kafoo",
      since Principle VI reserves that word for Meals.
- [x] **Principle VII — technology-agnostic.** Swept for `database`, `table`, `row`, `RLS`,
      `migration`, `API`, `framework`, `Supabase`, `Flutter`, `Dart`, `JWT`, `endpoint`, `schema`,
      `SQL`, `backend`, `server`, `Postgres`, `widget`, `repository`, `SDK`. The single match is
      the word "frameworks" inside the template's own scope guard.
- [x] **Principle IV — conversation over form.** A Kitchen Profile carries five details, which is
      past the constitution's four-field threshold. FR-012 therefore requires a conversation that
      asks one question at a time and forbids a form; SC-006 makes it measurable. This was a
      constitutional trigger, not a stylistic preference.
- [x] **Principle IV — Arabic first.** FR-023 and FR-024 cover Egyptian Arabic as the default
      locale and right-to-left rendering; SC-004 and SC-005 make both measurable.
- [x] **Principle II — AI suggests, humans approve.** The AI Assistant is explicitly out of scope
      for this feature (see Assumptions). No requirement here has anything AI-derived reaching
      stored information.
- [x] **Principle III — ownership provable, not asserted.** User Story 3 is a P1 deliverable, and
      FR-021 plus SC-003 require the proof to be automatic and repeated on every later change,
      not performed once by hand.
- [x] **Privacy — new personal-data category.** The phone number is new personal data. FR-022
      states why it is collected and who may read it; FR-020 restricts the reader set to the
      person themselves. The retention answer is incomplete and is raised as Open Question 3
      rather than papered over.

## Notes

**Three Open Questions are recorded in the spec rather than resolved.** They are not
[NEEDS CLARIFICATION] markers because none of them blocks planning — each has a stated working
assumption the spec proceeds under — but each changes user-visible behaviour, so they belong to
the founder rather than to this document:

1. Whether a Kitchen Profile has a draft state, or becomes visible the moment it is confirmed.
2. What happens when an Egyptian carrier reassigns a phone number to a different person.
3. How long a phone number is kept, which cannot be fully answered while removing an account is
   out of scope.

Question 2 is the one with trust consequences; it should be settled during `/speckit-clarify`
before `/speckit-plan` fixes an identity model around it.

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
