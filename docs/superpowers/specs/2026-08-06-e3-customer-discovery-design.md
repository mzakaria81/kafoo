# E3 Customer discovery — the design

**Date:** 2026-08-06
**Status:** Approved — design only, **not implemented**
**Decision records:** `decisions/0008-ship-a-customer-web-surface.md` Amendment 1
**Feeds:** `specs/004-customer-discovery/`

> **E3 does not exist yet.** What is settled here is the shape of it: which surfaces it covers,
> what renders the web one, how a Customer finds food, and what Kafoo declines to collect in order
> to do it. The spec, plan and tasks follow from this document; the code follows from those.

## The problem

E2 made a kitchen readable. Nothing finds one.

The database half is already true and was built in E2: a Kitchen Profile is discoverable exactly
while its Cook has a Meal on offer, enforced by two policies rather than one. But "discoverable"
today means only "not refused by the database". No surface does the finding. A Customer who does
not already hold a reference to a kitchen has no route to any Meal in Kafoo.

## What E3 covers

**Both surfaces — the app and the Customer web surface.** Founder's decision, 2026-08-06.

The web surface is **browse-only** in E3. Orders are E4, so a Customer can find a kitchen and read
its Meals on the web but cannot yet act on either. That is a smaller thing than ADR-0008 promises,
and it is deliberate: the ADR commits to browsing *and* ordering without an install, and only the
first half has content behind it.

## Decision 1 — the Customer web surface is Next.js and TypeScript on Cloudflare Workers

Closes ADR-0008's first open dependency, which the ADR itself deferred until "E2 lands and there is
a Meal to show". Both conditions have been met since 2026-08-05.

**What was weighed:**

| Option | Why not |
|---|---|
| The existing Flutter web build | 42 MB to a canvas. No link preview, no indexing, no text selection — it removes the reason the surface exists. ADR-0008 argues against it in terms. |
| Server-rendered HTML from an Edge Function | Genuinely the cheapest thing that satisfies a shareable link, and wrong for the scope the founder actually holds. It cannot carry an interactive application, so E4's ordering flow would replace rather than extend it. |
| Astro | Server-renders, previews and indexes identically, and ships less JavaScript by default. That advantage narrows once a Customer is signed in and interacting, which is the plan. |
| **Next.js + TypeScript** | **Chosen.** The most trodden path for React against Supabase on the web, and cookie-based sessions are the part that goes wrong. Supabase's own server library is written Next-first. |

The deciding argument was **ecosystem gravity, not capability**. Astro and Next.js can both render
this surface. The difference that matters is how much of the authentication and session work is
already solved on a path other people have walked.

**Cloudflare Workers hosts it.** `CLAUDE.md` already names Cloudflare, and the
`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` secrets are configured and currently read by
nothing — the deploy job that used them was deleted in August because it pointed at a directory
that had never existed. Next.js reaches Cloudflare through an adapter rather than natively, which
is more moving parts than Vercel would be. That cost was accepted rather than overlooked, in
exchange for not splitting Kafoo's deploy story across two vendors.

### The scope condition, which is load-bearing

**E3 builds the Customer surface only.** No Cook portal, no administrative surface.

ADR-0008 commits to a *Customer* surface and lists "whether the Cook flows appear on the web at
all" as an open dependency — harder than it looks, because Kafoo's constitution says a Cook
publishes a Meal by talking, and a browser is the weakest surface Kafoo has for voice. And there is
no `apps/admin` by decision, not by omission: E0's T045 defers an administrative surface until one
is needed.

Choosing Next.js does not commit Kafoo to building those. It only means that if they are ever
approved, the framework will not be the reason they are hard.

### The cost this accepts, stated plainly

**`packages/domain/` is Dart, and a TypeScript surface cannot import it.**

Every rule that lives there — a Meal's lifecycle, that only the Cook who owns a Meal may accept its
Order, that a Review requires a completed Order — would be written a second time in TypeScript, and
the two copies would drift silently. This is the divergence ADR-0008 already names as the cost of a
second front-end. It is the largest permanent cost of this decision and it applies to any
JavaScript surface, not to Next.js in particular.

**The answer is that neither front-end is trusted to be right.** Enforcement stays in Postgres —
RLS policies and constraints — so the database is the single arbiter and both clients are
presentation. Kafoo has already built most of this: 114 assertions run against a real Postgres, and
`scripts/mutate-policies.py` verifies that those assertions can actually fail. A rule restated in
TypeScript is then a convenience that can be wrong without being dangerous.

This must be written into the ADR rather than left as an intention, because the failure mode is
slow and quiet.

## Decision 2 — retrieval is deterministic, and the AI Assistant arrives after it

A Customer speaks or types what they want. Kafoo turns that into a query, retrieves Meals by
meaning rather than spelling, and **renders results immediately**. The AI Assistant runs after
retrieval, not before it, and never sits between the Customer and their results.

```
Customer speaks  →  text  →  embedding  →  filtered vector search  →  results rendered
                                                                          │
                                                          (only when nothing matched)
                                                                          ↓
                                                              AI Assistant responds
```

**Why the model is after and not before.** Three reasons, and the first is the one E2 already paid
for:

1. **Latency.** E2 measured description-to-first-estimate at 2177 ms against production, of which
   1997 ms is inside the model call. The founder's ruling was to accept the miss and show the
   person something while the model thinks. Putting a model call on the critical path of search —
   the highest-frequency action in the marketplace — would repeat that mistake one epic later, at
   greater volume. Vector retrieval answers in milliseconds.
2. **Degradation.** If the model call fails in this design, Kafoo loses a sentence. In the design
   where the model drives search, Kafoo loses search. Those are different categories of failure.
