# Feature Specification: Customer Discovery

**Feature Branch**: `004-customer-discovery`

**Created**: 2026-08-06

**Status**: Draft

**Input**: User description: "E3 — Customer discovery. A Customer finds a Meal or a kitchen without holding a direct reference to it."

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

E1 made a person known to Kafoo and gave them a kitchen. E2 put food on offer and made a kitchen
readable. **Nothing finds one.**

A Customer who does not already know a Cook has no route to any Meal in Kafoo. The rule that decides
what is findable was built in E2 — a Kitchen Profile is discoverable exactly while its Cook has a
Meal on offer — but nothing yet acts on it. This feature is where Kafoo stops being a place Cooks
publish into and becomes a place Customers arrive at.

**The hard part is not finding things. It is being honest about not finding them.**

A Customer asking for food in Egyptian Arabic is asking a question Kafoo can only answer
approximately, against a small number of kitchens, most of which are closed at any given moment. The
easy design hides that: it always returns its five best guesses, ranked confidently, and lets the
Customer discover for themselves that none of them is what they asked for. That design is cheaper to
build and it spends the trust Kafoo has not yet earned.

**So the organising rule of this feature is that Kafoo says when it does not have what was asked
for.** Everything else — how requests are understood, what is ranked, what the AI Assistant
contributes — is downstream of that.

Two further things follow from Kafoo's existing rules rather than from this feature:

**Discovery must not require an install.** A Cook sharing their kitchen is Kafoo's cheapest route to
a new Customer, and a person who has never used Kafoo is the least willing to install anything.

**Discovery must not need to know where the Customer is.** A Kitchen Profile already states its area
in the Cook's own words. Matching against that is less precise than knowing a Customer's location
and it is the version that does not collect a new category of personal data about a population Kafoo
has never collected anything about.

## Clarifications

### Session 2026-08-06

- Q: Is discovery reachable by a Customer who has not installed anything? → A: **Yes, both.**
  Discovery works inside Kafoo and for someone arriving without having installed it. The two show
  the same Meals under the same rules.
- Q: Does Kafoo collect a Customer's location in order to find kitchens near them? → A: **No.** A
  Kitchen Profile already states its area; that is what discovery matches against. "Near me" means
  "in the area you name", never a distance.
- Q: When does the AI Assistant speak? → A: **After results are shown, on every request**, to judge
  whether any of them honestly answers it. It was originally specified to speak only when nothing
  was found; measurement established that a request nothing answers cannot be told apart
  mechanically from one that is answered, so "nothing found" has to be judged rather than counted.
- Q: Can a Customer place an Order from what they discover? → A: **No.** Orders are E4. Discovery
  ends at a Meal and its kitchen.
- Q: What may a shared reference to a kitchen reveal about a Cook before it is opened? → A: **The
  kitchen's name, its area, and its photo. Nothing else.** Opening it shows the five details that
  are already public and no sixth. Kafoo does not hold a Cook's personal name, phone number,
  address or location, and this feature MUST NOT introduce any of them.
- Q: Can a Customer search for a Cook by name? → A: **No.** Discovery is about food. A Customer
  arrives wanting koshari, not wanting a named person. Following a Cook is the better answer to what
  name search is reaching for, and it needs Orders to exist first — it is not in E3.
- Q: A Customer's words have to leave Kafoo to be understood. May they refuse? → A: **Always.**
  Asked **once**, the first time they try to search, and the answer is remembered. A switch in
  Settings turns it on or off later, and once answered the question is never asked again. **Refusing
  falls back to browsing**, which is a complete way to use Kafoo rather than a punishment.
- Q: Where is that choice kept? → A: **On the Customer's own device.** Kafoo holds no record of a
  Customer at all, and discovery works without signing in — so a choice kept on Kafoo's side would be
  impossible for exactly the person the shareable link exists for. It also means the refusal itself
  creates no data about anyone.
- Q: With the switch off, can a Customer still search in some reduced way? → A: **No, and this is
  worth being blunt about.** A phrase leaves Kafoo to *become searchable at all*, not merely to be
  commented on. There is no halfway state where search works and nothing is sent. Off means browsing.
