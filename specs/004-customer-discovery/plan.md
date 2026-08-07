# Implementation Plan: Customer Discovery

**Branch**: `004-customer-discovery` | **Date**: 2026-08-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/004-customer-discovery/spec.md`

## Summary

A Customer says what they want, Kafoo shows Meals that match the meaning, and the AI Assistant says
afterwards whether any of them honestly answers the request.

The technical shape follows from one constraint the specification could not see: **ranking and
authorization have to happen in the same query.** The moment ranking moves outside the database —
fetch candidates, sort them somewhere else — one of two things must be true, and both are bad. Either
the thing doing the ranking holds a service-role key, which is how the AI Assistant acquires a write
path it is not supposed to have; or it re-implements the visibility rules in a second place, which
is how a Meal that should be invisible becomes findable while every authorization test still passes.

So the vector search runs **inside Postgres, under RLS, as the Customer's own identity**. The Edge
Function turns a phrase into a vector and hands it to the database; the database decides what that
Customer may see, and ranks only that. Discovery gains no authority of its own.

Two consequences follow, and the rest of this plan is detail:

**Nothing on the read path holds a service-role key**, exactly as in E2. One thing on the *write*
path does, and it is the single place this design has to be argued rather than asserted — see
Principle II below.

**The AI Assistant's judgement is a second call the Customer never waits for.** Results come from the
database and render. The judgement arrives after, or does not arrive, and the difference is a
sentence rather than a screen.

## Technical Context

**Language/Version**: Dart 3.6+ / Flutter 3.27+ (app, packages); TypeScript on Deno (Edge Functions);
TypeScript on Next.js (web surface, **new**); SQL / PL/pgSQL

**Primary Dependencies**: existing — `supabase_flutter` ^2.9, Riverpod. **New**: `pgvector` (Postgres
extension), Next.js + React + `@supabase/ssr` (web surface, ADR-0008 Amendment 1),
`@opennextjs/cloudflare` (deploy adapter)

**Storage**: Supabase Postgres. **No new table.** `meals` gains one column and one index. No new
bucket.

**Testing**: `dart test` (domain, ai), `flutter test` (mobile, ui), pgTAP via `./scripts/local-db.sh
test`, `deno test` (Edge Functions), golden cases in `packages/ai/test/goldens/`, and **one new kind
— a retrieval-quality regression** run against `docs/ops/discovery-corpus.json` by
`scripts/spike-discovery-embeddings.py`, promoted from a spike to a check.

**Target Platform**: Android and iOS (ADR-0006); Cloudflare Workers for the Customer web surface
(ADR-0008 Amendment 1). `apps/mobile/web/` remains a development target and is **not** this surface.

**Project Type**: Mobile app + web app + managed backend

**Performance Goals**: cached search < 1s (constitution). Results must render **before** the
relevance judgement returns; that ordering is a requirement (FR-011), not an optimisation.

**Constraints**: Exclusions are SQL predicates, never phrases handed to a model — measured on
2026-08-06, meaning-matching gets negation backwards. Embeddings are 768-dimensional; pgvector's
HNSW index refuses more than 2000, and Gemini's default of 3072 would produce a column that works
and cannot be indexed. All model calls through the provider registry (ADR-0005 Amendment 1).
Egyptian Arabic is the source locale on both surfaces.

**Scale/Scope**: Friends-and-family. One new column, one new index, one new database function, three
new Edge Functions, one new prompt, one new front-end, roughly four screens on each surface.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Source: `.specify/memory/constitution.md` (v1.1.0).

| # | Gate | Status | Notes |
|---|------|--------|-------|
| I | **User trust** | PASS — **with one sharp edge** | FR-031 forbids synthetic Meals; the corpus in `docs/ops/` is measurement fixtures and `verify.sh`'s synthetic-content check is scoped away from it already. FR-016 and FR-017 forbid the AI Assistant claiming popularity or proximity, both of which Kafoo would be inventing. **The sharp edge is exclusions**: allergens are AI estimates carrying `nutrition_source`, so a filter built on them can be wrong in the direction that matters. Kafoo must state what it filtered on and must never state that a Meal is safe. See research.md §3. |
| II | **AI suggests, humans approve** | **NEEDS JUSTIFICATION — argued below, not waved through** | One new Edge Function, `embed-meal`, holds a service-role key and writes to the database. Nothing else on either path does. The argument is in Complexity Tracking and it must be reviewed by `ai-boundary-reviewer` rather than accepted from this document. |
| III | **Security by default** | PASS | No new table, so no new ownership question. The new column inherits `meals`' existing RLS unchanged, and the post-design check below requires *proving* it is unchanged rather than assuming. The search function is `SECURITY INVOKER` so RLS applies as the caller. Negative tests written first: a draft, an unavailable and an archived Meal must each return zero rows through search, and a non-owner must not reach them by any ranking. |
| IV | **Conversation first, Arabic first** | PASS — **and this is where it would be easiest to fail** | A Customer expresses what they want, what they do not want, and where, in **one sentence**: `عايز حاجة من غير لحمة في المهندسين`. Exclusions and area are extracted from that sentence, not collected as separate controls. Three input fields would be a form at the exact point Principle IV forbids one. Strings in both ARB files on both surfaces, Arabic first, RTL throughout. |
| V | **Provider independence** | PASS — **with a real extension** | Both new model calls go through the registry in `supabase/functions/_shared/ai/`. That registry currently knows how to generate; it gains an **embedding** capability, which is a genuine addition rather than a new call site. Gemini, Anthropic and OpenAI adapters must each answer for it or declare they cannot. The new prompt is a file, `prompts/discovery-judgement.md`. |
| VI | **Canonical vocabulary** | PASS | `SearchPerformed`, `SearchFailed`, `RecommendationAccepted` — all three reserved in `docs/product/event-model.md`, none invented here. `SearchPerformed` carries `result_count` and never the phrase. |
| VII | **Documentation separation** | PASS | `spec.md` names no framework, no storage engine, no provider, no policy. Verified by grep at spec time, including one leak found and removed. |
| — | **Performance budgets** | **AT RISK** | Vector search under an index is fast; the query embedding is a network call to a vendor and nothing has measured it inside this shape. The budget is 1s and the judgement is explicitly outside it. Must be measured against production the way E2's numbers were, not asserted. |
| — | **Privacy** | PASS — **with a disclosure neither the spec nor the founder raised** | FR-023 adds no personal-data field and FR-029 forbids recording the phrase. But **a Customer's words leave Kafoo to be understood** — a phrase must reach a vendor to become a vector. That is the same disclosure E2 gave a Cook before a Meal description left, and a Customer is owed it too. Not recording something is not the same as not sending it. See research.md §5. |
| — | **Stop-and-ask triggers** | **THREE FIRED, ALL ANSWERED** | (1) Adds screens — browse, search, results, a kitchen page on a second surface. Approved 2026-08-06 as the E3 scope. (2) Recurring spend — the relevance judgement runs once per search, not once per failure, and the free tier cannot serve it. Surfaced to the founder 2026-08-06. (3) A new surface — ADR-0008 Amendment 1. **No new personal-data category**, which is the one that did not fire, by design. |

**Verification**: `./scripts/verify.sh` must pass before this feature's PR opens.

### Post-design re-check

Re-run after Phase 1. Five things, because each is a place where this design fails silently rather
than loudly:

1. **Did `embed-meal` stay unable to write anything but the embedding?** It is the only thing here
   holding a service-role key. If it grows a second column, the argument in Complexity Tracking
   stops being true and Principle II becomes decoration.
2. **Does `embed-meal` read the Meal's text from the database rather than the request body?** If it
   embeds what a client sends, a Cook can write a vector that ranks their Meal first for every
   query. That is ranking manipulation, and it is invisible.
3. **Is the search function `SECURITY INVOKER`?** `SECURITY DEFINER` would make every Meal findable
   and every existing authorization test would still pass, because none of them go through search.
4. **Does the vector index actually get used?** A filter written the wrong way bypasses it and
   degrades to a sequential scan that returns *correct* answers. Correct, slow, and invisible —
   check the query plan, do not infer it from the results.
5. **Do results render before the judgement returns?** If the client awaits both, FR-011 is violated
   and nothing fails: the feature merely becomes slow in the way E2 was measured to be.

## Project Structure

### Documentation (this feature)

```text
specs/004-customer-discovery/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── authorization.md
│   ├── discover.md
│   ├── embed-meal.md
│   └── judge-results.md
└── tasks.md             # Phase 2 — NOT created by /speckit-plan
```

### Source Code (repository root)

```text
apps/mobile/lib/features/discovery/
├── presentation/        # browse, search, results, empty-area, nothing-matched
├── application/         # controllers, Riverpod providers, judgement arriving late
└── data/                # discovery_repository.dart — the only layer touching Supabase

