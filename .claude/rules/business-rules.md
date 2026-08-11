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

**What that approval step looks like changed on 2026-08-10 (ADR-0013), and the rule did not.**
Kafoo is voice-first: the assistant speaks, the person speaks back, the screen is the receipt.

- **Reversible** — search, filter, navigation, and writing a draft that holds what the Cook *said* —
  executes immediately and is announced aloud. No gate.
- **Irreversible** — publishing a Meal, accepting or rejecting an Order, cancelling, changing the
  price of a published Meal, sending a Message, posting a Review — is read back aloud in full and
  waits for «أيوة». Both voice and tap answer the gate.
- **Silence never confirms.** No timeout resolves a gate. The question repeats once after eight
  seconds, then waits indefinitely.

**A draft is not a loophole.** Writing what the Cook said needs no gate because she authored it. An
AI-derived field inside that draft — calories, allergens, inferred cuisine or category — still needs
the approval step. Speaking a sentence is authoring; a model estimating a calorie count is not.

## Message

New with ADR-0013. **Not built** — no entity, no table, no policies. Recorded here so the rules
exist before the code rather than after it.

- **All Cook ↔ Customer communication is text.** Neither side ever receives audio. No voice note
  exists in this product in either direction.
- **The assistant transcribes; it does not improve.** Egyptian phrasing is preserved exactly. Never
  rewritten into Modern Standard Arabic, never made more polite, never shortened. A Cook who says
  «تحبي أبعته مع ابني» must not arrive sounding like a company.
- **A Message is attributed to the person, never to Kafoo.** The assistant is a pen, not a
  spokesperson. If a Customer thinks Kafoo is the one talking, the neighbourly relationship this
  product depends on is gone.
- **Read back verbatim before sending** — the single exception to "the assistant paraphrases". Those
  exact words reach another human, so the sender hears them literally and answers «أيوة».
- Reviews follow the same path: the Customer hears their own Review verbatim before it posts, so a
  harsh sentence said quickly stays a decision rather than a slip.
- **Message content is a new category of personal data** between two named people. It needs the
  privacy answers below and its own RLS before a table exists.

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

**That holds offline too, and the founder decided it explicitly on 2026-08-10.** The voice-first
design's offline state draws a queued-*audio* card; Kafoo queues the **transcript** instead. Speech is
transcribed on the device, the text is queued, the audio is discarded. No exception to the rule above
was needed and none was granted (ADR-0013, conflict 1).

**The state may only promise what the phone can actually deliver.** On-device Arabic recognition
normally needs the network on Android, and `docs/ops/measuring-transcription.md` records that `ar-EG`
is missing on many Egyptian handsets — so on some phones there is no transcript to queue, because the
thing that makes transcripts needs the network that just went away.

Where transcription succeeds, queue the text and say «محفوظ». Where it fails, **say so plainly and
offer tap or typing.** Never say «كلامك محفوظ» over words that were not captured: losing a Cook's
sentence after telling her it was safe is worse than telling her the truth immediately.