- Q: A Cook writes their area one way and a Customer names it another — `الدقى` against `الدقي`,
  `مهندسين` against `المهندسين`. → A: **Same area.** A Customer must not be blind to a kitchen
  because of a spelling. This covers how a name is written, not what it means: two genuinely
  different neighbourhoods stay different.
- Q: What happens when the area a Customer named has nothing on offer but another area does? → A:
  **Kafoo says the named area is empty and names the areas that do have food, then lets the Customer
  choose.** It never switches areas by itself. It states no distance and implies no deliverability,
  because Kafoo holds neither.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Customer sees what is on offer (Priority: P1)

A Customer opens Kafoo having said nothing. Kafoo shows the Meals that Cooks currently have on
offer, and from any of them the Customer can reach the kitchen behind it and read who cooks it.

**Why this priority**: It is the whole feature at its smallest. It works when there are twelve
Meals, which is the situation Kafoo is actually in, and it is what every other story falls back to.
Nothing else here is usable without it.

**Independent Test**: With several Cooks each having Meals in different states, open Kafoo without
searching. Every Meal on offer appears; no draft, unavailable or archived Meal does. Each Meal leads
to its kitchen.

**Acceptance Scenarios**:

1. **Given** three Cooks with Meals on offer and one Cook whose Meals are all drafts, **When** a
   Customer browses, **Then** only the three Cooks' Meals appear and the fourth kitchen is absent
   entirely.
2. **Given** a Meal on offer, **When** the Customer opens it, **Then** they can read the Meal and
   reach the Kitchen Profile that offers it.
3. **Given** a Cook takes their last Meal off the menu while a Customer is browsing, **When** the
   Customer next looks, **Then** that Meal and that kitchen are gone rather than leading to an empty
   shopfront.
4. **Given** no Cook anywhere has a Meal on offer, **When** a Customer browses, **Then** Kafoo says
   plainly that nothing is on offer right now rather than showing an empty screen.

---

### User Story 2 - A Customer asks for food in their own words (Priority: P2)

A Customer says or types what they feel like eating, in Egyptian Arabic, the way they would say it
to a person. Kafoo shows Meals that match what they meant — not the words they used.

**Why this priority**: It is the product thesis, and it is what makes Kafoo usable once there are
four hundred Meals rather than twelve. It depends on Story 1 for its starting point and its fallback.

**Independent Test**: Issue requests that share no words with the Meals that should answer them, and
requests written in a different language from the Meals, and confirm the right Meals are returned.

**Acceptance Scenarios**:

1. **Given** a Meal described in Arabic, **When** a Customer types the same food in another language
   or another script, **Then** that Meal is among the results.
2. **Given** Meals whose descriptions never use the Customer's words, **When** a Customer asks for
   something light, or something warming, or something their children would like, **Then** Kafoo
   returns Meals that fit the meaning.
3. **Given** a request, **When** Kafoo has results, **Then** they are shown before the AI Assistant
   has finished considering them — the Customer never waits on the AI Assistant to see results.
4. **Given** a Customer has not said anything yet, **When** they open search, **Then** they see what
   is on offer rather than an empty box.
5. **Given** a Meal matches a request but is not currently on offer, **When** results are shown,
   **Then** that Meal does not appear at all.

---

### User Story 3 - Kafoo says when it has nothing, instead of guessing (Priority: P2)

A Customer asks for something no Cook currently offers. Kafoo tells them so, and names what is
actually on offer that comes closest, rather than presenting its best guesses as answers.

**Why this priority**: It ships with Story 2 and cannot be deferred behind it. Search that always
answers confidently is the failure mode this feature exists to avoid, and Principle I puts trust
above every other consideration.

**Independent Test**: Ask for a food nothing in Kafoo resembles. Kafoo must state that nothing
matches. Then ask for something that is on offer and confirm it does not say the same thing.

**Acceptance Scenarios**:

1. **Given** no Cook offers anything resembling the request, **When** the Customer asks, **Then**
   Kafoo states that nothing on offer answers it.
2. **Given** the same situation, **When** Kafoo says nothing matches, **Then** it names Meals that
   *are* on offer, and every Meal it names is genuinely on offer at that moment.
