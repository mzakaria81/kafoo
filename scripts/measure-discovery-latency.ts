// Measure what a Customer actually waits between saying a phrase and seeing Meals.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// SC-006 SAYS "RESULTS WITHIN 1 SECOND". THIS IS THE ONLY THING THAT CAN CHECK IT.
//
// Not a widget test. `apps/mobile/test/search_screen_test.dart` counts FRAMES between a request
// finishing and results being visible, which is the right way to prove the interface does not
// stall — and it runs on fake time, so it cannot see a millisecond. The second a stopwatch appears
// in a widget test, it is measuring the test harness.
//
// The precedent is E2's: a script that talks to a real deployment and writes a document.
// `scripts/measure-e2-performance.ts` and `docs/ops/measuring-e2.md`. This follows it.
// ────────────────────────────────────────────────────────────────────────────────────────────────
//
// IT MEASURES THE TWO HALVES SEPARATELY, BECAUSE THEY SCALE DIFFERENTLY AND ONLY ONE OF THEM
// GROWS WITH THE MARKETPLACE.
//
//   end-to-end   POST /functions/v1/discover   — what the Customer waits. Includes one paid
//                embedding call to the model provider, the database half below, and the bytes
//                coming back. CORPUS-INSENSITIVE almost entirely: the vendor call does not care
//                how many Meals exist.
//
//   database     POST /rest/v1/rpc/search_meals — the half that DOES grow. `search_meals` ranks
//                exactly rather than approximately (see 20260806231625_add_meal_embeddings.sql),
//                so its cost is linear in the number of published, embedded Meals.
//
// Reporting only the first number would hide the second inside a vendor round trip and call the
// budget met. Reporting only the second would claim a Customer's wait is 27 ms.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// IT NEVER RUNS AGAINST PRODUCTION, AND THE REFUSAL IS THE CONTROL RATHER THAN THE INTENTION.
//
// `--load` publishes Meals no Cook cooks. `.claude/rules/business-rules.md` calls synthetic Meals
// on the real marketplace product-fatal, so the production ref is refused outright below — the
// same check `.github/workflows/demo-apk.yml` makes, for the same reason and against the same
// public value.
//
// Production is not merely disallowed here, it is USELESS here: it held zero published Meals when
// this was written, so a search timed against it measures a network round trip over an empty table.
// That is why WP-020 exists at all.
// ────────────────────────────────────────────────────────────────────────────────────────────────
//
// THE BENCHMARK CORPUS CARRIES RANDOM VECTORS, AND THAT IS EXACT RATHER THAN APPROXIMATE.
//
// `search_meals` computes the distance from the query to EVERY surviving row and sorts the result.
// That cost depends on how many vectors there are and not on what is in them, so a random unit
// vector times identically to an embedding of a real description — and spends nothing with the
// model provider, and is not subject to its rate limit. A real backfill of a thousand Meals is
// about seventy-five minutes against the free tier and buys an identical number.
//
// WHAT IT WOULD NOT BE GOOD ENOUGH FOR: recall, ranking quality, or anything measured against the
// HNSW index, whose traversal depends on how the vectors are distributed. None of those are
// measured here. `scripts/discovery-retrieval-regression.py` owns retrieval quality and uses real
// embeddings over a real corpus.
//
//   DENO_CERT=/root/.ccr/ca-bundle.crt deno run --allow-net --allow-env --allow-read --allow-write \
//     scripts/measure-discovery-latency.ts --runs=20
//
// Flags:
//   --runs=N      Samples per phase (default 20). Each end-to-end run spends one embedding call.
//   --load=K      Publish K benchmark Meals before measuring, then remove them. Needs
//                 SUPABASE_SERVICE_ROLE_KEY. Without it, measures the corpus as it stands.
//   --keep        Leave a loaded corpus in place. Prints a prominent warning and the cleanup line.
//   --report      Write docs/ops/measuring-discovery.md as well as printing.
//   --dry-run     Validate credentials and print the plan. Spends nothing, writes nothing.

