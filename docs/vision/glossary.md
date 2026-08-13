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

**One Conversation covers a whole journey (ADR-0015).** Publishing a Meal is one Conversation, not
four questions; onboarding a Cook is one Conversation, not five. A person may ask questions, ask for
advice and change the subject inside it, and the Assistant collects what it needs while that
happens. **Never** step, wizard, or flow, for the thing a person is having — those describe machinery
and Kafoo no longer has that machinery.

### Memory

الذاكرة. A short fact a person said, kept in their own words so the Assistant does not ask them the
same thing twice. Owned by that person, heard aloud on demand, deleted with one sentence. **Never**
profile, and **never** history — a Memory is something someone said, while *history* is something
they did and lives in `orders`.

Granted by ADR-0016 on 2026-08-13 and **not built** — no entity, no table, no policies. Listed here
so the word is fixed before the code.

### Recommendation

A Meal the AI Assistant suggests to a Customer. Ephemeral: never persisted as truth, owned by
nobody. Recording that a Recommendation was *accepted* is an analytics event, not a stored
entity.

### Message

الرسالة. Text sent between a Cook and a Customer, dictated to the AI Assistant and read aloud to
the recipient. **Never** chat, DM, or thread.

**Always text, never audio.** No voice note exists in Kafoo in either direction — the Assistant
transcribes speech into text and reads incoming text aloud, so what travels between two people is
always words on a screen that either of them can also hear. A Message is attributed to the person
who dictated it, never to Kafoo: the Assistant is a pen, not a spokesperson.

New with ADR-0013 and **not built** — no entity, no table, no policies. Listed here so the word is
fixed before the code, which is the whole purpose of this file.

## Voice

New with ADR-0013. Full specification in `docs/design/DESIGN.md` §10.

### Glance word

One of a **closed set of eleven** Arabic words permitted to appear at large size, each fixed in
size, weight, colour and position so it is recognised by shape rather than read:

منشورة · مسودة · مش متاحة · أرشيف · طلب جديد · وصل · اتلغى · محفوظ · مفيش نت · اتبعت · اتقرت

Colour carries the same meaning redundantly, so the word landing unread still lands. **Never
introduce a twelfth without adding it to the set** — an unrecognised shape is worse than no word.

Five of these name states Kafoo has not built: the Order words and the two delivery words. A glance
word for a state the app cannot reach is a promise nothing keeps, so they arrive with their feature.

### Confirmation gate

The read-back that stands in front of every irreversible action. The Assistant speaks the whole
thing, then waits for «أيوة» by voice or tap. **Silence never confirms** and no timeout resolves it.

### Talk button

The 88dp orb, bottom centre, hold-to-talk with tap-to-lock. Larger than the 48dp floor because it is
found by thumb without looking, sometimes with wet hands. **Never** mic button — the name describes
the hardware rather than what a person is doing with it.

## Actions

| Use | Never | Why |
|---|---|---|
| Publish / Archive a Meal | upload / delete | A Meal is an offer being made or withdrawn, not a file. Archived Meals stay readable for Order history. |
| Accept Order / Reject Order | approve / decline | The Cook is agreeing to cook, not adjudicating an application. |

## Analytics events

PascalCase, past-tense, and never renamed — renaming breaks historical comparison invisibly, so
retire and add instead. Event subjects use the canonical terms above: `KitchenProfileCreated`,
never `StoreCreated`.

The full registry — core events, product-analytics events, naming rules, attributes, statuses, and
the privacy rules binding all measurement — lives in `docs/product/event-model.md`. The core list
itself is constitutional (Principle VI). This glossary deliberately does not repeat either list;
copies drift.

## Arabic terms

Egyptian Arabic is the default locale, so the Arabic term is the primary one for anything a
Customer or Cook reads. The English entry is the translation.

Domain words that must not be "corrected" into Modern Standard Arabic, because they are what
people actually say: `كشري` (Koshary), `فراخ` (chicken — not `دجاج`), `عيش` (bread — not `خبز`).

**Participants have one Arabic name each, the same way they have one English one.** These were
being decided one string at a time until 2026-08-07, when a Customer-facing sentence introduced
`الزبون` with no entry anywhere and a second name for the AI Assistant alongside the five strings
that already had one.

| Concept | Arabic | Never |
|---|---|---|
| Customer | `الزبون` | `العميل` — the bank's word, not a marketplace's |
| Cook | `الطباخ` | `الشيف`, `البائع` |
| AI Assistant | `المساعد الذكي` | `البوت`, `الروبوت`, `الذكاء الاصطناعي` used as a name |

`المساعد الذكي` is what the five existing strings say, so it is the name — not because it is the
better of the two. `مساعد كفو` is arguably better register and does not assert cleverness, and
changing to it is a seven-string sweep and a founder's call, not something to do in two new strings
and leave the concept with two names.

Transliterated English is normal in this register and must be searchable: `برجر` (burger),
`بانيه` (panée). Cross-language matching is an embedding property, verified in evals — never a
`LIKE` query.
