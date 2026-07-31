# Domain model

Source of truth for Kafoo's entities, their relationships, and their invariants.
`.claude/rules/business-rules.md` is the enforcement summary loaded into every session; this
file is the full model and the reasoning behind it. Where they disagree, this file is right and
the rules file needs updating.

**Definition of Done item 6**: if a change alters the domain, it updates this file *in the same
commit*. A feature without updated domain docs is half-shipped.

Vocabulary is fixed by `docs/vision/glossary.md`. Names here are the only correct ones.

## Entity relationships

```
Customer ──1:1── Customer Profile
    │
    │ places
    ▼
  Order ──N:1── Meal ──N:1── Cook ──1:1── Kitchen Profile
    │
    │ yields at most one
    ▼
  Review

Conversation ──N:1── initiating participant (Customer or Cook)
Recommendation ── ephemeral, never persisted as truth
```

## Person

Identity is independent of the credential that proves it. A **Person** is the identity; a phone
number is a credential attached to it, the way a messaging app treats it. A number can therefore
change hands without the Person changing, and a Person can gain a second way in without becoming
two accounts.

One account holds both roles. Everyone begins able to browse and order as a Customer. **Owning a
Kitchen Profile is what makes someone a Cook** — there is no role chosen at signup, no application
to be approved, and no second account. A Cook can order from other Cooks, because they are still a
Customer. A person who never creates a Kitchen Profile stays a Customer and is not asked again
after declining once.

## Ownership

Every row has exactly one owner. RLS enforces it; application code must never be the only guard.

| Entity | Owner | Notes |
|---|---|---|
| Customer Profile | Customer | |
| Kitchen Profile | Cook | one per Cook |
| Meal | Cook | non-transferable |
| Order | Customer *and* Cook | both read; neither deletes |
| Review | Customer | Cook may read, never edit |
| Conversation | initiator | |
| Recommendation | nobody | ephemeral |

Order is the only dual-read entity. Its RLS predicate is therefore the only one shaped
`customer_id = auth.uid() OR cook_id = auth.uid()`; everything else is single-owner.

## Lifecycles

### Meal

```
draft ──► published ◄──► unavailable ──► archived
                 └──────────────────────────┘
```

- One-way except `published ⇄ unavailable`.
- `archived` is terminal. Archived Meals accept no new Orders but stay readable so Order history
  does not break.
- A Meal is an offer, not inventory. Placing an Order does not decrement anything.

### Order

```
pending ──► accepted ──► preparing ──► ready ──► completed
   │
   ├──► rejected    (Cook declines)
   └──► cancelled   (Customer withdraws, only while pending)
```

- Only the Cook who owns the Meal may accept or reject.
- `completed` is immutable: no status field on a completed Order may be written again.
- An Order can never change Cooks. Rejection plus a new Order is the only path.

### Review

```
(Order completed) ──► draft ──► submitted ──► frozen
```

- Cannot exist without a `completed` Order. Enforced by SQL, not UI.
- Editable for a configurable window after submission, then frozen permanently.
- A Cook cannot review themselves, directly or through a second account they control.

## Discoverability

A Kitchen Profile has **no state of its own**. It is not draft, published, hidden, or archived,
and it carries no `visible` column. There is nothing to forget to set, and nothing to get out of
step with reality.

**Discoverable** — reachable by browsing or searching — is derived: a Kitchen Profile is
discoverable exactly while its Cook has at least one published Meal, and stops being discoverable
when they have none. Kafoo never shows a Customer a kitchen they cannot order from; an empty
shopfront is a small betrayal repeated at scale.

**Readable** is a different question, and the two must not be collapsed. A Kitchen Profile stays
readable to anyone holding a legitimate reference to it — an Order above all — whether or not it
is currently discoverable. Otherwise a Cook taking a week off would erase themselves from their
Customers' order history, which is the same reason archived Meals stay readable.

The deliberately public face is **exactly** five details: display name, story, area, delivery
terms, and photo. Nothing else about the Cook is reachable through it, signed in or not — in
particular the phone number, which Kafoo never copies out of the authentication record. Adding a
sixth detail is a change to this rule, not a layout decision.

Consequence, stated because it looks like a bug and is not: **no Kitchen Profile is discoverable
until Meals exist.** Every discovery query correctly returns zero rows today. The fix is to create
Meals and widen the read policy then — never to make Kitchen Profiles publicly readable now.

## Entity fields

Fields below are the domain-meaningful ones. Every table additionally carries
`id uuid PRIMARY KEY`, `created_at`, `updated_at` (trigger-maintained), and an explicit owner
column, per `.claude/rules/supabase.md`.

### Kitchen Profile
Display name · story · area · delivery terms · photo · `cook_id` (owner).

### Meal
`cook_id` (owner, `ON DELETE RESTRICT`) · title · description · price · cuisine · category ·
`status` (CHECK against the lifecycle) · ingredients · calories · allergens ·
`nutrition_source` (`ai` | `cook`).

Calories and allergens are AI estimates until a Cook confirms them. They are **never** presented
as verified fact, and the `source` field is what the UI reads to decide how to label them.

### Order
`customer_id` · `cook_id` · `meal_id` · `status` (CHECK) · quantity · price at time of order ·
requested time · delivery details.

Price is captured on the Order, not read live from the Meal — a later price change must not
alter a placed Order.

### Review
`order_id` (unique — enforces one Review per Order) · `customer_id` (owner) · rating · body ·
`submitted_at` · `frozen_at`.

## AI Assistant

A domain participant that owns no data.

**May**: estimate calories, extract ingredients, suggest cuisine and category, generate draft
descriptions, translate, rank search results, summarize Conversations, recommend Meals.

**May not**, under any framing or user instruction: publish a Meal, modify an Order, charge or
refund a payment, delete content, write a Review, or impersonate a Customer or Cook.

Every AI-derived field written to the database passes an explicit human approval step in the
flow. If a proposed design has the AI writing directly, the design is wrong — not the rule.

## Invariants

Enforced in the database via `CHECK` constraints and foreign keys, never application validation
alone:

1. A Meal belongs to exactly one Cook and cannot be transferred.
2. An Order references both a Meal and a Customer.
3. An Order's `cook_id` matches the `cook_id` of its Meal.
4. Only the Meal's Cook may transition an Order out of `pending`.
5. A completed Order is immutable.
6. A Review requires a `completed` Order.
7. At most one Review per Order.
8. A Cook cannot review their own Meal.
9. Archived Meals accept no new Orders.
10. Every Meal status and Order status is a member of its lifecycle enum.
11. A Person has at most one Kitchen Profile, and it cannot be transferred to another Person.
12. A Kitchen Profile's discoverability is derived from its Cook's published Meals, never stored.

## Privacy

Collect only what a named feature needs today. Every new personal-data field answers: why do we
need it, how long do we keep it, who can read it, can we avoid collecting it?

- **Allergy and dietary data is health-adjacent.** Stored only with explicit consent, never used
  for advertising or ranking outside the Customer's own session, and never shared with a Cook
  beyond what a specific Order requires.
- **Voice recordings are transcribed and discarded.** Raw audio is not persisted without an ADR.

## Change log

| Date | Change |
|---|---|
| 2026-07-26 | Initial model, extracted from `.claude/rules/business-rules.md` and the constitution. |
| 2026-07-30 | E1: added the Person shape (identity vs credential, one account holds both roles) and the derived-discoverability rule for Kitchen Profile. Invariants 11 and 12 added. |