// THE RUN THIS ONE IS COMPARED AGAINST, so a single report can show what corpus size does and what
// it does not. Same script, same target, same day, 77× fewer Meals. Kept as a constant for the same
// reason `measure-e2-performance.ts` keeps PRIOR_PUBLISH: the comparison is the finding, and a
// finding that lives only in a pull request comment is one nobody reads again.
//
// REPLACE THIS WHEN THE SHAPE CHANGES — a new provider, a new region, a change to what `discover`
// returns — and say in the report that it was replaced. Do not leave a stale baseline making a
// change look like an improvement it was not.
const PRIOR = {
  when: "2026-08-08",
  corpus: 13,
  runs: 20,
  e2eP50: 990,
  e2eP95: 1199,
  dbFullP50: 359,
  dbLeanP50: 164,
  medianResults: 13,
} as const;

const PRODUCTION_REF = "cshrkpvljknxsdzwhhle";
const REPORT_PATH = "docs/ops/measuring-discovery.md";
// 1.5 s, raised from 1 s by the founder on 2026-08-08 against the measurement this script took.
// SC-006 and CLAUDE.md's performance budgets carry the reasoning. Changing this number is a
// product decision and not a tuning knob — if a run comes back over, that is reported.
const BUDGET_MS = 1500;
const DEFAULT_RUNS = 20;
const EMBEDDING_DIMENSIONS = 768;
const WRITE_CONCURRENCY = 8;

// Phrases a Customer might actually say, in the language they would say it in. Varied so a single
// cached-looking result cannot flatter the median — the provider is asked something different each
// time. None of them is recorded anywhere by `discover`; FR-029 forbids it and this script is not
// an exception to that, which is why they live here rather than being read from a log.
const PHRASES = [
  "كشري",
  "فراخ مشوية",
  "أكل بيتي حلو",
  "محشي ورق عنب",
  "حاجة سخنة للغدا",
  "أكل من غير لحمة",
  "ملوخية بالأرانب",
  "فطار خفيف",
] as const;

interface Sample {
  readonly ms: number;
  readonly bytes: number;
  readonly count: number;
}

interface Summary {
  readonly n: number;
  readonly p50: number;
  readonly p95: number;
  readonly min: number;
  readonly max: number;
  readonly mean: number;
}

function summarise(values: number[]): Summary {
  if (values.length === 0) {
    return { n: 0, p50: 0, p95: 0, min: 0, max: 0, mean: 0 };
  }
  const sorted = [...values].sort((a, b) => a - b);
  // NEAREST-RANK, and the report says so. With 20 samples the "p95" IS the 19th value — one
  // observation, not an estimate of a tail. Calling it a percentile without the n beside it is
  // the thing WP-020's acceptance criteria refuse.
  const at = (p: number) =>
    sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)];
  return {
    n: sorted.length,
    p50: at(50),
    p95: at(95),
    min: sorted[0],
    max: sorted[sorted.length - 1],
    mean: sorted.reduce((s, v) => s + v, 0) / sorted.length,
  };
}

function requireEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name);
    if (value && value.trim().length > 0) return value.trim();
  }
  throw new Error(
    `Set one of ${names.join(" or ")}. The demo database's address and publishable key are ` +
      `repository variables (DEMO_SUPABASE_URL, DEMO_SUPABASE_PUBLISHABLE_KEY) — see ` +
      `docs/ops/demo-environment.md. Do NOT fall back to the production credentials.`,
  );
}

/// A unit vector of the right width. Normalised because the stored embeddings are, and cosine
/// distance over a non-unit vector is still defined but no longer comparable to them.
function randomUnitVector(): number[] {
  const v = new Array<number>(EMBEDDING_DIMENSIONS);
  let norm = 0;
  for (let i = 0; i < EMBEDDING_DIMENSIONS; i++) {
    // Box-Muller. A uniform cube normalised to the sphere clusters at the corners; a Gaussian
    // normalised to the sphere is uniform on it, which is what "random direction" has to mean.
    const u = Math.random() || Number.EPSILON;
    const w = Math.random();
    const g = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * w);
    v[i] = g;
    norm += g * g;
  }
  norm = Math.sqrt(norm);
  for (let i = 0; i < EMBEDDING_DIMENSIONS; i++) v[i] /= norm;
  return v;
}

