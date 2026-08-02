# Handoff — state of the project

**Written**: 2026-07-28, at the end of the session that built E0.
**Updated**: 2026-07-30, at the end of the session that built E1.
**Updated**: 2026-07-31 — E1 follow-ups, E2 specified/planned/tasked, and the environment mix-up
below.

Read this first in a new session. It records what exists, what does not, and what is known to be
wrong. `specs/001-e0-foundation/tasks.md` has the task-level detail; this file has the judgement
that does not fit in a checkbox.

---

## Before anything else — check which cloud environment you are in

There are two Claude Code cloud environments on this account:

| Environment | Belongs to |
|---|---|
| **`Default`** | `bank-whisperer-lite-dev` — an unrelated household-finance application |
| **`Kafoo_Dev`** | **This repository.** Use this one. |

The whole of 2026-07-31 ran in `Default` by accident. The repository was Kafoo; the credentials
were the finance app's. That is how `SUPABASE_PROJECT_REF`, `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` came to name another product's database, and why the Supabase MCP
server never stayed connected (`.mcp.json` read a `_DEV`-suffixed name that was unset).

**Nothing was written to either database.** A read-only check caught it before any test ran.

**Verify before touching any deployed resource:**

```bash
curl -sS -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects
```

Kafoo's project is named `kafoo`, region `eu-central-1`. Its ref is the one the `Supabase Preview`
check on pull requests already links to. **If `$SUPABASE_PROJECT_REF` is not that project, stop and
switch environments** — do not work around it by overriding the variable.

Verified in `Kafoo_Dev` on 2026-08-01: the configured ref, the project URL and the `ref` claim
decoded from the service-role key itself all name `kafoo` / `cshrkpvljknxsdzwhhle` / `eu-central-1`.
Check the key's own claim, not just that it works — a working key only proves it belongs to *some*
project:

```bash
echo "$SUPABASE_SERVICE_ROLE_KEY" | cut -d. -f2 | tr '_-' '/+' | base64 -d | jq .ref
```

Still to do in `Kafoo_Dev`, by hand:

1. **Rotate the finance app's service-role key.** It sat in a session for an unrelated repository,
   and cloud environments have no secrets store — anyone who can use the environment can read it.
2. **Remove `RESEND_API_Key`.** Live third-party credential; nothing in this repository references
   Resend. Same reasoning as above — an unused credential in a shared environment is exposure with
   no offsetting benefit.

### Environment variable names

**Unsuffixed names only.** `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_DB_PASSWORD`.

`SUPABASE_PUBLISHABLE_KEY` — not `SUPABASE_ANON_KEY`. The app reads the publishable name as of
2026-08-02; see `.claude/rules/supabase.md` for why the two key migrations are separate and which
one is still blocked.

The environment briefly used `_DEV`-suffixed variants while the repository read the unsuffixed
ones. Nothing failed loudly: an unset variable expands to an empty string, so scripts ran against
an empty ref instead of stopping. Settled 2026-08-01 in favour of the unsuffixed names, which is
what the code, the workflows and the runbooks already used. If a second environment is ever added,
give it its own Claude Code environment rather than a second set of variable names in this one.

## Where things stand

E0 (foundation) is delivered except for the release story. **E1 (identity and Kitchen Profile) is
written and passing the gate**, but has never run against a live database or a real handset — see
"Known-wrong or unverified". **E2 (Meal publishing) is fully specified, planned and broken into 80
tasks; not one line of it is implemented.**

### Where to pick up

In rough order of value:

1. **Run E1's authorization suites.** They have never executed, and until 2026-07-31 they were
   *unrunnable* — the pgTAP extension and the `tests` helper schema they call existed nowhere.
   `supabase/seed.sql` fixes that. Walk `docs/ops/verifying-e1.md`; §5 is the step that converts
   "they passed" into "they would have caught it".
2. **Answer E2's blocking decision — choose a model provider** (`specs/003-meal-publishing/tasks.md`
   T080). Recurring spend, so it is a founder call. Requirements are in that feature's
   `research.md` §1. Nothing in E2's AI path can be honestly evaluated until it is answered.
