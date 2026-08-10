# Feature Specification: Ordering

**Feature Branch**: `005-ordering`

**Created**: 2026-08-10

**Status**: Draft — three clarifications outstanding

**Input**: User description: "E4 — Ordering. A Customer places an Order for a Meal they have found, the Cook accepts or rejects it, and the Order runs to completion with the Customer paying cash at handover. Kafoo takes no payment and holds no card details in this epic — payment as a system is E5. Ordering must work on both surfaces: the mobile app and the Customer website. Reviews are E5 and out of scope."

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

E1 made a person known to Kafoo. E2 put food on offer. E3 made that food findable by someone who
had never heard of the Cook. **None of it can be bought.**

A Customer today can find a Meal, read what is in it, see the kitchen behind it — and then has no
route to the food at all except leaving Kafoo and reaching the Cook some other way. Every promise
the first three epics made ends at a dead end. This feature is where Kafoo stops being a catalogue
and becomes a marketplace.

**The hard part is not recording an Order. It is that an Order is a promise between two strangers
that nothing in Kafoo can enforce.**

Money never passes through Kafoo in this feature. The Customer pays the Cook in cash when the food
changes hands, so Kafoo holds no deposit, no card and no leverage over either side. A Cook can
decline. A Customer can simply not turn up. Kafoo cannot make either of them appear, and — this is
the part that shapes the design — **Kafoo cannot even see whether they did.**

Two rules follow, and everything below is downstream of them.

**Kafoo must never display a state that overstates the promise.** A Customer who has asked for food
has not been promised food. The single moment at which a promise begins to exist is the Cook's
acceptance, and that moment must be unmistakable to both people. The comfortable design — a warm
confirmation screen the instant the Customer taps — is the one that spends trust Kafoo has not
earned, because most of the time it is describing a promise nobody has made yet.

**An Order Kafoo cannot observe cannot be reported on honestly.** Completion is a claim somebody
makes, not an event Kafoo witnesses. That is tolerable on its own and becomes dangerous in E5, where
the right to write a Review hangs off a completed Order. Whoever holds the power to mark an Order
complete also holds the power to decide whether they can be reviewed, so that choice is made here,
deliberately, rather than inherited by accident.

Two further things follow from rules Kafoo already holds rather than from this feature:

**Ordering is the moment a browser becomes a person.** Discovery deliberately works with no
account, because a shared kitchen link that demands an install converts nobody. An Order cannot —
it needs a Customer who can be reached, and a Cook who knows who is coming. So this feature owns
the only mandatory sign-in in the Customer's whole journey, and it must be the smallest one Kafoo
can build.

**The price shown is the price paid, in cash, exactly.** Kafoo charges no fee in this feature and
therefore has nothing to disclose — but the number a Customer sees before confirming is the number
of banknotes they will hand over, and that must stay true when fees arrive in E5.

## Clarifications

### Session 2026-08-10

- Q: Does Kafoo take a payment, hold card details, or charge a fee in this feature? → A: **No.**
  The Customer pays the Cook in cash at handover. Payment as a system is E5. Kafoo's Order records
  what is owed; it never moves money.
- Q: Does ordering work on the Customer website as well as the app? → A: **Yes.** Everything a
  Customer can do with an Order works identically on both surfaces. The founder's wider direction
  is that the website eventually reaches full parity with the app; the Cook's side of that parity
  is **not** in this feature — see "Out of scope".
- Q: Are Reviews part of this feature? → A: **No.** Reviews are E5. This feature produces the
  `completed` Order that a Review will later require, and nothing more.

### Outstanding — needed before planning

Three questions are marked `[NEEDS CLARIFICATION]` in the requirements below. Each changes what
gets built rather than how it is built, and each is the founder's to answer:

1. **Who travels** — does the Customer collect from the kitchen, does the Cook deliver, or both?
2. **Who marks an Order completed** — the Cook, the Customer, or both.
3. **Does an Order name a time** — and if so, who chooses it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Customer asks a Cook for food (Priority: P1)