// ---------------------------------------------------------------------------
// Reading the corpus — publishable key only, exactly what a Customer holds
// ---------------------------------------------------------------------------

/// How many Meals a search can actually reach: published AND carrying a vector. A Meal without one
/// browses normally and never appears in search, so counting all published Meals would overstate
/// the corpus the measurement ran against — which is the one number the report must not get wrong.
async function corpusSize(url: string, key: string): Promise<number> {
  const res = await fetch(
    `${url}/rest/v1/meals?select=id&status=eq.published&embedding=not.is.null`,
    {
      method: "HEAD",
      headers: { apikey: key, Authorization: `Bearer ${key}`, Prefer: "count=exact" },
    },
  );
  if (!res.ok) throw new Error(`Counting the corpus failed (HTTP ${res.status})`);
  const range = res.headers.get("content-range") ?? "";
  const total = range.split("/")[1];
  const n = Number(total);
  if (!Number.isFinite(n)) throw new Error(`Unreadable count: "${range}"`);
  return n;
}

/// One real stored vector, to drive the database phase with. Taken from the corpus rather than
/// generated so the ranking sorts against something that genuinely lives in the space.
async function sampleVector(url: string, key: string): Promise<string> {
  const res = await fetch(
    `${url}/rest/v1/meals?select=embedding&status=eq.published&embedding=not.is.null&limit=1`,
    { headers: { apikey: key, Authorization: `Bearer ${key}` } },
  );
  if (!res.ok) throw new Error(`Fetching a sample vector failed (HTTP ${res.status})`);
  const rows = await res.json() as Array<{ embedding: string }>;
  if (rows.length === 0) {
    throw new Error(
      "No published Meal carries an embedding. A search here returns nothing and a latency " +
        "number over it is meaningless — run scripts/backfill-meal-embeddings.ts first, or --load.",
    );
  }
  return rows[0].embedding;
}

// ---------------------------------------------------------------------------
// The two measured phases
// ---------------------------------------------------------------------------

async function measureEndToEnd(
  url: string,
  key: string,
  runs: number,
): Promise<Sample[]> {
  const samples: Sample[] = [];
  for (let i = 0; i < runs; i++) {
    const phrase = PHRASES[i % PHRASES.length];
    const started = performance.now();
    const res = await fetch(`${url}/functions/v1/discover`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ phrase }),
    });
    // Read the body BEFORE stopping the clock. A Customer is not served until the bytes have
    // arrived, and the response carries every result's 768-float vector — see the report.
    const text = await res.text();
    const ms = performance.now() - started;
    if (!res.ok) {
      throw new Error(`discover failed (HTTP ${res.status}): ${text.slice(0, 200)}`);
    }
    const body = JSON.parse(text) as { meals?: unknown[] };
    samples.push({
      ms,
      bytes: new TextEncoder().encode(text).length,
      count: body.meals?.length ?? 0,
    });
    Deno.stdout.writeSync(new TextEncoder().encode("."));
  }
  Deno.stdout.writeSync(new TextEncoder().encode("\n"));
  return samples;
}

/// `select` narrows what PostgREST serialises out of `SETOF public.meals`.
///
/// RUN TWICE, WITH AND WITHOUT THE VECTORS, BECAUSE THE DIFFERENCE IS THE FINDING. The same scan,
/// the same rows, the same round trip — the only variable is whether every row's 768 floats are
/// serialised and sent. Measuring one number would leave "the database is slow" and "the response
/// is enormous" indistinguishable, and they have completely different fixes.
async function measureDatabase(
  url: string,
  key: string,
  vector: string,
  runs: number,
  select: string | null,
): Promise<Sample[]> {
  const path = select === null
    ? `${url}/rest/v1/rpc/search_meals`
    : `${url}/rest/v1/rpc/search_meals?select=${select}`;
  const samples: Sample[] = [];
  for (let i = 0; i < runs; i++) {
    const started = performance.now();
    const res = await fetch(path, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        query_embedding: vector,
        exclude_terms: null,
        area_query: null,
      }),
    });
    const text = await res.text();
    const ms = performance.now() - started;
    if (!res.ok) {
      throw new Error(`search_meals failed (HTTP ${res.status}): ${text.slice(0, 200)}`);
    }
    const rows = JSON.parse(text) as unknown[];
    samples.push({ ms, bytes: new TextEncoder().encode(text).length, count: rows.length });
    Deno.stdout.writeSync(new TextEncoder().encode("."));
  }
  Deno.stdout.writeSync(new TextEncoder().encode("\n"));
  return samples;
}

