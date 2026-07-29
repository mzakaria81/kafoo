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

## Clarifications

### Session 2026-07-29

- Q: How should identity relate to the phone number? → A: A Person is the identity; the phone
  number is a credential attached to it, as WhatsApp does it. This enables a change-of-number
  flow. Dormancy rules and an optional second factor stay available later without reshaping
  anything.
- Q: How does email sign-in reach an existing identity, given most Cooks will not have email? →
  A: An email address is attached from inside an account, after signing in by phone, and only
  then works as a sign-in route. It is never required. Kafoo invites a person to add one once
  they are using Kafoo and have something a lost number would cost them, explains plainly why,
  and accepts no for an answer.
- Q: Does a Kitchen Profile have a draft state after confirmation? → A: No state field. A Kitchen
  Profile becomes *discoverable* to Customers when its Cook has at least one published Meal, and
  stops being discoverable when they have none. Discoverability and readability are separate: a
  Kitchen Profile stays readable to anyone holding a legitimate reference to it, such as an Order,
  for the same reason archived Meals stay readable. Consequence accepted: no Kitchen Profile is
  discoverable during this feature, because Meals do not exist yet.
- Q: Does account removal come into this feature? → A: Yes. A person can remove their account and
  everything attached to it, from inside Kafoo, without asking anyone. Required by App Store
  Review Guideline 5.1.1 for any app that supports account creation, and cheapest to build now,
  while a person owns nothing but a Kitchen Profile.
- Q: Does this feature extend the canonical analytics events? → A: Yes, a full funnel — signing in,
  each step of the Kitchen Profile conversation including where people give up, the email
  invitation, and removal. Records only *that* a step happened, never what was said. Two
  consequences accepted: removing an account must remove that person's funnel record too, or
  removal is not genuine; and extending the canonical list amends the constitution, so Principle VI
  and `CLAUDE.md` change in the same commit.

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

### User Story 4 - A Customer can see a Cook's kitchen — once there is food in it (Priority: P2)

A Customer looking at a Cook's kitchen sees what it is called, the Cook's story, the area they
cook in, how food reaches people, and a photo. That is the deliberately public face of a Kitchen
Profile, and it is visible whether or not the person looking is signed in. The Cook's phone number
is not part of it.

A kitchen becomes findable only when its Cook has food on offer, and stops being findable when
they have none. Kafoo never shows a Customer a kitchen they cannot order from — an empty shopfront
is a small betrayal repeated at scale.

Being findable and being readable are different things. A Customer who has already ordered from a
Cook can always still see who they ordered from, whether or not that Cook currently has food on
offer. Otherwise a Cook taking a week off would erase themselves from their Customers' history.

**Why this priority**: Without it a Kitchen Profile is a private note rather than a shopfront. It
is P2 because it depends on Kitchen Profiles existing first.

**Scope note**: no kitchen is findable during this feature, because Meals do not exist yet. What
this feature delivers is the rule and its enforcement, proven by test rather than by browsing. The
first genuinely findable kitchen appears when Meals do.

**Independent Test**: With a Cook who has no food on offer, confirm no person can find their
kitchen by any route, while a person holding a direct reference to it can still read exactly the
five public details and nothing more.

**Acceptance Scenarios**:

1. **Given** a Cook whose kitchen is findable, **When** any person views it, **Then** they see the
   kitchen's name, the Cook's story, the area, the delivery terms, and the photo.
2. **Given** a Cook with a Kitchen Profile, **When** any person views it, **Then** they cannot
   reach that Cook's phone number through it by any route.
3. **Given** a Cook who has not finished creating a Kitchen Profile, **When** any other person
   looks for it, **Then** they find nothing.
4. **Given** a Cook with no food on offer, **When** a Customer browses or searches, **Then** that
   kitchen does not appear.
5. **Given** a Customer holding a direct reference to a kitchen that is not currently findable,
   **When** they open it, **Then** they can still read its five public details.

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

### User Story 6 - Adding a second way in, by choice (Priority: P3)

Most Cooks will not have an email address and will never want one. Kafoo therefore never asks for
one to sign in, and never requires one to do anything.

