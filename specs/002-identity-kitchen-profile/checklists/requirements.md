# Specification Quality Checklist: Identity and Kitchen Profile

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-07-29
**Last re-validated**: 2026-07-29, after `/speckit-clarify` (5 questions answered)
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
- [x] **Privacy — new personal-data categories.** Two now, not one. The phone number: FR-022 states
      why it is collected, FR-020 restricts the reader set to the person themselves, and FR-032
      makes the retention answer real by giving an account a way to stop existing. Behavioural
      funnel data: FR-036 states the single question it exists to answer, FR-037 and FR-038 bound
      it to *which step*, never content or audio, and FR-040 fixes its reader set, its prohibited
      uses and its retention. FR-039 makes removal reach it.
- [x] **Principle I — no dark patterns.** Two flows in this spec are where dark patterns usually
      appear, and both are guarded explicitly rather than by good intentions: FR-029 stops the
      email invitation from becoming a nag, and FR-034 forbids making departure harder than
      arrival.
- [x] **Store requirement — App Store Review Guideline 5.1.1.** An app supporting account creation
      must offer in-app account removal, and deactivation does not satisfy it. FR-032 and FR-033
      cover it. Relevant early rather than late: ADR-0006 routes iOS through TestFlight with
      external testers, which means Beta App Review.

## Notes

### After `/speckit-clarify` — 2026-07-29

Five questions asked and answered. Three of the original Open Questions are now settled; two new
items were opened by the answers themselves.

**Settled:** the Kitchen Profile draft question (no state; discoverability derived from published
Meals), phone-number retention (removal now exists, so the answer is no longer circular), and the
identity-anchoring half of the recycled-number problem (a person is not their phone number).

**Still open, and each with a stated trigger rather than an open end:**

1. **The dormancy policy for recycled numbers.** Modelling settled; policy deferred. Stops being
   cheap when Reviews ship and identity starts carrying reputation.
2. **A person-assisted way back for a Cook who loses their number and never attached an email.**
   The common case, not the rare one, since most Cooks will decline the invitation. Cannot be
   improvised when first needed — it is by construction a way to move an identity to a new phone.
3. **The canonical event names, and the constitutional amendment carrying them.** Principle VI
   names every analytics event and calls the list stable; `CLAUDE.md` repeats it. A funnel means
   amending both in the same PR, MINOR bump. Must land before implementation, or this feature
   emits events no governing document knows about.

Items 1 and 2 both expire at the same moment — when Reviews ship. Item 3 is the only one that
blocks implementation.

**Two scope changes came out of clarification**, both enlarging the feature deliberately:
account removal (User Story 7, FR-032 to FR-035) and the measurement funnel (FR-036 to FR-040).
Neither was in the original spec; both were accepted with their costs named.

- Items marked incomplete require spec updates before `/speckit-clarify` or `/speckit-plan`
