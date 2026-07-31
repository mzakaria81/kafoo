# Feature Specification: Meal Publishing

**Feature Branch**: `003-meal-publishing`

**Created**: 2026-07-31

**Status**: Draft

**Input**: User description: "E2 — voice-first, AI-assisted Meal publishing. A Cook publishes a Meal by talking rather than filling in a form, and the AI Assistant helps by estimating rather than deciding."

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
>
> Also binding on this document: AI may suggest but never writes without human approval
> (Principle II); prefer a conversation over a form — a fourth input field means stop and
> propose a conversational flow (Principle IV).

## Why this feature exists

E1 made a person known to Kafoo and gave them a kitchen. Nothing in Kafoo is yet on offer.

This feature is where Kafoo becomes a marketplace, and where its thesis is first tested. Two things
happen here for the first time, and both are why the constitution has the shape it does.

**A Cook offers something.** Until now a Kitchen Profile describes a person who cooks. A Meal is an
*offer to cook a specific dish* — the first thing in Kafoo another person could act on. It is also
what makes a kitchen findable: E1 deliberately shipped with no way to discover a Kitchen Profile,
because discoverability follows from having food on offer, and there was none.

**The AI Assistant becomes real.** Every AI rule in the constitution has been theoretical, because
no model has ever been called. Publishing a Meal is where the AI Assistant earns its place — a Cook
says what they cooked, and Kafoo does the tedious part: pulling out the ingredients, estimating
calories, proposing allergens, suggesting a cuisine and a category, drafting a description in the
Cook's own register. It is also where the AI Assistant is most dangerous, because allergens and
calories are health-adjacent, and a confident wrong answer about peanuts is not a bug.

So this is the first real test of "AI suggests, humans approve" — not as a slogan, but as something
a Cook experiences one field at a time.

The hardest part is not the model. It is refusing to build the form. Publishing a Meal has, on the
face of it, eight or nine fields. The obvious design is a scrolling page of inputs; it would be
faster to build and worse at everything Kafoo claims to care about. The person this is for is
standing in a kitchen with flour on their hands.

## Clarifications

None yet. Three questions are open under "Open Questions" and MUST be answered before
`/speckit-plan`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Cook publishes a Meal by talking (Priority: P1)

A Cook has made something they want to offer. They open Kafoo, say what they cooked, and answer a
handful of short questions one at a time — by speaking, or by typing if speaking is unavailable.
Kafoo shows back what it understood and what it worked out on its own: the ingredients it heard,
roughly how many calories a portion has, which allergens it believes are present, a cuisine, a
category, and a description in the Cook's own words rather than marketing language.

Nothing is on offer until the Cook looks at all of it and says yes.

**Why this priority**: This is the feature. Everything else here is a variation on it, and without
it Kafoo has kitchens with nothing in them.

**Independent Test**: Complete the whole flow by voice alone, confirm, and find the Meal on offer
exactly as confirmed. Separately, abandon halfway and confirm nothing is on offer.

**Acceptance Scenarios**:

1. **Given** a Cook who owns a Kitchen Profile, **When** they describe a dish by speaking and answer
   each question in turn, **Then** they reach a summary showing every detail, including everything
   the AI Assistant worked out, before anything is offered to anyone.
2. **Given** a Cook at the summary, **When** they confirm, **Then** the Meal is on offer and their
   kitchen becomes findable.
3. **Given** a Cook part-way through, **When** they close Kafoo without confirming, **Then** no Meal
   is on offer to anyone.
4. **Given** a Cook answering by voice, **When** a spoken answer is understood wrongly, **Then** they
   see what was understood and can correct it before it is kept.
5. **Given** a Cook who does not own a Kitchen Profile, **When** they try to offer a Meal, **Then**
   they are taken to create a kitchen first, because a Meal cannot exist without one.
6. **Given** any point in the flow, **When** the Cook is on any screen, **Then** at most one
   unanswered question is on that screen.

---

### User Story 2 - The AI Assistant estimates, and the Cook decides (Priority: P1)