A Customer has found a Meal they want. They say how many they want and anything the Cook needs to
know, confirm the exact cash amount they will hand over, and send the request. Kafoo tells them
plainly that the Cook has not answered yet — it does not congratulate them on an order that does
not exist.

**Why this priority**: Without it there is no Order at all, and every other story in this feature
is unreachable. It is also the story that carries the trust rule the whole epic is built on: the
difference between *asked* and *promised* is established here or nowhere.

**Independent Test**: A Customer with an account opens a published Meal, requests it, and a Cook
sees a pending Order arrive. Deliverable on its own — a Cook could work the rest by phone and
Kafoo would still have made the introduction that does not exist today.

**Acceptance Scenarios**:

1. **Given** a Customer signed in and viewing a published Meal, **When** they request it and
   confirm, **Then** an Order exists in `pending`, the Cook is made aware of it without having to
   go looking, and the Customer is shown that no answer has been given yet.
2. **Given** a Customer who is not signed in and viewing a published Meal, **When** they request
   it, **Then** Kafoo asks them to sign in, and on success the Order they were placing is placed —
   they do not have to find the Meal again.
3. **Given** a Customer confirming an Order, **When** the confirmation is shown, **Then** the cash
   amount displayed is the whole of what they will owe at handover, with no charge added later.
4. **Given** a Meal whose Cook has taken it off offer or archived it, **When** a Customer tries to
   order it, **Then** the Order is refused and the Customer is told the food is no longer available
   — not shown a generic failure.
5. **Given** a Cook viewing their own Meal, **When** they attempt to order it, **Then** Kafoo
   refuses.

---

### User Story 2 - A Cook accepts or refuses (Priority: P1)

A Cook sees who has asked for what, and answers. Accepting is the moment the promise begins.
Refusing is a first-class answer, not a failure — a home cook who is out of an ingredient, already
cooking for forty people, or simply not cooking today must be able to say so without penalty and
without explaining themselves.

**Why this priority**: An Order nobody answers is worse than no Order — it leaves a Customer
waiting for food that is not coming. This is also the only place in Kafoo where one person's
decision creates an obligation for another, so the authorization around it is the tightest in the
product: only the Cook who owns the Meal may answer.

**Independent Test**: A Cook with a pending Order accepts it, and the Customer's view changes to
say the Cook has agreed. Then a second Order is rejected, and the Customer is told so.

**Acceptance Scenarios**:

1. **Given** a Cook with a pending Order for their Meal, **When** they accept, **Then** the Order
   moves to `accepted` and the Customer learns of it without having to check.
2. **Given** a Cook with a pending Order, **When** they reject it, **Then** the Order moves to
   `rejected`, the Customer learns of it, and the Customer is offered a route back to finding
   other food rather than a dead end.
3. **Given** any signed-in person who is not the Meal's Cook, **When** they attempt to accept or
   reject that Order, **Then** the attempt fails and no state changes.
4. **Given** an Order that has been rejected, **When** anyone attempts to accept it afterwards,
   **Then** the attempt fails — a terminal answer is final.
5. **Given** a Cook rejecting an Order, **When** they are asked why, **Then** giving a reason is
   optional and refusing to give one carries no consequence for the Cook.

---

### User Story 3 - The food is made and handed over (Priority: P2)

An accepted Order moves through the Cook actually cooking it, the food being ready, and the moment
it changes hands for cash. Both people can see where it has got to without messaging each other.

**Why this priority**: This is the substance of the transaction, but stories 1 and 2 deliver value
without it — a Cook and Customer who have been introduced and have agreed can complete the handover
by phone. It ranks below them because the states here describe reality rather than change it.

**Independent Test**: An accepted Order is walked through to `completed`, and both parties see each
step. Verifiable end to end without any other story beyond the two above.

**Acceptance Scenarios**:

1. **Given** an accepted Order, **When** the Cook begins cooking, **Then** both people see that it
   is being prepared.
2. **Given** an Order being prepared, **When** the Cook marks it ready, **Then** both people see
   that the food is ready and know what happens next in concrete terms.
3. **Given** a ready Order, **When** the handover happens and it is marked completed, **Then** the
   Order is `completed` and no field on it can be changed again by anyone.
4. **Given** a completed Order, **When** anyone attempts to change its state, **Then** the attempt
   fails.
5. **Given** an Order that has been accepted, **When** either person needs to reach the other about
   the handover, **Then** each has what they need to make contact — and not before acceptance.

---

### User Story 4 - Somebody changes their mind (Priority: P2)

A Customer who has asked for food and has not yet been answered can withdraw. After acceptance they
cannot — a Cook who has started shopping and cooking for a stranger has spent real money on the
strength of that promise. A Cook who accepted and then genuinely cannot cook needs an honest route
out that does not pretend the Customer was never told.

**Why this priority**: Without it, every mistaken tap becomes a phone call, and a Customer with no
way out learns to be careful about ordering, which is the opposite of what the marketplace needs.
It ranks below the core flow because the flow works without it, badly.

**Independent Test**: A pending Order is withdrawn by the Customer and the Cook sees it gone. An
accepted one cannot be withdrawn by the Customer.

**Acceptance Scenarios**:

1. **Given** an Order still pending, **When** the Customer withdraws it, **Then** it moves to
   `cancelled` and the Cook is told.
2. **Given** an Order the Cook has accepted, **When** the Customer attempts to withdraw it,
   **Then** the attempt fails and the Customer is shown how to reach the Cook instead.
3. **Given** any cancellation route offered anywhere in this feature, **When** it is presented,
   **Then** it is no harder to find or use than the route that placed the Order.

---

### User Story 5 - A Customer looks at what they have ordered (Priority: P3)

A Customer can see the Orders they have placed and what happened to each — including Orders for
Meals the Cook has since archived, and including Orders placed on the other surface.

**Why this priority**: It is how a Customer answers "did I actually order that, and what did I
agree to pay". It is also the precondition for E5's Reviews, which must attach to a specific
completed Order the Customer can find. It ranks last because a single Order in flight is visible
from the flow itself.

**Independent Test**: A Customer with several Orders in different states sees all of them with the
right state and the price they agreed at the time.

**Acceptance Scenarios**:

1. **Given** a Customer with Orders in several states, **When** they open their Orders, **Then**
   every one is listed with its current state.
2. **Given** an Order for a Meal the Cook has since archived, **When** the Customer opens it,
   **Then** it is still readable, including what the Meal was.
3. **Given** a Cook who has raised the price of a Meal since an Order was placed, **When** the
   Customer opens that Order, **Then** it shows the price agreed at the time, not the new one.
4. **Given** a Customer who placed an Order on the website, **When** they sign in to the app,
   **Then** the same Order is there in the same state, and the reverse.

---

### Edge Cases

- **The Cook never answers.** A pending Order that sits unanswered leaves a Customer waiting for
  food that is not coming, which is the worst outcome in this feature. Kafoo must not let a pending
  Order run forever silently; see FR-030.
- **The Meal goes off offer between opening it and confirming.** The Customer must be told the food
  is gone, in those terms, rather than shown a failure they cannot interpret.
- **Two Customers order the last of something.** A Meal is an offer, not inventory — placing an
  Order decrements nothing, and both Orders are legitimately placed. The Cook rejects whichever
  they cannot cook. Kafoo must not invent stock it does not track.
- **The Cook accepts and then cannot cook.** See FR-024. The route out must exist and must be
  honest with the Customer about what happened.
- **The Customer does not turn up.** Kafoo cannot observe this and must not pretend to. What it
  must not do is silently record the Order as completed.
