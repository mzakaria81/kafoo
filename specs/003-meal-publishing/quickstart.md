# Quickstart — proving this feature works

How to convince yourself E2 does what it claims. Written for someone picking this up cold, with
none of the conversation that produced it.

Implementation detail lives in `tasks.md`. This is the run-and-check guide.

## Prerequisites

```bash
bash .devcontainer/post-create.sh   # only outside Codespaces / Claude Code on the web
supabase start                       # Docker required — for Auth, PostgREST, Storage, Edge Functions
supabase db reset                    # rebuild from migrations + seed (Docker)
melos bootstrap
dart run build_runner build          # new in E2 — Riverpod codegen
```

`supabase db reset` is safe locally and **forbidden** against staging or production.

The authorization suites **do not need Docker**. `./scripts/local-db.sh test` starts a real Postgres
of the major version pinned in `supabase/config.toml`, applies migrations and seed, and runs every
suite. Documented in `docs/ops/local-database.md`. Docker is only needed for the *app's* local stack
and for serving Edge Functions locally — not for proving the policies. This matters because the
constitution requires a negative test to be *seen to fail*, and until `local-db.sh` existed that
meant pushing a commit and reading CI.

A model provider credential is needed for anything involving the AI Assistant. The default is
**Gemini** (`gemini-3.1-flash-lite`, key `GEMINI_API_KEY`); `AI_PROVIDER=anthropic` switches to
Claude Haiku 4.5 and nothing else changes — a *wrong* value throws rather than falling back. The
models were measured, not chosen from a pricing page: `gemini-3.1-flash-lite` answers in 645–1273 ms;
`gemini-3.6-flash` burns 642–941 "thinking" tokens on extraction and takes 4–8 seconds against a
2-second budget; `gemini-3.5-flash` returned invalid JSON. The detail lives in the registry. Without
a credential every step still works except the estimates — which is itself worth checking, because
FR-014 says a Cook can publish without the AI Assistant.

## The gate first

```bash
./scripts/verify.sh
```

The only definition of passing. 19 checks run; two change behaviour in this feature.

**codegen** — called `codegen drift` while E2 was being planned — asserts that `build_runner`
*succeeds*, and it now runs *before* `analyze` and `tests` because the first `@riverpod` controller
made generated code a compile requirement. The old name described an assertion that could never
fail: generated Dart is gitignored, so the `git diff` it ran had nothing to diff.

**rls coverage** now has three tables to inspect — `kitchen_profiles`, `analytics_events` and
`meals`. To prove it is awake rather than merely quiet, delete the
`ALTER TABLE meals ENABLE ROW LEVEL SECURITY` line from
`supabase/migrations/20260802113525_create_meals.sql`, re-run, and watch it report
`no RLS for table "meals"`. Put the line back.

A separate check, **localization codegen drift**, covers the generated `app_localizations*.dart`
files. They come from `flutter gen-l10n` and match neither `*.g.dart` nor `*.freezed.dart`, so the
check above never saw them; it compares file content against a snapshot rather than asking git. That
gap produced a real defect on 2026-08-03: two ARB keys were committed without their generated Dart
and the gate passed.

If any check reports "skipping", something did not land.

## 1. Authorization — the checks that matter most

```bash
./scripts/local-db.sh test            # no Docker — real Postgres, all suites
# or: supabase test db                # works if you have Docker
```

Proves every ✗ in `contracts/authorization.md`. Written before the policies, so they fail first and
pass once the migration lands. **If they pass on the first run they are testing nothing.**

There are **7 pgTAP suites, 69 assertions** in `supabase/tests/`. The four added by E2 are
`meals_rls_test.sql`, `meals_lifecycle_test.sql`, `meal_draft_completeness_test.sql` and
`meal_photos_storage_test.sql`.

The five worth watching:

- **A Cook cannot reassign their own Meal to someone else.** The `WITH CHECK` case. Omitting it is
  the specific mistake that survived review in E1 and is the same mistake one table later. This is
  no longer a one-time manual check: assertion 23 of `meals_rls_test.sql` weakens the `WITH CHECK`
  clause to `true` *inside a rolled-back transaction*, disables the trigger that would otherwise
  answer first, and proves the reassignment then succeeds. So the sensitivity of the reassignment
  case is measured on every commit rather than remembered from the day someone checked it by hand.
- **A retired Meal cannot come back.** Enforced by a trigger, not the UI, because "by any route"
  includes routes nobody has written.
- **Nobody signed out reads a draft, and everybody reads a published Meal.** First use of the `anon`
  role in Kafoo; the pair proves the widening is exactly as wide as intended.
- **A kitchen with only drafts is found by nobody.** Correct, and the thing most likely to be
  "fixed" into a bug.
- **Changing calories relabels the source as the Cook's**, whatever the client claimed.

## 2. Publishing by talking

```bash
flutter run -d <device>
```

- At no point are **two unanswered questions on screen at once**. SC-002, and the clearest sign the
  conversation rule was honoured rather than nodded at.
- Count the questions. A Meal has seven values. **If you are asked for all seven, the AI Assistant
  has failed** — most should be inferred from what you said and the photo. This is the number to
  watch, not the fact that it works.
- Answer by speaking. On a device without `ar-EG` recognition it degrades to typing with an
  explanation, exactly as in E1.
- **Before the photo is used, you are told it is sent away to be looked at**, and you can refuse.
  Refuse once and confirm the flow still completes with estimates from your words alone.
- Abandon halfway, force-quit, reopen: **the draft is still there and you can carry on.** This is a
  deliberate difference from E1, where abandoning the Kitchen Profile conversation kept nothing.
  A draft may be incomplete — the migration that created `meals` declared `title`, `description`,
  `price`, `cuisine` and `category` all `NOT NULL`, which silently contradicted persisting the draft
  as the conversation proceeds. `20260803160618_allow_incomplete_meal_drafts` drops `NOT NULL` from
  those five columns and moves the requirement onto the **transition** instead: a row may be
  incomplete while `status = 'draft'`, and must be complete to become anything else. Enforced on
  insert, on the draft-to-offer move, and on every later write to a non-draft row. This was a founder
  decision, because it changes what a draft *is*: a saved intention rather than a finished Meal
  awaiting a button.
- **Answer only some of the questions, then try to put the Meal on offer. The database refuses it**
  — not the UI. This is the half of the rule above that a green screen cannot show you.
- Nothing is on offer until you confirm.

## 3. The AI Assistant is an assistant

The heart of Principle II, and the place where a passing test can still be a broken promise.

- Every AI-derived value is **visibly an estimate**, with what it was based on. Not a tooltip — on
  the screen.
- Approve everything without changing anything. Then look at the stored Meal: calories and allergens
  are still marked as the AI Assistant's. **Approval is not verification**, and that difference has
  to survive all the way to a Customer reading the Meal.
- The `derive_nutrition_source` trigger decides who owns a Meal's calories and allergens, and it
  exists because the client must not be believed on that question. Until 2026-08-05 it promoted a
  figure to the Cook's own whenever the value changed — correct for a correction, wrong for the
  write that puts a value there in the first place. A Cook cannot publish without approving every
  estimate, and approving writes the AI Assistant's own number onto a column that held nothing.
  That read as a change, so **every published Meal came out labelled as a figure a person had
  checked.** `20260805120815_fix_nutrition_source_on_first_write` makes the promotion require a
  value to **replace**. The first write leaves the label as the AI Assistant's; changing a stored
  figure still makes it the Cook's. **Deliberate known inaccuracy:** a Cook who types their own
  figure as the very first thing that column ever holds is recorded as an estimate. The database
  cannot tell that write apart from an approval without believing the client about which act it was,
  and believing the client is what this trigger exists to refuse. The error runs toward
  under-claiming — calling a Cook's figure an estimate — rather than toward presenting a guess as
  verified.
