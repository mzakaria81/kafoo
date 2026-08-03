# Kafoo

AI-first marketplace connecting Egyptian home cooks with customers.
Voice-first, Egyptian Arabic default. Flutter (mobile) + Supabase (backend) + Cloudflare (deploy).

## Who you are talking to

**The user is the founder and a company director, not a developer.** He runs a software development
company and has never written code professionally. He is technically literate — he reads
architecture, weighs trade-offs, and makes the calls on cost, scope and risk — but he does not read
Dart, SQL or shell, and should never have to in order to follow you.

This changes how you write, not what you do. Engineering rigour is unchanged: the gate still runs,
RLS still lands in the same migration, tests still come first.

- **Lead with the decision or the outcome**, then the reasoning. Not a narration of what you did in
  the order you did it.
- **Explain in terms of consequence**, not mechanism. "This step would have failed the first time
  we deployed a database change" beats "the pinned npm version does not resolve."
- **Name the trade-off and give a recommendation.** He is deciding, so he needs the options and
  your expert opinion on which to take — not a neutral survey. Say which one you would pick and
  why.
- **Say what something costs**, in money and in ongoing commitment, whenever that is part of the
  choice.
- **Spell out jargon on first use**, briefly, in the same sentence. Not a glossary — a clause.
- **Show code only when it is the thing being discussed.** A file path and a plain-English summary
  of what changed is usually enough. Do not paste diffs to prove work happened.
- **Flag anything irreversible or externally visible before doing it**, in plain terms: what it
  changes, who can see it, and how hard it is to undo.

Do not perform simplicity by hiding bad news. If something is broken, half-finished, or riskier
than it looks, say so plainly and early — that is the judgement he is relying on you for.

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
entry. `ar` is the default locale, not the fallback.

**NEVER** build a form where a conversation would work. If you find yourself adding a fourth input
field, stop and propose a conversational flow instead.

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
| AI Assistant | bot, chatbot, LLM, robot |
| Publish / Archive | upload / delete |
| Accept Order / Reject Order | approve / decline |

Analytics events are PascalCase, past-tense, and never renamed. The core list is constitutional
(Principle VI); everything else — funnels, naming rules, attributes, statuses, measurement privacy
— lives in `docs/product/event-model.md`. Check that file before adding or emitting any event; do
not copy event lists into other documents.

## Repo map

```
apps/mobile/         Flutter app (Customer + Cook, one binary). The only app that exists.
packages/ui/         Shared widgets, design system
packages/domain/     Entities + business logic. No Supabase imports here.
packages/ai/         Provider abstraction, prompts, conversation engine
prompts/             Prompt files. Compiled into supabase/functions/_shared/prompts.ts.
scripts/             verify.sh (the gate), the toolchain installer, code generators
supabase/migrations/ SQL. Generated names only.
supabase/functions/  Edge Functions
specs/               Per-epic spec, plan and tasks
decisions/           ADRs. Read before proposing architecture changes.
```

`packages/domain/` must not import `supabase_flutter`. If you need it there, the boundary is wrong.

**There is no `apps/admin/`, and its absence is a decision rather than a gap.** E0's T045 defers an
administrative surface until one is needed. This map listed it as though it existed until
2026-08-03, which is worse than omitting it: a map is read as a description of what is there, and a
deferred decision written in the present tense reads as a directory somebody forgot to commit.

**There is no Customer web surface yet either.** ADR-0008 commits to one and deliberately leaves the
rendering technology open until E2 lands and there is a Meal to show. `apps/mobile/web/` is a
development and demonstration target, measured at 42 MB on a canvas that cannot produce a
previewable link — read ADR-0008 before treating it as the Customer surface, because it says in
terms not to.

## Building a feature

The order below is the path; "Definition of done" is the check at the end of it. Do not reorder
steps 5–7 — the constitution requires an authorization test to be written, and seen to fail, before
the policy it tests exists.

**Step 0 — check the stop-and-ask triggers before starting.** This sequence looks complete enough
to follow to the end without noticing that the feature needed approval three steps in. See "When to
stop and ask".