- **The Customer's phone credential goes dormant** between placing and completing an Order.
  ADR-0007 severs a phone credential rather than a person; an Order is the first thing in Kafoo
  with a live obligation attached to it, and the handover must not be broken by dormancy.
- **A Cook attempts to remove a Meal that an Order references.** The Order's history must survive.
- **An Order is placed on one surface and answered while the Customer is on the other.**
- **The Customer requests several of the same Meal.** An Order is for whole Meals; the amount owed
  is the Meal's price multiplied by how many, with nothing else added.

## Requirements *(mandatory)*

### Functional Requirements

**Placing an Order**

- **FR-001**: A Customer MUST be able to place an Order for any Meal that is currently published.
- **FR-002**: Kafoo MUST refuse an Order for a Meal that is a draft, unavailable, or archived, and
  MUST tell the Customer that the food is not available rather than reporting a generic failure.
- **FR-003**: Placing an Order MUST require a signed-in Customer. Browsing and discovery MUST
  remain available without an account.
- **FR-004**: A Customer who is signed out and places an Order MUST be returned to the same Order,
  in progress, after signing in. They MUST NOT have to find the Meal again.
- **FR-005**: An Order MUST record which Meal, which Customer, which Cook, how many whole Meals,
  and the price of the Meal at the moment the Order was placed.
- **FR-006**: An Order's price MUST NOT change when the Cook later changes the Meal's price.
- **FR-007**: The total cash amount MUST be shown to the Customer before they confirm, MUST equal
  the Meal's price multiplied by the number ordered, and MUST be the entire amount owed at
  handover. No charge of any kind may be added after confirmation.
- **FR-008**: A Cook MUST NOT be able to place an Order for their own Meal.
- **FR-009**: An Order's Cook MUST always be the Cook who owns the Meal, and MUST NOT be able to
  change for the life of the Order.
- **FR-010**: The information the Customer supplies when ordering MUST be gathered
  conversationally rather than as a form. Where the count of things a Customer must supply reaches
  four, Principle IV applies and a conversational flow is required, not optional.

**Answering an Order**

- **FR-011**: Only the Cook who owns the Meal MUST be able to accept or reject an Order. Every
  other party, signed in or not, MUST be refused.
- **FR-012**: A Cook MUST be able to reject an Order without giving a reason, and rejecting MUST
  carry no penalty or visible consequence for the Cook.
- **FR-013**: A Cook MUST be made aware of a new pending Order without having to go looking for it.
- **FR-014**: A Customer MUST be made aware of the Cook's answer without having to go looking for
  it.
- **FR-015**: An Order that has reached a terminal state — `rejected`, `cancelled`, or `completed`
  — MUST NOT be reopened or re-answered by anyone.

**The life of an Order**

- **FR-016**: An Order MUST follow `pending → accepted → preparing → ready → completed`, with
  `rejected` and `cancelled` reachable only from `pending`.
- **FR-017**: A completed Order MUST be immutable. No field on it may be written again by anyone,
  including the Cook, the Customer, or Kafoo itself.
- **FR-018**: [NEEDS CLARIFICATION: who marks an Order completed — the Cook alone, the Customer
  alone, or both parties having to agree? Whoever holds this power also decides, in E5, whether
  they can be reviewed.]
- **FR-019**: [NEEDS CLARIFICATION: does the Customer collect the food from the kitchen, does the
  Cook deliver it, or are both possible? Delivery requires Kafoo to hold a Customer's address,
  which is a new category of personal data.]
- **FR-020**: [NEEDS CLARIFICATION: does an Order name a time for the handover, and does the
  Customer request it or the Cook set it? Without one, neither party knows when to be anywhere.]
- **FR-021**: A Customer MUST be able to cancel an Order while it is pending, and MUST NOT be able
  to cancel it once the Cook has accepted.
- **FR-022**: The route to cancel MUST be no harder to find, and take no more steps, than the route
  that placed the Order.