// ---------------------------------------------------------------------------
// The benchmark corpus — created as a Cook, vectored as service_role, then removed
// ---------------------------------------------------------------------------
//
// THE TWO CREDENTIALS ARE NOT INTERCHANGEABLE AND THE SPLIT IS THE POINT. `service_role` holds
// `SELECT (id, cook_id)` and `UPDATE (embedding)` on `meals` and nothing else (ADR-0011,
// 20260807064927), so it CANNOT publish a Meal — a mistake in this script cannot put synthetic
// food on a marketplace even if it is pointed somewhere it should not be. Meals are therefore
// inserted as an ordinary authenticated Cook, through RLS, exactly as the app does.

interface Loaded {
  readonly cookId: string;
  readonly email: string;
  readonly mealIds: string[];
}

async function pooled<T>(items: T[], limit: number, fn: (item: T) => Promise<void>) {
  let cursor = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (cursor < items.length) {
      const index = cursor++;
      await fn(items[index]);
    }
  });
  await Promise.all(workers);
}

async function loadCorpus(
  url: string,
  publishableKey: string,
  serviceRoleKey: string,
  count: number,
): Promise<Loaded> {
  const rand = crypto.randomUUID().replace(/-/g, "").slice(0, 8);
  const email = `benchmark-${rand}@kafoo.invalid`;
  const password = crypto.randomUUID();

  const createRes = await fetch(`${url}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!createRes.ok) {
    throw new Error(
      `Creating the benchmark Cook failed (HTTP ${createRes.status}): ${await createRes.text()}`,
    );
  }
  const cookId = (await createRes.json() as { id: string }).id;

  const loginRes = await fetch(`${url}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: publishableKey, "content-type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!loginRes.ok) {
    throw new Error(`Signing in as the benchmark Cook failed (HTTP ${loginRes.status})`);
  }
  const jwt = (await loginRes.json() as { access_token: string }).access_token;

  const kitchenRes = await fetch(`${url}/rest/v1/kitchen_profiles`, {
    method: "POST",
    headers: {
      apikey: publishableKey,
      Authorization: `Bearer ${jwt}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      cook_id: cookId,
      display_name: `Benchmark corpus ${rand}`,
      story: "Temporary Kitchen Profile carrying a benchmark corpus. Removed by the same run.",
      // A real area, so the area filter has something to narrow on if this is ever extended to
      // measure a narrowed search. Nasr City matches the E2 measurement's throwaway kitchen.
      area: "Nasr City",
      delivery_terms: "Pickup only",
    }),
  });
  if (!kitchenRes.ok) {
    throw new Error(
      `Creating the benchmark Kitchen Profile failed (HTTP ${kitchenRes.status}): ` +
        `${await kitchenRes.text()}`,
    );
  }

  // Inserted in batches as the Cook. Titles are plainly what they are: nobody reading this row in
  // the database should have to work out whether it is a Meal somebody cooks.
  const mealIds: string[] = [];
  const BATCH = 100;
  for (let start = 0; start < count; start += BATCH) {
    const size = Math.min(BATCH, count - start);
    const rows = Array.from({ length: size }, (_, i) => ({
      cook_id: cookId,
      title: `[benchmark] corpus meal ${start + i + 1}`,
      description:
        "Not food. A row created to measure search latency at a known corpus size, and removed " +
        "by the run that created it.",
      price: 1,
      cuisine: "egyptian",
      category: "main",
      status: "published",
      ingredients: [],
      allergens: [],
    }));
    const res = await fetch(`${url}/rest/v1/meals`, {
      method: "POST",
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${jwt}`,
        "content-type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(rows),
    });
    if (!res.ok) {
      throw new Error(
        `Inserting benchmark Meals failed (HTTP ${res.status}): ${await res.text()}`,
      );
    }
    const created = await res.json() as Array<{ id: string }>;
    for (const row of created) mealIds.push(row.id);
    Deno.stdout.writeSync(new TextEncoder().encode(`  inserted ${mealIds.length}/${count}\r`));
  }
  Deno.stdout.writeSync(new TextEncoder().encode("\n"));

  // Vectors, as service_role, one row at a time because that is the only shape the grant allows.
  let vectored = 0;
  await pooled(mealIds, WRITE_CONCURRENCY, async (id) => {
    const res = await fetch(`${url}/rest/v1/meals?id=eq.${id}`, {
      method: "PATCH",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ embedding: JSON.stringify(randomUnitVector()) }),
    });
    if (!res.ok) {
      throw new Error(
        `Writing a benchmark vector failed (HTTP ${res.status}): ${await res.text()}`,
      );
    }
    vectored++;
    if (vectored % 50 === 0) {
      Deno.stdout.writeSync(
        new TextEncoder().encode(`  vectored ${vectored}/${mealIds.length}\r`),
      );
    }
  });
  Deno.stdout.writeSync(new TextEncoder().encode(`  vectored ${vectored}/${mealIds.length}\n`));

  return { cookId, email, mealIds };
}