**Steps 3–9 are delegated work.** Understanding the requirement, reviewing the architecture, and
the whole of step 10 onward are yours. See "Delegating implementation work" — the brief must carry
every constraint the task touches, because the implementer has none of this file's context.

1. Understand the requirement. Ambiguity is a reason to ask one specific question, not to pick a
   reading.
2. Review the existing architecture against it — `decisions/`, `docs/product/domain-model.md`, and
   the code that already does something similar.
3. **Define the interfaces and data models first**, in `packages/domain/`. No Flutter imports, no
   `supabase_flutter`. Entities before behaviour.
4. **Isolate infrastructure behind a repository interface**, and inject a fake in tests. Business
   logic never depends on Supabase directly. This is already the pattern — see
   `features/identity/data/account_repository.dart` and the `Fake*Repository` classes in
   `apps/mobile/test/`. Follow it rather than inventing a second approach.
5. **Write the authorization tests, run them, and confirm they FAIL.** A negative test that passes
   on its first run is testing nothing and must be fixed before you continue.
6. Write the migration — table, `ENABLE ROW LEVEL SECURITY`, and every policy in the **same file**.
   Then re-run the tests from step 5 and watch them pass.
7. Implement the business logic.
8. Unit tests for the domain logic, widget tests for the screens — loading, data, and error states.
   Add integration tests when a feature spans several screens or services.
9. Strings into both ARB files, Arabic written first. Analytics event if the change touches a
   tracked business action. Golden-case test if it adds AI behaviour.
10. Run `./scripts/verify.sh`. This is the gate — not `flutter test`, which misses the pure-Dart
    packages, and not `flutter analyze`, which misses RLS coverage, credentials, vocabulary, ARB
    parity and the Edge Function type-check.
11. On failure: diagnose, fix, re-run, repeat until green — **except** a failing RLS or
    committed-credentials check, which is a stop-and-report, never something to iterate against.
    The quickest way to turn a red authorization test green is to weaken the policy, which is the
    one outcome the test exists to prevent.
12. Verify every `SC-###` acceptance criterion in the spec, by name.
13. Update whatever the change made stale — `domain-model.md`, `event-model.md`, an ADR, this file.
    Documentation drift is part of the change, not follow-up work.
14. Extend the feature's `quickstart.md` so someone with none of your context can verify it by hand.
15. Run `/ship-check`, then it is done.

## Definition of done

A change is done when all of these are true:

1. `./scripts/verify.sh` passes
2. New tables have RLS policies and a test proving a non-owner cannot read the row
3. New user-facing strings exist in both `ar` and `en` ARB files
4. New AI behaviour has at least one golden-case test in `packages/ai/test/`
5. Analytics event emitted if the change touches a tracked business action
6. If the domain changed, `docs/product/domain-model.md` updated in the same commit

Item 6 is not optional. A feature without updated domain docs is half-shipped.

## Git

Branch: `feat/short-description`, `fix/short-description`.
Commit message: imperative, one logical change per commit. Do not bundle unrelated files.
Never `git push --force` to `main`.

## When to stop and ask

Stop and produce a short plan for approval instead of implementing when:

- The requirement is ambiguous and two reasonable implementations differ in user-visible behaviour
- A change would add a screen, a form field, or a settings toggle
- A change touches money, payouts, or pricing
- A change would collect a new category of personal data
- A change would let AI act without human approval
- A feature appears in the roadmap under Phase 2 or later and was not explicitly requested

Ambiguity is not a reason to invent behaviour. It is a reason to ask one specific question.

## Priority order when options conflict

1. User trust
2. Simplicity
3. AI assistance
4. Voice interaction
5. Performance
6. Long-term maintainability

Development speed is last. Do not trade trust or simplicity for it.

## Performance budgets

App launch <2s · voice response <2s · meal publish <3s · cached search <1s.
If a change pushes past a budget, say so in the PR rather than shipping it silently.

## Skill activation

At the start of any task-oriented session — any interaction where you will use tools and
produce deliverables — invoke the `task-observer` skill before beginning work. This ensures
skill improvement opportunities are captured throughout the session.