- **FR-023**: Both the Customer and the Cook MUST be able to read an Order they are party to.
  Neither MUST be able to delete it.
- **FR-024**: A Cook who has accepted an Order and cannot fulfil it MUST have a route that ends the
  Order honestly and informs the Customer. The Order MUST NOT be silently abandoned, and it MUST
  NOT be recorded as completed.
- **FR-025**: An Order MUST remain readable to both parties after the Meal it references is
  archived, including what the Meal was.
- **FR-026**: A Meal that any Order references MUST NOT be removable in a way that destroys that
  Order's history.

**Reaching each other**

- **FR-027**: Once an Order is accepted, each party MUST have what they need to contact the other
  about the handover.
- **FR-028**: Before acceptance, neither party's contact details MUST be revealed to the other.
- **FR-029**: No personal detail beyond what this specific Order requires MUST be shared between
  Customer and Cook. Dietary and allergy information in particular MUST NOT travel with an Order
  unless the Customer has chosen to send it for that Order.

**Not leaving people waiting**

- **FR-030**: A pending Order MUST NOT remain pending indefinitely without the Customer being told
  where they stand. Kafoo MUST either bring it to a stated conclusion or tell the Customer plainly
  that no answer has come.

**Both surfaces**

- **FR-031**: Every action a Customer can take on an Order MUST be available on both the app and
  the website, producing the same Order in the same state.
- **FR-032**: An Order placed on one surface MUST be visible, in the same state, on the other.

**The AI Assistant**

- **FR-033**: The AI Assistant MUST NOT place, accept, reject, cancel, or change the state of an
  Order under any framing or instruction.
- **FR-034**: Where the AI Assistant helps a Customer express an Order, the Customer MUST confirm
  the Meal, the quantity and the cash amount before the Order exists.

**Language and record**

- **FR-035**: Every user-facing string in this feature MUST exist in Egyptian Arabic first and in
  English, on both surfaces.
- **FR-036**: `OrderPlaced`, `OrderAccepted`, `OrderRejected`, `OrderCancelled` and `OrderCompleted`
  MUST be emitted as the corresponding state changes occur. These names are already reserved in the
  event registry and MUST NOT be renamed.
- **FR-037**: No analytics event in this feature MUST carry what the Customer typed or said.

### Key Entities

- **Order**: A Customer's request to a Cook for a specific Meal. Holds which Customer, which Cook,
  which Meal, how many whole Meals, the price agreed at the time, its current state, and the times
  at which it changed state. Owned jointly for reading by the Customer and the Cook; deletable by
  neither. It is the only entity in Kafoo that two different people both own a read on.
- **Meal**: Already exists. This feature adds the constraint that a Meal referenced by an Order
  cannot be removed in a way that loses the Order's history, and that only a published Meal can
  receive a new Order.
- **Customer** and **Cook**: Already exist. This feature adds the first obligation that runs
  between two of them.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Customer who has found a Meal they want can place an Order in under 60 seconds,
  including signing in for the first time.
- **SC-002**: A Customer who already has an account can place an Order in under 20 seconds.
- **SC-003**: **Zero** Orders exist whose Cook is not the Cook who owns the Meal.
- **SC-004**: **Zero** Orders were accepted, rejected, or advanced by anyone other than the Meal's
  Cook. One occurrence is a failure of the feature.
- **SC-005**: **Zero** completed Orders had any field written after completion.
- **SC-006**: **Zero** occurrences of a Customer being shown language implying their food is coming
  before the Cook has accepted. Verified by reading every state's wording in both languages, not by
  counting incidents.
- **SC-007**: In 100% of Orders, the cash amount shown before confirmation equals the amount owed
  at handover.
- **SC-008**: **Zero** Orders remain pending with the Customer uninformed beyond the period set by
  FR-030.
- **SC-009**: **Zero** Orders can be read by anyone who is neither its Customer nor its Cook.
- **SC-010**: A Cook learns that a new Order is waiting within 60 seconds of it being placed.
- **SC-011**: 100% of the Customer Order actions available in the app are available on the website,
  verified action by action by name.
