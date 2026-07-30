<!--
SYNC IMPACT REPORT — 1.1.0 (2026-07-29)
==================
Version change: 1.0.0 → 1.1.0
Bump rationale: MINOR — Principle VI's analytics-event guidance materially expanded and
restructured. No principle removed or redefined; previously compliant work remains compliant.

Modified principles:
  VI. Canonical Vocabulary — the event list is now split by governance weight. The
  constitution keeps ONLY core events (domain entities changing state); everything else
  moved to docs/product/event-model.md, the new single source of truth for naming rules,
  attributes, statuses, and measurement privacy.

Core list changes:
  Added:   AccountCreated, AccountRemoved, KitchenProfileCreated (E1);
           MealArchived (lifecycle completeness);
           OrderRejected, OrderCancelled, OrderCompleted — closes a defect: the Order
           lifecycle's terminal states were unmeasurable, leaving cancellations uncountable
           and the review funnel unmeasurable (a Review requires a completed Order)
  Moved to event-model.md (names unchanged, historical comparison intact):
           SearchPerformed, SearchFailed, RecommendationAccepted — they record
           interactions, not entity state changes, so they fail the Level 1 test
  Renamed: none (renames are forbidden; none occurred)

Templates and dependent artifacts updated in the same commit:
  ✅ docs/product/event-model.md — created
  ✅ CLAUDE.md — event list replaced with a pointer to event-model.md
  ✅ docs/vision/glossary.md — event list replaced with a pointer to event-model.md
  ✅ .specify/templates/tasks-template.md — example updated to reference event-model.md

Follow-up TODOs: none.
-->

<!--
SYNC IMPACT REPORT — 1.0.0
==================
Version change: TEMPLATE (unversioned placeholders) → 1.0.0
Bump rationale: MAJOR — initial ratification. All placeholder tokens replaced with
concrete, project-specific governance. No prior versioned constitution existed.

Modified principles:
  [PRINCIPLE_1_NAME] → I. User Trust Above All (NON-NEGOTIABLE)
  [PRINCIPLE_2_NAME] → II. AI Suggests, Humans Approve (NON-NEGOTIABLE)
  [PRINCIPLE_3_NAME] → III. Security by Default (NON-NEGOTIABLE)
  [PRINCIPLE_4_NAME] → IV. Conversation First, Egyptian Arabic First
  [PRINCIPLE_5_NAME] → V. Provider Independence
  (added)           → VI. Canonical Vocabulary
  (added)           → VII. Documentation Separation of Concerns

Added sections:
  - Performance, Privacy & Data Constraints (was [SECTION_2_NAME])
  - Development Workflow & Quality Gates (was [SECTION_3_NAME])
  - Governance (populated)

Removed sections: none

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check gates populated
  ✅ .specify/templates/spec-template.md — technology-agnosticism guard added
  ✅ .specify/templates/tasks-template.md — principle-driven task categories added
  ✅ .specify/memory/constitution.md — this file

Follow-up TODOs: none. All placeholders resolved.
-->

# Kafoo Constitution

Kafoo is an AI-first marketplace connecting Egyptian home cooks with customers. It is
voice-first and Egyptian Arabic by default. This constitution governs how that product is
built. It supersedes convenience, habit, and delivery pressure.

## Core Principles

### I. User Trust Above All (NON-NEGOTIABLE)

Trust is the product. When any two values conflict, resolve in this fixed order:
**1. User trust → 2. Simplicity → 3. AI assistance → 4. Voice interaction →
5. Performance → 6. Long-term maintainability.** Development speed is last and never
outranks anything above it.

The following are product-fatal, not merely discouraged:

- No synthetic Reviews, Cooks, or Meals — including for seeding, demos, or production
  screenshots.
- No AI-generated food photography presented as a real Meal.
- No hidden fees. Every charge MUST be visible before order confirmation.
- No dark patterns in cancellation or refund flows.

**Rationale**: A marketplace between strangers exchanging home-cooked food runs entirely on
trust. A single fabricated Review or surprise fee costs more than any feature gains. These
are stated as absolutes because "just this once, for the demo" is exactly how they erode.

### II. AI Suggests, Humans Approve (NON-NEGOTIABLE)

