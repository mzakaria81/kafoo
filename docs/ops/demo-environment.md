# The demo environment

A Kafoo you can hold in your hand, with food in it, that is not production.

## What it is

A **permanent** Supabase branch called `demo/environment` — its own database, its own API, its own
Edge Functions, its own fixed address. Founder's decision, 2026-08-07; the reasoning and the cost
are in `docs/ops/preview-branches.md`.

Permanent is the whole point. It was briefly a pull-request preview branch instead, and that shape
had a defect no amount of documentation fixes: a preview branch is destroyed when its pull request
closes, so the pull request could never be merged, so the repository carried one titled DO NOT MERGE
and every notification about it read as a warning. A demo you cannot merge away from is not a demo,
it is a hostage.

## Getting the app on a phone

1. GitHub → **Actions** → **Demo APK** → **Run workflow** → Run. Leave both inputs empty; the
   address comes from the repository variables.
2. When the run finishes, download **kafoo-demo-N** from the **Artifacts** box at the bottom of the
   run page. It arrives as a zip with the APK inside.
3. Open the APK on an Android phone. Android will ask whether to allow installing from this source —
   the build is signed with a debug key, which is exactly why it is not publishable.

The app opens on food, signed in to nothing. That is the Customer surface, and it is what a person
arriving from a shared link sees.

**The two inputs are an override**, for pointing a build at a throwaway pull-request branch without
disturbing the stored address. Empty means "use the demo database".

## The stored address

Two **repository variables**, at Settings → Secrets and variables → Actions → **Variables**:

| Variable | What |
|---|---|
| `DEMO_SUPABASE_URL` | the demo branch's API URL, `https://<ref>.supabase.co` |
| `DEMO_SUPABASE_PUBLISHABLE_KEY` | that branch's publishable (anon) key |

Both are in the Supabase dashboard under the demo branch's API settings.

**Variables and not secrets, deliberately.** A variable is readable, so anyone can check which
database a build pointed at — the exact question worth being able to answer about an app somebody
installed on their phone. And the publishable key ships inside every APK regardless; hiding it in a
secret would protect nothing while making the build harder to audit.

The workflow refuses the production ref outright, and refuses an empty address rather than building
an app that would throw on its first frame.

## Signing in as a Cook

The numbers and codes are in `supabase/demo-data.json`. No SMS is sent — `supabase/config.toml`
declares them as test numbers, and that declaration is deployed with everything else.

**Those test numbers are declared for every environment that reads `config.toml`, which includes
production.** Production has no Cooks and nothing to reach, so nothing is at risk today. It is a
pre-launch checklist item, not a live hole, and it is written down here because the place it would
otherwise be noticed is after launch.

## Search — working since 2026-08-08, and what it took

Browse, search, exclusion and area narrowing were all verified live against this database on
2026-08-08. Two things had to be true, and neither was:

**The Edge Functions had to be declared.** `discover`, `judge-results` and `embed-meal` had no
entries in `supabase/config.toml`, and only declared functions deploy — so `discover` answered 404
here *and on production*, and E3's search had never run anywhere. `./scripts/verify.sh` now fails on
a function directory with no entry, because the rule was already written in `config.toml`'s own
header and being stated in the file people forget to open is not enforcement.

**The branch needed its own model key.** A Supabase branch is a separate project and inherits no
secrets, so `GEMINI_API_KEY` was absent and every search returned 503 — reported to the Customer as
"search is unavailable", with no detail, because the detail leaks the phrase. Set once, per branch:

```bash
supabase secrets set GEMINI_API_KEY=<key> --project-ref <branch ref>
```

**That key is spendable by anyone holding the demo APK.** `discover` calls a paid embedding provider
per search and the APK ships the publishable key that reaches it. Small at demo scale and real —
if the APK goes further than intended, rotate the key or clear the secret, which stops search and
leaves browsing working.

**Embeddings are a one-off on a permanent database.** Seeded Meals have no vector, and a Meal
without one browses normally and never appears in search — *harder to find, never lost*. All
thirteen were embedded on 2026-08-08. Re-run only after changing the demo data:

```bash
SUPABASE_URL=<demo url> SUPABASE_SERVICE_ROLE_KEY=<demo service key> \
GEMINI_API_KEY=<key> DENO_CERT=/root/.ccr/ca-bundle.crt \
deno run --allow-net --allow-env scripts/backfill-meal-embeddings.ts
```

