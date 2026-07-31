# Verifying E1 for real

E1 is written, merged, and passing the gate. Its authorization tests have **never been executed**.
This is how you fix that, and how to tell the difference between "the tests pass" and "the tests
prove something".

Budget an hour the first time. Most of it is Docker pulling images.

## Why this matters more than it sounds

The constitution requires an RLS negative test to be written *before* the policy it tests, and seen
to fail. That ordering is the whole point: a test that passes on its first run has proven nothing,
because it might be asserting something that was never in doubt.

E1's tests were written in the right order but **never run in either state** — no Docker in the
session that wrote them. So today they are in a worse position than the constitution intends: not
red-then-green, just never observed. Step 5 is what recovers the guarantee.

Everything below is local. Nothing touches staging or production.

> **The suites could not have run before 2026-07-31.** They call pgTAP and four `tests.*` helpers,
> and nothing in the repository installed either — `supabase/seed.sql` now does. So "never
> executed" was not only a missing opportunity; the harness was missing too. If you tried these
> steps before that date, this is why they failed.

> **Check which project your environment points at.** `SUPABASE_PROJECT_REF` and `SUPABASE_URL` in
> a session are not guaranteed to be Kafoo's. On 2026-07-31 they pointed at an unrelated project.
> Confirm with `curl -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects`
> before pointing any command at a deployed database.

---

## Prerequisites

- **Docker**, running. The Supabase local stack is about 8 containers and wants ~4 GB.
- **~10 GB free disk** for images.
- A terminal in a clone of this repository.

Nothing else — step 1 installs the rest.

---

## Step 1 — Install the toolchain

```bash
bash .devcontainer/post-create.sh
```

Installs Flutter, melos, Deno, the Supabase CLI and the Android SDK. Idempotent; safe to re-run.

Confirm:

```bash
flutter --version && supabase --version && deno --version
```

If `supabase` is missing, install it alone:

```bash
curl -fsSL https://github.com/supabase/cli/releases/latest/download/supabase_linux_amd64.tar.gz \
  | sudo tar -xz -C /usr/local/bin supabase
```

---

## Step 2 — Start the local stack

```bash
supabase start
```

First run pulls images and takes several minutes. It prints an API URL, a DB URL, and keys — you
need the API URL and the publishable key in step 7.

Ports, from `supabase/config.toml`: API `54321`, database `54322`, Studio `54323`, mail `54324`.

Studio at <http://127.0.0.1:54323> is worth opening; it is how you look at rows in step 8.

---

## Step 3 — Build the database from the migrations

```bash
supabase db reset
```

Applies all three migrations from scratch, then runs `supabase/seed.sql`, which installs pgTAP and
the `tests` helper schema the suites depend on. **Skipping this step means step 4 fails on its first
statement** with "schema tests does not exist" — the harness is not part of the migrations, by
design.

**Safe locally, forbidden against staging or production** — it drops everything first.

If this errors, stop. Nothing below is meaningful against a database that did not build, and a
migration that fails here would have failed in production.

---

## Step 4 — Run the authorization tests

The step that has never happened.

```bash
supabase test db
```

Three files, roughly 18 assertions:

| File | Proves |
|---|---|
| `kitchen_profiles_rls_test.sql` | Seven ownership cases, including that a Cook cannot reassign their Kitchen Profile |
| `analytics_events_rls_test.sql` | Six cases, including that a person reads **zero** of their own events |
| `kitchen_discoverability_test.sql` | That nobody can find any kitchen — correct in E1, and it flips in E2 |

**Expect all of them to pass.** If any fail, you have found a real defect in a policy that has been
merged to `main` — read the assertion, do not "fix" the test.

Three worth reading even when green:

- **A Cook cannot reassign their Kitchen Profile to another person.** The `WITH CHECK` case. This is
  the one that fails when a policy is written from memory.
- **A non-owner gets zero rows, not an error.** An error would confirm the row exists.
- **A person cannot read their own analytics events.** Correct, and counterintuitive enough to be
  worth seeing pass.

---

## Step 5 — Prove the tests are not vacuous

**Do not skip this.** Green in step 4 is weaker evidence than it looks, because nobody has ever seen
these tests red. A suite that passes because it asserts nothing looks exactly like a suite that
passes because the policies are right.

Break something on purpose and confirm the suite notices.

```bash
# Temporarily weaken the UPDATE policy — remove its WITH CHECK
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres <<'SQL'
DROP POLICY "cook updates own kitchen profile" ON kitchen_profiles;
CREATE POLICY "cook updates own kitchen profile"
  ON kitchen_profiles FOR UPDATE TO authenticated
  USING (cook_id = auth.uid());
SQL

supabase test db     # the reassignment test MUST now fail
```