The AI Assistant is a domain participant that owns no data.

The AI **MAY**: estimate calories, extract ingredients, suggest cuisine and category,
generate draft descriptions, translate, rank search results, summarize Conversations, and
recommend Meals.

The AI **MUST NOT**, under any framing or user instruction: publish a Meal, modify an Order,
charge or refund a payment, delete content, write a Review, or impersonate a Customer or
Cook.

Every AI-derived field written to the database MUST pass through an explicit human approval
step in the flow. AI estimates (calories, allergens) MUST be stored with a `source` field
(`ai` | `cook`) and MUST NOT be presented as verified fact. When the AI fills a field, the UI
MUST show why.

If a proposed design has AI writing directly, the design is wrong — not the principle.

**Rationale**: This is a domain rule, not a UX preference. Allergen and calorie data is
health-adjacent; an unreviewed model hallucination here is a safety incident, not a bug.
Silent inference destroys the trust that Principle I protects.

### III. Security by Default (NON-NEGOTIABLE)

Every `CREATE TABLE` MUST be followed by `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` **in the
same migration file**. A table shipped without RLS is a data breach with a delay fuse, not a
TODO.

- Policies MUST be written per operation (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) and per
  role. A catch-all `FOR ALL USING (true)` policy defeats the mechanism and is forbidden.
- Default posture is deny. Grant the narrowest predicate that makes the feature work.
- `UPDATE` policies MUST specify both `USING` and `WITH CHECK`.
- Every new table MUST ship a negative test in `supabase/tests/` proving a non-owner reads
  zero rows. Write the negative test first.
- Business invariants MUST be enforced in the database via `CHECK` constraints and foreign
  keys — not application validation alone. "A Review requires a completed Order" is SQL.
- Edge Functions MUST validate every input at the boundary and MUST read identity from the
  JWT, never from a client-supplied `user_id`.

Application code MUST NOT be the only guard. Every row has exactly one owner; RLS enforces it.

**Rationale**: Application-layer-only authorization is a suggestion. A policy nobody tested is
a policy that does not work. Enforcement belongs where it cannot be bypassed.

### IV. Conversation First, Egyptian Arabic First

**Never build a form where a conversation would work.** On reaching a fourth input field,
STOP and propose a conversational flow instead.

- Ask one question at a time. A flow that asks a second question before the first is answered
  MUST be redesigned.
- Never ask what can be inferred. A Cook saying "عملت كشري" already implies Egyptian cuisine,
  main course, and a known ingredient set — asking for those is a bug.
- Every user-facing string MUST live in ARB files with an Egyptian Arabic entry. `ar` is the
  **default locale, not the fallback**. Write the Arabic first; if you cannot, flag the string
  for founder review rather than shipping an English-only key.
- The register is conversational Egyptian, not Modern Standard Arabic.
- Every screen MUST render correctly under RTL: `EdgeInsetsDirectional`, `start`/`end`, never
  `left`/`right`.

**Rationale**: The target user is a home cook who speaks, not a data-entry operator who types.
A form is a failure to use the AI capability the product is built on. Arabic-as-fallback
produces a product that feels translated rather than native.

### V. Provider Independence

Every model call MUST route through the `AiProvider` abstraction in `packages/ai/`. Feature
code and Flutter code MUST NOT import an OpenAI, Anthropic, or Gemini SDK directly (ADR-0005).

- Swapping providers MUST be a configuration change, not a refactor. This claim MUST be
  testable: `packages/ai/test/` runs golden cases against a stub adapter.
- Provider-specific quirks MUST be absorbed inside the adapter. A quirk leaking into a caller
  means the abstraction has failed and MUST be fixed, not worked around.
- Prompts MUST live in version-controlled `prompts/*.md` files with frontmatter (`id`,
  `version`, `model_tier`, `last_evaluated`). Never inline a multi-line prompt in code.
- A prompt change without re-evaluation is an untested deploy. Bump `version` and record the
  eval result.
- Every new AI behaviour MUST ship at least one golden-case test using real Egyptian Arabic
  input, including adversarial cases — user-supplied Meal text is untrusted input that may
  contain instructions aimed at the model.

