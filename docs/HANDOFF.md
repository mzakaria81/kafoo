# Handoff — state of the project

**Written**: 2026-07-28, at the end of the session that built E0.
**Updated**: 2026-07-30, at the end of the session that built E1.
**Updated**: 2026-07-31 — E1 follow-ups, E2 specified/planned/tasked, and the environment mix-up
below.
**Updated**: 2026-08-05 — E2 built. Database, Features, Edge Functions, Gate, E2 and Decisions rows
rewritten, and the prose above and below the table brought level with them.
**Updated**: 2026-08-06 — E2 measured itself, and one budget is missed. Six work packages merged
(WP-005, WP-007 to WP-010). **Read "Before E3" below before planning E3.**
**Updated**: 2026-08-07 — the review briefs now run in CI on the pull request diff
(`.github/workflows/review.yml`); it needs an `ANTHROPIC_API_KEY` secret that does not exist yet, so
today it skips loudly on every pull request. Borrowing an external voice benchmark was raised and
deferred — see "Smaller, real".
**Updated**: 2026-08-07, later — E3's WP-016 and WP-017 merged in #54. Five entries added to "Traps
this session hit", which is where a lesson goes when it has no code to live next to. The bar for
that list is deliberately high: something that cost real time, is not preventable by a check, and
carries a workaround. A lesson a check CAN prevent belongs in `scripts/verify.sh` instead, and one
about a single piece of code belongs in a comment beside it — those are read, and a list is only
read by somebody who already suspects they need it.
**Updated**: 2026-08-10 — the iOS build path without a Mac.
**Updated**: 2026-08-14 — **four days of silence, and this file caused it.** MVP mode landed on
2026-08-13 and the whole product direction changed underneath a file that still described a
question-and-answer wizard. Nothing had deleted this file; nothing pointed at it either. It was
reachable only through `specs/*/tasks.md`, which named it in numbered task items (T069, T078,
T194) — and MVP mode retired that per-epic workflow, so the last thread holding this file to the
work was cut without anyone noticing. **`CLAUDE.md` now names it in the Repo map and in the
Definition of done**, which is the repair: a file the next session is told to read, by the file
every session already reads. State, decisions, build path and traps 16–20 are all new below.

Read this first in a new session. It records what exists, what does not, and what is known to be
wrong. `specs/001-e0-foundation/tasks.md` has the task-level detail; this file has the judgement
that does not fit in a checkbox.

**This container is destroyed when the session ends.** The repository is the only thing that
survives it, and only what is committed and pushed. An observation written and not committed is
worth exactly nothing to the next session, and neither is a lesson that stayed in the transcript.

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

### MVP mode, and the direction change under it (2026-08-13 / 08-14)

**Everything below this sub-section was written before 2026-08-13 and describes a product that no
longer exists in that shape.** Read this first; treat the rest as history that is still true about
the database, the gate and the platform, and out of date about the flow.

**MVP mode is active and it is a trial with an end condition.** `CLAUDE.md` was cut from 328 lines
to about 230 on 2026-08-13 — ceremony suspended, the four non-negotiables kept. The pre-cut state is
commit `fab86d8`; `git checkout fab86d8 -- CLAUDE.md .claude/` restores the old rulebook whole, at
any time, and nothing expires. A local tag `pre-mvp-mode` points at the same commit and **could not
be pushed — this repository's token returns HTTP 403 on tag writes** — so quote the commit, never
the tag. The trial ends at a checkpoint, not a feeling: one voice journey built, five real Cooks
tried it, then keep / extend / abandon.

**The wizard is gone (ADR-0015).** A journey is now one screen holding one open conversation. Kafoo
owns the list of facts still missing; the model owns what to say next. The four-question Meal wizard
and the five-question onboarding wizard were deleted, not refactored. `mealSteps()` and
`nextUnansweredMealStep()` no longer exist; `packages/domain/lib/meal_facts.dart` holds an unordered
`Set<MealFact>` in their place. If anything grows a "next" or a "first", the wizard is growing back.

