# The demo environment

A Kafoo you can hold in your hand, with food in it, that is not production.

## What this is, and why it is a pull request that never merges

Supabase creates a **preview branch** — a whole separate database, API and set of Edge Functions —
for every open pull request, and destroys it when the pull request closes. `supabase/seed.sql` runs
when that branch is created, which is what puts the demo Cooks and Meals in it.

So the demo environment is a pull request held open on purpose. Merge it and the database goes with
it, along with everything you created while playing.

**Its branch is `demo/environment` and its only content is this file.** Nothing about it is meant to
reach `main`; it exists to own a database.

## Getting the app on a phone

1. GitHub → **Actions** → **Demo APK** → **Run workflow**.
2. Paste the preview branch's API URL and publishable key. Both are in the `supabase[bot]` comment
   on the demo pull request, behind **Database Settings**; the workflow refuses the production ref.
3. Wait for the run, then download **kafoo-demo-N** from the **Artifacts** box at the bottom of the
   run page. It arrives as a zip with the APK inside.
4. Open the APK on an Android phone. Android will ask whether to allow installing from this source —
   the build is signed with a debug key, which is exactly why it is not publishable.

The app opens on food, signed in to nothing. That is the Customer surface, and it is what a person
arriving from a shared link sees.

## Signing in as a Cook

The numbers and codes are in `supabase/demo-data.json`. No SMS is sent — `supabase/config.toml`
declares them as test numbers, and that declaration is deployed to the preview branch with
everything else.

**Those test numbers are declared for every environment that reads `config.toml`, which includes
production.** Production has no Cooks and nothing to reach, so nothing is at risk today. It is a
pre-launch checklist item, not a live hole, and it is written down here because the place it would
otherwise be noticed is after launch.

## What you will not see working

**Search finds nothing at first.** A Meal seeded by `seed.sql` has no vector, so it appears in
browsing and not in search — the documented behaviour of a missing embedding, which is *harder to
find, never lost*. To fix it for a branch:

```bash
SUPABASE_URL=<branch url> SUPABASE_SERVICE_ROLE_KEY=<branch service key> \
GEMINI_API_KEY=<key> DENO_CERT=/root/.ccr/ca-bundle.crt \
deno run --allow-net --allow-env scripts/backfill-meal-embeddings.ts
```

Thirteen Meals, spaced 4.5 seconds apart against the free tier, so about a minute.

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

**The new data does not reach a branch that already exists.** Supabase runs the seed once, at
creation. Close and reopen the demo pull request to get a fresh database — which also throws away
whatever you created by hand, so do it deliberately.

## Why none of this can reach production

Two locks, and they are independent on purpose.

`seed.sql` never runs against production: `supabase db push` applies migrations and nothing else.
That is a property of the tool, so the generated block adds one of its own — it inserts nothing into
a database that already holds a person.

The reason for two is `.claude/rules/business-rules.md`, which calls a synthetic Cook or Meal on the
real marketplace product-fatal rather than untidy. "The tool would not do that" is a weaker sentence
than a statement that cannot.