3. **Given** a request that several Meals do answer, **When** results are shown, **Then** Kafoo does
   not claim nothing matched.
4. **Given** Kafoo has said nothing matches, **When** the Customer opens a Meal it suggested
   instead, **Then** that is recorded as a suggestion the Customer acted on.

---

### User Story 4 - An exclusion is honoured exactly (Priority: P2)

A Customer says what they do not want — no meat, nothing fried, nothing with nuts. Kafoo does not
show it to them.

**Why this priority**: A Customer excluding a food is usually doing so for dietary, religious or
health reasons, and serving them the opposite is a betrayal rather than a poor result. Kafoo already
treats allergy and dietary information as health-adjacent. Measurement established that matching by
meaning alone gets exclusions **backwards** — asking for food with no meat returned meat — so this
needs to be specified as its own guarantee rather than assumed to fall out of Story 2.

**Independent Test**: Ask for food excluding something that several Meals on offer contain. Not one
of those Meals may appear, at any position.

**Acceptance Scenarios**:

1. **Given** Meals containing meat are on offer, **When** a Customer asks for food with no meat,
   **Then** no Meal containing meat appears anywhere in the results.
2. **Given** an exclusion removes everything on offer, **When** results would be empty, **Then**
   Kafoo says so plainly rather than relaxing the exclusion to fill the screen.
3. **Given** a Customer excludes something Kafoo cannot determine for a Meal, **When** results are
   shown, **Then** that Meal is withheld rather than included on the assumption it is safe.

---

### User Story 5 - Someone finds a kitchen without installing anything (Priority: P3)

A person who has never used Kafoo, and has installed nothing, can find a kitchen, read its Meals,
and see who cooks them.

**Why this priority**: It is how a Cook's own sharing reaches people, and it is the point of Kafoo
being reachable at all without an install. It is P3 because Stories 1 to 4 must be right first —
this widens the audience for discovery rather than changing what discovery is.

**Independent Test**: Reach a kitchen and its Meals having installed nothing and signed in to
nothing. Everything visible must obey the same rules as inside Kafoo.

**Acceptance Scenarios**:

1. **Given** a Cook with a Meal on offer, **When** someone with nothing installed reaches that
   kitchen, **Then** they see the kitchen's five public details and the Meals on offer.
2. **Given** a Cook has taken every Meal off the menu, **When** someone reaches that kitchen without
   installing anything, **Then** they are told the kitchen has nothing on offer rather than shown an
   empty page or a Meal they cannot order.
3. **Given** the same Meal, **When** it is seen with and without installing Kafoo, **Then** both show
   the same details and neither reveals anything the other withholds.

---

### Edge Cases

- **Nothing is on offer anywhere.** Kafoo says so. It never fills the screen with archived Meals,
  drafts, or kitchens that are closed.
- **A Meal goes off offer between being ranked and being opened.** The Customer is told it is no
  longer available rather than shown a Meal they cannot order.
- **A request in a script Kafoo's Meals are not written in.** Handled — it must find the Meal anyway.
- **A request mixing two scripts in one sentence**, which is ordinary in Egyptian typing.
- **A very long spoken request** that wanders before arriving at what the person wants.
- **A request that is not about food at all.** Treated as nothing matching, not as an error.
- **The Customer names an area no Cook has written.** Kafoo says nothing is on offer there rather
  than silently widening to everywhere.
- **Two Cooks write the same area differently** — the same neighbourhood spelled two ways, or named
  by a landmark. A Customer naming one must not be blind to the other.
- **Voice is unavailable or mishears.** Typing always works and is never a lesser path.
- **Every Cook offers the same dish.** Results must not be forty near-identical entries with no way
  to tell them apart.
- **The AI Assistant's judgement fails or is slow.** Results stay on screen; the Customer loses a
  sentence, never their results.

## Requirements *(mandatory)*

### Functional Requirements

**Browsing and what is findable**

- **FR-001**: A Customer MUST be able to see the Meals currently on offer without having said
  anything.
- **FR-002**: Only Meals on offer MUST appear in discovery. A draft, an unavailable, or an archived
  Meal MUST NOT appear, in browsing or in results.
