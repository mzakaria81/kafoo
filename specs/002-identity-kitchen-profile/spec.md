# Feature Specification: Identity and Kitchen Profile

**Feature Branch**: `002-identity-kitchen-profile`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "E1 — identity and Kitchen Profile. A person signs in to Kafoo with their phone number via a one-time code, with email as a fallback path. One account holds both roles: everyone starts able to browse and order as a Customer, and becomes a Cook by creating a Kitchen Profile — there is no role chosen at signup and no second account. A Cook can therefore order Meals from other Cooks. A Kitchen Profile carries a display name, a story, an area, delivery terms, and a photo, and belongs to exactly one Cook. A person has at most one Kitchen Profile. Anyone may read a published Kitchen Profile; only its owning Cook may create or change it, and nobody else can read a Kitchen Profile that has not been published. This is the first stored information in Kafoo, so it is also the first proof that a person's data is unreadable by anyone else — that proof is part of the deliverable, not a follow-up. Arabic is the default language throughout. The phone number is a new category of personal data and needs a stated reason, retention period, and reader set."

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

Kafoo currently stores nothing about anybody. This feature introduces the first information a
person entrusts to Kafoo, which makes it two things at once: the way someone becomes known to
Kafoo, and the first occasion on which Kafoo's promise that *a person's information is
unreadable by anyone else* is either kept or broken.

That promise has been asserted since the foundation was laid but never demonstrated, because
there was nothing stored to demonstrate it against. Demonstrating it is part of this feature's
deliverable, not a follow-up to it.

This feature also fixes the ownership shape that every later part of Kafoo copies. A Meal belongs
to a Cook; an Order belongs to a Customer and a Cook; a Review belongs to a Customer. None of
those can be built until "belongs to" means something concrete, and whatever it comes to mean
here will be repeated everywhere afterwards. Getting it wrong once is a cost paid many times.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A person signs in with their phone number (Priority: P1)

A person opens Kafoo for the first time. They are asked for their phone number, and nothing else.
A one-time code arrives by text message; they enter it and they are in. They are not asked to
choose whether they are a Cook or a Customer, they are not asked to invent a password, and they
are not asked for an email address.

Returning later on the same phone, they are still signed in. Returning on a new phone, the same
number and a fresh code restores the same identity.

**Why this priority**: Nothing else in Kafoo can exist until a person can be recognised when they
come back. Every subsequent story assumes a known person. It also establishes the least-friction
posture the rest of Kafoo inherits.

**Independent Test**: Sign in on a clean device with a phone number, close Kafoo entirely, reopen
it, and confirm the same identity is restored without re-entering a code. Then sign in on a
second device with the same number and confirm it resolves to the same person rather than
creating a new one.

**Acceptance Scenarios**:

1. **Given** a person who has never used Kafoo, **When** they enter a valid phone number and the
   code sent to it, **Then** they are signed in and Kafoo knows them as the same person on every
   later visit.
2. **Given** a person already known to Kafoo, **When** they sign in from a different device with
   the same phone number, **Then** they reach the same identity, including any Kitchen Profile
   they own — not a second, empty one.
3. **Given** a person who enters a code that is wrong or has expired, **When** they submit it,
   **Then** they are told plainly which of the two happened and can request a new code without
   starting again.
4. **Given** a person who requests codes repeatedly, **When** they exceed a reasonable rate,
   **Then** further requests are refused for a stated period, and the refusal says when they may
   try again.
5. **Given** a person part-way through entering a code, **When** they lose connectivity, **Then**
   they are told the request did not reach Kafoo, and are never left believing they are signed in
   when they are not.

---

### User Story 2 - A Cook creates a Kitchen Profile by talking, not by filling in a form (Priority: P1)

A person who wants to cook for others tells Kafoo about their kitchen. Kafoo asks one question at
a time, in conversational Egyptian Arabic, and accepts a spoken answer as readily as a typed one.
What is your kitchen called? Tell me about your cooking. Which area are you in? How do people get
their food from you?