Add `--dry-run` first; it lists what would be embedded and spends nothing. Thirteen Meals spaced
4.5 seconds apart against the free tier is about a minute, and it selects on `embedding IS NULL`, so
re-running only does the ones that are missing.

## What you will not see working

**Photos are absent.** No Meal in the demo set carries one. `photo_path` is nullable and every
screen renders correctly without it, which is deliberate — but it means the demo looks plainer than
the product will.

## Changing the food

Edit `supabase/demo-data.json`, then:

```bash
python3 scripts/generate-demo-seed.py
```

That rewrites the generated block at the foot of `supabase/seed.sql`, and `./scripts/verify.sh`
fails if you forget.

**Getting it into the permanent database is a RESET, and a reset is destructive.** Supabase runs
`seed.sql` once, when a branch is created — pushing a changed seed does not re-run it. Resetting the
branch reapplies the migrations and the seed, and throws away everything created by hand since. On
an ephemeral branch that cost nothing; on this one it is a real loss, so decide before you click.

## Why none of this can reach production

Two locks, and they are independent on purpose.

`seed.sql` never runs against production: `supabase db push` applies migrations and nothing else.
That is a property of the tool, so the generated block adds one of its own — it inserts nothing into
a database that already holds a person.

The reason for two is `.claude/rules/business-rules.md`, which calls a synthetic Cook or Meal on the
real marketplace product-fatal rather than untidy. "The tool would not do that" is a weaker sentence
than a statement that cannot.

## How a session reaches this database — read yes, write never

**A session can now READ the demo database directly, and could not until 2026-08-11.** That gap cost
a day. `analyze-meal` was refusing every analysis of a Meal with a photograph — 403
`photo_path_forbidden`, because it demanded `meal-photos/{uid}/{mealId}.jpg` and the app has only ever
sent `{uid}/{mealId}.jpg`. The function logs said so on the first request. Nobody could read them, so
it was found by reading code on both sides and comparing by eye, hours later, after one wrong guess
about a missing model key had already been reported to the founder as the likely cause.

`.mcp.json` now declares a second server, `supabase-demo`, pinned to `pzyngffppwfsvdsnslkb` and
`--read-only`. It carries `list_tables`, `list_migrations`, `list_edge_functions`, `get_advisors` and
`query_logs` against the demo project. Use `query_logs` FIRST when the demo build misbehaves.

Three things about that entry are deliberate:

- **The ref is written in, not taken from `SUPABASE_PROJECT_REF`.** That variable names the project
  the repository belongs to, and `scripts/verify.sh` fails when it disagrees with
  `supabase/project-ref` — pointing it at the branch to read the branch would turn the gate red. A
  project ref is not a secret either; it is in the URL inside every APK, and it is quoted in
  `docs/ops/measuring-discovery.md`.
- **Read-only, and that is not a formality.** The first server has been read-only since it was added.
  Nothing about diagnosing a demo build needs a write, and an agent holding a write credential
  against a live project is a different risk class from an agent that can look.
- **`.claude/hooks/guard-hard-blocks.py` still blocks the shell route, and should.** Its
  `LIVE_PROJECT` rule refuses any `supabase` command carrying `--project-ref` or `--linked`, which
  catches read-only subcommands like `secrets list` as collateral. That is the correct trade: the
  rule matches on how a command ADDRESSES a project rather than on what it does to it, because an
  allowlist of safe verbs is exactly the shape that leaks the first time somebody adds a verb.
  The read-only window belongs in the MCP server, where it cannot become a write.

**Two things a session therefore cannot do, both on purpose:**

**Set or read a secret.** Nothing in the read-only surface exposes secret names, let alone values. A
missing `GEMINI_API_KEY` on this branch has to be checked and fixed by a person, in the dashboard
under Project Settings → Edge Functions → Secrets, or with
`supabase secrets set GEMINI_API_KEY=<key> --project-ref pzyngffppwfsvdsnslkb` from a human's
terminal.

**Deploy.** Function code and migrations reach this branch when the `demo/environment` git branch is
updated, and that is the only path. It is slower than a command and better: every change to the
database the founder's phone talks to is a reviewed commit with a message, rather than something
somebody ran once. Bring it forward the way `3b66492` did — merge `main` into `demo/environment` and
push. **Say what it will change before pushing it**: the branch redeploys its functions and applies
every migration it has not seen.

## Turning it off

Delete the branch in the Supabase dashboard. The cost stops that day. The demo APK then points at a
database that no longer answers, so clear the two repository variables at the same time — the
workflow refuses an empty address, which is a better failure than an app that installs and hangs.
