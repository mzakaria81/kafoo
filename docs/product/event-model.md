# Event model

Source of truth for what Kafoo measures, what its events are called, and what may never be
recorded. `docs/product/domain-model.md` is the sibling of this file: that one governs the names of
things that exist, this one governs the names of things that happen.

The constitution (Principle VI) names the **core events** and defers everything else here. That
split is deliberate and explained under [Governance](#governance).

## What an event is

An event is a record that something happened, written once, never updated. It answers *how many*
and *how often*. It is not a log line, not a database row, and not a way to store information you
forgot to model.

An event records **that** a thing happened and **which** thing it was. It never records **what a
person said**.

## The three levels

| Level | What it is | Governed by | Changing it |
|---|---|---|---|
| **1 — Core** | A change of state in a domain entity Kafoo is accountable for | The constitution, Principle VI | Constitutional amendment |
| **2 — Product** | How people move through Kafoo, and where they give up | This document | Ordinary change |
| **3 — Operational** | System health | **Not events. See below.** | n/a |

**The Level 1 test**, so the boundary is checkable rather than a matter of taste: *does this record
a domain entity changing state in a way the business is answerable for?* An Order being cancelled
passes. A search being run does not — no entity changed, and `docs/vision/glossary.md` says a
Recommendation is owned by nobody and never persisted as truth.

Level 1 is small on purpose. It is the vocabulary Kafoo will still be using in five years, and the
amendment gate is what keeps it that way.

### Level 3 is not in this model at all

`SmsDeliveryFailed`, `AiRequestFailed`, `DatabaseTimeout` and their kind are **operational
telemetry**, not analytics. Keeping them out is not pedantry — they differ on every axis that
matters:

| | Analytics events | Operational telemetry |
|---|---|---|
| Keyed to a person | Yes | **Never** |
| Read by | People running Kafoo | Engineers on call |
| Volume | One per meaningful action | Unbounded under failure |
| Retention | Stated, bounded | Short |
| Removal must reach it | Yes | Not applicable — no person in it |

Putting them in one pipe means either giving operational data a privacy burden it should not carry,
or giving analytics a retention policy it must not have. They belong in monitoring.

`SignInFailed` is the honest edge case: it is a funnel step *and* an alarm for undelivered
messages. It stays an analytics event, and alerting is derived from it rather than duplicated.

## Naming

`PascalCase`. `<Subject><VerbInPastTense>` — `MealPublished`, `OrderCancelled`,
`KitchenProfileCreated`.

- **Past tense**, always. An event is a record of the past, not an instruction.
- **The subject is a canonical domain term.** `docs/vision/glossary.md` governs. `KitchenProfileCreated`,
  never `StoreCreated` or `ProfileCreated`.
- **Never name the interface.** `ButtonTapped`, `ScreenViewed`, `NextPressed` describe a layout
  that will be redesigned, and the event outlives the layout. If the name would stop making sense
  after a redesign, it is the wrong name.
- **One family per concept.** Two prefixes for one idea — `VoiceConversationStarted` alongside
  `AiConversationCompleted` — is the vocabulary drift Principle VI exists to prevent. Use one
  family and separate the cases with attributes.
- **Never rename.** A rename silently breaks every historical comparison, and the break is
  invisible: the query still runs and the number is just wrong. Retire and add instead.

### Attributes carry the variation, not the name

Prefer `ConversationCompleted { kind: meal_publish, input: voice }` over four separate events. It
keeps the registry small, lets one query answer a question across every conversation in Kafoo, and
means a new conversational surface needs no new event.

Every event carries: when it happened, which person it concerns (see Privacy), and the attributes
listed in the registry.

## Status

Every event has one:

- **active** — emitted today. Safe to query.
- **planned** — named, agreed, not yet emitted. Named early so each epic does not invent its own
  convention. **Querying one returns nothing, and that means "not built", not "never happens".**
- **retired** — no longer emitted. The name is burned permanently and must never be reused for
  anything else.

## Privacy

Binding, and not negotiable against a product insight:

1. **Never the content.** Not a kitchen's name, a Cook's story, an area, a Meal description, or a
   search phrase. Which step, not what was said.
2. **Never voice.** No audio, no transcript. The constitution requires an ADR before raw audio is
   stored anywhere; wanting funnel data is not a reason to keep a recording.
3. **Removal reaches here.** When a person removes their account, their events are removed or
   permanently unlinked. Otherwise "removed" means "removed from the app, retained in analytics",
   and the promise is false.
4. **Never used against the person it came from.** Events do not rank, target, or personalise
   anything a Customer or Cook sees. Allergy and dietary signals never leave the Customer's own
   session.
5. **Stated retention.** Every event in the registry has one. An event with no retention answer is
   not ready to be added.

## Registry

### Level 1 — Core (constitutional)

| Event | Status | Meaning |
|---|---|---|
| `AccountCreated` | active (E1) | A person became known to Kafoo |
| `AccountRemoved` | active (E1) | A person removed their account and everything attached |
| `KitchenProfileCreated` | active (E1) | A person became a Cook |
| `MealPublished` | planned (E2) | A Meal became available to order |
| `MealArchived` | planned (E2) | A Meal was withdrawn permanently |
| `OrderPlaced` | planned (E4) | A Customer placed an Order |
| `OrderAccepted` | planned (E4) | The Cook agreed to cook it |
| `OrderRejected` | planned (E4) | The Cook declined it |
| `OrderCancelled` | planned (E4) | The Customer withdrew it while pending |
| `OrderCompleted` | planned (E4) | The Order finished — the precondition for a Review |
| `ReviewSubmitted` | planned (E5) | A Customer reviewed a completed Order |

The three E1 events are `active` as of E1. The rest are `planned`: the features that would emit
them do not exist yet. The Order lifecycle is complete
here for the first time — `OrderRejected`, `OrderCancelled` and `OrderCompleted` were missing from
the constitution until v1.1.0, which left cancellations uncountable and the entire review funnel
unmeasurable, since a Review requires a completed Order.

### Level 2 — Product analytics

| Event | Status | Attributes | Meaning |
|---|---|---|---|
| `SignInStarted` | active (E1) | `route` | A code was requested |
| `SignInCompleted` | active (E1) | `route`, `first_time` | The person got in |
| `SignInFailed` | active (E1) | `route`, `reason` | Wrong code, expired, or rate-limited |
| `ConversationStarted` | active (E1) | `kind`, `input` | A conversation began |
| `ConversationStepCompleted` | active (E1) | `kind`, `step`, `input` | One question answered — **this is the drop-off signal** |
| `ConversationCompleted` | active (E1) | `kind`, `input` | The person confirmed and finished |
| `RecoveryEmailOffered` | active (E1) | — | Kafoo offered a second way in |
| `RecoveryEmailDeclined` | active (E1) | `times_declined` | They said no |
| `RecoveryEmailAttached` | active (E1) | — | They added one |
| `PhoneNumberChanged` | active (E1) | — | A person moved their identity to a new number. Also a takeover signal |
| `MealDrafted` | planned (E2) | — | A Cook began composing a Meal. With `MealPublished`, gives the draft-to-publish rate |
| `MealUpdated` | planned (E2) | `changed` | A published Meal was edited. `changed` distinguishes a price change from a typo |
| `SearchPerformed` | planned (E3) | `result_count` | A search ran |
| `SearchFailed` | planned (E3) | — | A search returned nothing |
| `RecommendationAccepted` | planned (E3) | — | A Customer acted on what the AI Assistant suggested |
| `ReviewEdited` | planned (E5) | — | A Review changed inside its editable window |

**Abandonment is derived, not emitted.** There is no `ConversationAbandoned`, because the moment
someone gives up is the moment they close Kafoo — exactly when nothing can be sent reliably. A
conversation with a `ConversationStarted` and no `ConversationCompleted` is abandoned, and the last
`ConversationStepCompleted` says where. Defining an event that cannot be emitted reliably produces
a number that is quietly wrong, which is worse than no number.

**`ConversationStepCompleted` covers the whole product**, not just the Kitchen Profile flow: Meal
publishing in E2 and conversational search reuse it. That is why it is a family with a `kind`
rather than one event per surface.

**`SearchPerformed` records that a search happened and how many results came back — not the
phrase.** What people search for is genuinely valuable to a food marketplace, but a search phrase
can contain dietary and health-adjacent information, which the constitution protects. Recording the
phrase needs its own decision, its own retention answer, and no join to a person.

`SearchPerformed`, `SearchFailed` and `RecommendationAccepted` were constitutional before v1.1.0.
They are **moved, not renamed** — the names are unchanged and historical comparison is intact. They
moved because they record interactions rather than a domain entity changing state, so they fail the
Level 1 test.

### Reserved namespaces

Names are **not** fixed for features whose design decisions have not been made. Reserved so nothing
invents a competing prefix:

- **`Payment*`** — there is no payment model. Naming `PaymentSucceeded` today would presume answers
  about escrow, refunds, and who charges whom that nobody has given. `CLAUDE.md` makes money a
  stop-and-ask; the names arrive with that decision.
- **`Favourite*`** — "Favourite" is not yet canonical vocabulary and appears in no domain document.
  It needs `domain-model.md` before it needs an event.

### Considered and not adopted

- **`NotificationOpened`** — whether a person read a message is engagement telemetry, and it is the
  metric that optimises toward sending more notifications. Kafoo's first principle is user trust,
  and this is the measurement most likely to erode it quietly. Revisit only with a stated reason
  that is not "we want engagement up".

## Adding an event

**Add one when** a real decision waits on the number, the name survives a redesign, and it passes
the Privacy rules above.

**Do not add one when** it describes the interface, duplicates something derivable from events you
already have, or is being added "so we have it later" — that is how a registry becomes noise
nobody trusts.

**Procedure:**

- **Level 2** — add a row here with its status, attributes and retention. Ordinary change, ordinary
  review.
- **Level 1** — a constitutional amendment. Update Principle VI and this file in the same PR, per
  the constitution's amendment procedure. MINOR version bump.

## Governance

The constitution keeps the core list rather than delegating all of it here, and the reason is
worth stating: **making the list easy to change would remove the guarantee that made it worth
having.** Principle VI calls the events stable, and the amendment gate is what makes that true
rather than aspirational.

So the split is by how often each part should change. Level 1 is a promise and lives behind the
gate. Everything else is a working tool and lives here, where a product question can be answered
without a governance ceremony.

`CLAUDE.md` and `docs/vision/glossary.md` point here. They do not copy the list — that duplication
is what this file was created to end.

## Change log

| Date | Change |
|---|---|
| 2026-07-30 | Created. Consolidates event rules previously duplicated across the constitution, `CLAUDE.md`, `glossary.md` and `tasks-template.md`. Completes the Order lifecycle, adds the E1 funnel, introduces levels, status, and the operational-telemetry boundary. |
| 2026-07-30 | E1 shipped: all thirteen E1 events moved from `planned` to `active`. A `planned` event that is emitted misleads exactly as much as an `active` one that is not. |