**Memory between conversations is granted with conditions (ADR-0016).** Hearable on demand,
deletable in one sentence, consent before a health-adjacent fact, expiring with ADR-0007's dormancy
window. **Not built.** Order history is not memory and must never be copied into it — a
recommendation reads `orders` directly, because a second copy of purchase history is a second set of
policies to keep correct and the second copy is the one that leaks.

**The live voice path is decided in direction and blocked on one spike (ADR-0017, supersedes
ADR-0009).** Kafoo uses an **ElevenLabs hosted agent**, not the plain text-to-speech API. The phone
never holds a vendor key: `supabase/functions/agent-session/` mints a signed URL valid 15 minutes.
That mint is **the one part of the audio path proven by a real call** — everything after it is
untested on a handset.

**Two live items are the founder's, not a session's:**

1. **`agent-session` is deployed on production and NOT on demo**, and the APK points at demo. A
   Supabase branch inherits no secrets, so it needs `ELEVENLABS_AGENT_ID` and `ELEVENLABS_API_KEY`
   set on the demo branch (`pzyngffppwfsvdsnslkb`) before the microphone can connect to anything.
2. **The agent's brain is ElevenLabs' hosted `gemini-3.5-flash`, not Kafoo's own Gemini key.**
   Pointing it at the founder's key returns `custom_llm_not_allowed_in_zrm` — a custom model
   requires turning zero-retention mode off, which means a third party stores Cooks' words.
   Privacy was chosen over the billing preference; the founder has the trade and has not ruled.

**Demo is the default target. Production is asked for, never assumed** (founder, 2026-08-13). This
binds Edge Function deploys, secrets, seeded rows and above all APK builds — an APK carries whatever
`SUPABASE_URL` it was built with, so a build made "just to test" against production is a test
against real Cooks' rows.

**`.github/workflows/demo-apk.yml` is the build path for any APK a person installs**, and it has
existed since 2026-08-07 with 20-odd runs. It refuses the production project by URL comparison,
refuses an empty address, and signs with the committed key at
`apps/mobile/android/demo/demo.keystore` so each build installs *over* the last one.
`scripts/build-apk.sh` is local-only and signs with the machine's debug key, which means **an APK
from the script will not install over one from the workflow** — Android refuses an update signed by
a different key.

**`docs/mvp-deferred.md` is the honest list of what was skipped** — 19 rows, including that Kitchen
Profile onboarding is still five questions, the publish gate is still a button rather than the
spoken read-back, and **the whole audio path has never run outside a container.**

### Everything below here predates 2026-08-13

E0 (foundation) is delivered except for the release story. **E1 (identity and Kitchen Profile) is
written and passing the gate**, but has never run against a real handset — see "Known-wrong or
unverified". **E2 (Meal publishing) is built and passing the gate.** A Cook can describe a Meal in
conversation, approve the AI Assistant's estimates one at a time, publish it, run a menu, and a
Customer can read it and find the kitchen behind it.

**E2 has now measured itself, and one number came back bad.** All of it landed on 2026-08-06.

**The 2-second voice budget is missed.** Description-finished to first estimate, measured against
production over 12 runs: **2177 ms median, range 1837–2608, 8 of 12 runs over.** Not a near miss and
not one outlier. **1997 ms of it is inside the model call**, so the database half could vanish
entirely and the median would clear the budget by 3 ms. Runs executed from a cloud container, so a
Cook on an Egyptian mobile network pays this *plus* their own latency — it is the optimistic end.
`docs/ops/measuring-e2.md` has the full report, generated rather than hand-written.

**Founder's position, 2026-08-06: accept the miss.** Do not optimise toward it and do not move the
number. The intended answer is to show the Cook something while the model thinks, which is an E3
design question rather than a tuning job. Confirm-to-on-offer is fine at 189 ms against 3 s.

Cost is settled and small: **$0.81 per 1,000 Meals published without a photo, $1.97 with one.**