But a person whose only way into Kafoo is a phone number loses everything if that number goes —
stolen, ported, cut off by a carrier. So once someone is using Kafoo and has something a lost
number would actually cost them, Kafoo offers, once, to attach an email address as a second way
in. It explains what it is for in one sentence, in plain Egyptian Arabic. If they say no, it stops
asking.

An address attached this way then works as a sign-in route reaching the same identity. It can only
ever be attached from inside the account, by someone already signed in with the phone number.

**Why this priority**: It protects against a loss that is permanent, but it protects a minority and
must never get in the way of the majority. P3 reflects that ordering, not that it is optional to
build — the guard in FR-029 is what keeps a well-meant prompt from turning into the kind of nagging
the constitution forbids.

**Independent Test**: Complete registration without ever seeing an email field. Later, accept the
invitation, attach an address, sign out, and sign in by email — confirming it reaches the same
identity and the same Kitchen Profile. Separately, decline the invitation repeatedly and confirm it
stops appearing and that nothing is withheld.

**Acceptance Scenarios**:

1. **Given** a person registering for the first time, **When** they complete registration, **Then**
   they were never asked for an email address at any point.
2. **Given** a Cook who has just confirmed a Kitchen Profile — the first moment they own something
   a lost number would cost them — **When** they finish, **Then** Kafoo offers once to attach an
   email address and says plainly what it protects.
3. **Given** a person who declines that offer, **When** they carry on using Kafoo, **Then** nothing
   is withheld or degraded, and after a small number of declines they are not asked again.
4. **Given** a person who has attached an email address, **When** they later sign in with it,
   **Then** they reach their existing identity, including any Kitchen Profile — never a second,
   empty one.
5. **Given** an email address that has never been attached to any account, **When** someone
   attempts to sign in with it, **Then** it reaches nothing — an address cannot claim an identity
   it was not attached to from within.

---

### User Story 7 - A person removes everything and leaves (Priority: P2)

A person decides they are done with Kafoo. From inside Kafoo, without asking anyone and without
explaining themselves, they remove their account. Their Kitchen Profile goes with it, along with
their phone number and any email address they attached. Kafoo confirms they mean it — once — and
then does it.

Afterwards their phone number reaches nothing. Using it again starts a new person from nothing, not
a restoration of who they were.

**Why this priority**: It is not optional. An app that lets people create accounts must let them
remove those accounts from inside the app, and a temporary disable does not satisfy that. It is
also the only thing that makes the retention promise in FR-022 mean anything — a promise to keep
data "while the account exists" is empty if an account can never stop existing.

It is P2 rather than P1 only because nothing can be removed until something can be created.

**Independent Test**: Create an account and a Kitchen Profile, remove the account, then confirm the
Kitchen Profile is gone, the phone number reaches nothing, and signing in with that number again
produces a new person with nothing attached.

**Acceptance Scenarios**:

1. **Given** a signed-in person, **When** they look for how to leave, **Then** they can find it
   without searching — it is not buried, and not harder to reach than creating the account was.
2. **Given** a person who chooses to remove their account, **When** they confirm once, **Then**
   their account, their Kitchen Profile, their phone number and any email address are removed.
3. **Given** a person who has removed their account, **When** they sign in again with the same
   phone number, **Then** they are a new person with nothing attached — not their former self
   restored.
4. **Given** a person part-way through removing their account, **When** they change their mind,
   **Then** they can stop, and nothing has been removed.
5. **Given** a person choosing to leave, **When** Kafoo asks them to confirm, **Then** it asks once
   and does not bargain, delay, or make leaving harder than joining.

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
- **A person removes their account while owning a Kitchen Profile.** The Kitchen Profile goes with
  it. Because no Meals, Orders or Reviews exist yet, nothing else references it — which is exactly
  why removal is being built now rather than after those arrive.
- **A Cook loses their phone number permanently and never attached an email address.** They have no
  way back to their Kitchen Profile on their own. This is the accepted cost of a phone-only route
  for people who decline the second one, and it is why the invitation exists at all. Whether Kafoo
  offers a person-assisted way back — and what would guard it, since moving a number between
  identities is itself a takeover route — is raised in Open Questions.

## Requirements *(mandatory)*

### Functional Requirements

**Identity**

- **FR-001**: A person MUST be able to sign in using only a phone number and a one-time code sent
  to it. No password is created at any point.
