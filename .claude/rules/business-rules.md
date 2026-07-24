# Business rules

Domain invariants. These are not derivable from the code — they constrain what the code is allowed
to do. If an implementation contradicts a rule here, the rule is right and the implementation is a
bug. Source of truth: `docs/product/domain-model.md`.

No `paths:` frontmatter — this loads every session on purpose. Keep it under 100 lines.

## Ownership

Every row has exactly one owner. RLS enforces it; application code must not be the only guard.

| Entity | Owner |
|---|---|
| Customer profile | Customer |
| Kitchen Profile | Cook |
| Meal | Cook |
| Order | Customer *and* Cook (both read; neither deletes) |
| Review | Customer |
| Conversation | The user who initiated it |
| Recommendation | Nobody — ephemeral, never persisted as truth |

## Meal

- A Meal belongs to exactly one Cook and cannot be transferred.
- Lifecycle: `draft → published → unavailable → archived`. Transitions are one-way except
  `published ⇄ unavailable`.
- Archived Meals cannot receive new Orders. They remain readable for order history.
- A Meal is an *offer*, not a recipe and not an order. Do not model it as inventory.
- Calories and allergens are AI *estimates*. Store them with a `source` field (`ai` | `cook`) and
  never present an AI estimate as verified fact.

## Order

- An Order cannot exist without both a Meal and a Customer.
- Lifecycle: `pending → accepted → preparing → ready → completed`.
  Alternate terminal states from `pending`: `rejected`, `cancelled`.
- An Order can never change Cooks. If the Cook cannot fulfil it, it is rejected and a new Order is
  placed.
- Completed Orders are immutable. No status field on a completed Order may be written again.
- Only the Cook who owns the Meal may accept or reject the Order.

## Review

- A Review requires a `completed` Order. Enforce this in the database, not just the UI.
- One completed Order produces at most one Review.
- A Cook cannot review themselves, directly or via a second account they control.
- Reviews attach to Orders, not Meals. Meal-level ratings are a derived aggregate.
- Reviews are editable for a configurable window, then frozen.

## AI Assistant

The AI is a domain participant but owns no data.

The AI **may**: estimate calories, extract ingredients, suggest cuisine and category, generate draft
descriptions, translate, rank search results, summarize conversations, recommend Meals.

The AI **may not**, under any framing: publish a Meal, modify an Order, charge or refund a payment,
delete content, write a Review, or impersonate a Customer or Cook.

Every AI-derived field written to the database requires an explicit human approval step in the flow.
If a proposed design has AI writing directly, the design is wrong.

## Trust

These are product-fatal, not merely disallowed:

- No synthetic Reviews, Cooks, or Meals — including for seeding, demos, or screenshots in production
- No AI-generated food photography presented as a real Meal
- No hidden fees. Every charge visible before order confirmation
- No dark patterns in cancellation or refund flows

## Privacy

Collect only what a named feature needs today. Every new personal-data field needs an answer to:
why do we need it, how long do we keep it, who can read it, can we avoid collecting it.

Allergy and dietary data is health-adjacent. It is stored only with explicit consent, is never used
for advertising or ranking outside the Customer's own session, and is never shared with Cooks beyond
what a specific Order requires.

Voice recordings are transcribed and discarded. Do not persist raw audio without an ADR.
