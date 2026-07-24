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
