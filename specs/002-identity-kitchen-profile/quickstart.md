# Quickstart — proving this feature works

How to convince yourself E1 actually does what it claims. Written for someone picking this up cold,
including a future session with none of this conversation.

Implementation detail lives in `tasks.md`. This is the run-and-check guide.

## Prerequisites

```bash
bash .devcontainer/post-create.sh   # only outside Codespaces / Claude Code on the web
supabase start                       # Docker required
supabase db reset                    # rebuild from migrations + seed
melos bootstrap
```

`supabase db reset` is safe locally and **forbidden** against staging or production.

## The gate first

```bash
./scripts/verify.sh
```

This is the only definition of passing. For the first time it has a real table to inspect, so the
RLS coverage check stops announcing that it has nothing to look at — if it still says that, the
migrations did not apply and everything below will pass for the wrong reason.

## 1. Authorization — the checks that matter most

```bash
supabase test db
```

Proves every ✗ in `contracts/authorization.md`. These are written before the policies, so they
should fail first and pass once the policies land. If they pass on the first run, they are testing
nothing.

The three worth watching, because they are the ones that fail when a policy is written from memory:

- **A Cook cannot reassign their Kitchen Profile** to another person. This is the `WITH CHECK` on
  the `UPDATE` policy. Omitting it is the specific mistake `.claude/rules/supabase.md` warns about.
- **Another signed-in person reads zero rows** — and gets zero rows, not an authorization error. An
  error would confirm the row exists.
- **A person cannot read their own analytics events.** Correct, and counterintuitive enough that
  it is worth seeing pass.

## 2. Sign in

```bash
flutter run -d <device>
```

- Enter a phone number. **Nothing else is asked** — no password, no email, no "are you a Cook or a
  Customer". If you were asked for anything else, SC-009 has been broken.
- Locally, Supabase writes the code to the auth logs rather than sending it:
  `supabase logs auth` — or use a test number configured in `supabase/config.toml`.
- Close the app completely and reopen it. **You are still signed in.**
- Sign in on a second device with the same number. You reach the **same** person, with the same
  Kitchen Profile — not a second, empty one.

Wrong code, then an expired one: each says plainly which happened, and you can request a new code
without starting over.

## 3. The Kitchen Profile conversation

The heart of the feature, and the place a form would have been easier.

- At no point are **two unanswered questions on screen at once**. That is SC-006, and it is the
  clearest single sign the constitution's conversation rule was honoured rather than nodded at.
- Answer by speaking. On a device without `ar-EG` recognition installed, it should **degrade to
  typing with an explanation**, not fail. Worth testing deliberately by disabling the language pack
  — this is the likeliest real-world failure and the one least likely to show up in the emulator.
- Abandon the conversation halfway, force-quit, reopen: **no Kitchen Profile exists**, and you are
  not shown to anyone as a Cook. Nothing is stored before confirmation (FR-013, FR-015).
- Reach the summary, change one answer, confirm. Only that answer changed.
- Try to start a second Kitchen Profile: you are taken to the existing one.

## 4. Discoverability — the surprising one

**Nothing is publicly visible, and that is correct.** FR-030 makes a kitchen findable only while
its Cook has a published Meal, and Meals do not exist yet.

So: signed in as a different person, you cannot find the Kitchen Profile at all. Do not treat this
as a bug and do not "fix" it by adding a public read policy — that policy belongs to E2, and
`data-model.md` has it written out ready.

## 5. The email invitation

- Register, and confirm you are **never** asked for an email address (SC-009).
- Confirm a Kitchen Profile. **Now** the invitation appears — once — saying plainly that it is how
  you keep access if you lose your number.
- Decline it. Nothing is withheld. Decline again a few times: **it stops appearing** (FR-029,
  SC-010).
- Accept it on a fresh account. Sign out, sign in by email, and reach the same identity and the
  same Kitchen Profile.
- Try signing in with an email address never attached to anything: it reaches **nothing**. An
  address cannot claim an identity it was not attached to from within.

## 6. Removal — end to end

The one path where the database's guarantees stop halfway, so check it directly rather than
trusting the cascade.

1. Create an account, a Kitchen Profile, and upload a photo.
2. Note the photo's storage path and the person's id.
3. Remove the account from inside the app. **One confirmation, no bargaining, no reason asked**
   (FR-034).
4. Check all four:
   - The `auth.users` row is gone.
   - The `kitchen_profiles` row is gone — by cascade, not by code.
   - The **photo is gone from storage**. This is the step nothing enforces automatically, so it is
     the step most likely to be missing.
   - The `analytics_events` rows **still exist**, with `person_id` null. Removed *and* still
     countable — FR-039.
5. Sign in again with the same phone number. You are a **new** person with nothing attached
   (FR-033). If your Kitchen Profile came back, removal was a deactivation and Apple's guideline is
   not satisfied.

## 7. Arabic and RTL

- Every screen reads right to left, with no element reading left to right.
- Every string appears in Egyptian Arabic — conversational, not Modern Standard.
- ARB parity is gated, so a missing Arabic key fails `verify.sh` rather than shipping in English.

## What this cannot prove locally

Stated plainly, because a green local run is not the same as a working feature:

- **That a code actually arrives on an Egyptian phone.** Local development writes codes to a log.
  Egyptian operators generally require registered sender IDs, and an unregistered sender is
  filtered *silently* — nothing errors, the code simply never comes. Only a real number on a real
  Egyptian network settles this.
- **That `ar-EG` recognition exists on the handsets Cooks own.** Emulators are not evidence. This
  needs mid-range Android devices bought in Egypt.
- **What sign-ins cost.** Every verification is billed. That number needs measuring before phone
  sign-in is committed to.

All three are in `research.md` as open risks. None blocks writing the code; all three block
believing it works.