- **FR-002**: A phone number MUST resolve to the same person on any device, for as long as that
  number is attached to them.
- **FR-025**: A person's identity MUST exist independently of the phone number that proves it. A
  phone number is a credential attached to a person, never the person themselves.
- **FR-026**: A person MUST be able to change the phone number attached to their identity, keeping
  their Kitchen Profile and everything else that belongs to them. The previous number MUST stop
  reaching that identity immediately.
- **FR-003**: A person MUST NOT be asked to choose between being a Cook and a Customer at any
  point. Every signed-in person can browse and place Orders.
- **FR-004**: A one-time code MUST expire after a short period and MUST be usable only once.
- **FR-005**: Repeated code requests for the same number MUST be refused beyond a reasonable rate,
  and the refusal MUST state when the person may try again.
- **FR-006**: Kafoo MUST NOT reveal, to someone entering a phone number, whether that number is
  already known to it.
- **FR-007**: A person MUST be able to sign in by email as an alternative route, reaching the same
  identity rather than a second one. An email address MUST be attachable only from inside an
  account, after signing in by phone; an address MUST NOT be able to claim an identity it was not
  attached to from within.
- **FR-027**: An email address MUST NOT be required at any point. Registration and every part of
  Kafoo MUST work without one, permanently, for a person who never adds one.
- **FR-028**: Kafoo MUST invite a person to attach an email address once they are using Kafoo,
  stating plainly that it is how they keep their access if they lose their phone number. The
  invitation MUST NOT appear during registration, where it would tax the very flow that is meant
  to be immediate.
- **FR-029**: That invitation MUST be declinable, MUST NOT block or degrade anything if declined,
  and MUST stop being offered after a small number of declines. Repeating an ask the person has
  already refused is a dark pattern, which the constitution forbids outright.

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
  story, area, delivery terms, and photo. Nothing else about its Cook MUST be reachable through it,
  signed in or not.
- **FR-030**: A Kitchen Profile MUST become discoverable to Customers — appearing in browsing or
  search — only while its Cook has at least one published Meal, and MUST stop being discoverable
  when they have none. A Kitchen Profile MUST NOT carry a state of its own; discoverability is
  derived, never stored.
- **FR-031**: A Kitchen Profile MUST remain readable to anyone holding a legitimate reference to it
  — an Order above all — whether or not it is currently discoverable. Discoverability governs
  whether a Customer can *find* a kitchen; it MUST NOT govern whether a Customer who already dealt
  with that Cook can still *see* who they dealt with.
- **FR-020**: A phone number MUST be readable only by the person it belongs to, and MUST NOT be
  reachable through any public view.
- **FR-021**: Ownership MUST be enforced where the app cannot bypass it, and MUST be proven by an
  automatic check that runs on every subsequent change to Kafoo — never verified once by hand.
- **FR-022**: A phone number MUST be collected for one stated reason only — to sign a person in,
  and to let a Cook and a Customer reach each other about a specific Order — and MUST be kept only
  while that person's account exists. Removing the account (FR-032) MUST remove it.
- **FR-032**: A person MUST be able to remove their account from inside Kafoo, without contacting
  anyone. Removal MUST take with it their Kitchen Profile, their phone number, and any email
  address they attached.
- **FR-033**: Removal MUST be genuine removal, not deactivation. A removed account MUST NOT be
  restorable by signing in again; the same phone number MUST produce a new person with nothing
  attached.
- **FR-034**: Removal MUST be confirmed once, and MUST NOT be made harder to reach or harder to
  complete than creating the account was. Kafoo MUST NOT bargain, delay, or require a reason.
  Leaving is where dark patterns are most tempting and most damaging.
- **FR-035**: A person MUST be able to abandon removal part-way through with nothing removed.

**Language**

- **FR-023**: Every string a person sees MUST exist in Egyptian Arabic, which is the default
  language and not a fallback.
- **FR-024**: Every screen in this feature MUST read correctly right-to-left.

**Measurement**

The purpose is one question: *where do Cooks give up?* A supply-constrained marketplace lives or
dies on that number, and a conversation cannot be improved if nobody can see which question loses
people. Everything below serves that and stops there.

