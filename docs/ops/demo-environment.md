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

## What you will not see working

**Search finds nothing until the database has embeddings.** A Meal seeded by `seed.sql` has no
vector, so it appears in browsing and not in search — the documented behaviour of a missing
embedding, which is *harder to find, never lost*. On a permanent database this is a one-off:

```bash
SUPABASE_URL=<demo url> SUPABASE_SERVICE_ROLE_KEY=<demo service key> \
GEMINI_API_KEY=<key> DENO_CERT=/root/.ccr/ca-bundle.crt \
deno run --allow-net --allow-env scripts/backfill-meal-embeddings.ts
```

Thirteen Meals, spaced 4.5 seconds apart against the free tier, so about a minute. Run it again
after changing the demo data.

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

## Turning it off

Delete the branch in the Supabase dashboard. The cost stops that day. The demo APK then points at a
database that no longer answers, so clear the two repository variables at the same time — the
workflow refuses an empty address, which is a better failure than an app that installs and hangs.