3. **Start E2 at Phase 1.** Tasks are ordered so US3 (ownership) comes first, because it creates
   the table every other story writes into.
4. **The three E1 spikes are still untouched** — `ar-EG` recognition on real handsets, SMS delivery
   to a real Egyptian number, and per-verification cost. Each can invalidate a decision cheaply now
   and expensively later.

| Area | State |
|---|---|
| Governance | Constitution v1.0.0, glossary, domain model, ADR-0005. All written, all cited by rules that now resolve. |
| Gate | `./scripts/verify.sh` — 10 checks, all running. Verified locally against the real toolchain, not inferred from CI. `edge functions` type-checks Deno sources; `no committed credentials` blocks a tracked API key. Both were confirmed to FAIL on a deliberately planted defect, not merely to pass on a clean tree. |
| Workspace | Dart pub workspace: `apps/mobile`, `packages/{domain,ai,ui}`. Builds, analyses, tests. |
| Platform projects | `android/` and `ios/` generated (ADR-0006: both platforms are in scope). An Android bundle builds end to end (41.9 MB, 3 symbol files); iOS has never been built. |
| Agents | 7 review agents in `.claude/agents/`. |
| CI/CD | Gate on push/PR to `main` and `develop`. Deploy on `main`: backend guarded by secrets; Android and iOS release candidates build but never submit. The iOS job is gated behind a preflight check so it costs no macOS minutes until credentials exist. |
| Codespaces | `.devcontainer/` installs the full toolchain including the Android SDK on rebuild. |
| Database | Three migrations: `kitchen_profiles`, `analytics_events`, and the `kitchen-photos` bucket with its storage policies. Every table has RLS and per-operation policies, **confirmed applied and correctly shaped on the deployed project** (read-only check, 2026-07-31 — the `UPDATE` policy carries both `USING` and `WITH CHECK`). **The pgTAP tests have still never been executed**: the harness they need did not exist until `supabase/seed.sql`, and seeds do not run against a deployed project. Run them locally. |
| Edge Functions | One: `delete-account`. Takes no arguments and reads identity from the JWT. Type-checks clean under `deno check`, which is part of the gate. **Never executed** — that needs Docker for the local stack. |
| Features | E1 complete: phone sign-in, the Kitchen Profile conversation, editing, the public view, account removal, recovery email, change-of-number. **No Meal, no Order, no AI call to a real provider.** |
| E2 | Specified, planned, tasked — `specs/003-meal-publishing/`: spec, plan, research, data-model, two contracts, quickstart, 80 tasks. **Zero implementation.** Blocked on a model-provider decision (T080). |
| Decisions | ADR-0007 (dormancy severs a phone credential — policy only, no code), ADR-0008 (a Customer web surface is in scope; technology deliberately undecided). **ADR-0005 needs amending** — E2's plan found that the model seam and the provider credential cannot live in the same place. |
| Web | `apps/mobile/web/` builds (`flutter build web --release`, 42 MB CanvasKit, `lang="ar" dir="rtl"`). Development and demo target **only** — it is not the Customer web surface of ADR-0008, and must not become one by default. |

## What is missing, in the order it probably matters

### 1. Release custody — the only item with permanent consequences

**T039: decide where the Android upload keystore lives, and make it recoverable by more than one
person.** This is FR-016. Losing an upload key means Kafoo can never update the app for anyone
who already installed it — not "inconvenient", *permanent*. Nothing has been generated yet, which
is why this is still cheap.

Then T040 (four signing secrets into repository settings) and T041 (verify a genuinely signed
candidate in CI — the current pipeline has only ever produced a debug-signed one).

### 2. Run E1's tests against a real stack — they exist and have never executed

This is now the largest gap, and it is a **verification** gap rather than a writing one.

```
supabase start
supabase test db                     # 3 pgTAP files, 18 assertions
supabase functions serve delete-account
deno test --allow-net --allow-env supabase/functions/delete-account/index.test.ts
```

`FR-008` — that a person's data is unreadable by anyone else — now has tests written *against
real tables*, which is further than E0 got. They still have to be seen passing. A negative test
that has never run has proven nothing, which is the whole reason the constitution wants it
written first.