The `meal-description` prompt has been replayed against a real model and the corpus can now see an
invented claim — see `docs/ops/eval-meal-description-findings.md`. It found the model stating things
the Cook never said, and the corpus had marked all three PASS.

### Where to pick up

**E3 is next, and it is Customer discovery** — finding a Meal or a kitchen without a direct
reference. `specs/003-meal-publishing/plan.md` draws the boundary: E2 made a kitchen *readable*;
finding one is a different feature. The events are already named and reserved in
`docs/product/event-model.md`: `SearchPerformed`, `SearchFailed`, `RecommendationAccepted`.

Everything in the previous version of this list is done. What is left, in order of value:

1. **`ar-EG` speech recognition on a real handset is still unmeasured**, and it is now the largest
   open risk in the product rather than the fourth. ADR-0009 calls it "the unmeasured risk, and the
   likeliest place a voice-first product fails in Egyptian Arabic". The Gemini Live API was the
   route that would have removed it by taking audio natively — **that route is closed for now**, see
   ADR-0009's 2026-08-06 addendum. So the on-device path is the only path and nobody has tested
   whether it hears Egyptian. It needs a physical handset bought in Egypt; no container has a
   microphone. `coordination/packages/WP-004.json`.
2. **SMS delivery to a real Egyptian number, and per-verification cost** (T073). Untouched. An
   unregistered sender ID is filtered silently — nothing errors, the code simply never arrives.
3. **Two ADR-0008 questions are now due**: which technology renders the Customer web surface, and
   what it shows. Both were explicitly deferred until "E2 lands and there is a Meal to show". E2 has
   landed and there is a Meal to show.

