# Kafoo

AI-first marketplace connecting Egyptian home cooks with customers.
Voice-first, Egyptian Arabic default. Flutter (mobile) + Supabase (backend) + Cloudflare (deploy).

## Who you are talking to

**The founder is a company director, not a developer.** He runs a software company and has never
written code professionally. He reads architecture, weighs trade-offs and makes the calls on cost,
scope and risk — but he does not read Dart, SQL or shell, and should never have to in order to
follow you. **Your job is to be the translator. If he has to translate you, you did the job wrong.**

This changes how you write, not what you do. Engineering rigour is unchanged: the gate still runs,
RLS still lands in the same migration, tests still come first.

**The answer shape is enforced by hooks, not by this file.**
`.claude/hooks/communication-contract.sh` re-states it before every reply and
`check-reply-shape.py` refuses one that ignores it: bottom line first, labelled sections, exactly
one closing line, the four claim labels, What → Why → Consequence → Recommendation. Do not restate
those rules here — a rule kept in two places drifts in one of them, and the hook is the copy that
runs.

What a hook cannot check, and you still owe him:

- **Explain in consequence, not mechanism.** "This would have failed the first time we deployed a
  database change" beats "the pinned npm version does not resolve".
- **Concrete over abstract.** Not "concept-level population in the food ontology" but "only create a
  food concept when an ingredient needs one — mayonnaise needs *egg* because someone may exclude
  eggs; sumac does not".
- **Name the trade-off and pick one.** He is deciding, so he needs your expert opinion rather than a
  neutral survey — and **say what it costs**, in money and in ongoing commitment.
- **Show code only when the code is the subject.** A file path and a plain-English summary is
  usually enough. Do not paste diffs to prove work happened.
- **Do not perform simplicity by hiding bad news.** Plain English is not softer English. If
  something is broken, half-finished or riskier than it looks, say so plainly and early — clearly
  enough that the bad news survives the simplification. That is the judgement he is relying on you
  for.

## Commands

```bash
./scripts/install-toolchain.sh   # Flutter, melos, Deno, Supabase CLI, opencode (idempotent, ~3s warm)
melos bootstrap              # install deps across all packages
melos run analyze            # dart analyze, all packages
melos run test               # unit + widget tests
flutter test test/foo_test.dart   # single test — prefer this over full suite
supabase start               # local stack (Docker required)
supabase db reset            # rebuild local DB from migrations + seed (needs Docker)
./scripts/local-db.sh test   # RLS suites against a real Postgres — no Docker. docs/ops/local-database.md
supabase migration new NAME  # NEVER hand-write migration filenames
supabase functions serve     # local Edge Functions
deno check supabase/functions/**/*.ts   # type-check Edge Functions (also in verify.sh)
./scripts/verify.sh          # full gate — must pass before any PR
```

`.env` is git-ignored. Copy `.env.example` and fill it. Never read, print, or commit `.env`.

## Non-negotiables

**YOU MUST** run `./scripts/verify.sh` before declaring any task done. Not "it should pass" — run it.

**YOU MUST** enable RLS on every new table in the same migration that creates it. A table without
RLS is a data breach, not a TODO.

**NEVER** call an AI provider SDK directly from Flutter or from feature code. All model calls go
through the provider abstraction in `packages/ai/`. Swapping OpenAI → Anthropic → Gemini must be a
config change, not a refactor. (ADR-0005)

**NEVER** hardcode user-facing strings. Every string goes through ARB files with an Egyptian Arabic
entry. `ar` is the default locale, not the fallback. **In `apps/web/` the same rule points at a
different file** — `apps/web/messages/ar.json` and `en.json`, because a TypeScript surface cannot
read Flutter's ARB. Two locale files, one rule: no string outside them, `ar` written first.

**The iOS permission prompts are the one exception, and it is a platform limit rather than a
choice.** `apps/mobile/ios/Runner/Info.plist` carries the `NS*UsageDescription` strings — the
sentences iOS shows when Kafoo asks for the microphone, speech recognition or the photo library.
iOS reads them before Flutter has started, so ARB does not exist yet at the moment they are
displayed; there is no version of this rule that reaches them. They are written in Egyptian Arabic
and not mirrored into English, because `main.dart` pins the locale to `ar` whatever language the
phone is set to. **Do not "fix" them into ARB** — the app crashes without them, and the crash is
silent to every check the gate runs. Raised by release-engineer on 2026-08-10, once the strings
existed and looked like an oversight.

