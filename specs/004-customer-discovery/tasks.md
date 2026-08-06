---

description: "Task list for E3 — Customer Discovery"
---

# Tasks: Customer Discovery

**Work is assigned as packages, not as tasks — see `coordination/`.** A task number here says what
must be true; a work package in `coordination/packages/` says who is doing it, what it may spend,
and what else it collides with.

**This file is the reasoning; the packages are the state.**

**Only the coordinator edits planning state here**, and only after pulling `main`. Two sessions each
took the number T097 on 2026-08-05 by reading a local copy.

**Task ids continue from T101 rather than restarting at T001, which breaks with E0, E1 and E2.**
Those three each restart, so `T045` names an E0 task and `T075` names an E2 one and nothing in the
number says which. `docs/HANDOFF.md` already cites bare task numbers across all three epics. Global
numbering costs nothing and makes a citation mean one thing. E3 owns **T101 onward**; the highest
number claimed anywhere before this file was T100.

**Input**: Design documents from `specs/004-customer-discovery/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Authorization tests are **mandatory** and are written before the thing they test, per the
constitution. Golden cases are mandatory for new AI behaviour. This epic adds a third mandatory
kind — **a retrieval-quality regression**, because ranking is the first thing in Kafoo whose
correctness is statistical rather than binary.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel — different files, no dependency on incomplete work
- **[Story]**: Which user story the task serves

## A note on ordering

**US1 needs no new database work at all**, and that is the point of it being P1. Browsing what is on
offer is answered entirely by the policies E2 already shipped. It is a genuinely thin slice that can
ship on its own, and everything expensive sits behind it.

So the migration, `pgvector`, and all three Edge Functions live inside **US2's** phase rather than in
Foundational. Putting them in Foundational would mean US1 could not ship without them, which would
make the priority ordering a fiction.

**Within US2, the authorization tests come before the migration**, and must be seen to fail. This is
the constitution's requirement and it matters more here than it did in E2: E3 adds no policy, so
every existing authorization test passes whether or not search leaks. A green suite is not evidence
about a route it does not travel.

---

## Phase 1: Setup

- [ ] T101 Confirm the `vector` extension is available on the Postgres version pinned in `supabase/config.toml`, and record the version and availability in `specs/004-customer-discovery/research.md` §1 — a missing extension changes the plan, not the migration
- [ ] T102 [P] Add `discovery` feature directories `presentation/`, `application/`, `data/` under `apps/mobile/lib/features/discovery/` following the E1 and E2 layering
- [ ] T103 [P] Add the `Discovery` section headers to `apps/mobile/lib/l10n/app_ar.arb` and `app_en.arb` so parity is established before the first string lands, Arabic written first
- [ ] T104 Read `docs/ops/spike-discovery-embeddings.md` end to end before starting T125 — it is the evidence behind three decisions in this file and one of them reverses an intuition

---

## Phase 2: Foundational

Shared by every story. Deliberately small — see the ordering note.

- [ ] T105 [P] Create `DiscoveryRequest` in `packages/domain/lib/discovery_request.dart` — phrase, exclusions, unparsed-exclusion marker, area. No Flutter, no Supabase
- [ ] T106 [P] Create `DiscoveryResult` in `packages/domain/lib/discovery_result.dart` — a ranked Meal plus a judgement that may not have arrived yet
- [ ] T107 [P] Create `Exclusion` and the controlled vocabulary in `packages/domain/lib/exclusion.dart` — each entry carries its Arabic surface forms
- [ ] T108 Export the three new entities from `packages/domain/lib/domain.dart`
- [ ] T109 Define `DiscoveryRepository` in `apps/mobile/lib/features/discovery/data/discovery_repository.dart` — the only layer permitted to touch Supabase
- [ ] T110 [P] Add `FakeDiscoveryRepository` to `apps/mobile/test/` following the existing `Fake*Repository` pattern, so every widget test runs without a network

---

## Phase 3: User Story 1 — A Customer sees what is on offer (P1)

**Goal**: A Customer opens Kafoo having said nothing and sees the Meals currently on offer, and can
reach the kitchen behind any of them.

**Independent test**: With several Cooks whose Meals are in different states, open Kafoo without
searching. Only Meals on offer appear; the kitchen with only drafts is absent entirely.

**This ships alone.** No embedding, no Edge Function, no migration.

- [ ] T111 [US1] Add `fetchMealsOnOffer` to `DiscoveryRepository` and implement it against Supabase, reading only what RLS already permits
- [ ] T112 [P] [US1] Widget test for the browse screen's three states — loading, Meals, empty — in `apps/mobile/test/features/discovery/`
- [ ] T113 [US1] Build the browse screen in `apps/mobile/lib/features/discovery/presentation/browse_screen.dart`. Use a `Column` inside a `SingleChildScrollView` for a fixed handful of children — a lazy `ListView` silently failed to build its first child on the public kitchen view and cost a test nobody could write
- [ ] T114 [US1] Riverpod controller in `apps/mobile/lib/features/discovery/application/browse_controller.dart`
- [ ] T115 [US1] Meal card widget in `packages/ui/` — title, price, kitchen name. Wrap any network image in a named widget and assert on that; `Image.network` cannot resolve under the test binding and takes its subtree with it
- [ ] T116 [US1] Route from a Meal to its Kitchen Profile, reusing E2's public kitchen view
- [ ] T117 [US1] Empty state — Kafoo says in words that nothing is on offer (FR-006), never a blank screen
- [ ] T118 [P] [US1] Arabic and English strings for the browse screen in both ARB files, Arabic first
- [ ] T119 [US1] Confirm by hand that a Cook with only drafts is absent from browse, and that taking the last Meal off the menu removes the kitchen — quickstart §4 rows 1 and 12
- [ ] T120 [P] [US1] Accessibility pass on the browse screen — semantic labels, tap targets, text scaling, RTL
- [ ] T121 [US1] Verify SC-001 by name: a Customer reaches a Meal's full details within three actions of arriving, without searching and without signing in

---

## Phase 4: User Story 2 — A Customer asks for food in their own words (P2)

**Goal**: A Customer says what they feel like and Kafoo returns Meals matching the meaning, including
across languages and scripts.

**Independent test**: Requests sharing no words with the Meals that should answer them, and requests
in a different language from the Meals, return the right Meals.

### The authorization tests, written first and seen to fail

- [ ] T122 [US2] Write `supabase/tests/discovery_rls_test.sql` covering cases 1–8 of [contracts/authorization.md](contracts/authorization.md), with fixtures containing a Meal of **every** status — a fixture holding only published Meals lets these assertions pass for the wrong reason
- [ ] T123 [US2] Write cases 9–11 of the same contract — a Cook must not be able to write `meals.embedding`. The existing `cook updates own meals` policy permits it today, so this passes trivially in the wrong direction until something stops it
- [ ] T124 [US2] **Run both and confirm they FAIL.** Record the failure output in the pull request. A negative test that passes on its first run is testing nothing
- [ ] T125 [US2] Update the `plan(N)` count in `discovery_rls_test.sql` — this line is a known collision point between parallel workers and belongs in `scope.shared_files` of any work package touching it

### The migration

- [ ] T126 [US2] `supabase migration new add_meal_embeddings` — **never hand-write the filename**
- [ ] T127 [US2] In that one file: enable `vector`, add `meals.embedding vector(768)` **nullable**, add the HNSW index for cosine distance, and create `search_meals` as **`SECURITY INVOKER`**. Nullable is a rule, not a default — a Meal with no vector must be invisible to search and still visible to browsing
- [ ] T128 [US2] Add a column-level protection preventing a client writing `meals.embedding`, and re-run T123 — it must now go green
- [ ] T129 [US2] Re-run T122 and T124's suites; all cases green. Then make `search_meals` `SECURITY DEFINER` on purpose, confirm cases 2–6 go **red**, and put it back
- [ ] T130 [US2] Run `python3 scripts/mutate-policies.py` — zero clauses with no assertion behind them. Weaken the kitchen policy and the meals policy **together** and confirm cases 7–8 go red; each masks the other, so weakening one alone proves nothing
- [ ] T131 [US2] `EXPLAIN ANALYZE` the search function and confirm the HNSW index is in the plan. A sequential scan returns correct answers slowly and no test will ever catch it

### The provider seam

- [ ] T132 [US2] Extend the registry in `supabase/functions/_shared/ai/types.ts` and `registry.ts` with an **embedding** capability alongside generation
- [ ] T133 [P] [US2] Implement embedding in `supabase/functions/_shared/ai/gemini.ts` — `gemini-embedding-2`, 768 dimensions, task-typed, and **normalise the vector**: the provider normalises only at its native 3072 and cosine similarity on a non-unit vector is quietly wrong
- [ ] T134 [P] [US2] Have `anthropic.ts` and `openai.ts` either implement embedding or declare that they cannot — a silent fallback to the wrong provider is what `registry_test.ts` exists to catch
- [ ] T135 [US2] Extend `registry_test.ts` for the embedding capability, including a half-added provider and a wrong-provider fallback

### `embed-meal`

- [ ] T136 [US2] Create `supabase/functions/embed-meal/index.ts` per [contracts/embed-meal.md](contracts/embed-meal.md). Request carries **a Meal id and nothing else**; the function reads `title` and `description` **from the database**
- [ ] T137 [US2] Constrain it to writing `meals.embedding` only — not `status`, not `updated_at` as a side effect that would reorder a Cook's menu
- [ ] T138 [P] [US2] `deno test` for `embed-meal`: a client-supplied text field is ignored, a nonexistent Meal id does not disclose whether it exists, a malformed vector writes nothing
- [ ] T139 [US2] Call `embed-meal` when a Meal is published and when its title or description changes. **Not** on a price, photo or status change
- [ ] T140 [US2] Publishing must succeed when the provider is unreachable, leaving the Meal without a vector. Test it with the provider stubbed to fail

### `discover`

- [ ] T141 [US2] Create `supabase/functions/discover/index.ts` per [contracts/discover.md](contracts/discover.md). **No service-role key**, and it passes the caller's credentials through to `search_meals`
- [ ] T142 [US2] Deterministic phrase parsing — negation markers, the noun after them, an area. **No model call**; a generative call here would put the model on the critical path FR-011 keeps it off
- [ ] T143 [P] [US2] `deno test` for `discover`: it never writes, never caches on the phrase, never reorders what the database returned
- [ ] T144 [US2] Wire `discover` into `DiscoveryRepository` and the search controller

### The app

- [ ] T145 [US2] Search input in `apps/mobile/lib/features/discovery/presentation/search_screen.dart` — **one** input carrying phrase, exclusion and area together. Three separate controls would be a form at the exact point Principle IV forbids one
- [ ] T146 [US2] Voice input where the device supports it, falling back to typing. Catch `Object` rather than `Exception` — an uninitialised client throws `StateError` and a missing plugin throws `TypeError`, and both stranded a spinner forever in E1
- [ ] T147 [US2] Results render as soon as `discover` returns, with no await on any judgement — FR-011
- [ ] T148 [US2] The zero-state of search is browse, and so is the fallback when nothing matched — FR-012
- [ ] T149 [P] [US2] Widget tests for search: loading, results, error, and voice-unavailable
- [ ] T150 [P] [US2] Arabic and English strings for search in both ARB files, Arabic first
- [ ] T151 [US2] Emit `SearchPerformed` with `result_count`. Assert by test that **no phrase** reaches the event, a log line, or an error carrying the request
- [ ] T152 [US2] Backfill vectors for Meals published before this feature — a script, not a migration, and an incomplete run must leave Meals harder to find rather than lost
- [ ] T153 [US2] Promote `scripts/spike-discovery-embeddings.py` to a retrieval-quality regression with a recorded baseline, and decide whether it runs in the gate or nightly — it calls a vendor and costs money, which `verify.sh` has never done
- [ ] T154 [US2] Measure search latency against production the way E2 measured its budgets, and report it against the 1s budget rather than asserting it
- [ ] T155 [US2] Verify SC-002 and SC-003 by name against the corpus

---

## Phase 5: User Story 3 — Kafoo says when it has nothing (P2)

**Goal**: When nothing on offer answers a request, Kafoo says so and names what is actually on offer,
rather than presenting its closest guesses as answers.

**Independent test**: Ask for a food nothing resembles — Kafoo states nothing matches. Ask for
something on offer — it does not say the same thing.

- [ ] T156 [P] [US3] Write `prompts/discovery-judgement.md` — a file, never a string literal. It must forbid claiming popularity, forbid claiming proximity, and forbid naming any Meal not supplied
- [ ] T157 [US3] Create `supabase/functions/judge-results/index.ts` per [contracts/judge-results.md](contracts/judge-results.md). It may not reorder, filter, add or remove a Meal
- [ ] T158 [P] [US3] Golden cases in `packages/ai/test/goldens/` built from `docs/ops/discovery-corpus.json`: results plainly answer; nothing answers; **results topically close but wrong**; a request inviting a popularity claim; a request inviting a proximity claim; adversarial text inside the request
- [ ] T159 [US3] The topically-close-but-wrong case is the one that justifies this whole function — if the judgement only catches obviously unrelated results, it has bought nothing a score already failed to do
- [ ] T160 [US3] Call `judge-results` **after** results are on screen, never before, and never awaited alongside them
- [ ] T161 [US3] When the judgement fails, times out, or returns nonsense, results stay exactly as they are and the Customer loses a sentence
- [ ] T162 [US3] Present "nothing matched" with named alternatives that are genuinely on offer at that moment — FR-015
- [ ] T163 [P] [US3] Arabic and English strings for the nothing-matched state, Arabic first, Egyptian register
- [ ] T164 [US3] Emit `SearchFailed` when the judgement says nothing answers, and `RecommendationAccepted` when a Customer opens a named alternative
- [ ] T165 [US3] Verify SC-004 by name — **100%**, and it does not degrade with corpus size

---

## Phase 6: User Story 4 — An exclusion is honoured exactly (P2)

**Goal**: A Customer says what they do not want and Kafoo does not show it to them.

**Independent test**: Ask for food excluding something several Meals contain. Not one of those Meals
appears, at any position.

**Read `research.md` §3 before starting.** Meaning-matching returns meat when asked for none — rank 6,
precision@5 of 0.00. This phase exists because that measurement happened.

- [ ] T166 [US4] Populate the controlled exclusion vocabulary in `packages/domain/lib/exclusion.dart` with its Arabic surface forms — meat, chicken, fish and seafood, eggs, dairy, gluten, nuts
- [ ] T167 [P] [US4] Unit tests for the negation-marker parser — `من غير`, `بدون`, `مش عايز`, and the same idea spelled three ways mapping to one exclusion
- [ ] T168 [US4] Translate exclusions into SQL predicates over `meals.ingredients` and `meals.allergens` inside `search_meals` — **never** into the phrase that gets embedded
- [ ] T169 [US4] Withhold a Meal whose relevant field is empty — FR-021. An unknown is a possible yes. This hides Meals that are fine, and that is the correct direction to be wrong in
- [ ] T170 [US4] When a negation marker is recognised but its noun is not, return the unparsed marker so the interface can say Kafoo did not understand — **never** return results as though no exclusion was asked for
- [ ] T171 [US4] Never relax an exclusion to fill the screen — FR-020
- [ ] T172 [P] [US4] Write `supabase/tests/discovery_exclusion_test.sql`, **seen to fail first**: a Meal containing the excluded thing appears at no position, and a Meal with an empty ingredient list is withheld
- [ ] T173 [US4] The interface states what was filtered on and **never states that a Meal is safe**. `meals.allergens` is frequently an AI estimate carrying `nutrition_source`, and the distinction between a filter and a medical claim is the whole point
- [ ] T174 [P] [US4] Arabic and English strings for the exclusion states, Arabic first
- [ ] T175 [US4] Verify SC-005 by name — **zero** occurrences across the exclusion test set. One is a failure of the feature, not a ranking miss

---

## Phase 7: User Story 5 — Finding a kitchen without installing anything (P3)

**Goal**: Someone who has installed nothing and signed in to nothing can find a kitchen, read its
Meals, and see who cooks them.

**Independent test**: Reach a kitchen and a Meal in a browser having installed nothing. Everything
visible obeys the same rules as inside Kafoo.

- [ ] T176 [US5] Scaffold `apps/web/` — Next.js, TypeScript, per ADR-0008 Amendment 1
- [ ] T177 [US5] Configure the Cloudflare Workers adapter and confirm a build deploys. Next reaches Cloudflare through an adapter rather than natively; this is the step most likely to cost a day
- [ ] T178 [US5] Supabase client in `apps/web/lib/` using **only** the publishable key
- [ ] T179 [US5] Add a check that fails the build if a service-role key reaches the bundle — `verify.sh` catches a *tracked* key, and a bundle is not a tracked file, so it does not inherit that protection
- [ ] T180 [P] [US5] Arabic and English message files under `apps/web/messages/`, Arabic first, and RTL throughout
- [ ] T181 [US5] Kitchen page showing **exactly** the five public details and no sixth
- [ ] T182 [US5] Meal page, reading the same data under the same policies
- [ ] T183 [US5] Browse and search on the web, calling the same `discover` function — no second data path, no second visibility model
- [ ] T184 [US5] A kitchen with nothing on offer is not reachable — FR-027, same terms as in the app
- [ ] T185 [US5] Shared-reference preview carrying **exactly** name, area and photo — FR-027a. Not the story, not the delivery terms, not a Meal count
- [ ] T186 [US5] Assert that no rating, review count or order count appears anywhere — FR-027c. None exist, and a placeholder for one is a fabricated measurement rather than an empty field
- [ ] T187 [P] [US5] Verify field by field that what is visible without installing is identical to what is visible inside Kafoo — SC-009
- [ ] T188 [US5] Restore the web deploy job in `.github/workflows/deploy.yml`, written against a surface that now exists. The previous one was deleted for pointing at a directory that never existed and reporting success on every merge
- [ ] T189 [US5] Verify SC-012 by name against the shared reference itself, not the page it leads to

---

## Phase 8: Polish & cross-cutting

- [ ] T190 Disclose that a Customer's words leave Kafoo to be understood, on both surfaces, following E2's precedent — `research.md` §5. Not recording a phrase is not the same as not sending it
- [ ] T191 Route to the founder: whether a Customer may refuse that and fall back to browsing only. E2 let a Cook refuse; the symmetry argues yes, and it is not a session's call
- [ ] T192 [P] Update `docs/product/domain-model.md` with the embedding column and the rule that a Meal without one is browsable but not searchable — Definition of Done item 6, in the same commit
- [ ] T193 [P] Update `docs/product/event-model.md` — `SearchFailed` now means "judged", not "scored below a line", because `research.md` §4 established that no line exists
- [ ] T194 [P] Update `docs/HANDOFF.md` — E3's state, the open cost question, and what the spike settled
- [ ] T195 [P] Update `CLAUDE.md`'s repo map with `apps/web/`, and the constraint that `packages/domain/` cannot be imported there
- [ ] T196 Extend `scripts/verify.sh`'s vocabulary and localization checks to cover `apps/web/` — a new surface that no check reads is a surface with no rules
- [ ] T197 Price a search end to end. The judgement runs once per search rather than once per failure, so it is the entire cost of discovery, and the free tier's 1,000 requests a day cannot serve it
- [ ] T198 [P] Accessibility review of every new screen on both surfaces
- [ ] T199 Walk `quickstart.md` end to end as someone with none of this context
- [ ] T200 Verify SC-001 to SC-013 individually by name. Four are stated as **zero** — SC-005, SC-008, SC-010, SC-013 — and one occurrence is a failure of the feature
- [ ] T201 Run `./scripts/verify.sh`, then `/ship-check`

---

## Dependencies

```text
Setup (T101–T104)
   └─> Foundational (T105–T110)
          ├─> US1  Browse            (T111–T121)   ships alone, no new backend
          ├─> US2  Search            (T122–T155)   needs US1's browse as its zero-state
          │        └─> US3  Nothing matched (T156–T165)
          │        └─> US4  Exclusions       (T166–T175)
          └─> US5  Without installing (T176–T189)  needs US1 and US2 to exist; independent of US3/US4
                                                    and can run in parallel with them
   └─> Polish (T190–T201)
```

**US3 and US4 both depend on US2 and not on each other.** They can run in parallel by two workers,
and both touch `search_meals` and the ARB files — declare those in `scope.shared_files`.

**US5 is the parallelisable one.** It shares no source files with the app work; its only collisions
are the ARB files and the deploy workflow.

## Parallel execution

- **T105, T106, T107** — three domain entities, three files, no dependencies
- **T133, T134** — provider adapters, one file each
- **US3 and US4** — after US2 lands, two workers, serialised only on `search_meals` and `plan(N)`
- **US5 alongside US3 and US4** — a third worker, colliding only on the ARB files

## Implementation strategy

**MVP is US1 alone.** Browsing what is on offer works at twelve Meals, needs no migration, no Edge
Function and no vendor, and is what every other story falls back to. It is worth shipping before
anything else is started.

**Then US2**, which is the largest phase by a distance and carries the migration, the three Edge
Functions and the provider extension.

**Then US3 and US4 together**, because search that always answers confidently is the failure this
feature exists to prevent, and neither is optional once US2 exists.

**US5 whenever a worker is free** after US2 — it is the only phase that shares almost no files with
the rest.