- Now change the calorie figure. It becomes yours. Change it back to the AI's number — it stays
  yours, because you touched it. **This works during publishing, on the estimate-approval step. It
  does not work on the Meal edit screen:** editable fields there are exactly title, description and
  price. Calories and allergens are deliberately absent, because a screen that sent the whole Meal
  back would trip the trigger and silently relabel an AI estimate as a figure the Cook stands
  behind.
- **Turn the provider off** (drop the credential) and publish a Meal. It must work. The AI Assistant
  is an assistant, not a dependency.

## 4. Timing — measure, do not assume

The budget most at risk, and Kafoo has never measured a model round-trip.

- Time from finishing your description to the first estimate appearing. Budget is **2 seconds**, and
  it should *start* arriving well before that because the response streams.
- Time from confirming to the Meal being on offer. Budget is **3 seconds**. This should be
  comfortable — estimation happens during the conversation, not here (FR-030). If this one is slow,
  something moved a model call into the publish path.
- **Write both numbers down.** E1's launch-time baseline (T068) was never taken and the budget is
  still unverified a whole feature later. Do not repeat that here. **As of this writing nobody has
  measured either number** (open tasks T075 and T076), so the reader taking these measurements is
  taking them for the first time.

## 5. Discoverability — the E1 promise finally kept

**This is the step that proves the inherited obligation landed.**

1. Sign in as a second person. Find the first Cook's kitchen. You can — because they have a Meal on
   offer. This was impossible in E1 and is the whole point.
2. As the Cook, take the Meal off the menu. As the second person, look again: **the kitchen is gone
   too.**
3. Put it back. The kitchen returns.

If step 1 fails, the widening policy did not ship in the `meals` migration, and **nothing will have
errored** — queries return zero rows. That silence is the failure mode this step exists to catch.

## 6. The menu

- Take a Meal off the menu and put it back. Nothing about it is lost.
- Retire a Meal. It leaves the menu and **cannot come back** by any route you can find.
- A retired Meal is still readable to you.
- Try to delete a published Meal. You cannot — archiving is what that is for.
- Delete a draft. It goes.

## 7. Arabic and RTL

- Every screen reads right to left, with no element reading left to right.
- Every string is Egyptian Arabic — conversational, not Modern Standard.
- **Including what the AI Assistant drafts.** A description that reads like a news anchor is a
  defect. This is the first Arabic in Kafoo that a model wrote rather than a person, and it is the
  most likely place for register to slip.
- **The Arabic word for Cook is `الطباخ`** (ADR-0010, founder decision 2026-08-04). A gate step
  named `arabic vocabulary` fails on the wrong word across `apps`, `packages`, `prompts` and
  `supabase`. The existing `vocabulary` step could never have caught this — it greps English words,
  and every occurrence was inside an Arabic string.
- **The AI Assistant never addresses the Cook in the second person.** Arabic marks gender on the
  second person, so every "you" forces a guess about whether this Cook is a man or a woman and
  there is no neutral form to fall back on. The prompt requires the third person about the Meal
  instead, which removes the guess rather than making it well. Confirm that nothing the AI Assistant
  writes addresses the Cook directly.

## What this cannot prove locally

Stated plainly, because a green local run is not a working feature:

- **That estimates are any good in Egyptian Arabic.** The goldens run against a stub. Real dialect
  quality needs a real provider and real Cooks' phrasing, and it varies between models in ways
  benchmarks do not predict.
- **What a published Meal costs.** Every publish now bills a vision call. That number needs
  measuring before phone sign-in and Meal publishing are both committed to — it joins E1's
  unmeasured per-verification cost, still open as T073.
- **That the voice budget survives a vision call on a real handset over a real Egyptian network.**
  The mitigation is designed, not proven.
- **That `ar-EG` recognition exists on the handsets Cooks own.** Still open from E1 as T071.
  Emulators are not evidence.
- **That `prompts/meal-description.md` works against a real model.** Only `meal-analysis` has been
  replayed against a provider (open task T098). The description the AI Assistant drafts has been
  checked against a stub and by review, not against the provider that will actually write it.
