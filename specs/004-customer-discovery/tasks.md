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

- [ ] T122 [US2] Write `supabase/tests/discovery_rls_test.sql` covering cases 1–8 of [contracts/authorization.md](contracts/authorization.md), **including its `plan(N)` line**, with fixtures containing a Meal of **every** status — a fixture holding only published Meals lets these assertions pass for the wrong reason
- [ ] T123 [US2] Write cases 9–11 of the same contract — a Cook must not be able to write `meals.embedding`. The existing `cook updates own meals` policy permits it today, so this passes trivially in the wrong direction until something stops it
- [ ] T124 [US2] **Run both and confirm they FAIL.** Record the failure output in the pull request. A negative test that passes on its first run is testing nothing
- [ ] T125 [US2] Declare `discovery_rls_test.sql`'s `plan(N)` line in `scope.shared_files` of every work package touching it — it is a known collision point between parallel workers, and two workers each adding a case will both edit this one line

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
- [ ] T154 [US2] Measure search latency against production the way E2 measured its budgets, and report it against the 1s budget rather than asserting it. **Measure SC-007 separately**: the time from a request finishing to results being visible, with the judgement responding and with it stubbed to hang — the two must be the same, and a single latency number does not show that
- [ ] T155 [US2] Verify SC-002 and SC-003 by name against the corpus

#### Narrowing by area

Added 2026-08-06 after `/speckit-analyze` found FR-022 and FR-024 had a parser and nothing else.

- [ ] T202 [US2] Arabic normalisation in `packages/domain/lib/area.dart` — unify alef forms, `ة` to `ه`, `ى` to `ي`, strip diacritics and tatweel, drop a leading definite article, collapse whitespace, fold Latin case. **A Cook's stored area is never rewritten**; normalisation happens at comparison time
- [ ] T203 [P] [US2] Unit tests for the pairs in `research.md` §8 — `الدقي`/`الدقى`, `المهندسين`/`مهندسين`, `العجوزه`/`العجوزة`, `إمبابة`/`امبابة`, with and without diacritics
- [ ] T204 [US2] Area alias table in `packages/domain/lib/area.dart` for places with a genuine second name — `مصر الجديدة`/`هليوبوليس`/`Heliopolis`, `المعادي`/`Maadi`. Small, explicit, additive, and the same shape as the exclusion vocabulary
- [ ] T205 [US2] Test that the alias table does **not** merge two different neighbourhoods — FR-022a governs spelling, not meaning, and a tolerance loose enough to catch a typo is loose enough to match a different place
- [ ] T206 [US2] Normalised area predicate inside `search_meals`, applied to the Cook's stored area at comparison time
- [ ] T207 [US2] Accept an area as part of the **one sentence** a Customer says — `عايز حاجة من غير لحمة في المهندسين`. Not a second control; three inputs would be the form Principle IV forbids
- [ ] T208 [US2] Empty-area state: Kafoo says the named area has nothing **and** names the areas that do, and the Customer must choose one before anything from it is shown — FR-024 and FR-024a. Widening is never Kafoo's action
- [ ] T209 [US2] Assert that no distance is stated and no ordering by proximity exists — FR-024b. Kafoo has no notion of where an area is
- [ ] T210 [US2] Assert that offering another area never states or implies that a kitchen there will deliver — FR-024c. Delivery terms are words, not a radius
- [ ] T211 [P] [US2] Write the area cases into `supabase/tests/discovery_rls_test.sql`, **seen to fail first**: a differently-spelled area reaches the same kitchens, and an area nobody wrote returns zero rows rather than everything
- [ ] T212 [P] [US2] Arabic and English strings for the area and empty-area states in both ARB files, Arabic first
- [ ] T213 [US2] Verify FR-022, FR-022a, FR-022b, FR-024, FR-024a, FR-024b and FR-024c by name

#### Before this story ships