| Area | State |
|---|---|
| Governance | Constitution v1.0.0, glossary, domain model, ADR-0005. All written, all cited by rules that now resolve. |
| Gate | `./scripts/verify.sh` — 19 checks, all running. Verified locally against the real toolchain, not inferred from CI. `edge functions` type-checks Deno sources; `no committed credentials` blocks a tracked API key. Both were confirmed to FAIL on a deliberately planted defect, not merely to pass on a clean tree. |
| Workspace | Dart pub workspace: `apps/mobile`, `packages/{domain,ai,ui}`. Builds, analyses, tests. |
| Platform projects | `android/` and `ios/` generated (ADR-0006: both platforms are in scope). An Android bundle builds end to end (41.9 MB, 3 symbol files); iOS has never been built. |
| Agents | 7 review agents in `.claude/agents/`. |
| CI/CD | Gate on push/PR to `main` and `develop`. Deploy on `main`: backend guarded by secrets; Android and iOS release candidates build but never submit. The iOS job is gated behind a preflight check so it costs no macOS minutes until credentials exist. |
| Codespaces | `.devcontainer/` installs the full toolchain including the Android SDK on rebuild. |
| Database | **Nine migrations**: `kitchen_profiles`, `analytics_events`, the `kitchen-photos` bucket and its storage policies, the restriction on kitchen-photo enumeration, `meals`, incomplete Meal drafts, the nutrition-source trigger fix, the Cook's form of address, and **the revoke of TRUNCATE/REFERENCES/TRIGGER/MAINTAIN** from anon, authenticated and service_role (2026-08-06 — measured as held on every table, granted by nobody, arriving by default privilege; TRUNCATE ignores RLS entirely so no policy can refuse it). Every table has RLS with per-operation policies. **`./scripts/local-db.sh test` — 8 suites, 114 assertions, no Docker**, against a real Postgres of the version pinned in `supabase/config.toml`. **`scripts/mutate-policies.py` is new and is the thing to run after touching a policy or a fixture**: it weakens one predicate clause at a time and reports which assertions notice. It found 15 clauses with no assertion behind them and 3 assertions passing for a reason other than their name; both are now zero. `docs/ops/policy-assertion-coverage.md`. |
| Edge Functions | Two: `delete-account` and `analyze-meal`. `analyze-meal` is where the vendor call happens. It holds no service-role key and has no write path, so the AI Assistant is *structurally* unable to write to the database. `supabase/functions/_shared/ai/` holds the provider registry with adapters for Gemini, Anthropic and OpenAI. It is the only place in Kafoo where a model name is written down, and the gate fails if a model id appears anywhere else. Both functions type-check under `deno check` in the gate, as before. **New since E1**: the shared AI code has unit tests (`*_test.ts`) that run in the gate on every commit — the registry suite is what keeps the one-variable provider switch honest, because a half-added provider or a silent fallback to the wrong one would pass every other check. `delete-account` has **still never been executed** — that needs Docker for the local stack. `analyze-meal` *has* been called against a real provider, which is how the model defaults were measured. |
| Features | E1 complete: phone sign-in, the Kitchen Profile conversation, editing, the public view, account removal, recovery email, change-of-number. E2 complete: publishing a Meal by conversation with AI-assisted estimates the Cook approves one at a time; the Cook's menu (put on offer, take off, retire, delete a draft); editing a published Meal one detail at a time; and the Customer's public view of a Meal. E2 also kept E1's inherited obligation: the migration that creates `meals` carries the widening `SELECT` policy on `kitchen_profiles`, so a Kitchen Profile with a Meal on offer is now findable by a Customer. That was impossible in E1. **Still no Order** — it is the next thing that does not exist. |
| E2 | **Built, passing the gate, and now measured.** Model provider decided 2026-08-02, ADR-0005 Amendment 1 — Gemini `gemini-3.1-flash-lite`, chosen by measuring four models against the real prompt. Anthropic Claude Haiku 4.5 stays configured as the alternative: `AI_PROVIDER=anthropic`, one variable, no code change. **All three open measurements closed on 2026-08-06**: the timing budgets (T075 — the 2 s one is missed, see above), the cost of a published Meal (T076 — $0.81 to $1.97 per thousand), and the `meal-description` replay (T098/T100). |
| Decisions | ADR-0007 (dormancy severs a phone credential — policy only). **ADR-0008** (a Customer web surface is in scope; **technology deliberately undecided, and that decision is now due** — it was deferred until E2 landed, and E2 has landed). **ADR-0005 Amendment 1** (the model seam stays `AiProvider` in Dart while the vendor swap moved inside the Edge Function). **ADR-0009 — still Proposed, and the spike has now run without settling it**: the ephemeral-token flow did not work from this account on 2026-08-06, so the thin-client option collapses into the disqualified one and the status quo stands. It is Proposed rather than Rejected because the spike proves the token *could not be used*, not that it cannot be. **ADR-0010 — Accepted and shipped**: a Cook is addressed in their own grammatical form; Customers are addressed as men for now, a deferral rather than a conclusion. |
| Web | `apps/mobile/web/` builds (`flutter build web --release`, 42 MB CanvasKit, `lang="ar" dir="rtl"`). Development and demo target **only** — it is not the Customer web surface of ADR-0008, and must not become one by default. |

## Before E3 — what is already decided, and what is not

Written 2026-08-06, at the founder's request, so an E3 session does not re-open settled questions or
assume unsettled ones.

### Settled. Do not re-litigate these.

- **The 2-second voice budget is missed and that is accepted.** 2177 ms median on production. The
  answer is to show the Cook something while the model thinks, not to optimise and not to move the
  number. If an E3 design needs the budget met, that is a new conversation with the founder.
- **Customers are addressed as men.** Kafoo stores a form of address for Cooks only. Every
  Customer-directed verb stays ungendered; only a *described* Cook changes. Giving Customers one is
  a new category of personal data for a new population and is the founder's call, deferred not
  refused. ADR-0010.
- **The thin-client voice architecture is not available.** ADR-0009 stays Proposed; the status quo —
  every model call through the Edge Function — stands. Re-run the spike before committing E3 to
  anything that assumes a direct client-to-model audio path.