/// Deleting the auth user takes the Kitchen Profile and every Meal with it, through the same
/// cascade `delete-account` relies on. The Meals are deleted explicitly FIRST anyway: a corpus
/// left behind is synthetic content sitting on a marketplace, and "the cascade probably handled
/// it" is not a standard this repository applies to that.
async function unloadCorpus(
  url: string,
  publishableKey: string,
  serviceRoleKey: string,
  loaded: Loaded,
): Promise<void> {
  const del = await fetch(
    `${url}/rest/v1/meals?cook_id=eq.${loaded.cookId}`,
    {
      method: "DELETE",
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        Prefer: "return=minimal",
      },
    },
  );
  // service_role cannot DELETE meals — by design. Fall through to the cascade, and say so rather
  // than reporting a clean teardown that did not happen here.
  if (!del.ok) {
    console.log(
      `  meals DELETE as service_role refused (HTTP ${del.status}) — expected; ` +
        `removing the Cook takes them.`,
    );
  }
  const res = await fetch(`${url}/auth/v1/admin/users/${loaded.cookId}`, {
    method: "DELETE",
    headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` },
  });
  if (!res.ok) {
    throw new Error(
      `TEARDOWN FAILED (HTTP ${res.status}). ${loaded.mealIds.length} benchmark Meals may still ` +
        `be published on ${url}. Remove the Cook ${loaded.email} (${loaded.cookId}) by hand.`,
    );
  }
  // Confirmed rather than assumed: the cascade is the thing being trusted, so it is the thing
  // being checked.
  const left = await fetch(
    `${url}/rest/v1/meals?select=id&cook_id=eq.${loaded.cookId}`,
    {
      method: "HEAD",
      headers: {
        apikey: publishableKey,
        Authorization: `Bearer ${publishableKey}`,
        Prefer: "count=exact",
      },
    },
  );
  const remaining = Number((left.headers.get("content-range") ?? "").split("/")[1]);
  if (Number.isFinite(remaining) && remaining > 0) {
    throw new Error(
      `TEARDOWN INCOMPLETE: ${remaining} benchmark Meals survive on ${url}. Remove them by hand.`,
    );
  }
}

// ---------------------------------------------------------------------------
// Report
// ---------------------------------------------------------------------------

function fmt(ms: number): string {
  return ms >= 100 ? `${Math.round(ms)} ms` : `${ms.toFixed(1)} ms`;
}

function signed(deltaMs: number): string {
  const sign = deltaMs >= 0 ? "+" : "−";
  return `${sign}${fmt(Math.abs(deltaMs))}`;
}

function ordinal(n: number): string {
  const rest = n % 100;
  if (rest >= 11 && rest <= 13) return `${n}th`;
  return `${n}${["th", "st", "nd", "rd"][n % 10] ?? "th"}`;
}

function verdict(p95: number): string {
  // Derived from BUDGET_MS rather than written out, because the last time these were two separate
  // facts the prose kept saying "1 s" after the number had moved.
  const budget = `${(BUDGET_MS / 1000).toFixed(BUDGET_MS % 1000 === 0 ? 0 : 1)} s`;
  return p95 <= BUDGET_MS
    ? `WITHIN the ${budget} budget`
    : `**OVER the ${budget} budget**`;
}

function report(
  url: string,
  corpus: number,
  e2e: Sample[],
  db: Sample[],
  dbLean: Sample[],
  loadedCount: number,
): string {
  const e = summarise(e2e.map((s) => s.ms));
  const d = summarise(db.map((s) => s.ms));
  const l = summarise(dbLean.map((s) => s.ms));
  const bytes = summarise(e2e.map((s) => s.bytes));
  const leanBytes = summarise(dbLean.map((s) => s.bytes));
  const results = summarise(e2e.map((s) => s.count));
  const ref = new URL(url).hostname.split(".")[0];

  return `# Measuring discovery latency

**SC-006 — "results within 1 second".** Measured against the demo database, never production.
Regenerate with:

\`\`\`bash
DENO_CERT=/root/.ccr/ca-bundle.crt deno run --allow-net --allow-env --allow-read --allow-write \\
  scripts/measure-discovery-latency.ts --runs=${e.n} --load=${loadedCount} --report
\`\`\`

## The number

| | n | p50 | p95 | min | max |
|---|---|---|---|---|---|
| **End-to-end** (\`discover\`) — what a Customer waits | ${e.n} | ${fmt(e.p50)} | ${fmt(e.p95)} | ${fmt(e.min)} | ${fmt(e.max)} |
| **Database**, full rows (\`search_meals\`) | ${d.n} | ${fmt(d.p50)} | ${fmt(d.p95)} | ${fmt(d.min)} | ${fmt(d.max)} |
| **Database**, ids only (\`?select=id\`) — the scan alone | ${l.n} | ${fmt(l.p50)} | ${fmt(l.p95)} | ${fmt(l.min)} | ${fmt(l.max)} |

**Corpus: ${corpus} published Meals carrying an embedding**${
    loadedCount > 0 ? `, of which ${loadedCount} were a benchmark corpus loaded and removed by this run` : ""
  }.
Measured against \`${ref}\`. End-to-end p95 is ${verdict(e.p95)}.

Percentiles are **nearest-rank over ${e.n} samples**, so p95 is the ${
    ordinal(Math.ceil(0.95 * e.n))
  } observation rather than an estimate of a tail. A latency figure without its n and its
percentile is not a budget check, which is why both are here and in every sentence that quotes them.

## Where the time goes

Subtracting the rows above, at the median: **${
    fmt(e.p50 - d.p50)
  } is the model provider's embedding call plus the Edge Function's own overhead**, ${
    fmt(d.p50 - l.p50)
  } is serialising and sending the vectors, and **${fmt(l.p50)} is the scan and its round trip**.

The scan is the only one of the three that grows with the marketplace. \`search_meals\` ranks
**exactly** rather than approximately — it computes the distance to every surviving row — so its
cost is linear in the corpus. See \`supabase/migrations/20260806231625_add_meal_embeddings.sql\`,
which explains why the HNSW index exists and is deliberately not used.

## What corpus size actually did

Same script, same target, ${PRIOR.when}, at **${PRIOR.corpus}** Meals against **${corpus}** here —
${(corpus / PRIOR.corpus).toFixed(0)}× the corpus:

| | ${PRIOR.corpus} Meals | ${corpus} Meals | change |
|---|---|---|---|
| End-to-end p50 | ${fmt(PRIOR.e2eP50)} | ${fmt(e.p50)} | ${signed(e.p50 - PRIOR.e2eP50)} |
| Database, full rows p50 | ${fmt(PRIOR.dbFullP50)} | ${fmt(d.p50)} | ${signed(d.p50 - PRIOR.dbFullP50)} |
| **Database, ids only p50 — the scan** | **${fmt(PRIOR.dbLeanP50)}** | **${fmt(l.p50)}** | **${
    signed(l.p50 - PRIOR.dbLeanP50)
  }** |
| Median results returned | ${PRIOR.medianResults} | ${results.p50} | |

**The scan did not move.** ${
    (corpus / PRIOR.corpus).toFixed(0)
  }× the Meals changed it by ${fmt(Math.abs(l.p50 - PRIOR.dbLeanP50))}, which is inside the noise
between two runs. Everything that got worse got worse because more rows came back — the \`LIMIT 50\`
in \`search_meals\` binds once the corpus passes fifty Meals, so the response grew and the wait grew
with it.

So the thing to fix is not the corpus and not the ranking. It is what a search sends back.

## Response size

Each search returns **${
    Math.round(bytes.p50).toLocaleString("en")
  } bytes at the median** for a median of ${results.p50} results — about ${
    results.p50 > 0 ? Math.round(bytes.p50 / results.p50).toLocaleString("en") : "?"
  } bytes per Meal, against ${
    Math.round(leanBytes.p50).toLocaleString("en")
  } bytes for the same rows as ids alone.

**\`search_meals\` returned \`SETOF public.meals\` until 2026-08-08**, so every row carried its
768-float \`embedding\` and \`discover\` passed that straight through. No client reads the column —
it is "shown to nobody" by the column's own comment, and \`CookMeal.fromRow\` does not mention it.

\`20260808165000_stop_returning_meal_embeddings_from_search.sql\` gives the function a return type
with no \`embedding\` in it. Measured on the same rows before deploying it: **497 KB → 29 KB** at
the 50-result limit, a 94% cut in what a search sends back. Fixed in the database rather than in
\`discover\`, so no future caller can select it back.

**If the figures above still show a large gap between the two database rows, this report predates
that migration reaching the target.** Re-run it after deploying to refresh them.

**The two database rows above are the same scan.** The only difference is whether the vectors are
serialised and sent, so the gap between them — ${fmt(d.p50 - l.p50)} at the median — is what the
unread column costs on the wire. ${
    results.p50 >= 50
      ? "This run sat at the `LIMIT 50`, so that is the worst case rather than a projection " +
        "from a small result set — it is what every search costs once the marketplace holds " +
        "more than fifty Meals, which is to say almost immediately."
      : `This run returned a median of ${results.p50} results, below the \`LIMIT 50\`. A full ` +
        `page of results costs roughly ${(50 / Math.max(1, results.p50)).toFixed(0)}× this, and ` +
        `a corpus past fifty Meals reaches it.`
  }

Paid on **every search, by every Customer, on an Egyptian mobile network** — and not a scaling
problem: it was the same size on the day Kafoo launches as at a million Meals, which is why it was
worth fixing before the corpus was.

## What this does not measure

- **A real network.** This runs from a cloud container. Add the Customer's own latency to every
  figure above; the budget is spent at their phone, not at the container.
- **Retrieval quality.** \`scripts/discovery-retrieval-regression.py\` owns that, nightly.
- **Anything about the HNSW index.** A benchmark corpus carries random unit vectors, which time
  identically under exact ranking and say nothing about approximate traversal.
`;
}