The Edge Function and its tests **do** now type-check on every gate run, which is not the same as
running them but is no longer nothing: it caught three errors that had survived review.

Then walk `specs/002-identity-kitchen-profile/quickstart.md` §6 end to end. The step most likely
to be quietly broken is the **photo deletion** during account removal: it is the only part of
removal no foreign key enforces.

### 3. E2

E1 established the ownership pattern every later table copies; E2 (voice-first, AI-assisted Meal
publishing) is the product thesis and the reason the constitution has the shape it does. It has
no spec yet and needs `/speckit-specify` — it adds screens and an AI-derived write path, both
stop-and-ask triggers.

E2 also carries an **inherited obligation**: the migration that creates `meals` must add the
widening `SELECT` policy on `kitchen_profiles` that `data-model.md` has already written out.
Without it Kafoo will have Meals whose kitchens nobody can find, and the failure is silent —
queries return zero rows rather than erroring. `supabase/tests/kitchen_discoverability_test.sql`
is the test that will start failing when that day comes, and its header says so.

### 4. Smaller, real

- **T030** — a check that every rule named in `CLAUDE.md` resolves to a file that exists. Closes
  the "rule written but no check" edge case, which is how this session started: three documents
  were cited by active rules and none of them existed.
- **T043** — pin GitHub Actions to commit SHAs. Currently mutable tags; a tag repoint runs
  attacker code in a job that holds the signing identity.
- **T044** — confirm branch protection on `main` actually requires the gate. `deploy.yml` claims
  migrations stay "behind a human-reviewed merge"; that is only true if review is required. **I
  could not verify this** — the API path is blocked through this session's proxy. It may be
  aspirational.
- **T045** — `apps/admin`, deferred until an administrative surface is needed.
- **iOS release credentials** — the pipeline now has an iOS job, but it is gated behind a
  preflight check and will not start until Apple Developer credentials exist. Needs Apple
  Developer Program membership, then `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_BASE64`, and `IOS_KEYCHAIN_PASSWORD` as repository secrets. Platform
  scope is recorded in ADR-0006: Kafoo ships on **both** Android and iOS, and iOS reaches users
  through **TestFlight first** — friends and family, which means external testers and therefore
  Beta App Review. The same signed archive serves both, so the pipeline is unchanged.

## Known-wrong or unverified

Stated plainly, because the expensive failures this session were all of this kind:

- **Branch protection is unverified** (above). If it is not enabled, a direct push to `main`
  deploys migrations to production with nobody in the loop.
- **`SUPABASE_PROJECT_REF` pointed at the wrong project entirely.** Checked 2026-07-31 against the
  Supabase account: the variable held the ref for `bank-whisperer-lite-dev`, an unrelated household
  finance application with 20 tables. Kafoo's project is a different ref, the one the
  `Supabase Preview` check on pull requests already uses. `SUPABASE_URL` and
  `SUPABASE_SERVICE_ROLE_KEY` matched the same wrong project — the service-role key gave this
  repository's sessions RLS-bypassing access to an unrelated application's database.
  `.mcp.json` read a `_DEV`-suffixed variable that was unset, which is why the Supabase MCP server
  never stayed connected. **Resolved 2026-08-01** — see "Environment variable names" below. The
  outstanding half is the cleanup: **remove the other project's credentials from this environment
  and rotate them.**
- **A green `verify.sh` never proved the authorization suites could run.** They call pgTAP and four
  `tests.*` helpers, and nothing in the repository installed either, so `supabase test db` would
  have failed on its first statement on any machine. `supabase/seed.sql` now installs both. This is
  the sharpest example of the gate's own warning: the check that would have caught it did not exist.
- **The performance budgets have never been measured.** Launch <2s and the rest are asserted in
  the constitution and unexercised. T068 asked for a launch baseline this session and it could
  not be taken — no device, no emulator, no Android SDK in the container. The first release build
  is still when these become real.
