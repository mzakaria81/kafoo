# Preview branches (ephemeral databases)

> **THEY ARE STILL ON. This document said otherwise until 2026-08-05.**
>
> The paragraph below recorded them as "turned OFF in Supabase" on 2026-08-03. Opening pull request
> #32 built one anyway — project `zkctybzvjrnktithgldg`, migrations applied, seed run, Edge
> Functions deployed — and pull request #29 had one too, live at the same moment. Whatever was
> retired, the Supabase GitHub integration was not switched off with it.
>
> **This matters for money, which is the reason the retirement was decided.** Branches bill while
> they exist, so the cost tracks how many pull requests are open. Two were open and billing while
> this was believed to be off. Either turn the integration off in the Supabase dashboard's GitHub
> settings, or delete this retirement notice — but the file and the account have to agree.
>
> **It also turned out to be useful, which complicates the decision rather than settling it.** WP-002
> needed a real Supabase to measure a Cook's publish latency against, production was unusable, and
> the preview branch was the thing that made the number takeable. That is the gap the retirement
> accepted, reappearing the first time somebody needed it.
>
> One limit found while using it: **a preview branch gets no copy of the parent project's secrets.**
> `analyze-meal` returns `502 provider_misconfigured` on one until a model credential is set on the
> branch itself. Anything touching the AI path cannot be verified on a preview branch out of the box.

> **RETIRED 2026-08-03 — the original notice, kept because the reasoning still stands.** Kafoo no
> longer builds a preview branch per pull request *by intent*, and the `Authorization` workflow no
> longer waits for one. The RLS suites now run
> against a real Postgres started inside the CI runner — see **[local-database.md](local-database.md)**.
>
> **Why.** Two costs, one of them money. Every open pull request billed a live Supabase project. The
> other cost was worse: with no local database, the constitution's requirement that a negative test
> be *seen to fail* meant pushing the test in its own commit and waiting for a branch to build. One
> extra push and a round trip for every red. The local harness answers in seconds and needs no
> secrets.
>
> **What was given up.** A preview branch was real Supabase — real Auth issuing real JWTs, real
> PostgREST, the real storage service. The local harness stands in for those, so it proves the
> schema, constraints, triggers and policies as SQL and nothing about Supabase's own services.
> `scripts/local-db-bootstrap.sql` names every stand-in. That is a real gap and it is the reason
> this document is retained rather than deleted.
>
> **Turning it back on** is a setting in the Supabase dashboard's GitHub integration, plus restoring
> the `SUPABASE_ACCESS_TOKEN` / `SUPABASE_PROJECT_REF` secrets and a workflow step that runs the
> suites against the branch. Everything below still describes how it worked, including the bug it
> caught in its first thirty seconds, which is the argument for bringing it back if the gap above
> ever starts to matter.
>
> **One consequence to keep in view.** Migrations still reach production when a pull request merges
> to `main`, through Supabase Branching's production deploys. Retiring *preview* branches removes
> the rehearsal, not the deployment. A schema change is now reviewed and locally tested, then
> applied to production on merge with nothing in between.

---

**Status: worked from 2026-08-02 to 2026-08-03.** The first preview branch was built on pull request
#16. It found a real bug in its first thirty seconds — see "What it caught immediately".

---

## What this is, in one paragraph

A preview branch is a **throwaway Supabase database created for a single pull request**. Supabase
builds it by applying every file in `supabase/migrations/`, then running `supabase/seed.sql`. When
the pull request is merged or closed, the branch is destroyed. It starts empty: no production data
is copied in, ever.

The point is to stop schema and configuration changes reaching the real database untried.

**Cost.** An ephemeral branch bills only while its pull request is open, so that part of the bill
tracks how many pull requests are open rather than a subscription. The permanent demo database below
is the standing cost — roughly $10/month, whether or not anyone opens it.

## There is now a permanent branch as well, and it is the demo database

**Founder's decision, 2026-08-07.** Kafoo keeps ephemeral branches for pull requests AND runs one
permanent branch called `demo/environment`. They are not alternatives; they answer different
questions. An ephemeral branch asks *does this change break the schema*. The permanent one asks
*what is Kafoo like to use*, and that question cannot be answered by a database that is deleted when
a pull request closes.

This section previously argued the opposite — that a permanent branch was "paying for a rehearsal
room with no performance to rehearse", and that the moment to buy one was when a real Cook signed up
or a build went to someone outside the team. **That reasoning was about protecting the production
database, and it was answering the wrong question.** The demo database does not exist to protect
anything. It exists so there is a Kafoo with food in it that somebody can hold, and the founder
needed that before either of those triggers, not after.

The ephemeral argument also had a practical cost nobody had priced: a demo environment on a pull
request cannot be merged without destroying itself, which put a pull request titled DO NOT MERGE at
the top of the repository and made every GitHub notification about it read as a warning.

**What the permanent branch changes:**

- Its API URL and publishable key are FIXED. They are stored as the repository variables
  `DEMO_SUPABASE_URL` and `DEMO_SUPABASE_PUBLISHABLE_KEY`, which is what makes building the demo APK
  a single click rather than a copy-and-paste.