At the end, the Cook sees everything Kafoo understood, in one place, and confirms it before any
of it is kept. Nothing from the conversation is stored until they approve it.

Creating a Kitchen Profile is what makes someone a Cook. There is no separate application, no
role toggle, and no second account. A person who never creates one remains a Customer and is not
asked about it again after declining once.

**Why this priority**: A Kitchen Profile is the supply side of the marketplace, and a Cook who
abandons a five-field form is a Cook who never lists a Meal. It is also the first place Kafoo's
conversational premise is either real or decorative — the constitution requires a conversation
here rather than a form, and this is where that is proven.

**Independent Test**: As a signed-in person with no Kitchen Profile, complete the conversation
end to end using voice for every answer, confirm the summary, and verify the Kitchen Profile
exists exactly as confirmed. Separately, abandon the conversation halfway and confirm nothing was
kept.

**Acceptance Scenarios**:

1. **Given** a signed-in person with no Kitchen Profile, **When** they choose to cook on Kafoo,
   **Then** Kafoo asks one question at a time and never presents more than one unanswered
   question at once.
2. **Given** a Cook part-way through the conversation, **When** they answer by speaking rather
   than typing, **Then** their answer is understood and shown back to them for confirmation.
3. **Given** a Cook who has answered every question, **When** they reach the end, **Then** they
   see a single summary of everything gathered and must actively confirm it before anything is
   kept.
4. **Given** a Cook looking at that summary, **When** they want to change one answer, **Then**
   they can change that answer alone without repeating the whole conversation.
5. **Given** a Cook who abandons the conversation before confirming, **When** they return later,
   **Then** no partial Kitchen Profile exists and they are not presented to anyone as a Cook.
6. **Given** a person who already owns a Kitchen Profile, **When** they attempt to create another,
   **Then** they are taken to their existing one instead, because a person has at most one.

---

### User Story 3 - Only the owner can reach what belongs to them (Priority: P1)

Whatever a person entrusts to Kafoo is theirs. Another person — signed in, using Kafoo normally,
doing nothing unusual — cannot read it, cannot change it, and cannot tell whether it exists. A
Cook can change their own Kitchen Profile and nobody else's. A person's phone number is visible
to nobody but themselves.

**Why this priority**: This is the promise the entire marketplace rests on, and it is currently
asserted with no evidence behind it. It is P1 not because it is a visible feature but because
discovering it was never true is unrecoverable — a marketplace between strangers exchanging
home-cooked food does not survive it.

**Independent Test**: Signed in as one person, attempt to read and to change another person's
information through every route Kafoo exposes. Every attempt returns nothing and changes nothing.
This test must be automatic and must run on every subsequent change to Kafoo, never once by hand.

**Acceptance Scenarios**:

1. **Given** two people who each own a Kitchen Profile, **When** one attempts to read the other's
   information beyond what is deliberately public, **Then** nothing is returned — not an error
   revealing that something exists, simply nothing.
2. **Given** two people who each own a Kitchen Profile, **When** one attempts to change the
   other's, **Then** the attempt fails and the other's Kitchen Profile is unchanged in every
   part.
3. **Given** a Cook who owns a Kitchen Profile, **When** they attempt to reassign it to another
   person, **Then** the attempt fails — a Kitchen Profile belongs to exactly one Cook and cannot
   be transferred.
4. **Given** any person, **When** they attempt to reach a phone number other than their own,
   **Then** nothing is returned, including through a Kitchen Profile's public view.
5. **Given** a person who is not signed in at all, **When** they attempt to reach anything that is
   not deliberately public, **Then** nothing is returned.

---

### User Story 4 - Anyone can look at a Cook's kitchen (Priority: P2)

A Customer browsing Kafoo can see a Cook's kitchen: what it is called, the Cook's story, the area
they cook in, how food reaches people, and a photo. This is the deliberately public face of a
Kitchen Profile, and it is public whether or not the person looking is signed in.

