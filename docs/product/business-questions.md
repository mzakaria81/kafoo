# Business questions

What Kafoo needs to be able to answer, and whether it can. Written 2026-08-08, at the founder's
instruction, instead of opening an analytics epic — the epic was considered and deferred, and the
reasoning is in "Why this is a page and not an epic" at the foot.

**This document does not add instrumentation. It decides what would be lost by waiting**, and
everything in "Collect now" was built in the same change that created this file.

`docs/product/event-model.md` is the registry — names, attributes, retention, and the rules. This
file is the demand side: the questions, and whether the registry answers them. When the two
disagree, the registry is the source of truth about what is emitted and this file is a statement of
what somebody wanted.

---

## The test that decides everything here

**Can this be answered later, from data that will still exist?**

Kafoo's database holds *state* — the Meals on offer, the Kitchen Profiles, the Orders once E4
exists. State can be queried at any time, so a question answerable from state is never urgent. A
question answerable only from a *moment* — somebody searched, somebody opened a thing, somebody gave
up — is answerable only if something recorded the moment as it happened.

So the only work that is urgent is the work that is **not recoverable**. Everything else can wait
for evidence that it is worth doing, and waiting is the cheaper mistake.

There is a second test underneath it, and it is the one that actually constrains Kafoo:

**Would recording this be collecting something we have promised not to?** A question that fails this
test does not get answered by working harder at it. It gets answered by a decision, taken
deliberately, with its own consent copy and its own retention answer — or it does not get answered.

---

## The questions

Grouped by who is asking. `✅` means answerable from what exists today; `⏳` means it becomes
answerable when the feature that would emit it ships; `➕` means something was added on 2026-08-08
because waiting would have lost it; `🚫` means deliberately unanswerable.

### Supply — is there anything to buy?

| Question | Answerable? | From what |
|---|---|---|
| How many Cooks have a Kitchen Profile? | ✅ | State: `kitchen_profiles` |
| How many Meals are on offer right now, and in which categories? | ✅ | State: `meals` |
| Which areas have Cooks in them? | ✅ | State: `kitchen_profiles.area` |
| How many Cooks start a Kitchen Profile and never finish? | ✅ | `ConversationStarted` without `ConversationCompleted`; the last `ConversationStepCompleted` says where they stopped |
| How many Meals are drafted and never published? | ✅ | `MealDrafted` against `MealPublished` |
| Do Cooks who publish once publish again? | ✅ | `MealPublished` over time, per person |
| Are Cooks speaking to Kafoo or typing at it? | ✅ | `ConversationStarted.input` and `.speech_locale` — the latter is how we learn whether Egyptian Arabic recognition is actually being served |
| Do Cooks keep their menus current, or does the marketplace go stale? | ✅ | `MealUpdated.changed`, `MealArchived` |

**Supply is well covered, and that is not luck.** E1 and E2 instrumented the Cook's side properly
because the Cook's side is where the conversational bet had to be measured.

### Demand — does anybody want it?

| Question | Answerable? | From what |
|---|---|---|
| How many searches happen? | ➕ | `SearchPerformed` — **recorded nothing for signed-out Customers until 2026-08-08.** See "The hole this document found" |
| **What type of food do people search for?** | ➕ | `SearchPerformed.top_cuisine` / `.top_category` — added 2026-08-08 |
| What do Customers actually choose to open? | ➕ | `MealOpened` — added 2026-08-08 |
| Is search earning its keep against browsing? | ➕ | `MealOpened.source` — added 2026-08-08 |
| How often does Kafoo have nothing that answers? | ✅ | `SearchFailed` |
| Is that because the menu is thin, or because there are no Cooks near them? | ➕ | `SearchPerformed.area_narrowed` — added 2026-08-08 |
| Does the AI Assistant's judgement help anyone? | ✅ | `RecommendationAccepted` against `SearchFailed` |
| **What are people asking for that Kafoo does not have?** | 🚫 | Needs the phrase. See "Deliberately unanswerable" |
| How many Customers refuse to let their words leave? | 🚫 | The answer never leaves the device — FR-029d. See "Deliberately unanswerable" |
| Do Customers come back? | ⏳ | Needs Orders (E4). A signed-out browser is not a person and must not become one |

### The transaction — E4 and E5, and not before

| Question | Answerable? | From what |
|---|---|---|
| How many Orders are placed, accepted, rejected, cancelled, completed? | ⏳ | The Order lifecycle events are already named in the registry, and the rows themselves will carry the history |
| How long does a Cook take to accept? | ⏳ | State: Order timestamps. Recoverable, so not urgent |
| What share of completed Orders get a Review? | ⏳ | State: Orders and Reviews. Recoverable |
| Which Cooks are worth recruiting more of? | ⏳ | Orders per Cook, per category. Recoverable from state once Orders exist |