- It survives its pull request being merged or closed, and it survives the git branch being deleted.
- **`seed.sql` still runs only at creation.** So changing `supabase/demo-data.json` no longer
  reaches it by closing and reopening a pull request — reset the branch instead, which reapplies
  migrations and the seed. That throws away anything created by hand, which on a permanent database
  is a real loss rather than a formality.
- It costs money every day nobody uses it. Deleting it is one click and the cost stops; the demo APK
  then points at nothing until a new address is stored.

**Do not copy real Customer data into it.** This will be suggested as "more realistic testing".
Allergy and dietary information is health-adjacent and is stored only with consent for a named
purpose (`.claude/rules/business-rules.md`); "we copied it to a test database" is not that purpose.
Realistic *shapes* of data, yes — that is what `supabase/demo-data.json` is. Real people's records,
no.

## What it caught immediately

The first branch build failed at its first step:

```
400 sms_test_otp: Must be a comma separated list of <phone-number>=<code>.
    Phone numbers are in E.164 without the leading + sign.
```

`supabase/config.toml` had written the test-OTP phone numbers with a leading `+`. The local stack
accepted that silently, so it survived from E1 through a green gate and three merged pull requests.
The first deployed environment to read the same file rejected it in seconds.

That is the entire argument for this feature, demonstrated on day one: **no amount of local testing
finds a setting the local stack does not validate.** Had the deploy workflow's migration step ever
been enabled, this would have failed against production instead.

## What a branch actually contains — measured