For every value the AI Assistant produced, the Cook sees that it came from the AI Assistant and what
it was based on. Calories and allergens are shown as estimates, never as facts. Each can be
corrected in a single action, and correcting one records it as the Cook's own rather than the AI
Assistant's.

If the Cook changes nothing, the estimates are still recorded as estimates. Approval is not
verification, and the difference stays visible to whoever reads the Meal later.

**Why this priority**: Constitution Principle II, made testable. Allergen and calorie data is
health-adjacent; presenting a model's guess as established fact is a safety failure, not a polish
issue. This ships with the flow rather than after it.

**Independent Test**: Publish a Meal correcting nothing, and confirm every AI-derived value is
labelled an estimate. Then correct one and confirm it is no longer attributed to the AI Assistant.

**Acceptance Scenarios**:

1. **Given** a summary containing AI-derived values, **When** the Cook looks at any of them, **Then**
   it is visibly an estimate from the AI Assistant, with what it was based on.
2. **Given** an AI-estimated calorie figure, **When** the Cook replaces it with their own, **Then**
   the value is recorded as the Cook's and is no longer presented as an estimate.
3. **Given** a Meal on offer with AI-estimated allergens, **When** anyone reads that Meal, **Then**
   the allergens are presented as an estimate and never as a verified list.
4. **Given** any AI-derived value, **When** the Cook wants to change it, **Then** it takes one
   action.
5. **Given** the AI Assistant is unreachable, **When** a Cook publishes a Meal, **Then** they can
   still publish it, with the fields the AI Assistant would have filled left to the Cook.
6. **Given** a Cook who has approved nothing, **When** they abandon the flow, **Then** no AI-derived
   value has been kept.

---

### User Story 3 - Only the owning Cook can change a Meal (Priority: P1)

Every Meal belongs to exactly one Cook, permanently. Another Cook cannot change it, take it over, or
see it before it is on offer. A Meal not on offer is invisible to everyone except the Cook who owns
it.

**Why this priority**: E1 proved this for Kitchen Profiles and the proof runs on every commit. Meals
are the second thing Kafoo stores and the first another person acts on. The proof must be extended
before there is anything worth taking, not after.

**Independent Test**: Signed in as one Cook, attempt to read and change another Cook's Meal by every
route. Every attempt returns nothing and changes nothing — automatically, on every commit.

**Acceptance Scenarios**:

1. **Given** a Meal not on offer, **When** anyone other than its Cook looks for it, **Then** they
   find nothing — not an error, which would confirm it exists.
2. **Given** a Cook who owns a Meal, **When** they attempt to make another person its owner, **Then**
   the attempt fails.
3. **Given** any signed-in person, **When** they attempt to change a Meal they do not own, **Then**
   nothing changes.
4. **Given** a Cook, **When** they offer a Meal, **Then** it is attributed to them and cannot later
   be attributed to anyone else.

---

### User Story 4 - A Cook takes a Meal off the menu, and puts it back (Priority: P2)

A Cook runs out of an ingredient, or is not cooking today. They mark the Meal unavailable. It stays
theirs, keeps everything about it, and stops being on offer. When they can cook it again, they put
it back with one action.

**Why this priority**: The most common thing a Cook does after publishing, and the difference
between a menu and a list. Without it, the only way to stop offering something is to retire it
permanently, which loses the work.

**Independent Test**: Take a Meal off the menu, confirm nobody can find it, put it back, confirm it
is findable again and unchanged.

**Acceptance Scenarios**:

1. **Given** a Meal on offer, **When** the Cook marks it unavailable, **Then** it stops being
   findable and nothing about it is lost.
2. **Given** an unavailable Meal, **When** the Cook makes it available again, **Then** it is on offer
   again exactly as before.
3. **Given** a Cook whose only Meal is unavailable, **When** anyone looks for their kitchen, **Then**
   the kitchen is not findable, because a kitchen is findable through food actually on offer.

---

### User Story 5 - A Cook retires a Meal for good (Priority: P2)

A Cook stops offering a dish permanently. It leaves the menu and does not come back. It stays
readable, so a record of what was once offered survives.