If it still passes, that test is not testing what it claims and **that is a finding worth more than
the whole run**.

Then put it back:

```bash
supabase db reset && supabase test db    # green again
```

Repeat for one more if you want confidence: drop the `analytics_events` select restriction and
confirm the "reads zero of their own events" case goes red.

---

## Step 6 — The Edge Function

```bash
supabase functions serve delete-account
```

In a second terminal:

```bash
deno test --allow-net --allow-env supabase/functions/delete-account/index.test.ts
```

Six cases from `specs/002-identity-kitchen-profile/contracts/delete-account.md`. The one that
matters most: **a caller deletes themselves regardless of anything in the request body.** A
`user_id` in a body is a vulnerability, not a parameter.

This type-checks on every gate run today, which caught three errors — but type-checking is not
running.

---

## Step 7 — Walk the app

```bash
flutter run -d <device> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<key from step 2>
```

Sign-in needs no real SMS. `supabase/config.toml` carries test numbers:

| Number | Code |
|---|---|
| `+201000000001` | `000001` |
| `+201000000002` | `000002` |

Two numbers, so you can be two people — which is what steps 8 and the ownership checks need.

Then follow `specs/002-identity-kitchen-profile/quickstart.md` §2 to §7. It is written for someone
with no context and covers sign-in, the conversation, discoverability, the email invitation,
removal, and RTL.

---

## Step 8 — The one nothing enforces

Account removal deletes a storage object. **No foreign key enforces that**, so it is the step most
likely to be quietly broken.

1. Sign in as `+201000000001`. Create a Kitchen Profile with a photo.
2. In Studio, note the `kitchen_profiles` row, the person's `id`, and the photo's path under
   `kitchen-photos`.
3. Remove the account from inside the app.
4. Check all four:
   - the `auth.users` row is gone
   - the `kitchen_profiles` row is gone — by cascade, not by code
   - **the photo is gone from storage** ← the one to actually look at
   - the `analytics_events` rows still exist, with `person_id` null
5. Sign in again with the same number. You are a **new** person with nothing attached. If your
   Kitchen Profile came back, removal was a deactivation and Apple's guideline 5.1.1 is not
   satisfied.

---

## Step 9 — The gate, with real schema underneath

```bash
./scripts/verify.sh
```

Ten checks. The one to watch is **RLS coverage** — it now has real tables to inspect rather than
announcing it has nothing to look at. A silent skip here would hide everything above.

---

## Step 10 — Write the numbers down

Two budgets have never been measured, and E1 shipped with T068 open because no device was available.

- **App launch.** Cold start to first interactive screen. Budget is under 2 seconds. Whatever the
  first figure is, it is the baseline — record it even if it is bad, especially if it is bad.
- **Meal publish** does not exist yet; that one arrives with E2.

Put both in `docs/HANDOFF.md` under "Known-wrong or unverified", replacing the claim that they have
never been measured.

---

## What "E1 is solid" means when you are done

| Claim | Proven by |
|---|---|
| The migrations apply from scratch | Step 3 |
| A non-owner cannot read another person's data | Steps 4 **and 5** |
| Those tests would catch a regression | Step 5 alone |
| Removal actually removes, including the photo | Steps 6 and 8 |
| A person is recognised across devices and restarts | Step 7 |
| The gate inspects real schema | Step 9 |

Step 5 is the one that converts the rest from "it passed" into "it would have caught it".

## What was already checked against the deployed project

Read-only, on 2026-07-31, against the project actually named `kafoo`. No writes, no test run.

| Check | Result |
|---|---|
| Migrations applied | All three — the deploy pipeline works |
| `kitchen_profiles` and `analytics_events` exist with RLS enabled | Yes |
| `kitchen_profiles` UPDATE policy has **both** `USING` and `WITH CHECK` | Yes — the reassignment hole is not present |
| `analytics_events` has any SELECT policy | No — so nobody reads their own events, as specified |
| Anonymous insert policy scope | Restricted to `person_id IS NULL` and only `SignInStarted` / `SignInFailed` |
| pgTAP installed | **No** — available but not created |
| `tests` schema present | **No** — zero functions |

The policy *definitions* on the deployed project are correct. That is worth having and is not the
same as proving they *behave* — only a run of the suites does that, and the last two rows are why
it cannot happen there.

## What this still cannot tell you

Local green is not a working product. These stay open regardless of how this run goes:

- **That a code arrives on an Egyptian phone** (T072). Local development writes codes to a log.
  Egyptian operators generally require a registered sender ID, and an unregistered sender is
  filtered *silently* — nothing errors, the code simply never comes.
- **That `ar-EG` recognition exists on the handsets Cooks own** (T071). Emulators are not evidence.
- **What sign-ins cost** (T073). Every verification is billed.
