# Kafoo

AI-first marketplace connecting Egyptian home cooks with customers.
Voice-first, Egyptian Arabic default. Flutter (mobile) + Supabase (backend) + Cloudflare (deploy).

## Commands

```bash
./scripts/install-toolchain.sh   # Flutter, melos, Deno, opencode (idempotent, ~3s warm)
melos bootstrap              # install deps across all packages
melos run analyze            # dart analyze, all packages
melos run test               # unit + widget tests
flutter test test/foo_test.dart   # single test — prefer this over full suite
supabase start               # local stack (Docker required)
supabase db reset            # rebuild local DB from migrations + seed
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
apps/mobile/         Flutter app (customer + cook, one binary)
apps/admin/          Web admin (Flutter web)
packages/ui/         Shared widgets, design system
packages/domain/     Entities + business logic. No Supabase imports here.
packages/ai/         Provider abstraction, prompts, conversation engine
supabase/migrations/ SQL. Generated names only.
supabase/functions/  Edge Functions
decisions/           ADRs. Read before proposing architecture changes.
```

`packages/domain/` must not import `supabase_flutter`. If you need it there, the boundary is wrong.

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

## Delegating implementation work

The opencode CLI is installed by `scripts/install-toolchain.sh`, so it is on `PATH` in every
session. **It is not signed in**: `auth.json` lives outside the repository, so a fresh container
has zero credentials and `opencode auth login` must be run once before delegating. An
unauthenticated `opencode models` lists only the anonymous free tier and shows none of the
allowlist below — that is a missing login, not a drifted plan.

`opencode-delegate` and `claude-delegate` hand a bounded task to a separate CLI agent, which
edits the working tree but never commits. **You stay the reviewer**: re-run the gates yourself,
read the diff against the brief, then commit. Never accept a delegated agent's "gates passed"
on faith — re-run `./scripts/verify.sh`.

### Allowed OpenCode models — flat-rate only

The OpenCode subscription on this account is **OpenCode Go**, a flat-rate plan covering a
specific set of models. The prefix is `opencode/` (verified against this account with
`opencode models`; the provider ID in `auth.json` is `opencode`).

**The `opencode/` prefix is NOT a billing boundary.** That namespace also serves frontier models
billed per token — `opencode/claude-opus-5`, `opencode/gpt-5.5-pro`, `opencode/gemini-3.1-pro`
and similar. They share the prefix with the flat-rate models and nothing in the model string
distinguishes them, so "starts with `opencode/`" is not a safety check.

**MUST NOT** dispatch a model outside the allowlist below. Selecting a frontier model produces a
real, unbudgeted charge. If a task seems to need one, say so and let a human decide — never pick
from `opencode models` output on the assumption that the prefix makes it safe.

### Allowlist — verified present on this account

`deepseek-v4-flash` · `deepseek-v4-pro` · `glm-5.1` · `glm-5.2` · `grok-4.5` · `kimi-k2.6` ·
`kimi-k2.7-code` · `minimax-m2.7` · `minimax-m3` · `qwen3.6-plus`

Each is on the published Go lineup *and* present in this account's catalog. Models with a
`-free` suffix are outside the plan's paid tier and fine to use.

| Task shape | Model |
|---|---|
| Mechanical — renames, migrations, removal sweeps, formatting | `opencode/deepseek-v4-flash` |
| Ordinary implementation | `opencode/qwen3.6-plus` |
| Subtle logic, tricky bugs, anything near money, auth, or RLS | `opencode/grok-4.5` |

Go is in beta and its lineup drifts — the published docs already list models this account does
not have (`kimi-k3`, `qwen3.7-plus`, `qwen3.7-max`, `mimo-v2.5`, `mimo-v2.5-pro`, `hy3`). Re-run
`opencode models --refresh` and update this allowlist rather than improvising per task. A model
that no longer exists fails loudly, which is safe; a metered one does not.

**Do not substitute a same-named model from another provider.** Checked on 2026-07-26 after a
cache refresh: `kimi-k3` is absent from `opencode/` but present as
`cloudflare-ai-gateway/moonshotai/kimi-k3`. That is a different provider — billed per token,
requiring separate credentials, and not covered by this subscription. The same applies to any
`openrouter/`, `cloudflare-ai-gateway/`, or similar path that happens to carry a model name from
the Go lineup. If a wanted model is missing from `opencode/`, the subscription cannot reach it
and no configuration changes that; use the nearest allowlisted model or ask.

### Delegated work is still Kafoo work

Everything in this file and in `.specify/memory/constitution.md` binds delegated code too. The
brief MUST carry the constraints the task touches — canonical vocabulary, RLS in the same
migration, `ar` ARB entries, no AI write path without human approval — because the implementer
has none of this conversation's context and does not auto-load this file.

Prefer `--read-only` (the `plan` agent) for diagnosis. Note the relay passes the parent
environment to the child process: do not delegate in a working tree holding a real `.env`.
