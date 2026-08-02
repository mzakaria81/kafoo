# Preview branches (ephemeral databases)

**Status: working since 2026-08-02.** The first preview branch was built on pull request #16. It
found a real bug in its first thirty seconds — see "What it caught immediately".

---

## What this is, in one paragraph

A preview branch is a **throwaway Supabase database created for a single pull request**. Supabase
builds it by applying every file in `supabase/migrations/`, then running `supabase/seed.sql`. When
the pull request is merged or closed, the branch is destroyed. It starts empty: no production data
is copied in, ever.

The point is to stop schema and configuration changes reaching the real database untried.

**Cost.** Branches bill only while they exist, so cost tracks how many pull requests are open rather
than a monthly subscription. An idle repository costs nothing. Compare a persistent staging
database, which is about $10/month whether or not anyone uses it.

## Why ephemeral rather than persistent, for now

Kafoo has no users. The live database holds nothing a mistake could damage, so it is already serving
as its own staging environment. Buying a permanent second database to protect an empty one is paying
for a rehearsal room with no performance to rehearse.

Revisit when either happens, whichever comes first:

- the first real Cook signs up, or
- a test build goes to someone outside the team and needs a fixed address to talk to

At that point add a persistent branch *as well*. These are not alternatives; the second becomes
worth its cost later.

**When that day comes, do not copy real Customer data into staging.** It will be suggested as "more
realistic testing". Allergy and dietary information is health-adjacent and is stored only with
consent for a named purpose (`.claude/rules/business-rules.md`); "we copied it to a test database"
is not that purpose. Realistic *shapes* of data, yes. Real people's records, no.

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

Exactly the intended shape. The narrow scope matters: the suites in `supabase/tests/` deliberately
*become* `anon` or `authenticated` and then call `clear_authentication()` to climb back out, so
revoking the whole schema would turn the bottom three `false` and fail every authorization test in
the project. The `tests` schema is also absent from `api.schemas`, and a PostgREST call to it returns
404 — checked, not assumed.

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
