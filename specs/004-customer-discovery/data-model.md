# Data Model: Customer Discovery

Phase 1 for [plan.md](plan.md). Authority for the domain remains
`docs/product/domain-model.md`; this records only what E3 changes.

**E3 adds no table, no bucket, and no personal data.** It adds one column, one index, one database
function, and three entities that live in `packages/domain/` and are never persisted.

## What changes in the database

### `meals` — one new column

| Column | Type | Null | Meaning |
|---|---|---|---|
| `embedding` | `vector(768)` | **yes** | A machine representation of `title` and `description`. Not a claim, not shown to anyone, not editable by a Cook. |

**Nullable on purpose, and the nullability carries a rule.** A Meal with no vector is **invisible to
search and still visible to browsing**. That makes an incomplete backfill, an unreachable provider,
or a failed embedding produce a Meal that is harder to find — never a Meal that is lost. If this
column were `NOT NULL` the failure would move into the publish path, where a vendor being down would
stop a Cook offering food.

**768 dimensions.** Measured (`research.md` §1). pgvector's HNSW index refuses more than 2000, so the
provider's default of 3072 would produce a column that works and cannot be indexed.

**Written by exactly one thing** — the `embed-meal` Edge Function, from text it reads out of the
database rather than from a request body. A Cook's session must never write this column, and RLS is
not what stops it: the existing `cook updates own meals` policy would permit it. The column is
excluded at the write path and the negative test in `discovery_rls_test.sql` proves a Cook cannot set
it.

### `meals` — one new index

An HNSW index over `embedding` for cosine distance, **created now and deliberately unused now.**

This paragraph previously described scanning every Meal as the failure mode. The design does that on
purpose. An approximate index picks its candidates and any filter applied afterwards discards them,
so a narrow search over a large corpus returns nothing while matching Meals plainly exist —
measured, and the reason `search_meals` narrows first and ranks what survives.

Exact ranking costs 27 ms at 5,001 Meals against a one-second budget and grows linearly, so the
budget is reached near 180,000 Meals. The index is **deferred capacity for that day**, not dead
weight and not something a later migration should drop. Taking it up again means filtering before
ranking rather than after — not reverting to the arrangement this replaced.

`cook_id` is already indexed (E2), which the existing policies need.

### RLS — unchanged, and that has to be proven rather than stated

No policy is added, removed, or altered. `meals` keeps its four per-operation policies and
`kitchen_profiles` keeps E2's widening `SELECT`. Discovery is a different way of asking the question
E2 already answered.

The proof obligation is on this feature anyway, because **every existing authorization test passes
whether or not search leaks** — none of them go through a ranking path that did not previously exist.
`discovery_rls_test.sql` must show a draft, an unavailable and an archived Meal each returning zero
rows *through search*, and must be seen to fail before the function exists.

### `search_meals` — one new database function

`SECURITY INVOKER`, so RLS applies as the caller. Takes a query vector, an optional set of
exclusions, and an optional area. Returns ranked Meals the caller is permitted to see.

**`SECURITY DEFINER` would make every Meal findable and no existing test would notice.** That is
recorded here because it is a one-word change that removes the entire authorization story.

## What does not change

- **No new table.** Nothing in discovery is owned by anyone, so there is no ownership question to
  answer. `docs/product/domain-model.md`'s ownership table is untouched.
- **A Kitchen Profile's public face stays at exactly five details** — display name, story, area,
  delivery terms, photo. FR-027b. Discovery adds no sixth and introduces no personal name, phone
  number, address or location for a Cook.
- **`kitchen_profiles.area` gains no structure.** It stays free text in the Cook's own words. It is
  not geocoded, standardised, or validated, which is why FR-024b forbids stating a distance — Kafoo
  has no notion of where an area is.
- **Nothing about a Customer is stored.** No search history, no preferences, no location, no
  relationship to a Cook. FR-023 and SC-010.

## Entities that exist only in memory

These live in `packages/domain/` — no Flutter, no Supabase — and are never written anywhere.

### `DiscoveryRequest`

What a Customer asked for, parsed from one sentence.

| Field | Meaning |
|---|---|
| `phrase` | What they said, as they said it. Held for the length of the interaction and **never recorded** (FR-029). |
| `exclusions` | Zero or more `Exclusion`s found in the phrase. |
| `unparsedExclusion` | Set when a negation marker was recognised but the thing excluded was not. **Kafoo says it did not understand rather than dropping it** — see `research.md` §3. |
| `area` | An area named by the Customer, matched against what Cooks wrote. Optional. |

### `Exclusion`

A controlled vocabulary, not free text. Each entry carries the Arabic surface forms that indicate it,
so the same idea written three ways is one exclusion.

The vocabulary is deliberately small and deliberately additive: an unknown noun after a negation
marker produces `unparsedExclusion` rather than a silent miss. **Growing this list is how exclusions
improve; guessing at it is how a Customer gets served meat they asked not to see.**

### `DiscoveryResult`

A ranked Meal, and what the AI Assistant later said about the set.

Two properties matter more than the fields. **The judgement is a separate arrival**, so a result set
is complete and displayable before any judgement exists — FR-011. And **the judgement can never
change a Meal's data**, only whether Kafoo says the set answers the request.

`Recommendation` stays what the glossary already says it is: owned by nobody, never persisted as
truth.

## Analytics

Three events, all reserved in `docs/product/event-model.md`, none invented here.

| Event | When | Attributes |
|---|---|---|
| `SearchPerformed` | a search ran | `result_count` — **never the phrase** |
| `SearchFailed` | the AI Assistant judged that nothing answered the request | — |
| `RecommendationAccepted` | a Customer opened a Meal the AI Assistant named instead | — |

`SearchFailed` now means "judged", not "scored below a line". `research.md` §4 establishes that no
line exists.

**SC-011 is a property of this table, not of the code that writes to it**: no phrase a Customer typed
or spoke may be recoverable from anything Kafoo records — not in an attribute, not in a log, not in
an error message carrying the request that produced it.
