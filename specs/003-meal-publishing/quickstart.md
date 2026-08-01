# Quickstart — proving this feature works

How to convince yourself E2 does what it claims. Written for someone picking this up cold, with
none of the conversation that produced it.

Implementation detail lives in `tasks.md`. This is the run-and-check guide.

## Prerequisites

```bash
bash .devcontainer/post-create.sh   # only outside Codespaces / Claude Code on the web
supabase start                       # Docker required
supabase db reset                    # rebuild from migrations + seed
melos bootstrap
dart run build_runner build --delete-conflicting-outputs   # new in E2 — Riverpod codegen
```

`supabase db reset` is safe locally and **forbidden** against staging or production.

A model provider credential is needed for anything involving the AI Assistant. Without one, every
step below still works except the estimates — which is itself worth checking, because FR-014 says a
Cook can publish without the AI Assistant.

## The gate first

```bash
./scripts/verify.sh
```

The only definition of passing. Two checks change behaviour in this feature: **codegen drift** stops
saying "no package uses build_runner yet" and starts doing work, and **RLS coverage** now has a
second table to inspect. If either still reports skipping, something did not land.

## 1. Authorization — the checks that matter most

```bash
supabase test db
```

Proves every ✗ in `contracts/authorization.md`. Written before the policies, so they fail first and
pass once the migration lands. **If they pass on the first run they are testing nothing.**

The five worth watching:

- **A Cook cannot reassign their own Meal to someone else.** The `WITH CHECK` case. Omitting it is
  the specific mistake that survived review in E1 and is the same mistake one table later.
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
- Nothing is on offer until you confirm.

## 3. The AI Assistant is an assistant

The heart of Principle II, and the place where a passing test can still be a broken promise.

- Every AI-derived value is **visibly an estimate**, with what it was based on. Not a tooltip — on
  the screen.
- Approve everything without changing anything. Then look at the stored Meal: calories and allergens
  are still marked as the AI Assistant's. **Approval is not verification**, and that difference has
  to survive all the way to a Customer reading the Meal.
- Now change the calorie figure. It becomes yours. Change it back to the AI's number — it stays
  yours, because you touched it.
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
  still unverified a whole feature later. Do not repeat that here.

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