- **Every model call goes through the provider abstraction.** ADR-0005 Amendment 1. Swapping vendors
  is one environment variable and the gate enforces that a model id appears in exactly one place.

### Open, and E3 has to answer or route to the founder

- **Which technology renders the Customer web surface**, and what it shows. ADR-0008 deferred both
  until "E2 lands and there is a Meal to show". Both conditions are met. `apps/mobile/web/` is a
  development target and **must not become the answer by default** — 42 MB of CanvasKit on an
  Egyptian mobile connection is a decision nobody made.
- **How a Customer finds food at all.** Search is not built and not designed. `.claude/rules/supabase.md`
  already forecloses one wrong answer: cross-language search (`برجر` → Burger) is an embedding
  concern with `pgvector` and an HNSW index, **never `ILIKE`**.
- **Whether `ar-EG` recognition works on a real handset.** The largest open risk in the product, and
  it needs the founder and a phone rather than a session.

### The pattern that cost the most on 2026-08-06 — read this one

**Five separate checks were found to be incapable of failing**, across areas with nothing else in
common:

| The check | Why it could not fail |
|---|---|
| ARB parity | compared key names in one direction only, and never placeholders |
| Three authorization assertions | a *different* policy refused first, so the one under test was never consulted |
| `anon cannot TRUNCATE` | the local harness had never granted the privilege it asserted was absent |
| The OpenCode spend ledger | reported `$18.85 left` while the service refused the dispatch for being over its weekly limit |
| Gemini's model catalogue | lists 50 models and omits the Live models it actually serves |

Two of them were caught only by **calling something expected to succeed before believing a
negative**, and one — a `404` on `auth_tokens:create` versus `auth_tokens` — was a four-character URL
suffix away from killing an architecture decision in the direction that closes doors.

**The habit to carry into E3: a green check is a claim, and a claim needs to have been seen to
fail.** Break the thing on purpose, watch the check go red, put it back. `scripts/mutate-policies.py`
does this for database policies now; nothing does it for anything else.

---

## What is missing, in the order it probably matters

### 1. Release custody — the only item with permanent consequences

**T039: decide where the Android upload keystore lives, and make it recoverable by more than one
person.** This is FR-016. Losing an upload key means Kafoo can never update the app for anyone
who already installed it — not "inconvenient", *permanent*. Nothing has been generated yet, which
is why this is still cheap.

Then T040 (four signing secrets into repository settings) and T041 (verify a genuinely signed
candidate in CI — the current pipeline has only ever produced a debug-signed one).

### 2. The parts of the backend a test still cannot reach

**The authorization suites are no longer in this category.** They run, without Docker, in seconds:

```
./scripts/local-db.sh test           # 7 pgTAP files, 76 assertions
```

That is the whole of `FR-008` — that a person's data is unreadable by anyone else — plus every
Meal ownership and lifecycle rule E2 added, exercised against a real Postgres of the version
`supabase/config.toml` pins. `docs/ops/local-database.md` explains how, and why Docker was never
the requirement: Postgres was.

**What is still unreachable is the rest of the stack around those policies** — Auth, PostgREST,
Storage, and Edge Functions at runtime. That needs Docker:

```
supabase start
supabase functions serve delete-account
deno test --allow-net --allow-env supabase/functions/delete-account/index.test.ts
```

`delete-account` has still never been executed. It type-checks on every gate run, which is not the
same as running it but is no longer nothing: it caught three errors that had survived review.

Then walk `specs/002-identity-kitchen-profile/quickstart.md` §6 end to end. The step most likely
to be quietly broken is the **photo deletion** during account removal: it is the only part of
removal no foreign key enforces.

### 3. E2 — built; the inherited obligation is discharged

E1 established the ownership pattern every later table copies; E2 (voice-first, AI-assisted Meal
publishing) is the product thesis and the reason the constitution has the shape it does. It is
specified, planned, built and passing the gate — `specs/003-meal-publishing/`.

