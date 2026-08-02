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
- A branch named **`staging` exists**, created by hand on 2026-08-02. It is healthy and correctly
  migrated, but it is **not** a preview branch: it has no `git_branch`, so no pull request creates
  or destroys it, and it does not make the check above pass. Creating a branch by hand and fixing
  the GitHub integration are separate jobs; only the second produces per-pull-request previews.
- `staging` is also flagged `persistent: false` while having no pull request to be torn down with —
  the running cost of a permanent branch with the lifetime guarantee of a temporary one. Decide
  which it is meant to be rather than leaving it in between.

Whatever is switched off is visible only in the dashboard:

1. Open **Project Settings → Integrations → GitHub** for the `kafoo` project.
2. Confirm the connected repository is `mzakaria81/kafoo` and that the **supabase directory** is
   `supabase` — a wrong or empty value here makes Supabase decide the pull request changes nothing
   it cares about, and skip.
3. Confirm the **production branch** is `main`.
4. On **Branches**, confirm preview branches are enabled for pull requests.

`Supabase Preview` turning from `skipped` to a real result on the next pull request that touches
`supabase/` is how you know it worked. If it still skips, the settings above are the place to look.

## What a branch actually contains — measured, not assumed

An earlier version of this document asserted that a branch gets the migrations and then the seed
file. That was written from the documented behaviour, before any branch existed to check. Half of it
is wrong.

Measured on 2026-08-02 against the `staging` branch (`jxujlmhfaxlngrjeuvhb`), by querying it
directly:

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
