# Kafoo

AI-first marketplace connecting Egyptian home cooks with customers.
Voice-first, Egyptian Arabic default. Flutter (mobile) + Supabase (backend) + Cloudflare (deploy).

## MVP mode — active, and a trial

**The founder cut this file from 328 lines to this on 2026-08-13.** The reason is not that the
removed rules were wrong. It is that Kafoo has 462 merged pull requests and no record of a
conversation with a real Cook, so the standards of a launched product were being applied to an
unvalidated one. What is suspended is ceremony. What is kept is the work whose failure cannot be
undone later.

**Everything removed is recoverable.** Commit `fab86d8` is the state before the cut — the tip of
`main` on 2026-08-13, and permanently in its history. **To restore the old rulebook whole, at any
time, including after this branch merges:**

```bash
git checkout fab86d8 -- CLAUDE.md .claude/
```

Nothing else is needed and nothing expires. (A local tag `pre-mvp-mode` points at the same commit;
it could not be pushed — this repository's token declines tag writes — so quote the commit, not the
tag, in anything another session has to read.)

**The trial ends at a checkpoint, not at a feeling:** one voice journey built, five real Cooks
tried it. Then the founder calls keep / extend / abandon.

**Every shortcut taken in MVP mode goes in `docs/mvp-deferred.md`, in the same commit that takes
it.** A shortcut that is not written down is not a shortcut, it is a defect nobody has met yet.

## Who you are talking to

**The founder is a company director, not a developer.** He runs a software company and has never
written code professionally. He reads architecture, weighs trade-offs and makes the calls on cost,
scope and risk — but he does not read Dart, SQL or shell, and should never have to in order to
follow you. **Your job is to be the translator. If he has to translate you, you did the job wrong.**