**Every question in this section is recoverable from state.** That is the strongest argument for not
building an analytics epic today: the part of the business that matters most is also the part that
records itself.

---

## The hole this document found

**`SearchPerformed`, `SearchFailed` and `RecommendationAccepted` were being discarded by the
database for every signed-out Customer, silently, since E3 shipped.**

`analytics_events` has an `anon` insert policy written in E1 that allows exactly two event names —
`SignInStarted` and `SignInFailed` — because in E1 those were the only two things that could happen
before somebody was known to Kafoo. It was right when it was written.

E3 then built discovery on the premise that it works without an account. That premise is the whole
reason a shared WhatsApp link is worth anything, and it is why the web surface exists at all. Every
search event it emits arrives at the database as an anonymous insert of a name that policy does not
allow, is rejected with 42501, and is swallowed — `emitEvent` catches everything on purpose, because
a measurement outage must never interrupt a Customer.

**Nothing was broken loudly enough to notice.** The app works. The web works. The gate is green.
`analytics_events_rls_test.sql` case 3 asserts that an anonymous caller cannot insert a non-funnel
event, and it passes — it was written to describe E1's world and it still describes it correctly.

Three things are worth taking from this beyond the fix:

- **A silent failure that is correct by design is the hardest kind to see.** The `catch` in
  `emitEvent` is right, and it is what hid this for the whole of E3.
- **An authorization rule written as a closed list ages differently from one written as a
  principle.** "These two names" was precise and became wrong; "an anonymous caller may record what
  an anonymous caller can do" would have aged.
- **The gate cannot catch this class.** It has no way to know that a feature emits an event a policy
  forbids, because the two live in different languages in different directories. That is a gap worth
  a check, and it is noted rather than built here.

---

## Collect now — the irrecoverable minimum

Four things, built on 2026-08-08. All of them are bounded vocabularies Kafoo controls. **None of
them is free text, and none is derived from anything a Customer said.**

### 1. Let a signed-out Customer's discovery events reach the table

The migration widens the anonymous insert policy to the discovery events with `person_id` forced to
null. Without it, nothing else on this list has anywhere to go.

### 2. `SearchPerformed` gains `top_cuisine` and `top_category`

The `cuisine` and `category` of the **first result** — the one the ranker thought best answered the
request. Both are fixed enums in `packages/domain/lib/meal.dart` (ten cuisines, nine categories),
never shown to anyone, chosen from a list rather than typed.

**Read this as what Kafoo served, not as what the Customer asked for**, and the difference is not
pedantic. Matching by meaning always returns something: a Customer asking for sushi against a corpus
with no sushi still gets a top result, and its category would be recorded as though it were demand.
That is exactly the failure research.md §4 measured when a score threshold was tried.

What makes it honest is reading it beside `SearchFailed`, which is the AI Assistant's judgement that
nothing on offer answered. High `top_category: main` with a low `SearchFailed` rate is real demand
for main dishes. The same number with a high `SearchFailed` rate is Kafoo repeatedly offering main
dishes to people who wanted something else.

### 3. `SearchPerformed` gains `area_narrowed`

A boolean: whether the search was restricted to an area. With `result_count: 0` it separates the two
failures a marketplace must never confuse — **"there are no Cooks near this person"** is a
recruitment problem in a named place, and **"the menu has nothing like this"** is a different problem
with a different fix. Today they arrive looking identical.

**A boolean and never the area itself.** The area is a phrase a Customer said, extracted from their
own sentence, and recording it is recording part of what they typed.

### 4. `MealOpened` — a new Level 2 event

`source` (`browse` or `search`), `cuisine`, `category`. Emitted when a Customer opens a Meal.

This is the strongest demand signal Kafoo can have before Orders exist, because it records what
somebody **chose** rather than what the ranker returned. It is also the only way to answer whether
search is worth what it costs: search runs an embedding call and an AI judgement per query, and
`source` is what says whether anybody arrives through it.

**`rank` was considered and dropped.** `RecommendationAccepted` already carries it for the one case
where position is the question. A rank on every open is a number nobody has a decision waiting on,
and the registry's own rule is not to add those.

---

## Deliberately unanswerable

Each of these is a real question with real value. Each is refused for a stated reason, and each
could be reopened by a decision — not by an implementation.