What is public is exactly this and nothing more. The Cook's phone number is not part of it.

**Why this priority**: Without it a Kitchen Profile is a private note rather than a shopfront, and
no Customer can choose a Cook. It is P2 only because it depends on Kitchen Profiles existing
first.

**Independent Test**: As a person who is not signed in, view a Cook's kitchen, confirm the five
public details appear, and confirm nothing else about that Cook is reachable.

**Acceptance Scenarios**:

1. **Given** a Cook with a Kitchen Profile, **When** any person views it, **Then** they see the
   kitchen's name, the Cook's story, the area, the delivery terms, and the photo.
2. **Given** a Cook with a Kitchen Profile, **When** any person views it, **Then** they cannot
   reach that Cook's phone number through it by any route.
3. **Given** a Cook who has not finished creating a Kitchen Profile, **When** any other person
   looks for it, **Then** they find nothing.

---

### User Story 5 - A Cook changes their kitchen later (Priority: P2)

A Cook's circumstances change — they move area, they stop delivering, they want a better photo.
They can change any part of their Kitchen Profile without recreating it, and the change reaches
Customers immediately.

**Why this priority**: A Kitchen Profile that cannot be corrected becomes wrong, and a wrong
Kitchen Profile misleads Customers about where their food comes from. That is a trust problem,
not a convenience one.

**Independent Test**: Change each part of a Kitchen Profile in turn and confirm each change is
visible to a different person immediately, and that no other part was altered.

**Acceptance Scenarios**:

1. **Given** a Cook with a Kitchen Profile, **When** they change one part of it, **Then** only
   that part changes, and the change reaches Customers straight away.
2. **Given** a Cook part-way through changing their kitchen, **When** they have not yet confirmed,
   **Then** Customers continue to see the previous version.

---

### User Story 6 - Signing in without a phone number (Priority: P3)

A person who cannot receive a text message — travelling, a number between carriers, a phone that
is not theirs — can sign in with an email address instead and reach the same Kafoo.

**Why this priority**: It is a fallback for a minority path. Building it first would be building
for the exception; omitting it entirely would strand people whose number stops working, which on
a phone-anchored identity means losing their Kitchen Profile.

**Independent Test**: Sign in by email, confirm it reaches a working identity, and confirm a
person who has used both routes has one identity rather than two.

**Acceptance Scenarios**:

1. **Given** a person who cannot receive a text message, **When** they choose the email route,
   **Then** they can sign in and use Kafoo fully.
2. **Given** a person who has previously signed in by phone number, **When** they later sign in by
   email using an address they have confirmed belongs to them, **Then** they reach their existing
   identity, including any Kitchen Profile — never a second, empty one.

---

### Edge Cases

- **A carrier reassigns a phone number to a different person.** Egyptian numbers are recycled. The
  new holder must not inherit the previous holder's Kitchen Profile, Orders, or Reviews. This is
  the sharpest risk in a phone-anchored identity and is raised in Open Questions rather than
  assumed away.
- **Someone enters a phone number that is not theirs.** Kafoo must not disclose whether that
  number is already known to it, since that alone reveals who uses Kafoo.
- **A photo fails to arrive** part-way through the conversation. The conversation must not be
  lost, and the Cook must be able to carry on and add a photo afterwards.
- **A person answers a question with something that is not an answer** — a question back, silence,
  or an unrelated remark. Kafoo asks again rather than storing nonsense or guessing.
- **A spoken answer is understood wrongly.** The Cook sees what was understood before anything is
  kept, and can correct it. Nothing spoken is stored as fact without being shown back first.
- **The same person is signed in on two devices and changes their Kitchen Profile on both.** The
  later confirmed change wins, and neither is shown a version that was silently discarded.
- **A person stops using Kafoo while owning a Kitchen Profile.** Removing an account is out of
  scope for this feature; raised in Open Questions.

