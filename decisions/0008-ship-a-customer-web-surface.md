# ADR-0008 — Ship a Customer web surface

**Status:** Accepted
**Date:** 2026-07-31
**Decider:** Founder

## Context

Kafoo ships as a mobile app on Android and iOS (ADR-0006). Every Customer therefore has to install
something before they can place a first Order.

What forced the decision:

- **The install barrier lands on the first Order, which is the one that matters most.** A Customer
  who has never used Kafoo is the least willing to install anything, and is exactly the person the
  marketplace needs to convert.
- **Distribution in Egypt runs through WhatsApp.** A Cook sharing their kitchen is the cheapest
  acquisition Kafoo has. A shared link that opens a kitchen directly converts; one that opens a
  store listing asks for an install first.
- **The founder has decided this is in scope** rather than a question to keep deferring. This ADR
  records that decision so it stops being reopened.

Two facts bound the decision, both established on 2026-07-31:

- **There is nothing to order yet.** Meals are E2 and Orders are E4. A Customer ordering surface has
  no content to render until both exist.
- **The Flutter web build is real and was measured.** Commit `048d923` added web as a build target
  for `apps/mobile`. It compiles clean and the gate passes. It also produces a **42 MB** bundle that
  renders to a **CanvasKit canvas**.

## Options considered

| Option | Cost | Risk | Reversibility |
|---|---|---|---|
| No web surface — mobile only | None | Every first Order needs an install; the WhatsApp share, Kafoo's cheapest acquisition, dead-ends at a store listing | High |
| Compile the existing Flutter app to web and serve that | Lowest — the build target already exists and works | 42 MB over Egyptian mobile data, against a constitution that budgets launch under 2s. Canvas rendering means **no link preview, no indexing, no text selection** — so a shared kitchen link shows a generic card rather than the kitchen's photo and name, which is the mechanic that made web worth building | High |
| A separate server-rendered web surface for browsing and ordering | A second surface to build and keep in step with the app | Divergence between what a Cook sees in the app and what a Customer sees on the web; more code for the same domain | Medium |

## Decision

**Kafoo ships a Customer web surface.** A person can find a kitchen, see its Meals, and place an
Order without installing anything.

**Which rendering technology serves it is deliberately left open**, and is decided when E2 lands and
there is a Meal to render. What today's measurement settles is that the answer is *probably not* the
existing Flutter web build: a 42 MB canvas cannot deliver the shareable link that justifies the
surface. That is evidence, not yet a decision, and the alternative has its own cost — a second
surface over one domain.

**The existing web build target is not this surface.** `048d923` exists so the app can be exercised
in a browser during development. It is a testing and demonstration target. Do not let it become the
Customer web surface by default, and do not point a Customer at it.

## Consequences

**Accepted costs.**

Kafoo now owns a third surface. Every rule that binds the app binds it: Arabic first with `ar` as
the default rather than the fallback, right-to-left throughout, canonical vocabulary, and no
user-facing string outside the localization files. Every trust rule applies unchanged — a web page
is where hidden fees and dark patterns are easiest to add and hardest to notice.

RLS carries over with no new policy work, because it is enforced in the database rather than the
client. That is the one part of this that is genuinely free. The publishable key sitting in a web
bundle is fine by design. **The service-role key must never reach any client bundle** on any
surface.

If the surface ends up server-rendered, Kafoo carries two front-ends over one domain and they can
drift. Whatever renders it, the domain rules stay in `packages/domain/` rather than being restated.

**What this forecloses.** Kafoo can no longer treat "install the app" as the only route to an Order,
and no flow may assume a Customer has the app installed. Voice-first has to degrade honestly on a
surface where voice input is weaker, rather than being assumed.

**Revisit trigger.** Any of: the ordering surface still unbuilt when E4 ships, which would mean this
was decided too early; measured evidence that Customers who arrive by link convert no better than
those sent to a store listing; or a Flutter web rendering mode that produces indexable, previewable
pages at a size that fits the launch budget, which would collapse the technology question.

## Open dependencies

1. **Which technology renders it.** Decided when E2 lands and there is a Meal to show. The
   Flutter-web measurement above is the evidence to weigh, not the verdict.
2. **What a shared kitchen link contains.** A preview showing the kitchen's name and photo is the
   entire point of the link, and it is also personal data leaving Kafoo's surface into a
   conversation Kafoo cannot see. It needs its own answer before any link is shareable.
3. **Whether the Cook flows appear on the web at all.** This ADR commits to a *Customer* surface.
   Whether a Cook can publish a Meal from a browser is a separate question, and the conversation
   rule makes it a harder one.

## Notes for Claude Code

Kafoo has a Customer web surface in scope: browsing and ordering without an install. It is **not**
built and its technology is **not** chosen — do not assume the Flutter web build under
`apps/mobile/web/` is it, and do not point a Customer at that build. Every rule that binds the app
binds the web surface: `ar` first, RTL, canonical vocabulary, strings in the localization files,
trust rules unchanged. Never let a service-role key reach a client bundle.
