// Give a vector to Meals that were published before Meals had vectors.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// A SCRIPT AND NOT A MIGRATION, AND THAT IS THE WHOLE DESIGN.
//
// A migration runs inside a transaction, on deploy, with nobody watching. This one makes a paid
// call to a model provider per Meal, at a few hundred milliseconds each, against a free tier that
// allows a fixed number of requests a minute. Put that in a migration and the first deploy on a
// real corpus either times out mid-transaction or holds a lock on `meals` while it waits on a
// vendor — and a rolled-back migration leaves nothing behind to resume from.
//
// AN INCOMPLETE RUN LEAVES MEALS HARDER TO FIND, NEVER LOST. That is not luck, it is three
// properties together:
//
//   1. `meals.embedding` is NULLABLE. A Meal with no vector is invisible to search and fully
//      visible to browsing — see the column comment in 20260806231625_add_meal_embeddings.sql.
//   2. This writes ONE COLUMN. Nothing else about a Meal is read into memory and written back, so
//      there is no shape in which a half-finished run can overwrite a Cook's words.
//   3. Each Meal is its own statement. Stopping after thirty of two hundred leaves thirty Meals
//      searchable and a hundred and seventy exactly as they were. Re-running picks up where it
//      stopped, because it selects on `embedding IS NULL`.
//
// So the interrupt story is: press Ctrl-C, run it again later.
// ────────────────────────────────────────────────────────────────────────────────────────────────
//
// IT HOLDS A SERVICE-ROLE KEY, for the same reason `embed-meal` does and under the same
// constraint. `20260807064927` grants service_role `UPDATE (embedding)` and `SELECT (id, cook_id)`
// on `meals` and nothing else, so a mistake here CANNOT publish, unpublish, reprice or delete a
// Meal — Postgres refuses the statement. The title and description are read through PostgREST as
// service_role, which is why this script also needs the read grant that migration gives it.
//
// IT DOES NOT REIMPLEMENT EMBEDDING. It imports the same `resolveEmbedding` the Edge Function uses,
// so there is one provider path in Kafoo and switching providers stays one environment variable —
// ADR-0005. A script with its own vendor call would be the second one, and the first place the two
// would disagree is the vector width.
//
//   DENO_CERT=/root/.ccr/ca-bundle.crt deno run \
//     --allow-net --allow-env scripts/backfill-meal-embeddings.ts --dry-run
//
// Flags:
//   --dry-run     list what would be embedded, spend nothing, write nothing
//   --limit=N     stop after N Meals. Useful for a first run against production.
//
// RATE LIMIT: the free tier allows a fixed number of requests a minute, and the paid tier is not on
// yet (docs/ops/discovery-model-costs.md). Every model call is spaced by SPACING_MS.

import { resolveEmbedding } from "../supabase/functions/_shared/ai/registry.ts";
import { embeddableText } from "../supabase/functions/embed-meal/text.ts";

/// 4.5 seconds, matching scripts/measure-e2-performance.ts. Slower than necessary on the paid tier
/// and the correct default while the free tier is what Kafoo is running on.
const SPACING_MS = 4500;

interface MealRow {
  id: string;
  title: string;
  description: string | null;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    console.error(`${name} is not set.`);
    Deno.exit(2);
  }
  return value;
}

/// Meals that are ON OFFER and have no vector.
///
/// Published only, deliberately. A draft is not discoverable, so embedding one spends money on a
/// Meal nobody can find — and the Cook's own save path asks for an embedding when it is published
/// anyway. Archived and unavailable Meals are the same argument.
export async function mealsNeedingVectors(
  url: string,
  key: string,
  limit: number | null,
): Promise<MealRow[]> {
  const query = new URLSearchParams({
    select: "id,title,description",
    status: "eq.published",
    embedding: "is.null",
    order: "published_at.asc",
  });
  if (limit !== null) query.set("limit", String(limit));

  const response = await fetch(`${url}/rest/v1/meals?${query}`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
  });
  if (!response.ok) {
    throw new Error(
      `could not list Meals: ${response.status} ${await response.text()}`,
    );
  }
  return await response.json() as MealRow[];
}