3. **Testability.** Embedding retrieval is deterministic, so an assertion that `برجر` retrieves
   Burger stays true and can be mutation-tested the way the RLS policies now are. A model ranking
   layer makes that assertion flaky, and this repository's stated habit after 2026-08-06 is that a
   green check is a claim that must have been seen to fail.

**Cross-language retrieval is a requirement, not a refinement.** `.claude/rules/supabase.md`
forecloses the wrong answer directly: `برجر` → Burger is an embedding concern with `pgvector` and an
HNSW index, **never `ILIKE`**.

**Browsing everything on offer is the floor.** It is the zero-state before a Customer has said
anything, and it is what a failed search falls back to. It also works at twenty Meals, which search
does not.

### What the AI Assistant does in E3, and what it must not say

**It speaks only when retrieval returns nothing.** That is the moment a Customer asked for
something Kafoo could not serve, and a conversational reply changes the outcome instead of
decorating it — naming what is actually on offer near what they asked for. It is also rare, so it
costs a fraction of summarising every successful search.

Summarising successful results is **deliberately not built**. Narrating three Meals a Customer can
already see is the weakest use of a model call. If evidence later says Customers want it, it is an
additive change.

**Two things the AI Assistant may not claim**, because Kafoo cannot back either:

- **Popularity.** There are no order counts and no Reviews until later epics. An AI Assistant
  calling a Meal popular is asserting a measurement that does not exist, which is a synthetic claim
  and on the product-fatal list.
- **Proximity in distance.** See Decision 3 — Kafoo does not know where a Customer is.

Every model call goes through the provider abstraction, unchanged: ADR-0005 Amendment 1, and the
gate fails if a model id appears outside the Edge Function's registry.

## Decision 3 — Kafoo does not collect a Customer's location in E3

A Kitchen Profile already carries an **`area`**, as free text, and it is one of exactly five
details deliberately public. Discovery uses that.

So "kitchens near me" means **"in the area you name"**, not "within N kilometres". A Customer says
or picks an area; Kafoo matches it against the areas Cooks stated about themselves.

This is a smaller feature than device location, and it is chosen for that reason. Collecting a
Customer's location would be a new category of personal data — a stop-and-ask trigger requiring the
founder's approval, a retention answer, and a consent flow — bought in exchange for precision that
a marketplace this size cannot yet use. If evidence later shows area matching is too coarse,
location is an additive decision with its own ADR.

## What the database needs

**`meals` gains an embedding column and an HNSW index**, in one migration, with RLS unchanged. No
new table, so no new ownership question.

**Filtering happens before ranking, not after it.** A pure similarity query will cheerfully return
a Meal that is off the menu or archived. Availability belongs inside the query. The trap worth
writing into the plan: a filter written the wrong way silently bypasses the vector index and
degrades to a sequential scan that still returns *correct* answers — correct, slow, and invisible.
That is exactly the class of defect the 2026-08-06 lesson is about, and the check for it has to be
one that has been seen to fail.

**Freshness is a first-class filter.** A home cook's Meal is on offer for a window, so the
searchable set changes through the day. This is not a refinement of discovery; it is most of what
makes it correct.

## Events

All three are already reserved in `docs/product/event-model.md` and none needs renaming:

| Event | When |
|---|---|
| `SearchPerformed` | a search ran — with `result_count`, never the phrase |
| `SearchFailed` | a search returned nothing |
| `RecommendationAccepted` | a Customer acted on what the AI Assistant suggested |

`RecommendationAccepted` has a home in this design specifically because of Decision 2: the AI
Assistant only speaks when nothing matched, so the alternative Meal it names *is* the
recommendation, and a Customer opening it is the acceptance.

The event model's existing rule stands unchanged and matters more here than anywhere else in Kafoo:
**`SearchPerformed` records that a search happened and how many results came back, never what was
said.**

## The largest risk, and what to do about it first

**Nobody has measured whether embedding search works in Egyptian Arabic.**

The whole of Decision 2 rests on an embedding model placing `نفسي في حاجة خفيفة` near grilled
chicken and salad in Kafoo's own corpus of Meals. That is assumed, not known. It is the same shape
as the `ar-EG` speech-recognition risk that has sat unmeasured since E1 — an assumption about
dialect quality that a benchmark cannot answer and that gets more expensive to discover the later
it is found.

**So E3's first work package should be a measurement spike, not code**, in the pattern WP-005 used
for the Gemini Live API: take a realistic set of Meals, embed them, run Egyptian phrasings against
them, and report whether the ranking is usable. If it is not, Decision 2 changes before anything is
built on it rather than after.

## Open, and not settled here

1. **What a shared kitchen link contains.** ADR-0008's second open dependency, still unanswered. A
   preview showing a Cook's name and photo is the entire point of the link, and it is also personal
   data leaving Kafoo's surface into a conversation Kafoo cannot see. It is the founder's call and
   it is needed before any link is shareable.
2. **Which embedding model, and its cost per search.** Unmeasured. It goes through the provider
   abstraction like every other model call, but which one — and whether it handles Egyptian Arabic
   — is what the spike above exists to answer.
3. **Whether voice reaches search at all in E3.** Voice input inherits WP-004's unmeasured risk:
   `ar-EG` recognition has never run on a real handset, and it needs a phone bought in Egypt rather
   than a session. Typing must work regardless.

## What this design deliberately does not build

- Result summaries for successful searches — Decision 2
- A Customer's location — Decision 3
- Cook or administrative web surfaces — Decision 1's scope condition
- Ordering on any surface — E4