**Why this priority**: Cheapest to define now. After Orders exist, a retired Meal has to stay
readable for people who ordered it, and building it then means reconciling records rather than
setting a rule.

**Independent Test**: Retire a Meal, confirm it cannot be offered again by any route, and confirm it
is still readable to its Cook.

**Acceptance Scenarios**:

1. **Given** a Meal on offer, **When** the Cook retires it, **Then** it stops being findable and
   cannot be put back on offer.
2. **Given** a retired Meal, **When** the Cook attempts to make it available again, **Then** the
   attempt fails.
3. **Given** a retired Meal, **When** its Cook looks at their past Meals, **Then** it is still
   readable.

---

### User Story 6 - A Customer can see what a Cook is offering (Priority: P2)

Someone who is not the Cook can see a Meal on offer: what it is, what is in it, what it costs, and
what the AI Assistant estimated, clearly marked as estimates. Through it they can reach the kitchen
it belongs to.

**Why this priority**: This is what finally makes E1's Kitchen Profile reachable, and the first
thing in Kafoo a Customer can act on. P2 rather than P1 because nothing can be ordered yet — the
value is the rule and the proof, not a transaction.

**Independent Test**: As a person who is not the Cook, confirm a Meal on offer is readable with its
estimates marked, that its kitchen is reachable from it, and that a Meal not on offer is not
readable at all.

**Acceptance Scenarios**:

1. **Given** a Meal on offer, **When** any person reads it, **Then** they see the dish, its
   ingredients, its price and its estimates, with every estimate marked as one.
2. **Given** a Meal on offer, **When** a person reads it, **Then** they can reach the Kitchen Profile
   of the Cook offering it.
3. **Given** a Cook with at least one Meal on offer, **When** anyone looks at their kitchen, **Then**
   it is readable — which was not true before this feature.
4. **Given** a Meal on offer, **When** any person reads it, **Then** they cannot reach the Cook's
   phone number by any route.

---

### User Story 7 - A Cook corrects a Meal already on offer (Priority: P3)

A Cook fixes a typo, changes a price, or improves a description on something already being offered.
The change takes effect immediately and nothing else about the Meal moves.

**Why this priority**: Real and expected, but a Cook can always take a Meal off the menu and offer a
corrected one, so it is a convenience rather than a gap.

**Independent Test**: Change each part of a Meal in turn; each change takes effect and nothing else
changes.

**Acceptance Scenarios**:

1. **Given** a Meal on offer, **When** the Cook changes one detail, **Then** only that detail changes
   and the Meal stays on offer.
2. **Given** a Cook changing a price, **When** they confirm, **Then** the new price is what anyone
   reading the Meal sees, with no other charge added to it.
3. **Given** a Cook editing, **When** the change has not been confirmed, **Then** anyone reading the
   Meal still sees the previous version.

---

### Edge Cases

- **The AI Assistant is unreachable, slow, or refuses.** The Cook must still be able to publish. The
  AI Assistant is an assistant, not a dependency, and a model outage must never stop a Cook offering
  food.
- **The AI Assistant returns something absurd** — a calorie figure ten times any plausible portion,
  an allergen list naming everything, a description in the wrong language. Kafoo must not present it
  for approval as though it were reasonable.
- **The AI Assistant misses an allergen that is present.** The failure that matters most. Approval
  by a Cook who was not paying attention must not turn a silent omission into an apparent guarantee
  — which is why an approved estimate is still recorded as an estimate.
- **A Cook describes something that is not food**, or answers a question with a question. Kafoo asks
  again rather than storing nonsense.
- **A Cook publishes the same dish twice.** Allowed. Two Meals may be genuinely similar and Kafoo is
  not the judge of that. Nothing deduplicates them silently.
- **A photo fails to arrive** part-way through. The Cook carries on and adds one later rather than
  losing the conversation, exactly as when creating a Kitchen Profile.
- **A Cook offers a Meal, then removes their account.** Everything they offered goes with them.
- **The same Cook edits one Meal on two devices.** The later confirmed change wins, and neither
  device shows a version that was silently discarded.