- **FR-003**: A Customer MUST be able to reach the Kitchen Profile behind any Meal they find.
- **FR-004**: A kitchen MUST be findable exactly while it has at least one Meal on offer, and MUST
  disappear from discovery when it has none.
- **FR-005**: Discovery MUST reflect what is on offer at the moment it is asked, not what was on
  offer earlier.
- **FR-006**: When nothing is on offer, Kafoo MUST say so in words rather than presenting an empty
  screen.

**Asking for food**

- **FR-007**: A Customer MUST be able to ask for food in Egyptian Arabic, in their own words, by
  speaking or by typing.
- **FR-008**: Typing MUST always be available and MUST NOT be a degraded path. Speaking MUST be
  offered where the Customer's device supports it and MUST fail to typing when it does not.
- **FR-009**: Kafoo MUST match a request by what it means rather than by the words it uses, so that a
  Customer who shares no vocabulary with a Meal's description still finds it.
- **FR-010**: A request phrased in a different language or script from a Meal's description MUST
  still find that Meal.
- **FR-011**: Results MUST be shown to the Customer before the AI Assistant has finished considering
  them. The AI Assistant MUST NOT sit between a Customer and their results.
- **FR-012**: Browsing what is on offer MUST be what a Customer sees before searching and what they
  are returned to when nothing matches.

**Honesty about what was not found**

- **FR-013**: The AI Assistant MUST judge whether the results honestly answer the request.
- **FR-014**: When nothing on offer answers a request, Kafoo MUST say so rather than presenting its
  closest guesses as answers.
- **FR-015**: When Kafoo says nothing matches, it MUST name Meals that are genuinely on offer at that
  moment as alternatives.
- **FR-016**: The AI Assistant MUST NOT describe a Meal as popular, well-reviewed, or frequently
  ordered. Kafoo measures none of these.
- **FR-017**: The AI Assistant MUST NOT describe a Meal as near the Customer or state a distance.
  Kafoo does not know where the Customer is.
- **FR-018**: The AI Assistant MUST NOT create, change, publish or remove anything as part of
  discovery. It ranks, judges and explains only.

**Exclusions**

- **FR-019**: A Customer MUST be able to exclude a food, and every excluded Meal MUST be absent from
  results entirely.
- **FR-020**: An exclusion MUST NOT be relaxed to produce more results. If it empties the results,
  Kafoo says so.
- **FR-021**: Where Kafoo cannot establish whether a Meal contains an excluded thing, that Meal MUST
  be withheld rather than shown.

**Area**

- **FR-022**: A Customer MUST be able to narrow discovery to an area, using the areas Cooks have
  stated about their own kitchens.
- **FR-022a**: An area written differently by a Cook and a Customer MUST be treated as the same area.
  A kitchen MUST NOT be unreachable because of a spelling. This governs how a name is *written* — two
  genuinely different neighbourhoods remain different, and Kafoo MUST NOT merge them.
- **FR-022b**: Where an area is widely known by more than one name, all of them MUST reach the same
  kitchens. Kafoo MUST NOT require a Customer to guess which name a Cook happened to write.
- **FR-023**: Kafoo MUST NOT collect, request, derive or store a Customer's location. No new personal
  data about Customers is created by this feature.
- **FR-024**: When nothing is on offer in the area a Customer named, Kafoo MUST say so rather than
  silently showing kitchens elsewhere.
- **FR-024a**: In that case Kafoo MUST also name the other areas that do have food on offer, and
  MUST require the Customer to choose one before showing anything from it. Widening MUST be the
  Customer's action, never Kafoo's.
- **FR-024b**: Kafoo MUST NOT state a distance between areas, or order them by proximity. It holds
  no location for any Customer, and no notion of where any area is or how far apart two areas are.
  An area is a phrase a Cook wrote about their own kitchen, nothing more.
- **FR-024c**: Offering another area MUST NOT state or imply that a kitchen there will deliver to the
  Customer. Kafoo holds a Cook's delivery terms as words and cannot evaluate them.

**Reaching discovery without an install**