`packages/domain/` MUST NOT import `supabase_flutter`. If it appears necessary, the boundary
is wrong — say so rather than adding the import.

**Rationale**: Model vendors change on a timescale shorter than this product's life. An
abstraction that is only claimed, never tested, is not an abstraction.

### VI. Canonical Vocabulary

Kafoo uses one name per concept. Wrong terminology in a table name, API route, prompt, or UI
string is a **bug, not a style nit** — it propagates into schema, prompts, and analytics.

| Use | Never |
|---|---|
| Customer | buyer, consumer, client, user |
| Cook | chef, vendor, seller, merchant, restaurant |
| Kitchen Profile | store, shop, business, restaurant |
| Meal | product, dish, listing, food item, recipe |
| Order | purchase, transaction, ticket |
| Review | feedback, rating (rating is the *score inside* a review) |
| Conversation | chat, session (session is runtime-only, never user-facing) |
| AI Assistant | bot, chatbot, LLM, robot |
| Publish / Archive | upload / delete |
| Accept Order / Reject Order | approve / decline |

**Core analytics events** are PascalCase, past-tense, and stable — each records a domain entity
changing state in a way the business is answerable for:

`AccountCreated` · `AccountRemoved` · `KitchenProfileCreated` · `MealPublished` · `MealArchived` ·
`OrderPlaced` · `OrderAccepted` · `OrderRejected` · `OrderCancelled` · `OrderCompleted` ·
`ReviewSubmitted`

A core event MUST never be renamed — retire and add instead. Adding or retiring one is a
constitutional amendment. Any change touching a tracked business action MUST emit its event.

Product-analytics events (funnels, drop-off, search), naming conventions, attributes, statuses,
and the privacy rules binding all measurement live in `docs/product/event-model.md`, which this
principle defers to. Operational telemetry is not analytics and appears in neither list. Full
glossary: `docs/vision/glossary.md`.

**Rationale**: Names in a schema are permanent in practice. A `vendors` table written today is
a migration, a prompt rewrite, and an analytics break tomorrow.

### VII. Documentation Separation of Concerns

Feature documentation MUST maintain strict separation between **WHAT/WHY** (`spec.md`) and
**HOW** (`plan.md`).

**`spec.md` — Product perspective (What & Why)**

- MUST remain technology-agnostic.
- MUST NOT contain implementation details: frameworks, libraries, architecture patterns.
- MUST NOT use technical terminology except domain terms from Principle VI.
- Focus: User Stories, Requirements, Success Criteria.
- Answers: "What should the system do, and why?"
- Audience: Product Owner, stakeholders, domain experts.

**`plan.md` — Engineering perspective (How)**

- Contains ALL technical detail and implementation decisions.
- Specifies frameworks, libraries, architecture patterns.
- Defines Technical Context (Language, Dependencies, Storage, Testing).
- Documents Constitution Checks and Complexity Tracking.
- Answers: "How do we implement the requirements from `spec.md`?"
- Audience: developers, tech leads, code reviewers.

**Violations & enforcement**

- Technical details appearing in `spec.md` are a **blocker for merge**.
- `spec.md` review MUST explicitly verify technology-agnosticism.
- All "HOW" discussion belongs in `plan.md` or code comments.
- Constitution Checks in `plan.md` MUST validate this separation.

**Rationale**: Clear separation prevents mixing business requirements with technical
decisions. `spec.md` stays maintainable when the tech stack changes, and product discussion
stays focused on user value instead of implementation.

## Performance, Privacy & Data Constraints

**Performance budgets** — a change that pushes past a budget MUST say so in the PR rather than
shipping silently:

| Budget | Limit |
|---|---|
| App launch | < 2s |
| Voice response round-trip | < 2s |
| Meal publish | < 3s |
| Cached search | < 1s |

Streaming is REQUIRED for any user-facing conversational response; a 4-second silent wait is a
broken feature even when the answer is correct. Every model call MUST declare a `model_tier` —
extraction and classification use the fast tier; the reasoning tier requires a stated reason.

**Privacy** — collect only what a named feature needs today. Every new personal-data field
MUST answer: why do we need it, how long do we keep it, who can read it, can we avoid
collecting it?