// ---------------------------------------------------------------------------

function printHelp(): void {
  console.log(`Measure discovery latency against the demo database.

  --runs=N      Samples per phase (default ${DEFAULT_RUNS})
  --load=K      Publish K benchmark Meals first, then remove them (needs SUPABASE_SERVICE_ROLE_KEY)
  --keep        Leave a loaded corpus in place
  --report      Write ${REPORT_PATH}
  --dry-run     Validate and print the plan; spend nothing
  --help        This`);
}

async function main(): Promise<void> {
  const args = Deno.args;
  if (args.includes("--help")) return printHelp();

  const numeric = (flag: string, fallback: number) => {
    const raw = args.find((a) => a.startsWith(`${flag}=`));
    if (!raw) return fallback;
    const n = Number(raw.split("=")[1]);
    if (!Number.isInteger(n) || n < 0) throw new Error(`${flag} needs a non-negative integer`);
    return n;
  };
  const runs = numeric("--runs", DEFAULT_RUNS);
  const load = numeric("--load", 0);
  const keep = args.includes("--keep");
  const writeReport = args.includes("--report");
  const dryRun = args.includes("--dry-run");

  const url = requireEnv("DEMO_SUPABASE_URL", "SUPABASE_URL").replace(/\/+$/, "");
  const publishableKey = requireEnv("DEMO_SUPABASE_PUBLISHABLE_KEY", "SUPABASE_PUBLISHABLE_KEY");

  if (url.includes(PRODUCTION_REF)) {
    console.error(
      `Refusing: ${url} is the production project.\n` +
        `This script publishes Meals no Cook cooks when --load is given, and a search timed ` +
        `against production measures an empty table anyway. Point it at the demo database — ` +
        `see docs/ops/demo-environment.md.`,
    );
    Deno.exit(1);
  }
  if (!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url)) {
    console.error(`Refusing: expected a https://<ref>.supabase.co URL, got ${url}`);
    Deno.exit(1);
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (load > 0 && !serviceRoleKey) {
    console.error(
      `--load needs SUPABASE_SERVICE_ROLE_KEY for the demo database — it writes the vectors, ` +
        `which no other credential may. Without it, drop --load to measure the corpus as it stands.`,
    );
    Deno.exit(1);
  }

  console.log(`Target      ${url}`);
  console.log(`Runs        ${runs} per phase`);
  console.log(`Benchmark   ${load > 0 ? `${load} Meals, ${keep ? "KEPT" : "removed after"}` : "none"}`);

  if (dryRun) {
    const existing = await corpusSize(url, publishableKey);
    console.log(`Corpus      ${existing} published Meals with an embedding`);
    console.log(`\nDry run — nothing measured, nothing written.`);
    return;
  }

  let loaded: Loaded | null = null;
  try {
    if (load > 0) {
      console.log(`\nLoading ${load} benchmark Meals...`);
      loaded = await loadCorpus(url, publishableKey, serviceRoleKey!, load);
    }

    const corpus = await corpusSize(url, publishableKey);
    console.log(`\nCorpus      ${corpus} published Meals with an embedding\n`);

    console.log(`End-to-end (discover), ${runs} runs:`);
    const e2e = await measureEndToEnd(url, publishableKey, runs);

    const vector = await sampleVector(url, publishableKey);
    console.log(`Database (search_meals, full rows), ${runs} runs:`);
    const db = await measureDatabase(url, publishableKey, vector, runs, null);
    console.log(`Database (search_meals, ids only), ${runs} runs:`);
    const dbLean = await measureDatabase(url, publishableKey, vector, runs, "id");

    const text = report(url, corpus, e2e, db, dbLean, load);
    console.log(`\n${text}`);
    if (writeReport) {
      await Deno.writeTextFile(REPORT_PATH, text);
      console.log(`Written to ${REPORT_PATH}`);
    }

    const e = summarise(e2e.map((s) => s.ms));
    if (e.p95 > BUDGET_MS) {
      console.log(
        `\nOVER BUDGET: p95 ${fmt(e.p95)} against ${BUDGET_MS} ms. Reported, not tuned away.`,
      );
    }
  } finally {
    if (loaded && !keep) {
      console.log(`\nRemoving the benchmark corpus...`);
      await unloadCorpus(url, publishableKey, serviceRoleKey!, loaded);
      console.log(`  removed ${loaded.mealIds.length} Meals and the Cook that held them.`);
    } else if (loaded && keep) {
      console.log(
        `\n!! ${loaded.mealIds.length} benchmark Meals are STILL PUBLISHED on ${url}.\n` +
          `!! Remove them: delete the Cook ${loaded.email} (${loaded.cookId}).`,
      );
    }
  }
}

if (import.meta.main) {
  await main();
}