- **Nothing in E1 has touched a live Supabase.** Every Dart test runs against an in-memory fake.
  The repositories, the RLS policies and the Edge Function are correct by construction and by
  review, which is not the same as correct. Preview branches are the intended fix and are prepared
  but not yet firing — `docs/ops/preview-branches.md` has the state and the one dashboard setting
  still outstanding.
- **Migrations were authored against Postgres 15 and would deploy to Postgres 17.** `config.toml`
  pinned the local stack to 15 while the project runs 17.6. Corrected 2026-08-01; no migration is
  known to depend on the difference, but none was written with it in mind either.
- **`ar-EG` speech recognition is unverified on real hardware** (spike T071). The conversation
  degrades to typing when recognition is unavailable and that path *is* tested, which is
  deliberate: research.md expects unavailability to be the common case on Egyptian mid-range
  handsets.
- **SMS delivery to Egyptian numbers is unverified** (spike T072). An unregistered A2P sender ID
  is filtered *silently* — nothing errors, the code simply never arrives. Local sign-in works
  today only because `supabase/config.toml` carries test numbers.
- **Per-verification cost is unmeasured** (spike T073). Every sign-in on a new device costs
  money, which makes the sign-in rate limit a spending control as much as a security one.
- **`--fatal-infos` is on.** A new lint in a future Dart release can turn a passing build red
  without any change to Kafoo. That is the intended trade; it will still be surprising.
- **The iOS project is generated but never built.** No macOS machine has touched it. The iOS
  release job is written but has never executed, so it is unverified in a way the Android job no
  longer is — that one was corrected against a real artifact.
- **Two signing identities now, not one** — but the custody problem is not what this file
  previously said it was. It claimed losing either the Android upload key or the Apple
  certificate is permanent for that platform. Neither is true: the upload key resets through
  Play Console under Play App Signing, and Apple treats certificate revoke-and-replace as
  routine. The genuinely irreversible asset is the Android **app signing key**, which was named
  nowhere in this repo. See `docs/ops/release-custody.md`.

## Traps this session hit, so the next one does not

1. **A green gate can mean nothing was checked.** `verify.sh` originally passed with five of
   seven checks skipping. Every check now says so out loud when it has nothing to inspect. If you
   add a check, make it announce its own emptiness.
2. **Melos 7+ needs a Dart pub workspace**, not `melos.yaml`. The root `pubspec.yaml` carries
   `workspace:` and the melos scripts.
3. **`hashFiles()` in a job-level `if:` runs before checkout** and always yields `''`, silently
   skipping the job. Guard at step level.
4. **A signature block is not proof of a publishable build.** A debug-signed bundle has one.
   Check the certificate owner for `CN=Android Debug`. Two earlier versions of that check passed
   a debug-signed artifact.
5. **Flutter's generated release config signs with debug keys** and leaves a `TODO`. Already
   fixed here; do not let a regenerate quietly undo it.
6. **The vocabulary check applies to your own comments.** It caught `vendor` in `packages/ai`
   during E0. The comments were changed, not the check.
7. **The synthetic-content check reads test fixtures as seed data.** It scanned all of
   `supabase/` and failed on pgTAP files that legitimately `INSERT`. Now scoped to
   `migrations/` and `functions/`. If you add a directory of SQL, decide which side it is on.
8. **A lazy `ListView` may silently not build its first child.** The public kitchen view lost its
   photo this way — no error, no ErrorWidget, just an absent subtree. For a handful of fixed
   children use a `Column` in a `SingleChildScrollView`; the laziness buys nothing and costs a
   test you cannot write.
9. **`Image.network` cannot resolve under the test binding** and takes its subtree with it. Wrap
   it in a named widget and assert on that, or you end up testing the network.
10. **`on Exception` does not catch `Error`.** An uninitialised Supabase client throws
    `StateError`; a missing plugin throws `TypeError`. Analytics and voice initialisation both
    caught only `Exception` and stranded a loading spinner forever. Where the rule is "this must
    never break the flow", catch `Object` and say why.

## Starting a session