When loading any skill, check the observation log for OPEN observations tagged to that skill.
Apply their insights to the current work, even if the skill file hasn't been updated yet. This
enables immediate application of observations before they're permanently integrated during the
weekly review.

**Workspace folder for `task-observer` is pinned to `.claude/skill-observations/` in this
repository.** Do not use `~/.claude/projects/<id>/`. Kafoo development runs in ephemeral
containers that are destroyed after each session, so the repository is the only storage that
outlives a session — and only for work that is committed and pushed. An observation log that
is written but never committed is lost at teardown. Say so rather than silently losing it.

`using-superpowers` is injected automatically at session start by
`.claude/hooks/superpowers-session-start.sh`; it does not need an instruction here.

**caveman and ponytail are wired but set to different intensities, on purpose.** Both are
hook-driven output-compression tools vendored into `.claude/`; the full reasoning is in
`.claude/skills/_vendor-licenses/VENDORED.md`, and the short version is:

- **caveman is `off`.** It compresses *prose to the reader*, and its `full` default contradicts the
  communication contract at the top of this file. Every command still works on demand —
  `/caveman lite`, `/caveman-stats`, `/caveman-commit`, `/caveman-review`. Do not switch the default
  on without saying so; the founder reads these answers to make decisions.
- **ponytail is `lite`.** It shapes generated *code*, so it does not collide with that contract, and
  it agrees with Simplicity at position 2 in the priority order. It is deliberately not `full`:
  RLS in the same migration, a negative test seen to fail, and both ARB locales are all work a
  strong "write less" prior will argue against. **Ponytail never outranks a non-negotiable.** If it
  suggests dropping one, ponytail is wrong.

Its subagent injection is scoped by `PONYTAIL_SUBAGENT_MATCHER` to implementation agents only.
The review agents in `.claude/agents/` exist to object, and telling them to do less defeats them.

## Delegating implementation work

**YOU MUST delegate implementation.** Writing production code directly is the exception, not the
default. Use `opencode-delegate` (or `claude-delegate`) to hand a bounded task to a separate agent,
then review its diff, re-run the gates yourself, and commit. Founder's decision, 2026-08-02.

The reason is not cost. It is that **the author of a change is the worst available reviewer of it**,
and this repository's whole safety model — RLS negative tests seen to fail, mutation checks, a gate
that must go red before it goes green — depends on somebody actually reading the code with fresh
eyes. Delegating creates that separation structurally instead of asking one agent to pretend.

**Delegate, always:** feature code, migrations, Edge Functions, tests, refactors, renames, sweeps.

**Do it yourself, and say why:**

- **Architecture and decisions.** ADRs, spec and plan documents, choosing between approaches, and
  anything in `decisions/` or `.claude/`. A brief cannot carry the conversation that produced the
  judgement.
- **Diagnosis.** Use `--read-only` (the `plan` agent) to investigate; do not delegate a fix for a
  bug nobody has understood yet.
- **A change smaller than its brief.** A one-line fix costs more to describe than to make.
- **Anything the founder asked you specifically to do.** He asked you, not a subagent.

**Reviewing is not optional and not a formality.** Never accept "gates passed" on faith — run
`./scripts/verify.sh` yourself, read the diff against the brief, and check the things a delegated
agent has no way to know: canonical vocabulary, Egyptian Arabic register, whether a negative test
was actually seen to fail, whether an RLS policy is as narrow as it looks. **You are accountable for
what you commit, whoever typed it.**

Model choice comes from the table below. **Read the prefix carefully** — `opencode-go/` is the
flat-rate subscription and `opencode/` is a metered product sharing the same credential. Re-verify
rather than trusting this sentence; both the lineup and the prefix have been wrong here before.

The opencode CLI is installed by `scripts/install-toolchain.sh`, so it is on `PATH` in every
session.