**NEVER** build a form where a conversation would work. If you find yourself adding a fourth input
field, stop and propose a conversational flow instead.

**NEVER** ship a component without its spoken Egyptian Arabic line. **Kafoo is voice-first as of
2026-08-10 (ADR-0013), and that is a different thing from what this file used to mean by it.** It
used to mean a microphone button on a form. It now means the assistant speaks, the user speaks
back, and **the screen is the receipt of that exchange rather than the place information first
appears.** The assumption underneath is that a Cook may not read comfortably — so anything only the
screen says is invisible to the person the product exists for.

Four consequences bind every screen, and `docs/design/DESIGN.md` §10 has the rest:

- **A component is unfinished until its spoken line is written.** Visual states alone are no longer
  a component. This changes what "done" means for `packages/ui/` and every widget above it.
- **The assistant paraphrases what it understood; it never shows a transcript.** The one exception
  is a message to another human, which is read back verbatim before sending — those exact words are
  what the other person receives.
- **Reversible actions execute and are announced. Irreversible ones are read back and wait for a
  spoken «أيوة». Silence never confirms**, and no timeout may resolve a gate.
- **Every state reaches the user three ways — visual, spoken, haptic — any one sufficient alone.**

**Tap is a complete alternative, never a degraded one**, and typing is never a *consequence* of the
assistant failing to understand. Large Arabic text is a closed set of eleven glance words; numerals
are the largest type in the system. Do not invent a twelfth glance word — add it to the set first.

**NEVER** let AI write to the database without explicit human approval in the flow. AI suggests,
humans approve. This is a domain rule, not a UX preference.

Prefer running single tests over the full suite while iterating.

## Canonical vocabulary

Kafoo uses one name per concept. Wrong terminology in a table name or API route is a bug, not a
style nit — it propagates into schema, prompts, and UI. Full glossary: `docs/vision/glossary.md`.

| Use | Never |
|---|---|
| Customer | buyer, consumer, client, user |
| Cook | chef, vendor, seller, merchant, restaurant |
| Kitchen Profile | store, shop, business, restaurant |
| Meal | product, dish, listing, food item, recipe |
| Order | purchase, transaction, ticket |
| Review | feedback, rating (rating is the *score inside* a review) |
| Conversation | chat, session (session is runtime-only, never user-facing) |
| Message | chat, DM, thread |
| AI Assistant | bot, chatbot, LLM, robot |
| Publish / Archive | upload / delete |
| Accept Order / Reject Order | approve / decline |

Analytics events are PascalCase, past-tense, and never renamed. The core list is constitutional
(Principle VI); everything else — funnels, naming rules, attributes, statuses, measurement privacy
— lives in `docs/product/event-model.md`. Check that file before adding or emitting any event; do
not copy event lists into other documents.

## Repo map

Read the directory tree from the disk. What it will not tell you:

- **`packages/domain/` must not import `supabase_flutter`.** Entities and business logic only. If
  you need it there, the boundary is wrong.
- **There is no `apps/admin/`.** E0's T045 defers an administrative surface until one is needed — a
  decision, not a gap. Choosing a framework capable of carrying one was not approval to build it.
- **`apps/web/` is the Customer web surface** — Next.js and TypeScript on Cloudflare Workers
  (ADR-0008 Amendment 1). Three things bind it, none optional: Customer flows only, no Cook portal
  or administrative surface without a new decision; the database is the arbiter and both front-ends
  are presentation, so a rule restated in TypeScript with no RLS policy or constraint behind it is a
  regression, not a shortcut; and its strings live in `apps/web/messages/{ar,en}.json`, not the ARB
  files.
- **`apps/mobile/web/` is not that, and never will be.** It is the Flutter web build: 42 MB to a
  canvas with no link preview, no indexing and no text selection. Never point a Customer at it.
- **`prompts/` compiles into `supabase/functions/_shared/prompts.ts`.** Edit the source, never the
  generated file.
- **Read `decisions/` before proposing any architecture change.** `specs/` holds per-epic spec, plan
  and tasks; `coordination/` holds work packages, one JSON file each.
- **`docs/design/` is the design system, and `DESIGN.md` §10 is the voice specification.** The
  HTML files beside it are design references — never shipped, never ported.

