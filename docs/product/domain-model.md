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

**A credential has an expiry; the Person does not.** A phone number proves a Person only while that
Person is in use. After 90 days with no Kafoo activity the number is detached, and whoever next
presents it is a new Person with nothing attached — never the old one. The dormant Person survives
without its phone credential, reachable through an attached recovery email, and is removed after a
further 365 days through the same path as ordinary account removal. Egyptian numbers are recycled,
so a number that is not being used is not evidence of who is holding it. ADR-0007 carries the
reasoning and the thresholds.

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

Consequence, stated because it looks like a bug and is not: **a Kitchen Profile is discoverable
exactly while its Cook has a Meal on offer.** E2 added the widening read policy that makes this
true. A Cook whose Meals are all drafts has never opened; a Cook who has taken everything off the
menu is closed. Both correctly return zero rows to everyone but the Cook, and the fix for "my
kitchen disappeared" is to put a Meal back on the menu — never to widen the policy.

**Two policies enforce that, not one, and the migration comment naming the kitchen policy "the
whole of Kafoo's discovery rule" overstates its share.** The kitchen policy asks whether a
published Meal exists; the meals policy decides which Meals the asker can see at all, and the
`EXISTS` runs under it. So a signed-out person is refused twice over.

Measured on 2026-08-05 rather than reasoned about. Widening either policy alone leaves
`kitchen_discoverability_test.sql` fully green — each layer masks the other, so a single-mutation
check reports a test that bites when it has not been given the chance to. Widening both together
turns two assertions red. That is real defence in depth rather than an accident, and it is written
down here because the next person to relax one of those policies will read the other one as
belt-and-braces and be wrong about which belt is holding.

## Entity fields

Fields below are the domain-meaningful ones. Every table additionally carries
`id uuid PRIMARY KEY`, `created_at`, `updated_at` (trigger-maintained), and an explicit owner
column, per `.claude/rules/supabase.md`.

### Kitchen Profile
Display name · story · area · delivery terms · photo · `cook_id` (owner) · form of address.

**Form of address** is `masculine` | `feminine` | unset, and it names the grammatical form of the
verb rather than the person. Arabic conjugates the second person and has no neutral form, so a
product that addresses a Cook at all has already chosen one; ADR-0010 decided to ask rather than
keep guessing. It is deliberately not a gender: the narrower field cannot be repurposed for ranking
or advertising, and it is the only version of this field defensible at the visibility it needs.

**It is asked, and asking is what makes the Kitchen Profile complete.** From T090 the conversation
has five steps, not four — display name, story, area, delivery terms, then the form of address —
and a draft with the first four answered is an unfinished conversation rather than a complete
profile with a blank. A fifth question is normally a failure to infer, and Kafoo's product rules
treat it as one. This is the exception because it genuinely cannot be inferred: an Egyptian given
name does not reliably carry the form, and the app must pick a verb ending on the first sentence it
says. It is asked last, and it is the only step answered by choosing rather than by speaking or
typing.

Everything before it is therefore asked in the unset form. That is the cost of asking rather than
guessing, and it is bounded: four sentences, once, before the Cook has told Kafoo anything.

It is readable wherever the Kitchen Profile is — which, per Discoverability below, includes
anonymous visitors of a kitchen with food on offer. That is required rather than incidental: two
Customer-facing strings describe a Cook and need the **Cook's** form, not the reader's. Only the
owning Cook may write it.

Unset is legal and permanent as a state. The Cook is asked during Kitchen Profile creation from
T090, and the ICU `select` in the ARB files carries an `other` branch regardless — an unset Cook
reads that branch rather than being guessed at.

### Meal
`cook_id` (owner) · title · description · price · cuisine · category ·
`status` (CHECK against the lifecycle) · ingredients · calories · allergens ·
`nutrition_source` (`ai` | `cook`) · photo path · `published_at`.

Calories and allergens are AI estimates until a Cook **changes** them. They are **never** presented
as verified fact, and `nutrition_source` is what the UI reads to decide how to label them.

**`nutrition_source` is derived, never accepted from a client.** A trigger sets it to `cook` when
an update REPLACES a calorie figure or an allergen list that was already stored, and leaves it
alone otherwise. Approving an estimate without editing it does not make it verified — that
distinction is the whole of the "AI suggests, humans approve" rule, and a client allowed to assert
the field could erase it. The one exception is INSERT, where there is no previous value to compare
against and the Cook is the one confirming.

**The word "replaces" is doing work, and it was wrong in the code until 2026-08-05.** The trigger
promoted on any change, and approving an estimate writes the AI Assistant's own number onto a
column that held nothing — which is a change. Since a Cook cannot publish without approving every
estimate, *every* published Meal came out labelled as a figure a person had checked. The rule this
paragraph already described was right; the implementation did not honour it. Cases 26 to 29 in
`supabase/tests/meals_rls_test.sql` now hold it, and the migration comment records the one
inaccuracy the fix accepts: a Cook's own figure written into an empty column reads as an estimate,
because the database cannot tell that write apart from an approval without believing the client.