Measured 2026-08-02 by querying preview branch `coamyiukxwrsnvyyextf` (pull request #16) directly:

| | Result |
|---|---|
| Postgres version | 17.6 — matches production |
| Migrations applied | Yes — both tables present |
| Row Level Security | Yes, on both tables |
| `supabase/seed.sql` run | **Yes** — `tests` schema and pgTAP both present |
| Edge Functions deployed | **No** — see below |

**This corrects an earlier claim, twice over.** A hand-created branch measured on the same day got
the migrations and *not* the seed, and this document previously recorded seeds as not running, with
"the difference is the git link" as an untested hypothesis. A git-linked branch now confirms it: the
seed runs when the branch is built from the repository, and does not when the branch has no
repository to read it from. Both halves are now observation rather than inference.

### The seed's REVOKE, verified for the first time

`seed.sql` revokes `tests.create_supabase_user` — which inserts straight into `auth.users`, bypassing
sign-up and phone verification — from `PUBLIC`, `anon` and `authenticated`. Until this branch existed
that statement had never executed anywhere. Measured on the branch:

| Helper | `anon` execute | `authenticated` execute |
|---|---|---|
| `create_supabase_user` | **false** | **false** |
| `authenticate_as` | true | true |
| `authenticate_as_anon` | true | true |
| `clear_authentication` | true | true |

The narrow scope is right: the suites in `supabase/tests/` deliberately *become* `anon` or
`authenticated` and then call `clear_authentication()` to climb back out, so revoking the whole
schema would fail every authorization test in the project. The `tests` schema is also absent from
`api.schemas`, and a PostgREST call to it returns 404 — checked, not assumed.

**But that table was read too generously, and the conclusion drawn from it was wrong.** `EXECUTE`
being granted does not make a function callable: `tests.foo()` also needs `USAGE` on the schema, and
a newly created schema grants `USAGE` to nobody. Measured 2026-08-02: `has_schema_privilege` is
`false` for both roles, and every call raised `permission denied for schema tests`. The privileges
read as granted while nothing was callable. `seed.sql` now grants the `USAGE` as well.

## The authorization suites still do not run

They have never executed, and the reason has changed twice. pgTAP and the `tests` helpers were
missing until `seed.sql` was added; that was fixed, and revealed two blockers underneath. Both were
measured on 2026-08-02, and both apply to a local stack exactly as much as to a branch:

1. **No `USAGE` on schema `tests`** for `anon` or `authenticated`, so `tests.clear_authentication()`
   — which every suite calls *while* acting as one of those roles — raised permission denied. Fixed
   in `seed.sql`.
2. **No `SELECT` on `auth.users`** for either role. Every suite resolves a user with
   `(SELECT id FROM auth.users WHERE email = '...')` while authenticated as that user, and neither
   role can read that table in any Supabase project.

The second is **not** fixed, deliberately. Granting a test role read access to `auth.users` would
weaken the database the suites exist to check, and a suite that passes because the database was
loosened for it proves nothing. The fix belongs in the suites: capture the ids that
`tests.create_supabase_user` already returns into a temp table, `GRANT SELECT` on it to `anon` and
`authenticated`, and read ids from there. That pattern is verified working — the probes described
below use it.

Until that lands, "the authorization suites pass" remains a thing nobody has ever observed.

## What was verified instead, on 2026-08-02

Rather than modify the suites in place, their intent was re-expressed as direct probes run as the
real `anon` and `authenticated` roles against preview branch `iknhgmnmdecuvsdibrdi`. Eleven checks,
all passing, plus a deliberately-wrong twelfth that failed — because a harness that has only ever
printed PASS may be incapable of printing FAIL, which would make every other line meaningless.

| Check | Result |
|---|---|
| Owner reads own Kitchen Profile | 1 row |
| A different Cook reads Kitchen Profiles | 0 rows |
| A different Cook updates the owner's profile | 0 rows affected |
| A different Cook inserts a profile owned by the owner | rejected |
| A different Cook reassigns `cook_id` to themselves | rejected |
| Owner's `display_name` after those attempts | unchanged |
| Signed-out visitor reads Kitchen Profiles | 0 rows |
| A person reads their own analytics events | 0 rows |
| A person attributes an event to someone else | rejected |
| Anonymous records `SignInStarted` | allowed |
| Anonymous records a non-funnel event | rejected |
| **Control — deliberately wrong** | **failed, as required** |

This is evidence that the policies *behave*, which is a different claim from the policies being
written correctly, and it is the first time the former has been true of this project.

## Merging a pull request changes the production database

This is the part of branching that is easy to switch on without noticing. **When a pull request
merges to `main`, Supabase applies that branch's migrations to the production database**, through the
GitHub integration. Nothing in `.github/workflows/` does it and nothing asks first.

Observed on 2026-08-02: the merge of #17 carried `20260802065138_restrict_kitchen_photo_enumeration`,
the deploy workflow's migration step **failed** on a malformed token, and production received the
migration anyway — recorded in `supabase_migrations.schema_migrations`, with the old policy gone.

Two consequences worth holding on to:

1. **The pull request review is the only gate on a schema change.** There is no separate approval
   between merge and the live database. Treat a migration in a diff as a production change, because
   that is what merging it does.
2. **`deploy.yml` no longer deploys migrations.** The step was deleted rather than repaired, because
   two systems writing the same schema is worse than one: they race, neither knows what the other
   applied, and `db push` reconciling against a history Supabase has already advanced is how a
   migration gets applied twice or skipped. If that job is ever wanted back, turn Supabase's
   production deploys off first.

## Operating notes

**Only new migration files are pushed on each commit.** Supabase's own comment on the pull request:
"Tasks are run on every commit but only new migration files are pushed. Close and reopen this PR if
you want to apply changes from existing seed or migration files." So editing `seed.sql` or an
existing migration and pushing does **not** re-apply it — close and reopen the pull request, or the
branch keeps the old version and you will be testing against something that is not in the diff.

**Edge Functions are not deployed to branches by default.** The build warns: "Only Functions declared
in config.toml will be automatically deployed to branches: `[functions.my-slug]`". Nothing is
declared, so `delete-account` does not exist on a preview branch and its contract tests cannot run
there.

Declaring it is **not** a one-line fix, and is deliberately left undone. The platform's default
`verify_jwt = true` rejects unauthenticated requests *before* the function runs — including the CORS
preflight `OPTIONS`, which carries no `Authorization` header and which this function handles
explicitly. Declaring the function without settling that would break preflight for web clients. The
function already verifies the JWT itself and returns 401 without a bearer token, so it is not
unprotected today; it is simply absent from branches. Treat adopting it as its own change with its
own test.

## The follow-up worth doing next

E1's authorization suites have still never run against a real Postgres — every Dart test uses an
in-memory stand-in.

The blocker is now gone. A preview branch has the migrations, pgTAP, and the `tests` helpers, which
is everything `supabase test db` needs. The next change should run `supabase/tests/*.sql` against the
preview branch on every pull request. That is what turns "the policies are correct by review" into "a
non-owner was observed getting zero rows on a real database".

## If a preview stops appearing

Read the check's own summary before changing any setting — it names the cause directly. That field
sat unread through four pull requests while this document guessed at two wrong causes:

```bash
# check-run id comes from the pull request's checks
curl -sS -H "Authorization: Bearer $GH_TOKEN" \
  https://api.github.com/repos/mzakaria81/kafoo/check-runs/<id> \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['output']['summary'])"
```

The toggle lives in **Project Settings → Integrations → GitHub**. It cannot be changed from a
session: the Management API publishes 115 endpoints and none touches the GitHub integration —
checked 2026-08-02 against the API's own specification, so this is a property of the API rather than
a missing permission.

## Local development is unaffected

`supabase start` still runs the whole stack on your machine and is the fastest loop. Preview branches
are for what happens after you push. `supabase/config.toml` pins `major_version = 17` to match the
deployed project; if your local volume predates 2026-08-01, `supabase db reset` rebuilds it.

## A note on inspecting branches

Fetch what you need, not the whole record. `GET /v1/branches/{id}` embeds the branch's database
password and JWT signing secret in plaintext, so a read-only "is it healthy?" check copies live
credentials into whatever transcript or log is watching. Use
`POST /v1/projects/{ref}/database/query` for state questions, and
`GET /v1/projects/{ref}/api-keys` when a key is genuinely needed.