**The answer shape is enforced by hooks, not by this file.**
`.claude/hooks/communication-contract.sh` re-states it before every reply and
`check-reply-shape.py` refuses one that ignores it. Do not restate those rules here — a rule kept in
two places drifts in one of them, and the hook is the copy that runs.

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
./scripts/install-toolchain.sh   # Flutter, melos, Deno, Supabase CLI, opencode (idempotent)
melos run test               # unit + widget tests
flutter test test/foo_test.dart   # single test — prefer this while iterating
./scripts/local-db.sh test   # RLS suites against a real Postgres — no Docker
supabase migration new NAME  # NEVER hand-write migration filenames
deno run -A scripts/generate-voice-clips.ts  # SPENDS MONEY — buys any fixed sentence not owned yet
./scripts/verify.sh          # the gate, 49 checks, 3m12s measured — run it before declaring done
./scripts/build-apk.sh       # release APKs — refuses to run without the two --dart-define values
```

**Demo is the default target. Production is asked for, never assumed (founder, 2026-08-13).**
Anything that reaches a live project — an Edge Function deploy, a secret, a seeded row, an APK built
to point somewhere — goes to the **demo** branch (`pzyngffppwfsvdsnslkb`) unless the founder names
production in that request. `docs/ops/demo-environment.md` holds its URL and key.

An APK is the easy one to get wrong: it carries whichever `SUPABASE_URL` it was built with, so a
build made "just to test" against production is a test against real Cooks' rows. Build with
`DEMO_SUPABASE_URL` and `DEMO_SUPABASE_PUBLISHABLE_KEY` and say which one it points at when handing
it over.

**There is no fast gate and MVP mode did not create one.** It was tried on 2026-08-13 and measured:
cutting to the eight checks behind the non-negotiables saved 29 seconds of 3m12s, because codegen,
analyze, tests and the authorization suites are nearly all of the time and all of them are keepers.
A second definition of "passing" for 29 seconds is the trade this repository has already lost once —
three Deno checks reported ok for months without running. One gate.

`.env` is git-ignored. Copy `.env.example` and fill it. Never read, print, or commit `.env`.

## Non-negotiables

Four. They survived the cut because each one fails in a way no later sprint can repair.

**YOU MUST** enable RLS in the same migration that creates a table, with a test proving a non-owner
cannot read the row. A table without RLS is a data breach, not a TODO — and Kafoo's rows carry the
home addresses of women cooking alone.

**NEVER** commit credentials, and never read or print `.env`. A key in git history is public
forever.

**NEVER** hardcode user-facing strings. Every string goes through the ARB files with an Egyptian
Arabic entry, `ar` written first. `apps/web/` uses `messages/{ar,en}.json` instead. Free now, a
rewrite of every screen later.

**NEVER** let AI write to the database without explicit human approval in the flow. AI suggests,
humans approve. A domain rule, not a UX preference.

**The one platform exception:** `apps/mobile/ios/Runner/Info.plist` carries the `NS*UsageDescription`
strings in Egyptian Arabic. iOS reads them before Flutter starts, so ARB cannot reach them. Do not
"fix" them into ARB — the app crashes without them, silently to every check the gate runs.

**On gate failure:** diagnose, fix, re-run. **Except** a failing RLS or credentials check, which is
stop-and-report. The quickest way to turn a red authorization test green is to weaken the policy,
which is the one outcome the test exists to prevent.

## One conversation, not a questionnaire

Kafoo is voice-first (ADR-0013): the assistant speaks, the user speaks back, the screen is the
receipt. The assumption underneath is that a Cook may not read comfortably.

**And it is one open conversation, not a form read aloud (ADR-0015, 2026-08-13).** A journey is a
single screen holding a single exchange. The Cook or Customer can ask questions, ask for advice and
change the subject; the assistant answers, and collects what it needs inside that. **Kafoo owns the
list of facts still missing. The model owns what to say next.** It never decides what a Meal
requires, and Kafoo never dictates the order of the asking.

What this deletes: the four-question Meal wizard and the five-question onboarding wizard, and every
screen that existed because a step ended.

**In MVP mode this binds one journey, not every screen:** a Cook talks a Meal into being in one
conversation, hears it read back, says «أيوة», and it is published. Build that to full fidelity.
Other screens may ship tap-only and say so in `docs/mvp-deferred.md`.

Four rules hold inside that journey and anywhere voice appears:

- **Irreversible actions are read back aloud and wait for «أيوة». Silence never confirms**, and no
  timeout resolves a gate. Reversible ones execute and are announced.
- **Tap is a complete alternative, never a degraded one.** Typing is never a consequence of the
  assistant failing to understand.
- **The assistant paraphrases; it never shows a transcript** — except a message to another human,
  read back verbatim, because those exact words are what the other person receives.
- **Advice never becomes a stored fact.** The assistant may suggest a Meal; only the Cook's own
  words put one in the database.

Full specification: `docs/design/DESIGN.md` §10 (voice) and §11 (the conversation screen). Do not
invent a twelfth glance word.

**Two things this direction needs are decided separately and neither is built.** Memory between
conversations is ADR-0016 — **accepted, and its conditions are the grant**: hearable on demand,
deletable in one sentence, consent before a health-adjacent fact, expiring with ADR-0007's dormancy
window. How the live conversation reaches a model is ADR-0017 — accepted in direction, **blocked on
one spike**, whose first question is whether the app can connect without a permanent key on the
handset.

## Canonical vocabulary

One name per concept. Wrong terminology in a table name or route is a bug, not a style nit — it
propagates into schema, prompts and UI. Glossary: `docs/vision/glossary.md`.

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

Analytics events are PascalCase, past-tense, never renamed. List and rules:
`docs/product/event-model.md`.

## Repo map

Read the tree from disk. What it will not tell you:

- **`packages/domain/` must not import `supabase_flutter`.** Entities and business logic only.
- **`apps/web/` is the Customer web surface** (Next.js on Cloudflare). **Paused in MVP mode** — no
  new work without the founder. Its strings live in `apps/web/messages/`, not ARB.
- **`apps/mobile/web/` is the Flutter web build, not a Customer surface.** 42 MB to a canvas.
- **`prompts/` compiles into `supabase/functions/_shared/prompts.ts`.** Edit the source.
- **There is no `apps/admin/`**, by decision.
- `decisions/` holds ADRs, `specs/` per-epic specs, `coordination/` work packages,
  `docs/design/DESIGN.md` the design system.

## Definition of done

1. `./scripts/verify.sh` passes. Run it — not "it should pass". It takes about three minutes.
2. New tables have RLS policies and a test proving a non-owner cannot read the row.
3. New user-facing strings exist in both `ar` and `en`.
4. **Docs updated in the same commit** if the change made them stale — `domain-model.md`,
   `event-model.md`, an ADR, this file. Documentation drift is part of the change.
5. Any shortcut taken is written into `docs/mvp-deferred.md` in the same commit.

Tests are required for money, authorization and domain rules. Elsewhere in MVP mode they are a
judgement call — write the one check that would catch the thing breaking, and skip the rest.

**Journey tests are not required per screen in MVP mode, but the voice journey has one.** Five
defects reached the founder's phone on 2026-08-10 with the gate fully green, and every one lived in
the step *between* screens. Two passing widget tests either side of a broken transition is the exact
shape to distrust.

## Git

Branch: `feat/short-description`, `fix/short-description`. Commit message: imperative, one logical
change per commit. Never `git push --force` to `main`.

**Never `git add -A` while a review agent is running.** They write probe files into the same working
tree you are about to stage. Stage named paths, or `git add -u` plus what you created.

## When to stop and ask

Three triggers. Adding a screen is no longer one of them — an MVP is made of new screens.

- A change touches money, payouts, or pricing
- A change would collect a new category of personal data
- A change would let AI act without human approval

Ambiguity is not a reason to invent behaviour. It is a reason to ask one specific question.
**Flag anything irreversible or externally visible before doing it.**

## Priority order when options conflict

User trust → evidence from real Cooks → simplicity → voice → performance → maintainability.

Development speed sits above maintainability in MVP mode and nowhere else. It never outranks trust.

## Skills, modes and review

**Ponytail is `full` and caveman is `full`** (founder's decision, 2026-08-13). Ponytail shapes
generated code toward the shortest thing that works. Caveman compresses prose — including replies to
the founder, which is the one place it fights the communication contract above; when the two
disagree, **the contract wins and caveman yields.** Revert either with `/ponytail off`,
`/caveman off`, or by editing `.claude/settings.json`.

**Ponytail never outranks a non-negotiable.** RLS in the same migration, credentials, both locale
files and the AI write boundary are all work a "write less" prior will argue against. If it suggests
dropping one, ponytail is wrong.

**Review agents are advisory in MVP mode, except one.** `rls-reviewer` stays mandatory on any
migration or policy change. `ai-boundary-reviewer` and `trust-reviewer` run on money, personal data
and AI write paths. The rest — accessibility, localization, conversation-design, release — run when
asked, and their findings are input, not blockers. One round, then decide.

Invoke `task-observer` at the start of any session producing deliverables. Its workspace is
`.claude/skill-observations/` **in this repository** — containers are destroyed after each session,
so commit the log in the session that writes it.

## Delegating implementation work

**ACTIVE as of 2026-08-13 — the founder lifted the suspension.** OpenCode is back and installed
(`opencode 1.18.16`).

Delegation exists because **the author of a change is the worst available reviewer of it.**
Delegating implementation is the default; writing production code directly is the exception.

Load the `opencode-delegate` skill before dispatching: this account's model allowlist, billing caps
and spend-ledger workflow live in its `references/kafoo-account.md`. **Nothing outside the
`opencode-go/` prefix may ever be dispatched.**

**The spend ledger's verdict is not authority.** It printed `OK to dispatch` on 2026-08-06 while the
account was already over its weekly limit. Check the real account state before a large dispatch, and
tell the founder when a limit is close.

## Working alongside another session

Kafoo runs more than one session at a time. **Read `coordination/README.md` before picking up any
work.** What it cannot enforce:

- **The coordinator pulls `main` before proposing anything.** A stale plan is indistinguishable from
  a correct one until the merge.
- **Never claim a task number from a local copy of `tasks.md`.** The coordinator allocates ids.
  Nothing can retroactively fix a number two sessions have already used.
- **`./scripts/verify.sh` grades the working tree**, so a run started while another agent is
  mid-edit is grading a mixture. If the tree is not yours alone, say what you measured.
- **A worker still stops and asks** on money, new personal data and AI write paths. Those route to
  the founder.