**Absence is spelled differently on the two columns.** `calories` is nullable, so absence is NULL.
`allergens` is `NOT NULL DEFAULT '{}'`, so a draft nobody has answered holds an empty list — a null
check on it is true for every row that has ever existed and would silently leave the allergen half
of the trigger behaving as before. Emptying a list that had something in it still counts as the
Cook's own answer: disagreeing with a warning is a claim a person makes.

**Two surfaces read this distinction, at different moments.** A Customer reading a published Meal
reads the column. The Cook's summary screen, mid-conversation, reads the conversation's own record
of which fields were replaced — the draft has not been read back at that point, and waiting for a
round trip to decide whether to show a badge would show the wrong one first. They must agree, and
the test pair in `apps/mobile/test/meal_summary_test.dart` ("approved estimates keep their badge",
"a corrected estimate stops reading as one") is what holds the client half to it.

**`published_at` is the first time a Meal went on offer**, set by trigger and never overwritten. A
Meal taken off the menu and put back has been made available again, not republished.

**Price covers the whole Meal**, not a portion. There is no quantity on a Meal — it is an offer,
not inventory.

**`cook_id` is `ON DELETE CASCADE` today, and this document previously said `RESTRICT`.** RESTRICT
is right once an Order can reference a Meal, and wrong before then: E1 promises that removing an
account removes everything belonging to it, and RESTRICT would break that promise for the only case
that currently exists. **The migration that creates `orders` must change it to `RESTRICT`.**

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

**The exchange is one open Conversation, not a sequence of questions (ADR-0015).** Kafoo owns the
set of facts a journey requires; the Assistant owns what to say next. It may answer questions, give
advice and be steered mid-journey. **Advice is not data:** a Meal the Assistant suggested enters the
database only from what the person then says themselves.

**The Assistant may remember across Conversations (ADR-0016), and nothing is built yet.** A memory
is a short fact in the person's own words, owned by that person, written without a gate — on
condition it can be heard aloud on demand, deleted with one sentence, and that a health-adjacent
fact is never stored without asking. Cooks and Customers both. Expires with ADR-0007's dormancy
window.

**A memory informs what the Assistant says; it never fills a field.** A remembered value reaching a
Meal, Order or Review passes the normal approval step. One person's memory never reaches another
person's screen and never enters ranking. **Order history is not memory** — recommendations read
`orders`, which does not exist until E4.

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
13. A phone number resolves to a Person only while that Person has been active within the dormancy
    window. Past it, the number is detached and resolves to nobody (ADR-0007).

## Privacy

Collect only what a named feature needs today. Every new personal-data field answers: why do we
need it, how long do we keep it, who can read it, can we avoid collecting it?

- **Allergy and dietary data is health-adjacent.** Stored only with explicit consent, never used
  for advertising or ranking outside the Customer's own session, and never shared with a Cook
  beyond what a specific Order requires.
- **Voice recordings are transcribed and discarded.** Raw audio is not persisted without an ADR.
- **A Cook's form of address is a grammatical field, not a demographic one.** It records which verb
  ending to use and nothing about the person. It is visible to anyone who can see the kitchen, kept
  for the life of the account, and removed with it by cascade. Storing a gender instead would carry
  the same visibility with none of the same justification — see ADR-0010 before proposing one.

## Change log

| Date | Change |
|---|---|
| 2026-07-26 | Initial model, extracted from `.claude/rules/business-rules.md` and the constitution. |
| 2026-07-30 | E1: added the Person shape (identity vs credential, one account holds both roles) and the derived-discoverability rule for Kitchen Profile. Invariants 11 and 12 added. |
| 2026-07-31 | Settled E1's Open Question 2: a phone credential expires with dormancy while the Person does not. Invariant 13 added. ADR-0007. |
| 2026-08-05 | Kitchen Profile gained a form of address — grammatical, not demographic, readable wherever the kitchen is and writable only by its Cook. ADR-0010, T089. |
| 2026-08-06 | The Kitchen Profile conversation asks the form of address as a fifth and final step, and a profile is not complete without an answer. Customers are addressed as men for now: Kafoo stores a form of address for Cooks only, so a Customer-directed verb stays ungendered. ADR-0010, T090–T093. |
| 2026-08-13 | A journey is one open Conversation rather than an ordered sequence of questions. The required facts are unchanged and still enforced by the database; the fixed order is gone. Advice the Assistant gives is never stored as though the person said it. ADR-0015. |
| 2026-08-13 | Memory between Conversations granted for Cooks and Customers, written without a gate, on three conditions that ship with it: hearable on demand, deletable in one sentence, consent before a health-adjacent fact. Expires with the ADR-0007 dormancy window. Order history stays in `orders` and is never copied into memory. ADR-0016. |