## Requirements *(mandatory)*

### Functional Requirements

**Identity**

- **FR-001**: A person MUST be able to sign in using only a phone number and a one-time code sent
  to it. No password is created at any point.
- **FR-002**: The same phone number MUST always resolve to the same person, on any device.
- **FR-003**: A person MUST NOT be asked to choose between being a Cook and a Customer at any
  point. Every signed-in person can browse and place Orders.
- **FR-004**: A one-time code MUST expire after a short period and MUST be usable only once.
- **FR-005**: Repeated code requests for the same number MUST be refused beyond a reasonable rate,
  and the refusal MUST state when the person may try again.
- **FR-006**: Kafoo MUST NOT reveal, to someone entering a phone number, whether that number is
  already known to it.
- **FR-007**: A person MUST be able to sign in by email as an alternative route, reaching the same
  identity rather than a second one.

**Kitchen Profile**

- **FR-008**: A person MUST become a Cook by creating a Kitchen Profile, and by no other means.
- **FR-009**: A person MUST own at most one Kitchen Profile.
- **FR-010**: A Kitchen Profile MUST belong to exactly one Cook and MUST NOT be transferable.
- **FR-011**: A Kitchen Profile MUST carry a display name, a story, an area, delivery terms, and a
  photo.
- **FR-012**: Creating a Kitchen Profile MUST be a conversation that asks one question at a time
  and MUST NOT present a form of four or more fields. It MUST accept spoken answers.
- **FR-013**: Nothing gathered in that conversation MUST be kept until the Cook has seen a summary
  of all of it and actively confirmed it.
- **FR-014**: A Cook MUST be able to correct any single answer from the summary without repeating
  the conversation.
- **FR-015**: An abandoned conversation MUST leave no Kitchen Profile and MUST NOT present the
  person as a Cook.
- **FR-016**: A Cook MUST be able to change any part of their Kitchen Profile after creating it,
  with the change reaching Customers immediately.

**Ownership and privacy**

- **FR-017**: Only the owning Cook MUST be able to create or change a Kitchen Profile. Every other
  person's attempt MUST fail and leave it unchanged.
- **FR-018**: A person MUST NOT be able to read another person's information beyond what is
  deliberately public, and a refused attempt MUST return nothing rather than an error revealing
  that something exists.
- **FR-019**: The deliberately public part of a Kitchen Profile MUST be exactly its display name,
  story, area, delivery terms, and photo, and MUST be readable by anyone, signed in or not.
- **FR-020**: A phone number MUST be readable only by the person it belongs to, and MUST NOT be
  reachable through any public view.
- **FR-021**: Ownership MUST be enforced where the app cannot bypass it, and MUST be proven by an
  automatic check that runs on every subsequent change to Kafoo — never verified once by hand.
- **FR-022**: A phone number MUST be collected for one stated reason only — to sign a person in,
  and to let a Cook and a Customer reach each other about a specific Order — and MUST be kept only
  while that person's account exists.

**Language**

- **FR-023**: Every string a person sees MUST exist in Egyptian Arabic, which is the default
  language and not a fallback.
- **FR-024**: Every screen in this feature MUST read correctly right-to-left.

### Key Entities

- **Person**: Someone known to Kafoo, anchored to a phone number. Every person can browse and
  place Orders. A person owns at most one Kitchen Profile; owning one is what makes them a Cook.
  Their phone number is readable only by them.
- **Kitchen Profile**: A Cook's kitchen as Customers see it — display name, story, area, delivery
  terms, photo. Belongs to exactly one Cook, permanently. Those five details are public; nothing
  else about its Cook is.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A person new to Kafoo goes from opening it to signed in within 60 seconds, having
  supplied only a phone number and a code.
- **SC-002**: A Cook creates a complete Kitchen Profile in one sitting in under 3 minutes, using
  voice for every answer, without abandoning it.