- **FR-036**: Kafoo MUST record the sign-in funnel — started, completed, failed — and the Kitchen
  Profile conversation funnel, including which question a Cook was on when they gave up, whether
  they attached an email address when invited, and whether they removed their account.
- **FR-037**: A recorded event MUST capture only *that* a step happened and *which* step it was. It
  MUST NOT capture what a person said, typed, or spoke. A kitchen's name, a Cook's story, an area
  and delivery terms are that Cook's information, not measurement.
- **FR-038**: No recording MUST ever contain voice audio or a transcript of it. Spoken answers are
  understood and discarded, and measurement MUST NOT become the reason a recording is kept.
- **FR-039**: Removing an account (FR-032) MUST also remove or permanently unlink that person's
  recorded events. A person who has asked to be forgotten MUST NOT remain identifiable in
  measurement — otherwise FR-033's promise of genuine removal is false.
- **FR-040**: Recorded events MUST be readable only by people running Kafoo, MUST NOT be used to
  rank or target anything a Customer or Cook sees, and MUST carry a stated retention period.

### Key Entities

- **Person**: Someone known to Kafoo. A person exists in their own right; a phone number is a
  credential attached to them and can be changed without their becoming someone new. Every person
  can browse and place Orders. A person owns at most one Kitchen Profile; owning one is what makes
  them a Cook. Their phone number is readable only by them.
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
- **SC-009**: A person completes registration and reaches a usable Kafoo having been asked for an
  email address zero times.
- **SC-010**: A person who declines the invitation to attach an email address is not asked again
  after a small, stated number of declines, and loses access to nothing by declining.
- **SC-011**: A person can reach account removal in no more steps than it took them to create the
  account, and complete it with a single confirmation.
- **SC-012**: After removal, no information about that person remains reachable by any route —
  recorded events included — and signing in with the same phone number yields a person with nothing
  attached. Verified automatically, alongside the ownership checks in SC-003.
- **SC-013**: For any Kitchen Profile conversation that was abandoned, it is possible to say which
  question the Cook was on when they stopped, without any recorded event containing a word they
  said.

## Assumptions

Reasonable defaults chosen where the description did not specify. Each is a decision that can be
revisited, not an oversight.

- **One account holds both roles.** Decided on 2026-07-29, not assumed. A person becomes a Cook by
  owning a Kitchen Profile; there is no role chosen at signup and no second account. A Cook can
  order Meals from other Cooks. The rule that a Cook cannot review their own Meal therefore
  becomes a comparison between the reviewer and the Meal's Cook, rather than a property of the
  account.
- **Phone number is the only route in, and email is an optional second one.** Decided on
  2026-07-29, not assumed. Most Cooks are not technical and will not have an email address, so
  requiring one — or asking for one during registration — would cost more people than it protects.
  It is offered later, once, to those who have something to lose.
- **The invitation to attach an email is triggered by a Cook confirming a Kitchen Profile**, rather
  than by elapsed time or a count of visits. Chosen because that is the first moment a person owns
  something that losing their number would actually cost them, which is both the most honest time
  to ask and the most persuasive. A Customer who owns nothing is not asked.
- **The AI Assistant is not involved in this feature.** The Kitchen Profile conversation is guided
  and asks one question at a time, which satisfies the constitution's requirement to prefer a
  conversation over a form, but it does not draft, infer, or suggest anything. Having the AI
  Assistant draft a Cook's story from what they say is deliberately deferred to E2, where the
  approval flow it needs is being built anyway. This keeps the feature free of any dependency on a
  model provider.
- **Spoken answers are understood and the recording discarded.** No raw recording is kept; the
  constitution requires a recorded architectural decision before any raw audio is stored, and this
  feature does not propose one. Measurement does not change this — FR-038 exists so that wanting
  funnel data never becomes the reason audio is retained.
- **Measurement is a full funnel, and it is bounded.** Decided on 2026-07-29, not assumed. It exists
  to answer where Cooks give up, which is the number a supply-constrained marketplace most needs.
  It records that a step happened and which one, never what was said (FR-037). It is the largest
  new collection of behavioural data in this feature, which is why FR-039 and FR-040 bound who can
  read it, how long it is kept, what it may not be used for, and that removal reaches it.