- **SC-012**: **Zero** Orders were placed, answered or advanced by the AI Assistant without a human
  confirming.
- **SC-013**: A Customer can find every Order they have ever placed, including those whose Meal has
  been archived, in 100% of cases.
- **SC-014**: The whole ordering journey is completable in Egyptian Arabic on both surfaces, start
  to finish, without encountering an untranslated string.
- **SC-015**: **Zero** contact details are visible to either party before the Cook has accepted.

## Assumptions

These are reasonable defaults chosen where the description did not specify. Each is a decision the
founder can overturn, and the ones that would change scope are called out as such.

- **An Order is for whole Meals.** E2 settled that a Meal's price covers the whole Meal rather than
  a serving, so quantity here is a count of whole Meals and nothing is divisible.
- **Kafoo charges nothing in this feature.** There is no commission, no delivery charge and no
  service fee, so there is nothing to disclose beyond the Meal price. The rule that every charge is
  visible before confirmation is trivially satisfied now and must survive E5 adding charges.
- **Kafoo never touches the money.** Cash passes directly from Customer to Cook. Kafoo holds no
  card details, no bank details and no balance, and records only what was owed.
- **Identity is the one already built.** Ordering uses E1's existing phone-based sign-in. This
  feature adds no new way of proving who somebody is.
- **The Cook's side of the website is not in this feature.** The founder's direction is that the
  website reaches full parity with the app, including the Cook's tools. Delivering that means
  rebuilding identity, the Kitchen Profile and voice-led Meal publishing on a second surface, which
  is a larger body of work than ordering itself and carries no new value for this epic. **This
  feature therefore puts Customer ordering on both surfaces and leaves the Cook answering Orders in
  the app.** Full Cook parity on the website is its own epic and needs an amendment to the decision
  that scoped the website to Customer flows. *Scope-changing — overturn this and the epic roughly
  triples.*
- **No rating or Review appears anywhere in this feature.** Reviews are E5. This feature's only
  obligation to them is producing a completed Order they can attach to.
- **No scheduling of a Cook's capacity.** Kafoo does not model how many Orders a Cook can take, opening
  hours, or a calendar. A Cook rejects what they cannot cook. Anything more is a later decision.
- **No modification of a placed Order.** A Customer who wants something different cancels while
  pending and places another. There is no edit.
- **No Order without a Meal.** Kafoo does not support ordering something that is not on offer, in
  any form, including as a request to the Cook.

## Dependencies

- **E2 (Meal publishing)** — delivered. An Order cannot exist without a Meal to order.
- **E3 (Customer discovery)** — delivered, with closeout outstanding. A Customer must be able to
  find a Meal before they can order it. E3's remaining work does not block this feature from being
  planned, but E3's acceptance criteria should be verified before this feature ships.
- **E1 (identity)** — delivered. Ordering requires the sign-in it built, and inherits the dormancy
  behaviour that ADR-0007 defined.
- **The Meal-to-Order link must protect history.** The existing rule that deleting a Meal removes
  what depends on it was correct while nothing referenced a Meal. It becomes wrong the moment an
  Order does, and must be changed in the same migration that creates Orders.

## Out of scope

- **Payment of any kind** — cards, wallets, transfers, deposits, escrow, refunds. E5.
- **Fees, commission and payouts.** Kafoo earns nothing in this feature.
- **Reviews and ratings.** E5.
- **The Cook's tools on the website.** See Assumptions.
- **Delivery logistics** — couriers, tracking, distance, or routing — regardless of how FR-019 is
  answered.
- **Scheduling, capacity, opening hours, or a Cook's calendar.**
- **Editing a placed Order.**
- **Disputes, complaints, or any arbitration between a Customer and a Cook.**
- **Repeat ordering, favourites, or a basket holding Meals from more than one Cook.**