**Signing in: set `OPENCODE_API_KEY` as a cloud-environment variable.** opencode reads it directly
for the OpenCode Go and Zen providers, so a session starts already signed in. `opencode auth login`
also works but writes `~/.local/share/opencode/auth.json`, which is destroyed with the container —
it signs in this session only. Set the variable at claude.ai/code → the cloud icon above the
message box → the gear on your environment → **Environment variables**, one `KEY=value` per line.
**Never put the key in this repository**; `./scripts/verify.sh` fails if a real-looking one is
tracked by git.

Two things to know about that variable. Cloud environments have **no secrets store**: anyone who
can use the environment can read the value, so keep the key in a personal environment rather than
an organization-shared one, and treat it as rotatable. And the API host `opencode.ai` is **not** on
the default **Trusted** network allowlist — it is reachable from the environment this was set up in,
but an environment restricted to Trusted may need `opencode.ai` added under **Custom**.

Without a credential, `opencode models` lists only the anonymous free tier and shows none of the
allowlist below. That is a missing key, not a drifted plan — every model below was confirmed
present once a key was supplied.

`opencode-delegate` and `claude-delegate` hand a bounded task to a separate CLI agent, which
edits the working tree but never commits. **You stay the reviewer**: re-run the gates yourself,
read the diff against the brief, then commit. Never accept a delegated agent's "gates passed"
on faith — re-run `./scripts/verify.sh`.

### Allowed OpenCode models — the prefix IS the billing boundary, and it is `opencode-go/`

The OpenCode subscription on this account is **OpenCode Go**. Its namespace is **`opencode-go/`**.
Everything dispatched for Kafoo uses that prefix.