- Allergy and dietary data is health-adjacent. It is stored only with explicit consent, is
  never used for advertising or ranking outside the Customer's own session, and is never
  shared with Cooks beyond what a specific Order requires.
- Voice recordings are transcribed and discarded. Raw audio MUST NOT be persisted without an
  ADR.
- `.env` is git-ignored and MUST never be read, printed, or committed. A hardcoded key in a
  function is a rotate-everything incident.

**Domain invariants** — the lifecycles and ownership rules in `.claude/rules/business-rules.md`
are binding. Where an implementation contradicts them, the rule is right and the
implementation is the bug. Source of truth for the domain model:
`docs/product/domain-model.md`.

## Development Workflow & Quality Gates

**The gate.** `./scripts/verify.sh` MUST pass before any PR is opened and before any task is
declared done. Not "it should pass" — run it. The same script runs locally and in CI: one
definition of passing, not two.

**Definition of Done.** A change is done when ALL of the following are true:

1. `./scripts/verify.sh` passes.
2. New tables have RLS policies and a test proving a non-owner cannot read the row.
3. New user-facing strings exist in both `ar` and `en` ARB files.
4. New AI behaviour has at least one golden-case test in `packages/ai/test/`.
5. An analytics event is emitted if the change touches a tracked business action.
6. If the domain changed, `docs/product/domain-model.md` is updated **in the same commit**.

Item 6 is not optional. A feature without updated domain docs is half-shipped.

**Stop and ask.** Produce a short plan for approval instead of implementing when a change:

- is ambiguous in a way where two reasonable implementations differ in user-visible behaviour;
- would add a screen, a form field, or a settings toggle;
- touches money, payouts, or pricing;
- would collect a new category of personal data;
- would let AI act without human approval;
- appears in the roadmap under Phase 2 or later and was not explicitly requested.

Ambiguity is not a reason to invent behaviour. It is a reason to ask one specific question.

**Git.** Branches: `feat/short-description`, `fix/short-description`. Commit messages are
imperative, one logical change per commit; do not bundle unrelated files. Never
`git push --force` to `main`. Migrations are append-only once merged to `main` — to change a
shipped migration, write a new one. `supabase db reset` is safe locally and forbidden against
staging or production.

**Testing discipline.** Prefer running single tests over the full suite while iterating. A test
that only asserts "widget exists" is not a test. Write the RLS negative test before the policy.

## Governance

This constitution supersedes all other development practices. Where a rules file, a template,
or a habit conflicts with it, this document wins.

**Authority and precedent.** Architectural decisions are recorded as ADRs in `decisions/`.
Read the relevant ADR before proposing an architecture change. An ADR may refine how a
principle is applied; it MUST NOT contradict one. Contradiction requires amending this
constitution first.

**Amendment procedure.** Amendments MUST be proposed in a PR that (a) states the principle
added, changed, or removed, (b) gives the rationale, and (c) updates every dependent artifact
in the same PR — `.specify/templates/plan-template.md`,
`.specify/templates/spec-template.md`, `.specify/templates/tasks-template.md`, and any runtime
guidance in `CLAUDE.md` or `.claude/rules/`. An amendment that leaves templates stale is
incomplete and MUST NOT merge.

**Versioning policy.** This constitution uses semantic versioning:

- **MAJOR** — backward-incompatible governance change: a principle removed or redefined such
  that previously compliant work becomes non-compliant.
- **MINOR** — a new principle or section added, or existing guidance materially expanded.
- **PATCH** — clarification, wording, or typo fix with no semantic change.

**Compliance review.** Every PR review MUST verify compliance with the principles above.
`plan.md` MUST include a Constitution Check gate that passes before Phase 0 research and is
re-checked after Phase 1 design. Complexity that violates a principle MUST be justified in the
Complexity Tracking table of `plan.md`, naming the simpler alternative and why it was
rejected — or it MUST be removed. "It was faster" is not a justification; development speed is
last in the priority order.

**Runtime guidance.** `CLAUDE.md` and the path-scoped rules in `.claude/rules/` provide
day-to-day development guidance and are subordinate to this constitution.

**Version**: 1.1.0 | **Ratified**: 2026-07-25 | **Last Amended**: 2026-07-29