### What are people asking for that Kafoo does not have?

**This needs the phrase, and the phrase is not recorded anywhere.** Not a log line, not a cache, not
an analytics attribute — FR-029 and SC-011, and both Edge Functions go out of their way to keep it
out of their own error bodies.

The reason is not squeamishness. A search phrase in a food marketplace routinely carries health
information: *"من غير جلوتين"* is a coeliac diagnosis and *"عندي حساسية من الفول السوداني"* is a
peanut allergy, volunteered, attached to a timestamp.

And the Customer has been **told**, in the consent question they answer before their first search,
that Kafoo does not record these words or keep them. Recording them makes that false, which means
re-asking everybody who has already answered — the most expensive thing in this whole area, and a
cost that grows with every Customer Kafoo gains.

**What it would take:** its own decision, its own retention answer, no join to a person, and new
consent copy on both surfaces. `event-model.md` already says exactly this. It is worth reopening
when there are enough Cooks that "recruit somebody who makes X" is an action Kafoo can take — not
before, because a signal nobody can act on is not worth a promise.

### Which foods do Customers avoid?

`discover` already extracts a canonical exclusion id — `meat`, `peanut`, `gluten` and ten others —
so this one is *technically* the cheapest thing on the page. **It is the most sensitive, and the
apparent cheapness is the trap.**

A row saying somebody avoids peanuts is health data about a named moment. Privacy rule 1 says
collect only what a named feature needs today, and no feature needs this. Rule 4 says allergy and
dietary signals never leave the Customer's own session, which this would plainly breach. The
business rules call the same thing out independently.

**Not reopened by a decision about analytics.** If it is ever wanted it is a health-data decision,
and it starts somewhere other than this document.

### How many Customers refuse to let their words leave?

Genuinely valuable — it is the only way to know what the privacy stance costs in conversions. And
**it is unanswerable as the specification currently stands**: FR-029d says the answer is kept on the
Customer's own device and MUST NOT be stored by Kafoo.

It cannot be approximated either. A Customer who refuses emits nothing at all, and there is no
arrival event to compare against, so "searches per visitor" has no denominator.

**What it would take:** a founder decision amending FR-029d to permit recording the *outcome* — one
of two values, with no phrase and no person attached. Defensible, and deliberately not taken here,
because a document about analytics is precisely the wrong place to quietly weaken a privacy
guarantee. Recommendation: leave it closed until the refusal rate is suspected of being high enough
to matter.

### Who is this individual Customer and what do they like?

Never. Events do not rank, target or personalise anything anybody sees — Privacy rule 4 — and
discovery deliberately works without an account, so there is usually no person to attach anything to.
This is not a gap.

---

## Where this work lives

**Analytics stays tied to the feature that generates the event.** Founder's instruction, 2026-08-08,
and it is also how E1 and E2 produced instrumentation good enough that the supply table above is
nearly all `✅`.

Concretely:

- The event's attributes are decided by the change that emits it, by whoever understands what the
  moment means. A central analytics workstream written months earlier does not know what a step in
  the Cook's conversation is for.
- A new event is a row in `event-model.md` — Level 2, ordinary review. Only the core list behind
  Principle VI needs a constitutional amendment.
- **This file is not a to-do list and must not become one.** It is the demand side, reviewed when a
  question changes, and the registry is what says what exists. Two lists of events would drift, and
  the direction they drift is a number somebody trusts that nothing emits.

---

## Why this is a page and not an epic

The founder proposed an analytics epic on 2026-08-08. It was considered and deferred, for reasons
worth keeping so the question can be reopened on evidence rather than re-argued from scratch:

- **The registry already holds the design.** The Order and Review events are named, statused and
  scheduled. The work is not undone; it is queued behind the features that emit it.
- **Two of the four steps in the only funnel that matters do not exist.** Find → open → order → come
  back. Orders are E4 and returning is E5. Measurement designed for a transaction nobody can make is
  measurement designed against imagination.
- **There are no Customers yet.** Analytics reads behaviour, and there is none.
- **An epic is where a privacy promise gets traded away without anybody deciding to.** "Record search
  phrases — we are doing analytics properly now" arrives as item fourteen of twenty, next to
  nineteen uncontroversial ones, in a review nobody reads line by line. Keeping that question
  standing alone, as its own decision with its own consent copy, is most of what protects it. This
  file keeps it standing alone on purpose.

**Revisit trigger.** When E4 ships and there are real Orders, walk this file again. If the questions
it cannot answer are blocking decisions somebody is actually trying to take, the epic has earned
itself. If they are not, it has not.
