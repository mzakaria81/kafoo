# ADR-0008 — Ship a Customer web surface

**Status:** Accepted — **amended 2026-08-06, see Amendment 1**
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

1. ~~**Which technology renders it.**~~ **Closed 2026-08-06 by Amendment 1** — Next.js and
   TypeScript on Cloudflare Workers.
2. ~~**What a shared kitchen link contains.**~~ **Closed 2026-08-06 by the founder, while specifying
   E3** — a shared reference reveals exactly three things before it is opened: the kitchen's name,
   its area, and its photo. Opening it shows the five details already public and no sixth. Kafoo
   holds no personal name, phone number, address or location for a Cook, so there is nothing further
   that could leak. Recorded as FR-027a to FR-027c and SC-012 to SC-013 in
   `specs/004-customer-discovery/spec.md`.
3. **Whether the Cook flows appear on the web at all.** This ADR commits to a *Customer* surface.
   Whether a Cook can publish a Meal from a browser is a separate question, and the conversation
   rule makes it a harder one.

## Notes for Claude Code

> **Superseded in part by Amendment 1 below — the technology IS now chosen.** The paragraph that
> follows is the 2026-07-31 text and is kept so the decision's history reads straight. Read
> Amendment 1's own notes for what binds today.

Kafoo has a Customer web surface in scope: browsing and ordering without an install. It is **not**
built and its technology is **not** chosen — do not assume the Flutter web build under
`apps/mobile/web/` is it, and do not point a Customer at that build. Every rule that binds the app
binds the web surface: `ar` first, RTL, canonical vocabulary, strings in the localization files,
trust rules unchanged. Never let a service-role key reach a client bundle.

---

# Amendment 1 — the technology is Next.js and TypeScript, and both front-ends are presentation

**Status:** Accepted
**Date:** 2026-08-06
**Decider:** Founder
**Amends:** Open dependency 1 above, and adds a consequence the original decision did not carry.
Everything else in this ADR stands. Open dependency 2 was closed separately later the same day, in
the course of specifying E3 — see the note against it above. **Open dependency 3, whether the Cook
flows appear on the web at all, remains open and is not touched by anything here.**

## Why this was reopened

Because the ADR said to. The rendering technology was deliberately left open "until E2 lands and
there is a Meal to render". E2 landed on 2026-08-05 and measured itself on 2026-08-06, so the
condition is met and the question is due rather than deferred.

One thing changed between the original decision and this one, and it changed the answer. ADR-0008
justifies the surface almost entirely on the shareable link — a preview of a kitchen in a WhatsApp
conversation. Optimising for that alone points at the smallest thing that renders server-side HTML
with preview tags, and the first recommendation made in this session was exactly that. It was wrong,
not because the reasoning failed, but because the scope was inherited from this document instead of
confirmed with the founder. **The intent is a functional web application beside the app, not a set
of public pages.** That is a different question and it has a different answer.

## Decision

**The Customer web surface is Next.js and TypeScript, hosted on Cloudflare Workers.**

Astro and Next.js both server-render, both produce previewable and indexable pages, and both run
React with TypeScript — the "static site versus application" framing is not what separates them.
What separates them is that cookie-based Supabase sessions on the web are the part that goes wrong,
and Next.js is the path where that is already solved and documented. Astro's smaller default
JavaScript payload is a real advantage on an Egyptian mobile connection and it narrows once a
Customer is signed in and interacting, which is the plan.

The existing Flutter web build is rejected for the reasons this ADR already gave: 42 MB to a canvas,
with no link preview, no indexing and no text selection. That was evidence when this ADR was
written; it is now the verdict.

Cloudflare hosts it because `CLAUDE.md` already names Cloudflare and the `CLOUDFLARE_API_TOKEN` and
`CLOUDFLARE_ACCOUNT_ID` secrets are already configured and read by nothing. Next.js reaches
Cloudflare through an adapter rather than natively, which is more moving parts than Vercel. That
cost was weighed and accepted rather than missed, in exchange for not splitting the deploy story
across two vendors.

**Scope condition: this decision authorises a Customer surface only.** No Cook portal and no
administrative surface. Open dependency 3 above is untouched, and there is no `apps/admin` by
decision rather than by omission — E0's T045 defers one until it is needed. Choosing a framework
capable of carrying those surfaces is not approval to build them.

## The consequence this ADR did not previously carry

**`packages/domain/` is Dart, and a TypeScript surface cannot import it.**

Kafoo's business rules — a Meal's lifecycle, that only the Cook who owns a Meal may accept its
Order, that a Review requires a completed Order — would be written a second time in TypeScript, and
the two copies would drift. The original ADR named front-end divergence as a risk in general terms.
This is what it looks like in particular, and it is the largest permanent cost of shipping any
JavaScript surface.

**Therefore: neither front-end is trusted to be right.** Enforcement lives in Postgres — RLS
policies and constraints — so the database is the single arbiter and both clients are presentation.
A rule restated in TypeScript is a convenience that may be wrong without being dangerous.

This is already most of the way built and it is what makes the decision affordable: 114 assertions
run against a real Postgres, and `scripts/mutate-policies.py` verifies those assertions can actually
fail. Any rule added to a client without a policy behind it is a regression against this amendment,
not a shortcut.

## Notes for Claude Code

The Customer web surface is **Next.js + TypeScript on Cloudflare Workers**, Customer flows only.
Do not add Cook or administrative flows to it without a new decision. Do not restate a domain rule
in TypeScript without a database policy or constraint enforcing it — the database is the arbiter and
both front-ends are presentation. Everything that binds the app binds this surface unchanged: `ar`
first and RTL, canonical vocabulary, no user-facing string outside the localization files, and the
trust rules. The publishable key belongs in the bundle; the service-role key never reaches any
client.
