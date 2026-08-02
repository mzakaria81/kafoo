# Preview branches (ephemeral databases)

**Status: prepared in the repository, not yet firing.** The repository side is done. One dashboard
setting is not, and it cannot be done from a session — see "The part a human has to do".

---

## What this is, in one paragraph

A preview branch is a **throwaway Supabase database created for a single pull request**. Supabase
builds it by applying every file in `supabase/migrations/` to an empty database, then running
`supabase/seed.sql`. When the pull request is merged or closed, the branch is destroyed. It starts
empty: no production data is copied in, ever.

The point is to stop schema changes reaching the real database untried. Today a migration is
reviewed by reading it. With previews, every pull request that touches the database gets one built
from scratch, and a migration that cannot apply cleanly fails there instead of on the live project.

**Cost.** Branches bill only while they exist, so cost tracks how many pull requests are open rather
than a monthly subscription. An idle repository costs nothing. Compare a persistent staging
database, which is about $10/month whether or not anyone uses it.

## Why ephemeral rather than persistent, for now

Kafoo has no users. The live database holds nothing a mistake could damage, so it is already
serving as its own staging environment. Buying a permanent second database to protect an empty one
is paying for a rehearsal room with no performance to rehearse.

Revisit this when either of these happens, whichever comes first:

- the first real Cook signs up, or
- a test build goes to someone outside the team and needs a fixed address to talk to

At that point add a persistent branch as well. Preview branches and a persistent staging branch are
not alternatives; the second becomes worth its cost later.

**When that day comes, do not copy real Customer data into staging.** It will be suggested as "more
realistic testing". Allergy and dietary information is health-adjacent and is stored only with
consent for a named purpose (`.claude/rules/business-rules.md`); "we copied it to a test database"
is not that purpose. Realistic *shapes* of data, yes. Real people's records, no.

## The part a human has to do

Connecting Supabase to GitHub is an authorization step. It cannot be done through the API or the
CLI, so no session can do it.

**Current state, checked 2026-08-02:**

- Branching is **enabled** on the project — the API reports a default branch for `main`.
- The GitHub integration is **connected enough to post a check**: every pull request gets a
  `Supabase Preview` entry.
- That check has come back **`skipped` on every pull request so far** — #12, #13, #14 and #15 —
  including #12, which added all three migrations, and #15, which changed two files inside
  `supabase/`. So the "the pull request had nothing database-related in it" explanation is ruled
  out.
- A branch named `staging` was created by hand on 2026-08-02 and **deleted the same day**. It was
  healthy and correctly migrated, but it was not a preview branch — no `git_branch`, so no pull
  request created or destroyed it, and it did nothing for the check above. Creating a branch by hand
  and enabling the integration are separate jobs; only the second produces per-pull-request
  previews. It was deleted because it was empty, billed while it existed, and was flagged
  non-persistent with no pull request to be torn down with — the running cost of a permanent branch
  with the lifetime of a temporary one.
- The project therefore has **one branch, `main`**, and no preview branch has ever been built.

**The reason, read from the check itself rather than guessed.** The GitHub check run carries a
summary field, and on pull request #15 it said:

> Creating a new preview branch per PR is disabled. You can re-enable it in Project Integrations
> Settings.

So the integration is connected and working correctly. One toggle is off. Earlier revisions of this
document speculated about the repository connection and the *supabase directory* setting; both were
wrong, and the check had been carrying the real answer the whole time.

**The fix:** open **Project Settings → Integrations → GitHub** for the `kafoo` project and enable
creating a preview branch per pull request.

This cannot be done from a session. The Supabase Management API publishes 115 endpoints and not one
of them touches the GitHub integration — checked 2026-08-02 against the API's own specification, so
this is a property of the API rather than a missing permission.

`Supabase Preview` turning from `skipped` to a real result on the next pull request that touches
`supabase/` is how you know it worked.

**If it skips again, read the check's summary before changing any setting.** That field names the
cause directly:

```bash
# the check-run id comes from the pull request's checks
curl -sS -H "Authorization: Bearer $GH_TOKEN" \
  https://api.github.com/repos/mzakaria81/kafoo/check-runs/<id> \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['output']['summary'])"
```

## What a branch actually contains — measured, not assumed

An earlier version of this document asserted that a branch gets the migrations and then the seed
file. That was written from the documented behaviour, before any branch existed to check. Half of it
is wrong.

Measured on 2026-08-02 by querying the `staging` branch directly, before it was deleted. The branch
is gone, so these numbers cannot be re-derived — that is the reason for writing them down rather
than linking to a dashboard:

| | Result |
|---|---|
| Migrations applied | **Yes** — all three, and `supabase_migrations` records them |
| Row Level Security on both tables | **Yes** |
| Postgres version | 17.6, matching production |
| `supabase/seed.sql` run | **No** — no `tests` schema, no pgTAP |

So the security rules do reach a branch, which is the main thing. The test harness does not.

**Why, most likely — and this is a hypothesis, not a finding.** `staging` was created by hand and
carries no `git_branch`. A git-linked branch is built from the repository, where `seed.sql` lives; a
hand-made branch has no repository to read it from. That fits the evidence and nothing here has
tested it, because no git-linked branch has ever been built. Verify it rather than repeating it.

**Consequence worth tracking:** the `REVOKE` at the foot of `seed.sql` has still never executed
anywhere. It is written for the case where the seed *does* reach a deployed branch, and that case
has not happened yet.

**Consequence for the follow-up below:** the pgTAP suites need the `tests` schema, so they cannot
run on a branch that never got the seed. Whatever makes the seed run is a prerequisite for the CI
job, not a detail to sort out afterwards.

**Production is not seeded** — `supabase db push` applies migrations only. That part holds.

## The follow-up worth doing next

E1's authorization suites have still never run against a real Postgres — every Dart test uses an
in-memory stand-in, and `supabase test db` has only ever been run locally, if at all.

Once previews fire, the suites in `supabase/tests/` can run against the preview branch on every pull
request. That is the change that turns "the policies are correct by review" into "a non-owner was
observed getting zero rows on a real database". It is deliberately **not** in this change: a CI job
that cannot be watched working is a job that gets written wrong and merged green.

Do it in the first pull request after `Supabase Preview` reports a real result.

## Local development is unaffected

`supabase start` still runs the whole stack on your machine, and it is the fastest loop. Preview
branches are for what happens after you push. Note that `supabase/config.toml` now pins
`major_version = 17` to match the deployed project; it said 15 until 2026-08-01, so migrations were
being authored against a different major version than the one they would be applied to. If your
local volume predates that change, `supabase db reset` rebuilds it.
