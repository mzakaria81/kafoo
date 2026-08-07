# ADR-0011 — Store a Meal's embedding from the function that produces it

- **Status**: Accepted
- **Date**: 2026-08-07
- **Deciders**: Founder
- **Supersedes**: nothing. **Amends**: the blanket rule in `.claude/rules/ai.md` that a function
  reaching the model layer holds no write credential.

## Context

Kafoo's domain rule is that **the AI Assistant suggests and a human approves**. `.claude/rules/ai.md`
makes that structural rather than behavioural: the function that talks to a model provider holds no
service-role key and has no write path, so the AI Assistant is *unable* to write rather than
trusted not to. `scripts/verify.sh` enforced it by refusing any Edge Function that both imports
`_shared/ai/` and names a write credential.

E3 needs `meals.embedding` populated. Producing a vector means calling a provider; storing it means
writing a column that `protect_meal_embedding` deliberately allows only `service_role` to write —
because a client that can supply its own vector can supply the one nearest every query and rank its
Meal first for everything, permanently and invisibly.

So `embed-meal` needs both halves, and the gate refused it. That refusal was correct and the check
was working. What it could not express is that **this particular write is not the thing the rule
protects against.**

## Decision

**One exception, named, constrained, and enforced more tightly than the rule it replaces.**

`supabase/functions/embed-meal/` may hold a service-role credential and reach the model layer. In
exchange it is constrained by `scripts/check-ai-write-boundary.py`, which asserts:

- it writes **exactly** `meals.embedding` and no other column — plus `updated_at`, which an
  existing lifecycle trigger sets on every update to `meals` regardless of who is writing. Nothing
  reads it for ordering. Named here because the sentence was originally written without it and a
  claim that is almost true is the kind that gets quoted.
- it touches **only** the `meals` table
- it never `.insert(`, `.delete(`, `.upsert(` or `.rpc(`
- the exception cannot be claimed by a function that does not exist

Every other function keeps the original blanket ban. A new function reaching the model layer with a
write credential still fails, unchanged.

**That sentence was false for a day.** The check scanned only `*.ts`, so the same function written
in `.js` — which Deno runs — was invisible, and the replacement was therefore *wider* than the grep
it replaced on an axis nobody had considered. It also missed a connection string used as a
credential. Both fixed 2026-08-07, and both were found by running them rather than by reading.

**The privileges are the real guarantee; the script is the second line.** Migration
`20260807064927` grants `service_role` exactly `UPDATE (embedding)` and `SELECT (id, cook_id)` on
`meals`, over a role holding no table-level privilege there. `data_api_grants_test.sql` asserts the
consequence as an ENUMERATION — exactly three column privileges and no others — rather than as a
list of forbidden columns, because a hand-written list of what is forbidden is only as good as the
imagination of whoever wrote it. Six plausible widenings passed the hand-written version.

A column grant constrains the statement and not the row that lands, so a later BEFORE trigger could
write anything during the permitted update — demonstrated. `service_role_writes_only_embedding`
states the rule directly, and `discovery_rls_test` cases 28-29 hold it.

Every evasion demonstrated against the script dies at the database.

## Why an embedding is the value the approval rule cannot cover

The rule exists because a model's output is a *claim* — a calorie estimate, an allergen list, a
description — and a claim reaching a Customer without a human seeing it is how Kafoo would lie to
somebody. Every such field in Kafoo carries a `source` column and an approval step for exactly that
reason.

An embedding is none of that:

- **It is not a claim.** It is a machine representation of words the Cook already wrote and already
  approved. Nothing new is asserted about the food.
- **It is shown to nobody.** No screen renders it, and nothing presents it as an assertion about
  food.

  **The stronger claim — that nothing even fetches it — was written here and was false.**
  `meal_repository.dart` used a bare `select()`, so every Meal the Cook's app read carried the
  vector, and `search_meals` returns whole rows to `anon`. Found by ai-boundary-reviewer on
  2026-08-07 and fixed on the client. It matters less for bandwidth than for ranking: a Cook cannot
  write their own vector, but they write the description that produces it, and a public corpus of
  text-and-vector pairs is what makes tuning a description against the ranker practical. The read
  side was reopening what the write side closed.

- **Ranking is an AI act Kafoo already permits, and this is the honest version of the claim above.**
  A vector orders what a Customer reads, and ordering asserts relevance. `business-rules.md` lists
  "rank search results" among the things the AI Assistant may do, so this is permitted rather than
  unnoticed — but "nothing here reaches a Customer" would have been the wrong defence. What does not
  depend on the model is the one place Kafoo makes a factual statement off this query: FR-024's
  "your area is empty" is decided by the filter-first CTE, not by a vector.
- **There is no judgement to apply.** Asking a Cook to approve 768 floating-point numbers is
  theatre, and theatre that teaches people to click through approval screens is worse than no
  approval screen — it devalues the ones that matter.
- **Its failure mode is already safe.** The column is nullable, and a Meal without a vector is
  harder to find rather than lost or wrong.

## What was rejected

**Putting the provider credential inside Postgres** so the database embeds. Rejected during E3
design (`research.md` §7) and again here: a model provider's key living in the database is a worse
trade than this one, and it moves a secret into a system whose backups and logs have different
handling.

**Splitting into two functions**, one that calls the model and one that writes. It moves the
credential without removing it — something still holds both ends — and it buys a boundary that a
reader would have to reconstruct from two files instead of one.

**Dropping searchable Meals from E3.** Browse and exclusions would still work; "find me something
light" would not. That is most of what E3 is for.

**Editing the gate to let `embed-meal` through.** This is the option that looks like the others and
is not one. The check is the reason the property is true; a check with a hole shaped like the thing
it was about to catch is not a check. The difference between that and this ADR is that the
exception here is *narrower* than the rule, written down, and mechanically enforced.

## Consequences

**The property is now conditional and says so.** "The AI cannot write" becomes "the AI cannot write
anything but a vector into one column of one table". That is a weaker sentence and it is a true one,
which the previous sentence would have stopped being the moment this feature shipped.

**The blast radius is enumerable.** The model's output reaches the database only as numbers, whose
width is checked before the write. It has no path to a title, a price, a status, or a Review,
because the function never writes those columns under any input.

**A second column is a new decision, not a code change.** The check fails on it, and the failure
names this ADR. That is the mechanism that stops this exception growing quietly, which is how
exceptions normally fail.

**If `embed-meal` ever needs to write something else, this ADR is wrong** rather than incomplete.
The reasoning above is entirely about embeddings not being claims; it does not transfer to a second
field, and it must not be stretched to cover one.