- **A one-time code expires after 5 minutes** and may be used once.
- **Removing an account is in scope.** Decided on 2026-07-29, not assumed. Required by App Store
  Review Guideline 5.1.1 for any app supporting account creation, which ADR-0006's TestFlight-first
  route brings forward to Beta App Review. Built now because a person currently owns nothing but a
  Kitchen Profile; after Orders and Reviews exist, removal has to reconcile records a Cook needs to
  keep and Reviews other Customers relied on, which is a materially harder feature.
- **Meals, Orders and Reviews are all out of scope.** A Kitchen Profile in this feature has no
  Meals attached and shows no rating, because neither exists yet. Because discoverability is
  derived from published Meals (FR-030), the practical effect is that **no kitchen is findable
  during this feature at all**. That is the accepted consequence of choosing a derived rule over a
  stored state, and it is why User Story 4 is proven by test rather than by browsing.
- **Delivery terms are free text**, not a structured schedule or a distance calculation.
  Structuring them is a later decision that needs real Cooks' answers to inform it.

## Open Questions

Decisions that materially affect scope, privacy, or user-visible behaviour, and that this
specification does not have the standing to settle. They are listed rather than guessed at.

Two of them — items 2 and 4 — stop being cheap at the same moment: when Reviews ship and a
person's identity starts carrying reputation rather than just a Kitchen Profile.

1. **Settled: a Kitchen Profile has no state of its own.** Decided on 2026-07-29. Discoverability
   is derived from whether the Cook has a published Meal (FR-030), and readability is separate
   (FR-031). The domain model keeps its property that only Meals, Orders and Reviews have
   lifecycles.

   One consequence needs recording rather than discovering later: **`docs/product/domain-model.md`
   must gain the derived-discoverability rule** when this feature is implemented, under Definition
   of Done item 6. It is a domain rule even though it adds no field, and a rule that lives only in
   a feature specification is a rule the next feature will not know about.

2. **Deferred, not open: what happens when a carrier reassigns a phone number?** The modelling half
   of this is settled (FR-025, FR-026) — a person is not their phone number, so a recycled number
   is a credential question rather than an identity question. The *policy* half is deliberately
   deferred: whether a dormant identity expires, and whether restoring one should need more than a
   one-time code. It is deferred rather than answered because the stakes rise sharply once Reviews
   exist — a recycled number inheriting a Cook's Reviews would attach real reputation to the wrong
   person, which is a worse failure than the synthetic Reviews the constitution already forbids.
   **This MUST be settled before Reviews ship, and the decision is cheap only while it is.**

3. **Settled: how long is a phone number kept?** Decided on 2026-07-29. It is kept while the
   account exists and removed when the person removes the account (FR-022, FR-032), which is now
   something they can actually do. The retention answer is no longer circular.

4. **Is there a person-assisted way back for a Cook who loses their number and never attached an
   email?** Most Cooks will decline the email invitation, so this is the common case rather than
   the rare one. Kafoo can offer a human-verified route that attaches a new number to an existing
   person — but that route is, by construction, a way to move an identity to a different phone,
   which is exactly what an attacker wants. It therefore cannot be improvised at the moment it is
   first needed; whatever guards it has to be designed and written down. Left open because it is a
   support process as much as a feature, and because at friends-and-family scale the answer may
   legitimately be "a person handles it case by case" — but that must be a decision, not a gap.

5. **Which event names enter the canonical list, and the amendment that carries them.** The
   constitution names every analytics event and calls the list stable; `CLAUDE.md` repeats it.
   Adding a funnel therefore amends the constitution rather than merely extending a spec, and the
   constitution's own amendment procedure requires every dependent artifact to change in the same
   PR. The names themselves are a naming decision that belongs with that amendment, not here — but
   it MUST happen before implementation, or this feature ships events that no governing document
   knows about. A MINOR version bump, by the constitution's own versioning policy.

## Dependencies

- This is the first feature to store any information in Kafoo. It depends on no earlier feature
  and blocks every later one.
- Sending a one-time code by text message depends on an outside service that has not been chosen
  or paid for. That choice belongs in `plan.md`; that it carries a recurring cost per message is
  noted here because it bears on whether the phone route can be the primary one.