- **A Cook marks unavailable the only Meal making their kitchen findable.** The kitchen stops being
  findable. Correct, and surprising enough that the Cook must be told rather than left to discover
  it.

## Requirements *(mandatory)*

### Functional Requirements

**The conversation**

- **FR-001**: A Cook MUST be able to offer a Meal through a conversation that asks one question at a
  time. Kafoo MUST NOT present the details of a Meal as a form to be filled in.
- **FR-002**: A Cook MUST be able to answer by speaking, and MUST be able to answer by typing when
  speaking is unavailable, with a plain explanation of why.
- **FR-003**: Every spoken answer MUST be shown back to the Cook before it is kept.
- **FR-004**: Nothing about a Meal MUST be offered to anyone until the Cook has seen a summary of
  every detail and confirmed it.
- **FR-005**: Every detail in the summary MUST be correctable in a single action.
- **FR-006**: A Cook MUST be able to abandon the conversation at any point and MUST NOT have
  anything on offer as a result.
- **FR-007**: The conversation MUST be in Egyptian Arabic by default, in the register a person
  actually speaks, and MUST be usable end to end without any other language.

**The AI Assistant**

- **FR-008**: The AI Assistant MAY extract ingredients, estimate calories, estimate allergens,
  suggest a cuisine, suggest a category, and draft a description.
- **FR-009**: The AI Assistant MUST NOT put a Meal on offer, change one already on offer, or retire
  one, under any framing or instruction.
- **FR-010**: Every AI-derived value MUST pass an explicit approval by the Cook before it is kept.
- **FR-011**: Every AI-derived value MUST record whether it came from the AI Assistant or from the
  Cook, and correcting a value MUST record it as the Cook's.
- **FR-012**: Calories and allergens MUST be presented as estimates wherever they appear, to the
  Cook and to anyone else reading the Meal. They MUST NOT be presented as verified.
- **FR-013**: When the AI Assistant fills a value, Kafoo MUST show what it was based on.
- **FR-014**: A Cook MUST be able to complete and publish a Meal when the AI Assistant is
  unavailable.
- **FR-015**: Kafoo MUST NOT present an AI-generated image as a photograph of a Meal.

**The Meal**

- **FR-016**: A Meal MUST belong to exactly one Cook and MUST NOT be transferable.
- **FR-017**: A Meal MUST NOT exist without a Kitchen Profile to belong to.
- **FR-018**: A Meal MUST move only along: draft → on offer; on offer ⇄ unavailable; and from any of
  those to retired. Retired MUST be final.
- **FR-019**: A Meal MUST NOT be treated as inventory. Offering it does not consume it and it has no
  count.
- **FR-020**: A retired Meal MUST remain readable to its Cook.
- **FR-021**: A Meal's price MUST be visible to anyone who can read the Meal and MUST be the whole of
  what the Meal costs. No charge may be added later that was not visible.

**Who can see and change what**

- **FR-022**: Only the Cook who owns a Meal MUST be able to change it, take it off the menu, or
  retire it.
- **FR-023**: A Meal not on offer MUST NOT be readable by anyone except its Cook, and an attempt to
  read it MUST return nothing rather than an error.
- **FR-024**: A Meal on offer MUST be readable by anyone, whether or not they are signed in.
- **FR-025**: A Kitchen Profile MUST become readable to anyone once its Cook has at least one Meal on
  offer, and MUST stop being findable when the Cook has none.
- **FR-026**: A Cook's phone number MUST NOT be reachable through a Meal by any route.

**Measurement**

- **FR-027**: Kafoo MUST record when a Meal is begun, published, changed and retired, and MUST record
  each step of the publishing conversation as it completes.
- **FR-028**: Nothing recorded about the conversation MUST include what a Cook said or typed — which
  step, never the words.

### Key Entities

- **Meal**: An offer to cook a specific dish. Belongs permanently to one Cook. Carries what it is,
  what is in it, what it costs, what kind of food it is, an estimate of its calories and allergens,
  and where each estimate came from. Not a recipe, not inventory.
- **Cook**: An existing person who owns a Kitchen Profile. Unchanged here, except that they now have
  something to offer.