apps/web/                # NEW — Next.js, TypeScript, Cloudflare Workers (ADR-0008 Amendment 1)
├── app/                 # routes: browse, search, a kitchen, a Meal
├── lib/                 # Supabase client (publishable key only), shared formatting
└── messages/            # ar / en — the same two locales, Arabic first

packages/domain/lib/
├── discovery_request.dart   # what was asked, what was excluded, where
├── exclusion.dart           # the controlled exclusion vocabulary and its Arabic surface forms
└── discovery_result.dart    # a ranked Meal and why it is here — no Flutter, no Supabase

supabase/
├── migrations/          # pgvector, meals.embedding, HNSW index, search function — one file
├── functions/
│   ├── discover/        # phrase → vector → database, as the caller. NO service-role key.
│   ├── embed-meal/      # the one thing that writes. Reads text FROM the database.
│   └── judge-results/   # query + results → does any of this answer it
└── tests/               # discovery_rls_test.sql, discovery_exclusion_test.sql

prompts/
└── discovery-judgement.md

scripts/
└── spike-discovery-embeddings.py   # promoted from spike to retrieval-quality regression
```

**Structure Decision**: The app follows E1 and E2's layering exactly — `presentation/`,
`application/`, `data/` per feature, `data/` the only layer touching Supabase, `packages/domain/`
free of both Flutter and Supabase.

`apps/web/` is the departure and it is deliberate. It is a **second front-end over one domain**, and
ADR-0008 Amendment 1 records what that costs: `packages/domain/` is Dart and TypeScript cannot import
it, so any rule restated there can drift. The mitigation is structural rather than disciplinary —
enforcement lives in Postgres, both front-ends are presentation, and a rule added to a client without
a policy or constraint behind it is a regression against the amendment rather than a shortcut.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| **`embed-meal` holds a service-role key and writes to the database** — the only thing in Kafoo that does on an AI path | A Meal must carry a vector to be findable, and **the vector must be produced by Kafoo rather than supplied by a client.** A client-supplied embedding is a ranking-manipulation hole: a Cook writes the vector that sits nearest every query and their Meal ranks first for everything, invisibly and permanently. So the function reads the Meal's *stored, already-published* text from the database, embeds that, and writes back one column for one Meal id. **Principle II is not violated, and here is the argument rather than the assertion:** the principle exists so no claim a human reads enters the database without a human approving it. An embedding is not a claim. It asserts nothing, is shown to nobody, and is a machine representation of text a Cook already wrote and already published. Requiring a Cook to approve 768 floating-point numbers would be theatre. **This must be reviewed by `ai-boundary-reviewer` on the diff, not accepted from this paragraph.** | Writing the embedding from the Cook's own session preserves the letter of the rule and opens the manipulation hole above — the client would supply the vector. A database trigger calling out to a vendor puts a vendor credential inside Postgres, which is worse than an Edge Function in every respect. Doing nothing means Meals are not findable, which is the feature. |
| **Three new Edge Functions rather than one** | They differ in every property that matters: `discover` is on the critical path, holds no service-role key, and must be fast; `judge-results` is off the critical path, is allowed to fail silently, and calls a generative model; `embed-meal` runs at publish time, holds a service-role key, and writes. Folding them together would give the union of their privileges to all three — the read path would inherit a write capability it must not have. | One function with a mode flag is smaller in file count and strictly worse in authority: the thing serving anonymous search requests would hold the key that writes Meals. |
| **The provider registry gains an embedding capability** | Embedding is a second kind of model call and ADR-0005 Amendment 1 requires every model call through the registry, with the model id in exactly one place. A second call shape means the registry describes two, not that a second seam appears. | Calling the vendor directly from `discover` puts a model id outside the registry, which `verify.sh` fails on by design, and would make the provider switch a lie for half the AI in the product. |
| **A second front-end in a second language** | ADR-0008 Amendment 1, founder's decision. | Recorded there, not re-argued here. |

## What this plan does not decide

- **Which model performs the relevance judgement, and what a search costs.** The embedding model is
  settled — `gemini-embedding-2` at 768 dimensions, measured. The judgement is a generative call
  running once per search, and it is now the entire cost of discovery. It needs pricing the way E2
  priced a published Meal, and the free tier's 1,000 requests a day cannot serve it.
- **How a Meal published before this feature gets its vector.** A backfill exists and is mechanical;
  whether it runs as a migration or a one-off script is a `tasks.md` question.
- **Whether the retrieval-quality regression runs in the gate or nightly.** It calls a vendor and
  costs money on every run, which `verify.sh` has never done.
- **Anything about Orders.** Discovery ends at a Meal. E4.