/// Writes EXACTLY ONE COLUMN. The database refuses anything else from this role, and this is the
/// statement that stays inside what it permits.
export async function writeVector(
  url: string,
  key: string,
  id: string,
  vector: readonly number[],
): Promise<void> {
  const response = await fetch(
    `${url}/rest/v1/meals?id=eq.${encodeURIComponent(id)}`,
    {
      method: "PATCH",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "content-type": "application/json",
        Prefer: "return=minimal",
      },
      body: JSON.stringify({ embedding: JSON.stringify(vector) }),
    },
  );
  if (!response.ok) {
    throw new Error(`${response.status} ${await response.text()}`);
  }
}

async function main(): Promise<void> {
  const dryRun = Deno.args.includes("--dry-run");
  const limitArg = Deno.args.find((a) => a.startsWith("--limit="));
  const limit = limitArg ? Number(limitArg.split("=")[1]) : null;
  if (limit !== null && (!Number.isInteger(limit) || limit < 1)) {
    console.error("--limit must be a positive whole number");
    Deno.exit(2);
  }

  const url = requireEnv("SUPABASE_URL").replace(/\/+$/, "");
  const key = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

  const meals = await mealsNeedingVectors(url, key, limit);
  if (meals.length === 0) {
    console.log("Every Meal on offer already has a vector. Nothing to do.");
    return;
  }

  console.log(
    `${meals.length} Meal(s) on offer have no vector.` +
      (dryRun ? " Dry run — nothing will be spent or written." : ""),
  );

  if (dryRun) {
    for (const meal of meals) console.log(`  ${meal.id}  ${meal.title}`);
    return;
  }

  // Resolved ONCE and before the loop, so a missing key or a provider that cannot embed fails
  // immediately rather than after the first Meal has already been charged for.
  const { embed, model, apiKey, dimensions } = resolveEmbedding((k) =>
    Deno.env.get(k)
  );
  console.log(`Embedding with ${model} at ${dimensions} dimensions.\n`);

  let done = 0;
  const skipped: string[] = [];
  const failed: string[] = [];

  for (const [index, meal] of meals.entries()) {
    if (index > 0) await new Promise((r) => setTimeout(r, SPACING_MS));

    const text = embeddableText(meal);
    if (text.length === 0) {
      // Nothing to represent. Left without a vector rather than given an empty one — a Meal that
      // is harder to find is the correct outcome, and a vector of a blank string would sit
      // somewhere arbitrary in the space and answer queries it has nothing to do with.
      skipped.push(meal.id);
      console.log(`  skip  ${meal.id}  (no title or description to represent)`);
      continue;
    }

    try {
      // `document`, not `query`. The provider treats the two differently and research.md §1
      // measured the difference; a Meal embedded as a query would rank against a corpus it does
      // not belong to.
      const { vector } = await embed(
        { model, text, task: "document", dimensions },
        apiKey,
      );
      await writeVector(url, key, meal.id, vector);
      done++;
      console.log(`  ok    ${meal.id}  ${meal.title}`);
    } catch (error) {
      // CONTINUE RATHER THAN STOP. One Meal whose text the provider rejected, or one transient
      // 429, must not cost the remaining hundred their vectors — and the Meal that failed is
      // exactly where it was before, so the next run retries it.
      failed.push(meal.id);
      console.error(`  FAIL  ${meal.id}  ${String(error)}`);
    }
  }

  console.log(
    `\n${done} embedded, ${skipped.length} skipped, ${failed.length} failed.`,
  );
  if (failed.length > 0) {
    console.log(
      "Failed Meals still have no vector, so they are harder to find and not lost.\n" +
        "Run this again to retry them.",
    );
    // Non-zero so a scheduled run is visibly incomplete rather than quietly partial.
    Deno.exit(1);
  }
}

if (import.meta.main) {
  await main();
}