- **FR-025**: A person MUST be able to find a kitchen and read its Meals without installing anything
  and without signing in.
- **FR-026**: What is visible without installing MUST be exactly what is visible inside Kafoo —
  neither more nor less — and MUST obey every rule in this specification unchanged.
- **FR-027**: A kitchen with nothing on offer MUST NOT be reachable this way, on the same terms as
  FR-004.
- **FR-027a**: A shared reference to a kitchen MUST reveal, before it is opened, exactly three
  things: the kitchen's name, its area, and its photo. It MUST NOT reveal the Cook's story, their
  delivery terms, how many Meals they have, or anything derived from them.
- **FR-027b**: Kafoo MUST NOT introduce a Cook's personal name, phone number, address, or location
  as part of this feature. A Kitchen Profile's public face stays at exactly five details, and the
  Cook's phone number is never copied out of the record that authenticates them.
- **FR-027c**: Nothing in discovery MUST display a rating, a review count, an order count, or any
  other measure of a Cook's standing. None of these exist yet, and a placeholder for one is a
  fabricated measurement rather than an empty field.

**Language, measurement and trust**

- **FR-028**: Every string a Customer reads MUST exist in Egyptian Arabic and in English, with
  Arabic written first, and MUST render right-to-left.
- **FR-029**: Kafoo MUST record that a search happened and how many results it returned. It MUST NOT
  record what was searched for.
- **FR-029a**: Before a Customer's words leave Kafoo for the first time, Kafoo MUST say that they
  will and MUST let the Customer refuse. Browsing MUST NOT require an answer — the question is asked
  at the first attempt to search, never on arrival.
- **FR-029b**: The answer MUST be asked **once** and remembered. A Customer who has answered MUST NOT
  be asked again, whichever way they answered.
- **FR-029c**: A Customer MUST be able to change the answer at any time, in one place, in both
  directions.
- **FR-029d**: The answer MUST be kept on the Customer's own device and MUST NOT be stored by Kafoo.
  Kafoo holds no record of a Customer, and discovery works without signing in; a choice kept on
  Kafoo's side would be unavailable to exactly the person who arrives by a shared link.
- **FR-029e**: With the answer set to refuse, Kafoo MUST NOT send a Customer's words anywhere, and
  search MUST be unavailable rather than degraded. Kafoo MUST say plainly that searching is off and
  that browsing still works. There MUST NOT be a reduced form of search that matches on spelling.
- **FR-030**: Kafoo MUST record when a search returned nothing, and when a Customer acted on a Meal
  the AI Assistant suggested.
- **FR-031**: No Meal, Cook or Kitchen Profile that is not a real Cook's own MUST ever appear in
  discovery, including as an example, a placeholder, or a demonstration.

### Key Entities

- **Meal** — unchanged by this feature. Discovery reads Meals; it never writes one. What discovery
  adds is that a Meal must be *reachable by meaning*, not only by reference.
- **Kitchen Profile** — unchanged. Its **area**, already one of exactly five public details, becomes
  the basis of narrowing discovery by place. Adding a sixth public detail is out of scope.
- **Request** — what a Customer asked for, in their own words. Held for the length of the
  interaction and never stored as truth about the Customer.
- **Recommendation** — what the AI Assistant offers when nothing matched. Owned by nobody, never
  persisted as truth, and never presented as a Meal the Customer asked for.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A Customer who has never used Kafoo can reach a Meal's full details within three
  actions of arriving, without searching and without signing in.
- **SC-002**: A request phrased in a different language or script from a Meal's description returns
  that Meal in the top five results in at least 95% of tested cases.
- **SC-003**: For requests that something on offer genuinely answers, a relevant Meal appears in the
  top five in at least 80% of tested cases.
- **SC-004**: For requests that nothing on offer answers, Kafoo states this rather than presenting
  results as answers in **100%** of tested cases. This criterion does not degrade with corpus size.
- **SC-005**: An excluded food appears in results **zero** times across the exclusion test set. Any
  occurrence is a failure of the feature, not a ranking miss.
