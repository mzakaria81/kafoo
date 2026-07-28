# Handoff — state of the project

**Written**: 2026-07-28, at the end of the session that built E0.

Read this first in a new session. It records what exists, what does not, and what is known to be
wrong. `specs/001-e0-foundation/tasks.md` has the task-level detail; this file has the judgement
that does not fit in a checkbox.

## Where things stand

E0 (foundation) is delivered except for the release story. Nothing else has started — there is no
feature code, no database table, and no user-facing flow beyond a placeholder screen.

| Area | State |
|---|---|
| Governance | Constitution v1.0.0, glossary, domain model, ADR-0005. All written, all cited by rules that now resolve. |
| Gate | `./scripts/verify.sh` — 8 checks, all running. Verified locally against the real toolchain, not inferred from CI. |
| Workspace | Dart pub workspace: `apps/mobile`, `packages/{domain,ai,ui}`. Builds, analyses, tests. |
| Platform projects | `android/` and `ios/` generated (ADR-0006: both platforms are in scope). An Android bundle builds end to end (41.9 MB, 3 symbol files); iOS has never been built. |
| Agents | 7 review agents in `.claude/agents/`. |
| CI/CD | Gate on push/PR to `main` and `develop`. Deploy on `main`: backend guarded by secrets; Android and iOS release candidates build but never submit. The iOS job is gated behind a preflight check so it costs no macOS minutes until credentials exist. |
| Codespaces | `.devcontainer/` installs the full toolchain including the Android SDK on rebuild. |
| **Database** | **Nothing.** No migrations, no tables, no RLS exercised. |
| **Features** | **Nothing.** No Meal, no Order, no Conversation, no AI call to a real provider. |

## What is missing, in the order it probably matters

### 1. Release custody — the only item with permanent consequences

**T039: decide where the Android upload keystore lives, and make it recoverable by more than one
person.** This is FR-016. Losing an upload key means Kafoo can never update the app for anyone
who already installed it — not "inconvenient", *permanent*. Nothing has been generated yet, which
is why this is still cheap.

Then T040 (four signing secrets into repository settings) and T041 (verify a genuinely signed
candidate in CI — the current pipeline has only ever produced a debug-signed one).

### 2. The first migration, and with it the first real proof of RLS

`FR-008` — that a person's data is unreadable by anyone else — is **machinery without evidence**.
The hook blocks a table created without RLS, the gate fails on it, and `rls-reviewer` carries the
checklist. None of it has ever run against a real table.

Whoever writes the first migration is also writing the first negative test. Write the test first;
`.claude/rules/supabase.md` has the policy shape and the `USING` + `WITH CHECK` pair that a
missing `WITH CHECK` would let a Cook use to reassign a Meal to someone else.

### 3. E1 and E2

E1 (identity and Kitchen Profile) establishes the ownership pattern every later table copies.
E2 (voice-first, AI-assisted Meal publishing) is the product thesis and the reason the
constitution has the shape it does. Neither has a spec yet. E2 needs `/speckit-specify` — it adds
screens and an AI-derived write path, both stop-and-ask triggers.

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
- **`SUPABASE_PROJECT_REF` vs `SUPABASE_PROJECT_REF_DEV`** — `deploy.yml` uses the former for
  production, `.mcp.json` uses the latter for development. That reads as deliberate, but nobody
  has confirmed the production ref exists as a secret.
- **The performance budgets have never been measured.** Launch <2s and the rest are asserted in
  the constitution and unexercised. The first release build is when they become real.
- **`--fatal-infos` is on.** A new lint in a future Dart release can turn a passing build red
  without any change to Kafoo. That is the intended trade; it will still be surprising.
- **The iOS project is generated but never built.** No macOS machine has touched it. The iOS
  release job is written but has never executed, so it is unverified in a way the Android job no
  longer is — that one was corrected against a real artifact.
- **Two signing identities now, not one.** ADR-0006 doubles the custody problem: losing either
  the Android upload key or the Apple certificate is permanent for that platform.

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

## Starting a session

**Claude Code on the web**: nothing to run. `.claude/hooks/session-start.sh` installs Flutter,
Dart, and melos, then bootstraps the workspace — roughly 90 seconds cold, 2 seconds warm. Without
it the gate skips five of eight checks and still prints `PASS`.

It deliberately does **not** install the Android SDK: that is only needed to build a release
candidate, and it would add minutes to every session. For the rare session that needs one, run
`bash .devcontainer/post-create.sh`.

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