- [ ] T214 [US2] Have `ai-boundary-reviewer` and `rls-reviewer` review the `embed-meal` diff **before it merges**. The plan argues that a service-role key on an AI path is acceptable here because an embedding is not a claim; that argument must be checked by something other than the document making it
- [ ] T215 [US2] Disclose that a Customer's words leave Kafoo to be understood, before the first search, following E2's precedent for a Cook. **This ships with search, not after it** — as originally ordered it sat in Polish, which would have put search in front of Customers before they were told
- [ ] T216 [US2] A Meal that goes off offer between being ranked and being opened tells the Customer it is no longer available — FR-005, and the one freshness case a Customer actually meets

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
- [ ] T217 [P] [US3] `deno test` proving `judge-results` holds no service-role key and writes nothing — FR-018. It is write-free by construction today, and nothing currently stops that changing

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
- [ ] T218 [US5] Call `judge-results` from the web surface too, after results render. FR-026 requires what is visible without installing to be **exactly** what is visible inside Kafoo, and a web surface with results but no honesty layer would ship the confident wrong answer this feature exists to prevent
- [ ] T219 [US5] Area narrowing and the empty-area state on the web, matching the app — FR-022 and FR-024 on both surfaces
- [ ] T220 [US5] The disclosure from T215 on the web surface as well
- [ ] T184 [US5] A kitchen with nothing on offer is not reachable — FR-027, same terms as in the app
- [ ] T185 [US5] Shared-reference preview carrying **exactly** name, area and photo — FR-027a. Not the story, not the delivery terms, not a Meal count
- [ ] T186 [US5] Assert that no rating, review count or order count appears anywhere — FR-027c. None exist, and a placeholder for one is a fabricated measurement rather than an empty field
- [ ] T187 [P] [US5] Verify field by field that what is visible without installing is identical to what is visible inside Kafoo — SC-009
- [ ] T188 [US5] Restore the web deploy job in `.github/workflows/deploy.yml`, written against a surface that now exists. The previous one was deleted for pointing at a directory that never existed and reporting success on every merge
- [ ] T189 [US5] Verify SC-012 by name against the shared reference itself, not the page it leads to

---

## Phase 8: Polish & cross-cutting

- [ ] T190 Confirm the disclosure shipped on **both** surfaces — T215 and T220. It was written here originally, which would have meant search reaching Customers a whole phase before they were told their words leave Kafoo. Kept as a check rather than deleted, because the ordering mistake is easy to make again
- [ ] T191 **Answer before T215 is built, not here**: may a Customer refuse the disclosure and fall back to browsing only? E2 let a Cook refuse and the symmetry argues yes. It is the founder's call, and T215 cannot be finished without it
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
          ├─> US2  Search            (T122–T155, T202–T216)   needs US1's browse as its zero-state
          │        ├─> US3  Nothing matched (T156–T165, T217)
          │        ├─> US4  Exclusions       (T166–T175)
          │        └─> US5  the search half  (T183, T218, T219)
          └─> US5  the static half   (T176–T182, T184–T189)   needs only US1
   └─> Polish (T190–T201)
```

**US5 splits, and the earlier note overstated its dependence.** Scaffolding the web app, the kitchen
page, the Meal page and the shared preview need nothing from US2 — they read what E2 already
published, under policies that already exist. Only browse-and-search on the web (T183, T218, T219)
waits. **The static half can start alongside US1**, which is much earlier than the first version of
this graph implied.

**US3 and US4 both depend on US2 and not on each other.** Two workers in parallel; both touch
`search_meals` and the ARB files — declare those in `scope.shared_files`.

**T191 blocks T215, and T215 blocks US2 shipping.** It is a founder decision, so it should be asked
at the start of US2 rather than discovered at the end of it.

## Parallel execution

- **T105, T106, T107** — three domain entities, three files, no dependencies
- **T133, T134** — provider adapters, one file each
- **T202–T205** — area normalisation and aliases, independent of the migration
- **US5's static half alongside US1** — a second worker from the very beginning
- **US3 and US4** — after US2 lands, two workers, serialised only on `search_meals` and `plan(N)`

## Implementation strategy

**MVP is US1 alone.** Browsing what is on offer works at twelve Meals, needs no migration, no Edge
Function and no vendor, and is what every other story falls back to. It is worth shipping before
anything else is started.

**Then US2**, which is the largest phase by a distance and carries the migration, the three Edge
Functions and the provider extension.

**Then US3 and US4 together**, because search that always answers confidently is the failure this
feature exists to prevent, and neither is optional once US2 exists.

**US5's static half from the very beginning**, alongside US1, by a second worker. The web scaffold,
the kitchen page, the Meal page and the shared preview read what E2 already published under policies
that already exist — none of it waits on the migration. Only browse-and-search on the web needs US2.

**T191 first, before anything in US2 is built.** It is a one-line founder decision that T215 cannot
be completed without, and discovering that at the end of the largest phase is how a phase stalls.