## Building a feature

**Step 0 — check the stop-and-ask triggers first.** This sequence looks complete enough to follow to
the end without noticing that the feature needed approval three steps in.

**Do not reorder steps 5–7.** The constitution requires an authorization test to be written, and
seen to fail, before the policy it tests exists.

1. Understand the requirement. Ambiguity is a reason to ask one specific question, not to pick a
   reading.
2. Review the existing architecture against it — `decisions/`, `docs/product/domain-model.md`, and
   the code that already does something similar.
3. **Define the interfaces and data models first**, in `packages/domain/`. No Flutter imports, no
   `supabase_flutter`. Entities before behaviour.
4. **Isolate infrastructure behind a repository interface**, and inject a fake in tests. Follow the
   existing pattern — `features/identity/data/account_repository.dart` and the `Fake*Repository`
   classes in `apps/mobile/test/` — rather than inventing a second approach.
5. **Write the authorization tests, run them, and confirm they FAIL.** A negative test that passes on
   its first run is testing nothing and must be fixed before you continue.
6. Write the migration — table, `ENABLE ROW LEVEL SECURITY`, and every policy in the **same file**.
   Then re-run the tests from step 5 and watch them pass.
7. Implement the business logic.
8. Unit tests for the domain logic, widget tests for the screens — loading, data and error states.
   Integration tests when a feature spans several screens or services.
9. Strings into both locale files, Arabic written first. Analytics event if the change touches a
   tracked business action. Golden-case test if it adds AI behaviour.
10. Verify every `SC-###` acceptance criterion in the spec, by name. Then the checks below.

## Definition of done

1. `./scripts/verify.sh` passes — this is the gate. Not `flutter test`, which misses the pure-Dart
   packages; not `flutter analyze`, which misses RLS coverage, credentials, vocabulary, ARB parity
   and the Edge Function type-check.
2. New tables have RLS policies and a test proving a non-owner cannot read the row.
3. **A change that moves a person between screens has a journey test** in
   `apps/mobile/test/journey_test.dart` — one that boots the whole app and walks the path, asserting
   both the arrival and the departure. Five defects reached the founder's phone on 2026-08-10 with
   the gate fully green, and every one lived in the step *between* screens rather than inside one.
   Two passing widget tests either side of a broken transition is the exact shape to distrust.
   `.claude/rules/dart.md` has what a journey test must do.
4. New user-facing strings exist in both `ar` and `en`.
5. New AI behaviour has at least one golden-case test in `packages/ai/test/`.
6. Analytics event emitted if the change touches a tracked business action.
7. `docs/product/domain-model.md` updated in the same commit if the domain changed. Not optional — a
   feature without updated domain docs is half-shipped. Update whatever else the change made stale:
   `event-model.md`, an ADR, this file. Documentation drift is part of the change.
8. The feature's `quickstart.md` lets someone with none of your context verify it by hand.
9. `/ship-check` run.

**On gate failure:** diagnose, fix, re-run until green — **except** a failing RLS or
committed-credentials check, which is a stop-and-report, never something to iterate against. The
quickest way to turn a red authorization test green is to weaken the policy, which is the one
outcome the test exists to prevent.

## Git

Branch: `feat/short-description`, `fix/short-description`.
Commit message: imperative, one logical change per commit. Do not bundle unrelated files.
Never `git push --force` to `main`.

**Never `git add -A` while a review agent is running.** They run the code they review, writing probe
files into the same working tree you are about to stage. Stage named paths, or `git add -u` plus the
files you actually created. `zz_*` is git-ignored so the known case cannot recur silently, but a
blanket add in a shared tree is still a commit nobody reviewed.

## When to stop and ask

Stop and produce a short plan for approval instead of implementing when:

- The requirement is ambiguous and two reasonable implementations differ in user-visible behaviour
- A change would add a screen, a form field, or a settings toggle
- A change touches money, payouts, or pricing
- A change would collect a new category of personal data
- A change would let AI act without human approval
- A feature appears in the roadmap under Phase 2 or later and was not explicitly requested

Ambiguity is not a reason to invent behaviour. It is a reason to ask one specific question.

**Flag anything irreversible or externally visible before doing it**: what it changes, who can see
it, how hard it is to undo.

## Priority order when options conflict

1. User trust
2. Simplicity
3. AI assistance
4. Voice interaction
5. Performance
6. Long-term maintainability