**It is not flat-rate, and this file said it was until 2026-08-03.** Go is $5 for the first month
then $10/month, and it meters usage against three dollar-denominated caps
(https://opencode.ai/docs/go/):

| Window | Cap |
|---|---|
| rolling 5 hours | $12 of usage |
| week | $30 of usage |
| month | $60 of usage |

So the `cost` field in a relay's `result.json` is not notional — **it is what counts against those
caps.** Three `grok-4.5` dispatches on 2026-08-03 cost $0.44, $0.71 and $0.76: $1.91 for one
session's work, about a sixth of a five-hour window. A delegation-heavy day can exhaust a window,
and the failure mode is work stopping mid-task rather than a surprise bill.

Model choice moves this by orders of magnitude, not percentages — the docs put MiMo-V2.5 at roughly
150,400 requests a month against Kimi K3's 490. **Send mechanical work to a cheap model because it
is cheap, not merely because it is sufficient.**

**YOU MUST run the spend ledger around every dispatch.** Two commands, and neither is optional:

```bash
python3 scripts/opencode-spend.py report          # BEFORE dispatching. Obey the verdict.
python3 scripts/opencode-spend.py record <relay-result-dir>   # AFTER every relay, pass or fail
```

Then **commit `.claude/opencode-spend.jsonl`**. It is append-only, one row per dispatch, and it
lives in the repository for the same reason the observation log does: cloud containers are
destroyed after each session, so an uncommitted ledger is a ledger that resets to zero against a
cap that does not. `opencode stats` cannot do this job — it reads the container's local database
and starts empty every time.

The report prints `OK`, `WARN` at 70% of any window, or `STOP` at 90%. `WARN` means send the next
task down the model table. `STOP` means finish what is in flight and start nothing new: the failure
being avoided is a long task dying halfway, not a bill.

**It is an approximation and it is honest about being one.** It records what Kafoo spent, which
tracks the account only while delegated coding is the sole consumer of the subscription — true as
of 2026-08-03. It cannot see spend from a laptop or another machine. The authoritative number is
the OpenCode workspace console, which needs a browser credential that must not be put in a cloud
environment: there is no secrets store, so anyone with access to the environment could read it, and
a console session reaches billing rather than just model calls.

**`opencode/` is a different product and it bills per token.** One `OPENCODE_API_KEY` authenticates
two separate providers, which is why this file spent from 2026-07-26 to 2026-08-02 telling every
agent to use the metered one:

| Prefix | Provider | Billing | Models |
|---|---|---|---|
| `opencode-go/` | OpenCode Go | flat-rate subscription | 17 — the published Go lineup |
| `opencode/` | OpenCode Zen | **metered, per token** | 60 — includes frontier models |

Corrected on 2026-08-02, and not by reading anything. A dispatch to `opencode/grok-4.5` failed with
HTTP 401 `CreditsError: Insufficient balance`, against `https://opencode.ai/zen/v1/responses` — the
model string named a Go-lineup model and the request still went to Zen. `opencode auth list` then
showed `OPENCODE_API_KEY` listed twice, once under "OpenCode Go" and once under "OpenCode Zen".

The earlier text said the provider id was `opencode` "verified with `opencode models`". Both
providers appear in that output, both carry Go-lineup model names, and the flat-rate one sorts
lower. Verifying that a model *exists* is not verifying which account pays for it.

**MUST NOT** dispatch anything outside `opencode-go/`. A metered model produces a real, unbudgeted
charge. If a task seems to need one, say so and let a human decide.

The zero balance that produced the error above is not a safety net to rely on. It made this
particular mistake free; a topped-up balance would have made the same mistake silent.

### Allowlist — verified present on this account, 2026-08-03

The full published Go lineup is available. Listing `opencode-go/` returns all eighteen:

`deepseek-v4-flash` · `deepseek-v4-pro` · `glm-5.1` · `glm-5.2` · `gpt-5.6-luna` · `grok-4.5` ·
`hy3` · `kimi-k2.6` · `kimi-k2.7-code` · `kimi-k3` · `mimo-v2.5` · `mimo-v2.5-pro` ·
`minimax-m2.7` · `minimax-m3` · `qwen3.6-plus` · `qwen3.7-max` · `qwen3.7-plus` · `qwen3.8-max`

Six of these — `kimi-k3`, `qwen3.7-plus`, `qwen3.7-max`, `mimo-v2.5`, `mimo-v2.5-pro`, `hy3` — were
once recorded here as "on the published docs but not on this account", and a note warned that Go's
lineup drifts. They were never missing. They were under the prefix nobody had looked at.

**`qwen3.8-max` is the case that note was reaching for, and it is a cache, not drift.** A plain
`opencode models` returned seventeen; `opencode models --refresh` returned eighteen. So the local
catalog does go stale, and the symptom is indistinguishable from a model being unavailable —
**always `--refresh` before concluding a model is missing.**

| Task shape | Model |
|---|---|
| Mechanical — renames, migrations, removal sweeps, formatting | `opencode-go/deepseek-v4-flash` |
| Ordinary implementation | `opencode-go/qwen3.6-plus` |
| Subtle logic, tricky bugs, anything near money, auth, or RLS | `opencode-go/grok-4.5` |

Pick down this table, not up. `grok-4.5` is the expensive row and every dispatch on 2026-08-03 used
it, including one that generated JSON fixtures — work the mechanical row would have done for a
fraction of the cap. Reserve it for what the row actually says: subtle logic, auth, RLS, money.

Re-run `opencode models --refresh` and update this allowlist rather than improvising per task. A
model that no longer exists fails loudly, which is safe; a metered one does not.

**Do not substitute a same-named model from another provider.** `cloudflare-ai-gateway/`,
`amazon-bedrock/`, `github-models/` and `openrouter/` all carry names from the Go lineup and none
of them are covered by this subscription — they bill separately and need their own credentials.
This is the same trap as `opencode/` versus `opencode-go/`, one level out: a familiar model name is
not evidence of who pays for the call. If a wanted model is missing from `opencode-go/`, the
subscription cannot reach it and no configuration changes that; use the nearest allowlisted model
or ask.

### Delegated work is still Kafoo work

Everything in this file and in `.specify/memory/constitution.md` binds delegated code too. The
brief MUST carry the constraints the task touches — canonical vocabulary, RLS in the same
migration, `ar` ARB entries, no AI write path without human approval — because the implementer
has none of this conversation's context and does not auto-load this file.

Prefer `--read-only` (the `plan` agent) for diagnosis. Note the relay passes the parent
environment to the child process: do not delegate in a working tree holding a real `.env`.