- **SC-003**: A person who does not own a piece of information retrieves none of it, across every
  route Kafoo exposes, verified automatically on every change to Kafoo rather than once by hand.
- **SC-004**: 100% of strings a person sees in this feature exist in Egyptian Arabic, checked
  automatically rather than by review.
- **SC-005**: Every screen in this feature reads correctly right-to-left, with no element reading
  left-to-right.
- **SC-006**: No point in the Kitchen Profile conversation presents more than one unanswered
  question.
- **SC-007**: Kafoo opens to a usable screen in under 2 seconds — the budget this feature must not
  push past.
- **SC-008**: A Cook viewing the confirmation summary can reach a correction for any single answer
  in one action.

## Assumptions

Reasonable defaults chosen where the description did not specify. Each is a decision that can be
revisited, not an oversight.

- **One account holds both roles.** Decided on 2026-07-29, not assumed. A person becomes a Cook by
  owning a Kitchen Profile; there is no role chosen at signup and no second account. A Cook can
  order Meals from other Cooks. The rule that a Cook cannot review their own Meal therefore
  becomes a comparison between the reviewer and the Meal's Cook, rather than a property of the
  account.
- **Phone number is the primary route, email the fallback.** Decided on 2026-07-29, not assumed.
- **The AI Assistant is not involved in this feature.** The Kitchen Profile conversation is guided
  and asks one question at a time, which satisfies the constitution's requirement to prefer a
  conversation over a form, but it does not draft, infer, or suggest anything. Having the AI
  Assistant draft a Cook's story from what they say is deliberately deferred to E2, where the
  approval flow it needs is being built anyway. This keeps the feature free of any dependency on a
  model provider.
- **Spoken answers are understood and the recording discarded.** No raw recording is kept; the
  constitution requires a recorded architectural decision before any raw audio is stored, and this
  feature does not propose one.
- **A one-time code expires after 5 minutes** and may be used once.
- **Removing an account is out of scope.** A person cannot yet remove their account or their
  Kitchen Profile. This is a gap, recorded below, not a decision that removal should be
  impossible.
- **Meals, Orders and Reviews are all out of scope.** A Kitchen Profile in this feature has no
  Meals attached and shows no rating, because neither exists yet.
- **Delivery terms are free text**, not a structured schedule or a distance calculation.
  Structuring them is a later decision that needs real Cooks' answers to inform it.

## Open Questions

Three decisions that materially affect scope, privacy, or user-visible behaviour, and that this
specification does not have the standing to settle. They are listed rather than guessed at.

1. **Does a Kitchen Profile have a draft state?** The description says a Kitchen Profile that is
   not published cannot be read by others, which implies a lifecycle the domain model does not
   give it — only Meals, Orders and Reviews have lifecycles there. Either a Kitchen Profile
   becomes visible the moment it is confirmed (simpler, and consistent with the domain model as
   written), or it gains a draft state (more control for the Cook, and a change to the domain
   model). This specification assumes the former; User Story 4's third acceptance scenario is
   written to hold under either answer.

2. **What happens when a carrier reassigns a phone number?** Egyptian numbers are recycled, and a
   phone-anchored identity means a new holder could reach the previous holder's Kitchen Profile,
   Orders and Reviews. Options run from doing nothing, to expiring identities after a period of
   inactivity, to requiring something more than a code before a dormant identity is restored. This
   is a trust question rather than a convenience one, and is left open deliberately.

3. **How long is a phone number kept once someone stops using Kafoo?** The stated answer is "as
   long as the account exists", but with no way to remove an account there is currently no way for
   an account to stop existing. Either removal comes into scope here, or the retention answer is
   incomplete and should say so.

## Dependencies

- This is the first feature to store any information in Kafoo. It depends on no earlier feature
  and blocks every later one.
- Sending a one-time code by text message depends on an outside service that has not been chosen
  or paid for. That choice belongs in `plan.md`; that it carries a recurring cost per message is
  noted here because it bears on whether the phone route can be the primary one.