**Claude Code on the web**: nothing to run. `.claude/hooks/session-start.sh` installs Flutter,
Dart, and melos, then bootstraps the workspace — roughly 90 seconds cold, 2 seconds warm. Without
it the gate skips five of ten checks and still prints `PASS`.

Since E1 it also installs **Deno** (Edge Functions are Deno, and without it the function cannot
even be type-checked) and the **opencode CLI** (the `opencode-delegate` skill). Both add seconds,
not minutes. A warm re-run of `scripts/install-toolchain.sh` takes about 3 seconds.

It deliberately does **not** install the Android SDK: that is only needed to build a release
candidate, and it would add minutes to every session. For the rare session that needs one, run
`bash .devcontainer/post-create.sh`.

**Installing opencode does not sign it in**, and `opencode auth login` does not survive the
container: it writes `~/.local/share/opencode/auth.json`, which is outside the repository and gone
at teardown — the same limitation as the statusline badge below.

The fix is `OPENCODE_API_KEY` as a **cloud-environment variable** (claude.ai/code → cloud icon →
gear → Environment variables). opencode reads it directly, so every session starts signed in with
nothing to re-run. Verified here: with the variable set, `opencode auth list` reports OpenCode Go
and Zen, `opencode/` goes from 7 models to 60, and all ten models in `CLAUDE.md`'s allowlist are
present — so that allowlist is accurate, and an empty-looking list means a missing key rather than
a changed plan.

Two caveats, both from the cloud-environments documentation and both real:

- **There is no secrets store.** Environment variables are readable by anyone who can use the
  environment. Keep the key in a *personal* environment, not an organization-shared one, and treat
  it as rotatable. `./scripts/verify.sh` now fails if a real-looking `OPENCODE_API_KEY` or
  `SUPABASE_SERVICE_ROLE_KEY` is tracked by git, so the repository is guarded; the environment
  configuration is not.
- **`opencode.ai` is not on the default Trusted network allowlist.** The endpoint
  `https://opencode.ai/zen/v1` answered 200 from the environment this was set up in, so it is
  reachable here. An environment locked to **Trusted** may need `opencode.ai` added under
  **Custom** before delegation works.

**Codespaces**: nothing to run either. `.devcontainer/post-create.sh` covers everything including
the Android SDK.

**Anywhere else**: `bash .devcontainer/post-create.sh`, then follow
`specs/001-e0-foundation/quickstart.md`.

## Environment that does not live in the repo

`.devcontainer/post-create.sh` restores the toolchain and two Claude Code plugins on rebuild.
Both are behavioural preferences rather than project requirements — set `KAFOO_SKIP_PLUGINS=1` to
opt out of both, or remove one line to drop just that one.

| Plugin | Effect |
|---|---|
| `caveman` | Compresses output; drops articles and filler |
| `ponytail` | Biases toward the simplest solution that works: YAGNI, standard library first, no unrequested abstractions |

`ponytail` aligns with Simplicity, which is second in the constitution's priority order. It does
**not** outrank User trust, which is first. An argument that something is simpler never justifies
weakening RLS, skipping a negative test, or dropping an Arabic string — if a suggestion trades
trust for brevity, the constitution wins. Worth watching, since that is exactly the kind of
pressure a simplicity bias creates.

Reinstalling by hand:

```
/plugin marketplace add JuliusBrussee/caveman   && /plugin install caveman@caveman
/plugin marketplace add DietrichGebert/ponytail && /plugin install ponytail@ponytail
```

The statusline badge is separate and is **not** restored: it lives in the container's own
`~/.claude/settings.json`, which no repository file can reach. Re-add it with the `statusLine`
entry pointing at the plugin's statusline script. Both plugins ship one; only one can be active.

## Working agreements that are not written elsewhere

- The gate is the only definition of passing. If something matters, add it to `verify.sh` rather
  than to a review checklist a human has to remember.
- A migration belongs with the feature that needs its table, together with RLS and a negative
  test. Do not create tables in advance.
- `spec.md` is technology-agnostic and it is enforced by grep, not goodwill. All technical detail
  goes in `plan.md`.
- Delegated work is still Kafoo work. The brief must carry the constraints, because the
  implementer loads none of this context.
