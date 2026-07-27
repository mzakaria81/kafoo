# Glossary

The canonical vocabulary. One name per concept, everywhere: schema, API routes, prompts, UI
strings, analytics, and conversation. Wrong terminology is a bug, not a style nit — it
propagates into table names, prompt text, and event names, and every one of those is expensive
to rename later.

`CLAUDE.md` carries the short table; this file is the full definition and the reasoning. Where
they disagree, this file is right and `CLAUDE.md` needs updating.

## Participants

### Customer

A person who discovers, orders, and reviews Meals. **Never** buyer, consumer, client, or user.

"User" is banned in user-facing text and in the domain layer because Kafoo has two kinds of
people with opposite needs, and collapsing them hides which one a feature serves. `user` remains
acceptable only for the Supabase auth row (`auth.uid()`), which is an implementation detail.

### Cook

A person who prepares and sells home-cooked Meals. **Never** chef, vendor, seller, merchant, or
restaurant.

"Chef" implies professional training; "restaurant" implies a commercial kitchen. Kafoo exists
for home cooks, and the wrong word here misrepresents the product to its own team.

### AI Assistant

The AI participant in a Conversation. **Never** bot, chatbot, LLM, or robot.

It is a named participant with defined powers (see `.claude/rules/business-rules.md`), not a
feature. "Chatbot" carries an expectation of scripted menus, which is the opposite of what Kafoo
builds.

## Entities

### Kitchen Profile

A Cook's public identity: name, story, location area, delivery terms, photo. **Never** store,
shop, business, or restaurant.

One Cook has one Kitchen Profile. It is what a Customer browses before trusting someone to cook
for them, so it is a trust surface, not a settings page.

### Meal

An *offer* to cook a specific dish. **Never** product, dish, listing, food item, or recipe.

- Not a recipe: it carries no instructions for reproducing the food.
- Not inventory: a Meal is not decremented by an Order.
- Belongs to exactly one Cook, permanently. It cannot be transferred.

Lifecycle: `draft → published → unavailable → archived`. One-way except `published ⇄ unavailable`.

Calories and allergens are AI *estimates* until a Cook confirms them, and carry a `source` field
(`ai` | `cook`) recording which.

### Order

A Customer's committed request for a Meal from a Cook. **Never** purchase, transaction, or ticket.

Requires both a Meal and a Customer. Read by both parties, deleted by neither. Can never change
Cooks — if the Cook cannot fulfil it, the Order is rejected and a new Order is placed.

Lifecycle: `pending → accepted → preparing → ready → completed`. Terminal alternates from
`pending`: `rejected`, `cancelled`. A completed Order is immutable.

### Review

A Customer's account of a completed Order. **Never** feedback. **Never** rating — a *rating* is
the numeric score *inside* a Review, not a synonym for it.

Attaches to an Order, not a Meal; Meal-level ratings are a derived aggregate. Requires a
`completed` Order, enforced in SQL. One Order yields at most one Review. Editable for a
configurable window, then frozen.

### Conversation

An exchange between a person and the AI Assistant, or between a Customer and a Cook. **Never**
chat. **Never** session — `session` is a runtime concept (auth session, HTTP session) and never
appears in user-facing text.

Owned by whoever initiated it.

### Recommendation

A Meal the AI Assistant suggests to a Customer. Ephemeral: never persisted as truth, owned by
nobody. Recording that a Recommendation was *accepted* is an analytics event, not a stored
entity.

## Actions

| Use | Never | Why |
|---|---|---|
| Publish / Archive a Meal | upload / delete | A Meal is an offer being made or withdrawn, not a file. Archived Meals stay readable for Order history. |
| Accept Order / Reject Order | approve / decline | The Cook is agreeing to cook, not adjudicating an application. |

## Analytics events

PascalCase and stable. Renaming one breaks historical comparison, so treat these as an API:

`MealPublished` · `OrderPlaced` · `OrderAccepted` · `ReviewSubmitted` · `SearchPerformed` ·
`SearchFailed` · `RecommendationAccepted`

Adding an event is cheap; renaming one is not. Any change touching a tracked business action
must emit its event.

## Arabic terms

Egyptian Arabic is the default locale, so the Arabic term is the primary one for anything a
Customer or Cook reads. The English entry is the translation.

Domain words that must not be "corrected" into Modern Standard Arabic, because they are what
people actually say: `كشري` (Koshary), `فراخ` (chicken — not `دجاج`), `عيش` (bread — not `خبز`).

Transliterated English is normal in this register and must be searchable: `برجر` (burger),
`بانيه` (panée). Cross-language matching is an embedding property, verified in evals — never a
`LIKE` query.