- **SC-006**: Results appear within **1.5 seconds** of a Customer finishing their request.

  **This said one second until 2026-08-08 and was raised by the founder, not relaxed to fit.**
  The criterion had never been measured — the one-second figure was an estimate, and the 27 ms
  quoted elsewhere for ranking is `EXPLAIN ANALYZE` inside Postgres rather than a Customer's wait.
  Measured end to end for the first time that day: 1112 ms median, 1438 ms at p95, at a corpus of
  1,013 Meals. `docs/ops/measuring-discovery.md` carries the figures, the method, and what it does
  not cover.

  **Corpus size is not what spends it.** The same measurement at 13 Meals and at 1,013 moved the
  ranking scan by about 2 ms. What grows is the response: 415 ms of the median wait is the
  `embedding` column being serialised into a payload no client reads. That is a fixable cost and
  is not absorbed by this criterion.
- **SC-007**: The AI Assistant's judgement never delays results appearing. Measured as the time
  between a request finishing and results being visible, which must be unaffected by whether the AI
  Assistant has responded.
- **SC-008**: A Meal not on offer appears in discovery **zero** times, including where a Cook changes
  a Meal's state during the interaction.
- **SC-009**: Everything visible without installing Kafoo is identical to what is visible inside it,
  verified field by field against the five public details of a Kitchen Profile.
- **SC-010**: This feature adds **zero** new categories of personal data about Customers.
- **SC-011**: No search phrase a Customer typed or spoke is recoverable from anything Kafoo records.
- **SC-012**: A shared reference to a kitchen reveals exactly three things before it is opened —
  name, area, photo — verified against the shared reference itself rather than the page it leads to.
  Any fourth is a failure.
- **SC-013**: This feature adds **zero** fields to a Kitchen Profile's public face, which stays at
  five, and **zero** new personal details about a Cook.
- **SC-014**: A Customer who has refused sends **zero** words to anything outside Kafoo, verified by
  watching what leaves rather than by reading the code that decides.
- **SC-015**: A Customer is asked about this **once**. After any answer, the question appears zero
  times until they change it themselves.

## Assumptions

- **A Customer cannot order what they find.** Orders are E4. Discovery ends at a Meal and the
  kitchen behind it. A Meal being findable does not imply it can be acted on.
- **The marketplace is small at first.** Browsing is expected to be the more useful path until there
  are enough Meals for searching to beat looking. Both must work at twelve Meals and at four
  thousand.
- **A Cook's stated area is free text in their own words** and is not validated, standardised, or
  checked against a list of places. Matching a Customer's named area against it is therefore
  approximate, and FR-024 exists because that approximation must fail visibly.
- **Delivery is a matter between the Customer and the Cook.** Kafoo holds a Cook's delivery terms as
  words, not as a radius, and this feature does not interpret them.
- **Speech recognition in Egyptian Arabic is unverified on real hardware.** Every requirement here is
  written so that typing alone satisfies it.
- **Discovery reads and never writes.** No Meal, Kitchen Profile or Customer record is created or
  changed by anything in this specification.

## Deliberately out of scope

**Searching for a Cook by name.** Discovery is about food. A Customer arrives wanting koshari, not
wanting a named person, and a directory of Cooks is a different feature carrying a different privacy
question. Excluded from E3 by the founder, 2026-08-06.

**Following a Cook.** This is the better answer to what name search reaches for — a Customer who
liked Fatma's cooking should not have to search for her again — and it is stronger for retention
than any name search would be. It is not in E3 for three reasons, each of which would be enough on
its own: it is only meaningful once a Customer has *ordered* from a Cook, which is E4; it creates a
lasting relationship between a Customer and a Cook, which is a new category of personal data; and
telling a Customer that Fatma is cooking today requires a way of reaching them that Kafoo does not
have. Recorded here so it is picked up deliberately rather than rediscovered.

**Anything a Cook does.** This feature is read-only and Customer-facing throughout. A Cook's view of
how they are found — what Customers searched before reaching them, how often their kitchen appeared
— is not part of it, and the measurement rules make most of it unanswerable by design.

**Ordering, and everything that implies.** No basket, no price total, no fees, no availability
window a Customer can act on. Discovery ends at a Meal and the kitchen behind it.
