# Kafoo

AI-first marketplace connecting Egyptian home cooks with customers.
Voice-first, Egyptian Arabic default. Flutter (mobile) + Supabase (backend) + Cloudflare (deploy).

## Commands

```bash
melos bootstrap              # install deps across all packages
melos run analyze            # dart analyze, all packages
melos run test               # unit + widget tests
flutter test test/foo_test.dart   # single test — prefer this over full suite
supabase start               # local stack (Docker required)
supabase db reset            # rebuild local DB from migrations + seed
supabase migration new NAME  # NEVER hand-write migration filenames
supabase functions serve     # local Edge Functions
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

Analytics events are PascalCase and stable: `MealPublished`, `OrderPlaced`, `OrderAccepted`,
`ReviewSubmitted`, `SearchPerformed`, `SearchFailed`, `RecommendationAccepted`.

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

`opencode-delegate` and `claude-delegate` hand a bounded task to a separate CLI agent, which
edits the working tree but never commits. **You stay the reviewer**: re-run the gates yourself,
read the diff against the brief, then commit. Never accept a delegated agent's "gates passed"
on faith — re-run `./scripts/verify.sh`.

### Allowed OpenCode models — flat-rate only

The OpenCode subscription on this account is **OpenCode Go**. Only models on that flat-rate plan
are covered; everything else in the catalog is billed per token.

**MUST NOT** dispatch a model outside the flat-rate namespace. `opencode models` lists hundreds
of entries from metered providers (OpenRouter and similar); selecting one produces a real,
unbudgeted charge. If a task seems to need a model outside it, say so and let a human decide —
never guess from the catalog. This rule holds regardless of what the namespace is called.

> **⚠️ The prefix below is UNVERIFIED against this account. Confirm it before the first
> delegation.** The Go documentation gives model IDs as `opencode-go/<model-id>`, but the
> account's `auth.json` registers the provider as `opencode`, so the model strings may be
> `opencode/<model-id>` instead. These are different things — a provider ID and a model
> namespace — and only the CLI can settle which applies here:
>
> ```bash
> opencode models | grep -iE '^(opencode|zen)'
> ```
>
> Correct the prefix throughout this section, then delete this warning. Until that is done, do
> not run a fresh delegation unattended: an unrecognised model errors out harmlessly, but a
> near-miss that resolves to a metered provider does not.

| Task shape | Model (verify prefix first) |
|---|---|
| Mechanical — renames, migrations, removal sweeps, formatting | `deepseek-v4-flash` |
| Ordinary implementation | `qwen3.7-plus` |
| Subtle logic, tricky bugs, anything near money, auth, or RLS | `grok-4.5` |

Model *names* come from the published Go lineup; the *prefix* is what needs confirming. Go is in
beta and its lineup changes, so re-check with `/models` in the TUI or `opencode models` and adjust
this table rather than improvising per task.

### Delegated work is still Kafoo work

Everything in this file and in `.specify/memory/constitution.md` binds delegated code too. The
brief MUST carry the constraints the task touches — canonical vocabulary, RLS in the same
migration, `ar` ARB entries, no AI write path without human approval — because the implementer
has none of this conversation's context and does not auto-load this file.

Prefer `--read-only` (the `plan` agent) for diagnosis. Note the relay passes the parent
environment to the child process: do not delegate in a working tree holding a real `.env`.