Development speed is last. Do not trade trust or simplicity for it.

## Performance budgets

App launch <2s · voice response <2s · meal publish <3s · search <1.5s.
If a change pushes past a budget, say so in the PR rather than shipping it silently.

**Two more arrived with voice-first (ADR-0013), and they are tighter than anything above.** Input is
acknowledged — haptic and orb growth — within **150 ms**, and the thinking state visible before
**400 ms**. Half a second of silence reads as "the button didn't work", so the Cook taps again and
cuts off her own speech. They govern the gap before the 2 s round-trip, not instead of it. **Nothing
in a voice flow may be silent and still.**

**Neither is measured and the path behind them is unproven** — `docs/ops/spike-gemini-live.md`
records the ephemeral-token flow failing on 2026-08-06 and ADR-0009 is open. Targets a design
committed to, not budgets a build has met.

**Only the founder raises a budget.** Search was <1s until 2026-08-08, when he raised it having seen
the first end-to-end measurement — 1112 ms median, 1438 ms p95 over 1,013 Meals.
`docs/ops/measuring-discovery.md` has the numbers, what they exclude, and the 415 ms of avoidable
cost inside them. Raising a budget so a measurement passes is otherwise the move this repository
refuses.

`discover` must not cache on a Customer's phrase — a cache keyed on what somebody said is a
recording of what they said (FR-029, SC-011).

## Skills and hooks

Invoke `task-observer` at the start of any session where you will use tools and produce
deliverables. When loading any skill, check the observation log for OPEN observations tagged to it
and apply them, even if the skill file has not been updated yet.

**`task-observer`'s workspace is pinned to `.claude/skill-observations/` in this repository**, not
`~/.claude/projects/<id>/`. Containers are destroyed after each session, so the repository is the
only storage that outlives one — and only for work that is committed and pushed. Commit the log in
the session that writes it; an uncommitted observation is lost at teardown.

**Ponytail never outranks a non-negotiable.** It is set to `lite` and shapes generated code, which
agrees with Simplicity at position 2 above — but RLS in the same migration, a negative test seen to
fail, and both locale files are all work a "write less" prior will argue against. If it suggests
dropping one, ponytail is wrong. Caveman is `off` because it compresses prose to the reader, which
collides with the communication contract at the top of this file; do not switch it on without
saying so. Reasoning for both: `.claude/skills/_vendor-licenses/VENDORED.md`.

## Working alongside another session

Kafoo runs more than one session at a time. **Read `coordination/README.md` before picking up any
work** — roles, work-package fields, lifecycle and what the gate enforces are all there. What it
cannot enforce:

- **The coordinator pulls `main` before proposing anything.** A stale plan is indistinguishable from
  a correct one until the merge.
- **Never claim a task number from a local copy of `tasks.md`.** The coordinator allocates ids.
  Nothing can retroactively fix a task number two sessions have already used.
- **`./scripts/verify.sh` grades the working tree**, so a run started while an agent is mid-edit is
  grading a mixture. If the tree is not yours alone, say what you measured.
- **A worker still stops and asks.** Owning a package end to end is not authority to decide a new
  screen, money, a new category of personal data, or an AI write path. Those route to the founder.

## Delegating implementation work

**SUSPENDED 2026-08-06 — do not delegate until the founder lifts this.** The OpenCode weekly limit
is reached. Write the code directly; every other rule holds — the gate runs, RLS lands in the same
migration, a negative test is still seen to fail first. What is suspended is the dispatch, not the
discipline. **The founder lifts it, not the tooling:** the spend ledger printed `OK to dispatch`
while the account was already over its limit, so its verdict is not authority to resume.

Delegation exists because **the author of a change is the worst available reviewer of it.** With it
suspended you lose that separation, so replace it deliberately: the review agents in
`.claude/agents/` are not delegation and are not suspended. Use `rls-reviewer`,
`ai-boundary-reviewer` and `trust-reviewer` on anything touching authorization, money, personal
data, or an AI write path.

**When the suspension is lifted, delegating implementation becomes mandatory again** — writing
production code directly is the exception, not the default (founder's decision, 2026-08-02). Load
the `opencode-delegate` skill at that point: this account's model allowlist, billing caps and
spend-ledger workflow live in its `references/kafoo-account.md`, and nothing outside the
`opencode-go/` prefix may ever be dispatched.