- **Kitchen Profile**: Unchanged, except that it becomes findable through the Meals its Cook offers.
- **Conversation**: The publishing flow itself — the same family as the Kitchen Profile conversation
  from E1, not a second, separate idea.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Cook who has never published before puts a first Meal on offer in under 5 minutes,
  using voice only.
- **SC-002**: No screen in the publishing conversation shows more than one unanswered question.
- **SC-003**: 100% of AI-derived values visible to any person are labelled as estimates from the AI
  Assistant.
- **SC-004**: Every AI-derived value can be corrected in exactly one action from the summary.
- **SC-005**: A Cook completes publishing with the AI Assistant unavailable, in 100% of attempts.
- **SC-006**: A person who does not own a Meal that is not on offer reads zero of them, by every
  route, on every commit.
- **SC-007**: Confirming a Meal puts it on offer in under 3 seconds.
- **SC-008**: A kitchen with no Meal on offer is found by zero people; a kitchen with one is found by
  anyone looking.
- **SC-009**: Every screen reads right to left and every string appears in Egyptian Arabic.
- **SC-010**: A retired Meal is returned to offer in zero cases, by any route.
- **SC-011**: A Cook takes a Meal off the menu and puts it back in under 15 seconds.

## Assumptions

- **A Cook publishes one Meal at a time.** Offering several at once is a different flow, not in
  scope.
- **There is no approval or moderation step.** A Meal is on offer the moment its Cook confirms. This
  matches Kafoo's scale today; moderation is a decision for when strangers outnumber friends.
- **Allergen data about a Meal is not personal data.** It describes food, not a person. A Customer's
  own allergies are a separate matter, not in scope here.
- **No fees exist.** Nothing is charged in this feature, so a Meal's price is the whole of its cost
  and there is nothing to disclose beyond it.
- **Cuisines and categories come from a fixed set** the AI Assistant chooses from rather than
  inventing freely, so two Cooks describing the same food land in the same place.
- **The register is Egyptian Arabic throughout**, including anything the AI Assistant drafts. Modern
  Standard Arabic in a drafted description is a defect.

## Open Questions

Decisions that materially affect scope, privacy, or user-visible behaviour, and that this
specification does not have the standing to settle. **All three MUST be answered before
`/speckit-plan`.**

1. **What does a Meal's price cover?** A portion, or the whole dish the Cook made? The answer changes
   what the Cook is asked, what a Customer believes they are buying, and every later conversation
   about Orders. Money is a stop-and-ask under `CLAUDE.md`, so this is not something to default.
   [NEEDS CLARIFICATION: is the price per portion or for the whole dish, and does the Cook state how
   many portions exist?]

2. **Does the AI Assistant see the Meal's photo?** Estimating calories and allergens from a
   photograph is materially better than from a spoken description, and materially more expensive and
   slower. It also sends a Cook's photograph to a model provider, which is a privacy question as
   much as a cost one. [NEEDS CLARIFICATION: does the AI Assistant receive the photo, or only what
   the Cook says?]

3. **How long does an unpublished draft live?** A Meal has a draft state, so an abandoned
   conversation may leave something behind — unlike the Kitchen Profile conversation in E1, which
   deliberately kept nothing until confirmation. If drafts persist they need a lifetime; if they do
   not, the draft state exists for something else. [NEEDS CLARIFICATION: does an abandoned
   conversation leave a draft, and if so for how long?]

## Dependencies

- **Depends on E1.** A Meal cannot exist without a Cook who owns a Kitchen Profile.
- **Discharges an obligation E1 deliberately left.** E1 shipped with no way for anyone to find a
  Kitchen Profile, because discoverability follows from having food on offer. This feature makes
  kitchens findable, and if it does not, Kafoo will have Meals whose kitchens nobody can reach — and
  the failure is silent rather than loud.
- **First use of a real model provider.** Every rule about the AI Assistant becomes live here rather
  than theoretical, and the cost of a model call becomes a real recurring cost for the first time.
- **Blocks E4.** Orders cannot exist without something to order.