E2 carried an **inherited obligation** and **it landed**: the migration that creates `meals` adds
the widening `SELECT` policy on `kitchen_profiles` at the foot of the same file, so a Kitchen
Profile with a Meal on offer is findable. Without it Kafoo would have had Meals whose kitchens
nobody could find, and the failure would have been silent — queries return zero rows rather than
erroring. `supabase/tests/kitchen_discoverability_test.sql` is the suite that would have gone red,
and it passes.

What E2 has not done is measure itself — see "Where to pick up".

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
- **Borrowing an external voice benchmark — raised 2026-08-07, deferred by the founder.** Not
  started, nothing written. Three candidates were identified and they are not interchangeable, so
  whoever picks this up should pick deliberately rather than take the first one:
  - **Per-component latency**, the shape of Tables 2–5 in arXiv 2603.05413 (Salesforce's tutorial,
    measuring Alibaba's Qwen models). Splits one end-to-end figure into per-stage P50/mean/min/max
    so a missed budget names the stage that caused it. Would extend `scripts/measure-e2-performance.ts`
    rather than add anything, and needs no new corpus. This was the recommendation.
  - **VoiceBench**, the voice-assistant quality benchmark Qwen publishes against. Tuning it for
    Kafoo means authoring an Egyptian Arabic spoken-instruction set — substantial, and it partly
    duplicates `docs/ops/transcription-corpus.json`.
  - **BenchForce**, Salesforce's function-calling voice eval. Measures whether an agent calls the
    right tool; Kafoo's AI calls no tools and takes no actions, so most of it has no equivalent here
    yet.

  **Watch the attribution.** "The benchmark from Alibaba" has no referent — Alibaba is Qwen, whose
  models the paper *measures*; the benchmark the paper *cites* is Salesforce's. Getting this wrong
  picks the wrong artefact.

  Worth weighing against all three: `docs/ops/transcription-corpus.json` is already a 26-utterance
  Egyptian Arabic accuracy benchmark with an `msa_substituted` scoring rule, written 2026-08-03 and
  never run (WP-004, `NOT_STARTED`). Building the harness for the corpus that exists may beat
  importing one that does not.
- **iOS release credentials** — the pipeline has an iOS job, gated behind a preflight check that
  will not let it start until Apple credentials exist. **The setup lives in one place and it is not
  this file: `docs/ops/ios-testflight.md`.** It needs an Apple Developer Program membership, then
  `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` and `APPLE_TEAM_ID` as repository secrets.

  Until 2026-08-10 this bullet named `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_BASE64` and `IOS_KEYCHAIN_PASSWORD`, which no longer exist anywhere in
  the pipeline. Anyone following it would have set four secrets nothing reads, watched preflight
  report `App Store Connect credentials present: false` forever, and had no reason to doubt the
  document. Found by release-engineer, in the same change whose own commits fixed three comments
  making that identical mistake — a rename is only finished when the prose is renamed with it.

  It also said "the same signed archive serves both, so the pipeline is unchanged", which was never
  the plan and is not what shipped. iOS signs through Apple's cloud signing: `xcodebuild` presents
  the API key and Apple issues the certificate, so no `.p12` is exported from a Mac keychain — which
  matters because Kafoo has no Mac. Platform scope is still ADR-0006: **both** Android and iOS, iOS
  through **TestFlight first**. Internal testers — the founder's own phone — need no Beta App
  Review; the moment a tester outside the Apple account is added, that changes.

## Repository secrets the Customer web surface needs

**Both, or the site returns 500 on every page that reads data.** Recorded here because this file
documented four iOS secrets and four Android ones in detail and said nothing about these two — which
is most of why one of them could be absent from 2026-08-07 to 2026-08-09 with nobody noticing.

| Secret | Value | Where it is used |
|---|---|---|
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` | Build, and bound to the Worker at deploy time |
| `SUPABASE_PUBLISHABLE_KEY` | The `sb_publishable_…` key, Supabase → Settings → API | Same |

**`SUPABASE_PUBLISHABLE_KEY` is the publishable key and never the service-role one.** The
service-role key bypasses RLS entirely, so a leak defeats every policy in `supabase/migrations` at
once. `apps/web/scripts/check-no-service-role.mjs` fails the build if it reaches the output, but not
copying it is cheaper than catching it.

**They go in GitHub, not in Cloudflare.** `.github/workflows/deploy.yml` binds them to the Worker
with `--var` on every deploy, and `--var` replaces a Worker's variables wholesale — so a value set
by hand in the Cloudflare dashboard is overwritten by the next merge to `main`. One source, and it
is the one the build already reads.

### What went wrong, so it is not repeated

`SUPABASE_URL` was never set. **An unset GitHub secret expands to an empty string**, silently:
`--var "SUPABASE_URL:"` bound a variable that wrangler listed in its binding table exactly like a
healthy one — `env.SUPABASE_URL ("(hidden)")` — and `publicBackend()` rejects an empty string the
same way it rejects an undefined one. Browse, kitchen and Meal pages returned 500 for two days
through **fifteen consecutive green deploy runs**. `/settings` worked throughout, because it reads
the browser's own storage and never touches Supabase.

Two checks now stand between that and a repeat, and they catch different halves:

- **`refuse to deploy without the values the site needs`** fails before publishing and names the
  empty secret. It exists because the deploy was correct and the failure was invisible.
- **`smoke check the published site`** curls `/` after deploying and fails on anything but 200. A
  deploy that published a broken site is not a successful deploy.

There was also a genuine second defect, fixed in the same change and worth knowing separately: the
values were passed to the **build** and never bound to the **Worker**, and every page here is
`force-dynamic` and reads `process.env` when the request arrives. `wrangler.jsonc` said the key
"arrives as a build-time variable", which is true of anything Next inlines and false of every page
on this surface. Either defect alone was enough to keep the site down.

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
  The Edge Functions are correct by construction and by review, which is not the same as correct.
  **The RLS policies are no longer in that category**: they run against a real Postgres on every
  pull request and locally in seconds — `docs/ops/local-database.md`, 76 assertions. What that does
  not cover is Supabase's own services around them, so the gap has narrowed rather than closed.
  Preview branches were the earlier answer and are retired; `docs/ops/preview-branches.md` says why
  and what it would take to bring them back.
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
11. **A selector that finds nothing is indistinguishable from finding nothing wrong.** The gate
    globbed `*_test.ts`, and three suites were named `*.test.ts` — one character. They had never
    run in CI, including all of WP-015's Edge Function suite and its assertion that no word of a
    Customer's phrase comes back in a response. The check printed `ok` throughout. When you add
    something to a suite, list what the harness actually selected and diff it against what exists
    on disk; a passing check only proves the checked set passed.
12. **A measurement can report its own transport.** The first SC-004 replay printed 60%. The model
    had not failed anything — the provider rate-limited on the thirteenth call and twelve un-judged
    cases were recorded as failures. Any harness that calls something external must tell a refusal
    it produced apart from one the network did, and must not average them together. It now paces,
    backs off, and resumes.
13. **`git add -A` in a shared working tree commits somebody else's scratch.** Review agents run
    the code they review and write probes into the tree while you work. Two were left behind on
    2026-08-07 and one reached a commit. `zz_*` is now git-ignored repo-wide and every brief in
    `.claude/agents/` tells its agent to use that prefix or the scratchpad — but stage named paths
    anyway. The same hazard makes a `verify.sh` run started mid-edit a grade of a mixture.
14. **One NUL byte makes git call a source file binary.** A stray `'\0'` in
    `judge-results/index_test.ts` meant `git diff` printed `Bin 0 -> 14130 bytes` and nothing else,
    so the file carrying every FR-018 write-boundary assertion was the one no reviewer could read —
    including the CI job that reviews the pull-request diff. If a diff shows `Bin` for a file you
    know is text, search it for control characters rather than assuming git is confused.
15. **A negative test can pass in both directions.** Four assertions were written for the Arabic
    folding fix, then the fix was reverted to watch them fail. Three went red; the fourth stayed
    green, because its fixture was already satisfied by the substring match it was meant to test.
    "Seen to fail" is a property of each assertion, not of the suite — record WHICH ones went red
    and compare that list against what the change was supposed to protect.

Added 2026-08-14. Same bar as above: each of these cost real time, none is preventable by a check
that exists, and each carries a workaround.

16. **An empty result from a search is a claim about the search, not about the repository.** On
    2026-08-14 a session told the founder this project had no CI and no automated build path, then
    built an APK by hand. Six workflows existed, one of them `demo-apk.yml` with 20-odd runs and a
    fixed signing key — every property the hand-built APK then got wrong. The cause was reading one
    empty shell result and not re-checking. This is trap 11 aimed at the project rather than at a
    test suite, and it is worse there, because the founder cannot tell "I looked and found nothing"
    apart from "there is nothing". **Before building any pipeline, list `.github/workflows/` and
    read what is there.** Say "I found none" only after naming where you looked.
17. **`String.fromEnvironment` answers `""` for a name nobody defined**, so a Flutter build with a
    missing `--dart-define` compiles cleanly, installs, and opens to a black unresponsive screen —
    `main()` throws before the first frame and no check in the gate can see it. `demo-apk.yml`
    already refuses an empty address for exactly this reason and says so in a comment.
    `scripts/build-apk.sh` now refuses too. If you must build by hand, pass both defines.
18. **Writing a whole config file deletes every entry you did not think to mention.** A `Write` to
    `.mcp.json` removed both Supabase MCP servers mid-session; the symptom was tools quietly
    vanishing, several turns later, with nothing linking the two. **Edit a config file you did not
    just read in full — never overwrite it.** Same hazard for `settings.json` and `config.toml`.
19. **A fixed defect comes back when the code around it moves.** The 2026-08-11 resume defect —
    `ref.watch` below an early return in an `autoDispose` controller, so the provider disposes while
    the screen is still alive — was reintroduced on 2026-08-13 by a refactor that had nothing to do
    with it. It now carries a comment saying why the line is where it is. **A fix with no comment is
    a fix with a shelf life**, and the person who undoes it will be you.
20. **Semantics can be inherited from a parent you are about to delete.** The Meal receipt's photo
    label was read aloud because the `ListView` above it merged the subtree. Turning the receipt
    into a panel removed the parent and the label went silent — visually identical, and no widget
    test noticed, because the tests asserted the text existed rather than that it was one node to a
    screen reader. **When a container changes, re-check what the container was providing**, and for
    a voice-first product assume that is more than layout.

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

**Corrected 2026-08-14: caveman and ponytail are no longer container plugins.** Both are vendored
into `.claude/skills/` and switched on in `.claude/settings.json`, so they are committed, they
survive a rebuild, and nothing needs reinstalling. **Both are set to `full`** (founder's decision,
2026-08-13); the paragraph below described them as `lite` and `off`, which was true before that.

| Skill | Effect |
|---|---|
| `caveman` | Compresses output; drops articles and filler |
| `ponytail` | Biases toward the simplest solution that works: YAGNI, standard library first, no unrequested abstractions |

`ponytail` aligns with Simplicity, which sits mid-way in the priority order. It does **not** outrank
User trust, which is first. An argument that something is simpler never justifies weakening RLS,
skipping a negative test, or dropping an Arabic string. `caveman` compresses prose to the reader,
which collides head-on with the communication contract — the founder is not a developer and terse
fragments are the wrong register for him. **Where they disagree, the contract wins and caveman
yields**, and that is written in `CLAUDE.md` rather than left to judgement.

Turn either off with `/ponytail off`, `/caveman off`, or by editing `.claude/settings.json`.

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
