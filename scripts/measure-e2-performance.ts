// Measure Kafoo's two E2 performance numbers and the per-Meal model cost.
//
// Three numbers that were estimates must become measurements:
//
//   1. description-finished → first estimate  (budget 2 s)
//      One HTTPS round trip to the deployed analyze-meal Edge Function.
//      This is what a Cook waits after describing their Meal.
//
//   2. confirm → on-offer  (budget 3 s)
//      One PostgREST PATCH that sets the Meal's status to published.
//      This is what a Cook waits between tapping "publish" and seeing the Meal on offer.
//
//      OFF BY DEFAULT, AND REFUSED OUTRIGHT AGAINST PRODUCTION. See `resolvePhases`: this phase
//      creates a *published* Meal, and a published Meal that no Cook cooks is synthetic content on
//      a real marketplace — `.claude/rules/business-rules.md` calls that product-fatal. Running
//      this script against production was approved on 2026-08-05 on exactly one condition, that
//      nothing it creates is ever discoverable, which holds only while every Meal stays a draft.
//      The figure is already measured on a preview branch and carried forward in the report.
//
//   3. model cost of one published Meal
//      Input and output tokens per analysis, so a dollar figure per Meal can be computed.
//      A Meal published with a photo costs two analyses (the second carries the image).
//
// This script creates a throwaway Cook on the live Supabase project, runs the measurements,
// tears the Cook and every test Meal down, and writes a report to docs/ops/measuring-e2.md.
//
// What it proves: the wall-clock latency a real Cook pays, including Row Level Security,
// and the token cost the project will incur once it moves off the free tier.
//
// What it does not prove: latency from an Egyptian mobile network (runs from a cloud container),
// Flutter widget-rebuild time after the reply arrives, or the cost of models other than the
// fast tier.
//
//   DENO_CERT=/root/.ccr/ca-bundle.crt deno run \
//     --allow-net --allow-env --allow-read --allow-write scripts/measure-e2-performance.ts
//
// Phases are selected with --phases=<list>, default `latency,cost`. `publish` must be asked for by
// name and cannot be granted against production at all.
//
// RATE LIMIT: the free tier allows 15 requests per minute on the fast-tier model. Every
// model-touching call is spaced by SPACING_MS below.

import { resolveProvider } from "../supabase/functions/_shared/ai/registry.ts";
import { PROMPTS } from "../supabase/functions/_shared/prompts.ts";
import { MEAL_ANALYSIS_SCHEMA } from "../supabase/functions/analyze-meal/schema.ts";
import type {
  ModelImage,
  ModelRequest,
} from "../supabase/functions/_shared/ai/types.ts";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const SPACING_MS = 4500;
const DEFAULT_RUNS = 12;
const REPORT_PATH = "docs/ops/measuring-e2.md";
const GOLDENS_DIR = "packages/ai/test/goldens/meal_analysis";
const INPUT_RATE_PER_M = 0.25;
const OUTPUT_RATE_PER_M = 1.50;
const PROMPT_ID = "meal-analysis";
const MAX_TOKENS = 2048;

/// The confirm → on-offer measurement this script no longer re-runs.
///
/// Measured on 2026-08-05 against the pull request's Supabase preview branch — a real Supabase with
/// real Auth, real PostgREST and real Edge Functions, colder than production and otherwise the same
/// stack. It is carried forward rather than re-measured because the phase that produces it is
/// refused against production; see `resolvePhases`. Reported as measured elsewhere, never as a
/// production number.
const PRIOR_PUBLISH = {
  runs: 12,
  medianMs: 189.5,
  minMs: 179,
  maxMs: 420,
  meanMs: 224.9,
  budgetMs: 3000,
  measuredOn: "2026-08-05",
  where: "a Supabase preview branch, not production",
} as const;

/// The composite estimate the description-finished → first estimate measurement replaces.
///
/// Recorded in docs/ops/measuring-e2.md on 2026-08-05, when the analysis phase could not run: all
/// twelve calls returned HTTP 502 `provider_misconfigured`, because Supabase does not copy a parent
/// project's secrets into a preview branch and `analyze-meal` therefore had no model credential
/// there. Each part below was measured. They were never measured together, and a sum of three
/// medians is not a median of the sum — which is the whole reason this comparison is worth
/// printing rather than quietly dropping.
const PRIOR_ESTIMATE = {
  persistMs: 220, //           12 runs, preview branch
  edgeBeforeModelMs: 740, //   12 runs, the failed calls' own timings
  modelCallMs: 1397, //         8 runs, this container straight to the provider
  composedMs: 2357, //         220 + 740 + 1397
  verdict: "misses the 2000 ms budget",
} as const;

// ---------------------------------------------------------------------------
// Interfaces
// ---------------------------------------------------------------------------

interface Fixture {
  readonly file: string;
  readonly name: string;
  readonly kind: string;
  readonly said: string;
}

interface AnalysisRun {
  readonly run: number;
  readonly fixture: string;

  /// Persisting the description. Part of the Cook's wait, not a setup step:
  /// MealConversationController.answer() awaits _persistAnswer and only calls
  /// _startAnalysis once it succeeds, so this round trip happens before the
  /// analysis is even requested.
  readonly persistMs: number;

  /// The analyze-meal round trip on its own.
  readonly analyzeMs: number;

  /// persistMs + analyzeMs — the span the 2-second budget is about.
  readonly elapsedMs: number;
  readonly status: number;
  readonly responseType: string;
  readonly errorCode: string | null;
}

interface PublishRun {
  readonly run: number;
  readonly mealId: string;
  readonly elapsedMs: number;
  readonly status: number;
}

interface TokenUsage {
  readonly fixture: string;
  readonly promptTokens: number | null;
  readonly outputTokens: number | null;
  readonly thinkingTokens: number | null;
  readonly totalTokens: number | null;
  readonly elapsedMs: number;
  readonly rawUsage: Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

function loadFixtures(): Fixture[] {
  const files = [...Deno.readDirSync(GOLDENS_DIR)]
    .filter((e) => e.isFile && e.name.endsWith(".json"))
    .map((e) => e.name)
    .sort();
  if (files.length === 0) throw new Error(`no fixtures in ${GOLDENS_DIR}`);
  return files.map((file) => {
    const raw = JSON.parse(Deno.readTextFileSync(`${GOLDENS_DIR}/${file}`));
    return {
      file,
      name: raw.name as string,
      kind: raw.kind as string,
      said: raw.said as string,
    };
  });
}

function usableFixtures(fixtures: Fixture[]): Fixture[] {
  // empty_garbage has kind "empty" and its said is deliberate noise — not a real Cook description.
  // It is included in Phase 3 (cost measurement) but excluded from Phase 1 (E2 latency).
  return fixtures.filter((f) => f.kind !== "empty");
}

// ---------------------------------------------------------------------------
// Stats helpers
// ---------------------------------------------------------------------------

/// Signed difference from an estimate to a measurement, in ms and as a share of the estimate.
/// Signed on purpose: "412 ms" leaves the reader to work out which way an estimate was wrong.
function signedDelta(estimate: number, measured: number): string {
  const diff = measured - estimate;
  const sign = diff >= 0 ? "+" : "−";
  const pct = estimate === 0 ? 0 : (diff / estimate) * 100;
  return `${sign}${Math.abs(diff).toFixed(1)} ms (${sign}${
    Math.abs(pct).toFixed(1)
  }%)`;
}

function stats(
  values: number[],
): { min: number; max: number; mean: number; median: number } {
  if (values.length === 0) return { min: 0, max: 0, mean: 0, median: 0 };
  const sorted = [...values].sort((a, b) => a - b);
  const min = sorted[0];
  const max = sorted[sorted.length - 1];
  const mean = sorted.reduce((s, v) => s + v, 0) / sorted.length;
  const mid = Math.floor(sorted.length / 2);
  const median = sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
  return { min, max, mean, median };
}

// ---------------------------------------------------------------------------
// A valid image of known dimensions, for measuring image input cost
//
// PNG rather than JPEG, and that is a deliberate substitution worth knowing about. The Cook's app
// uploads JPEG (`photo_picker.dart`: maxWidth 1600, imageQuality 85), and the first version of this
// hand-rolled a baseline JPEG encoder — 330 lines of Huffman bit-packing that the provider then
// rejected with "Unable to process input image". Debugging a bespoke encoder is not what this
// script is for.
//
// PNG is correct by construction here because the platform supplies the hard part: DEFLATE comes
// from CompressionStream, and the rest is four length-prefixed chunks and a CRC.
//
// THE ASSUMPTION THIS CARRIES: the provider counts image tokens from the decoded dimensions, not
// from the encoded bytes, so a 1600×1200 PNG and a 1600×1200 JPEG cost the same input tokens. That
// is stated in the report as an assumption rather than a measurement, because this script did not
// measure a JPEG. If it ever matters to a decision, upload one real photo through the app and
// compare — do not refine the guess.
//
// The image is a flat colour. Token cost is a function of dimensions, and Kafoo's rules forbid
// synthetic food imagery, so a grey rectangle is both sufficient and the only defensible choice.
// ---------------------------------------------------------------------------

function crc32(bytes: Uint8Array): number {
  let crc = 0xFFFFFFFF;
  for (const b of bytes) {
    crc ^= b;
    for (let k = 0; k < 8; k++) {
      crc = crc & 1 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

function u32(value: number): Uint8Array {
  return new Uint8Array([
    (value >>> 24) & 0xFF,
    (value >>> 16) & 0xFF,
    (value >>> 8) & 0xFF,
    value & 0xFF,
  ]);
}

function pngChunk(type: string, data: Uint8Array): Uint8Array {
  const typeBytes = new TextEncoder().encode(type);
  const body = new Uint8Array(typeBytes.length + data.length);
  body.set(typeBytes, 0);
  body.set(data, typeBytes.length);
  const out = new Uint8Array(4 + body.length + 4);
  out.set(u32(data.length), 0);
  out.set(body, 4);
  out.set(u32(crc32(body)), 4 + body.length);
  return out;
}

async function deflate(raw: Uint8Array): Promise<Uint8Array> {
  const source = new ReadableStream<Uint8Array<ArrayBuffer>>({
    start(controller) {
      controller.enqueue(new Uint8Array(raw));
      controller.close();
    },
  });
  const stream = source.pipeThrough(new CompressionStream("deflate"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// A flat mid-grey PNG of exactly [width] x [height].
async function createSolidGrayPng(
  width: number,
  height: number,
): Promise<Uint8Array> {
  // 8-bit greyscale, one filter byte (0 = None) per scanline.
  const raw = new Uint8Array(height * (1 + width));
  for (let y = 0; y < height; y++) {
    const row = y * (1 + width);
    raw[row] = 0;
    raw.fill(128, row + 1, row + 1 + width);
  }

  const ihdr = new Uint8Array(13);
  ihdr.set(u32(width), 0);
  ihdr.set(u32(height), 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 0; // colour type 0 = greyscale
  ihdr[10] = 0; // deflate
  ihdr[11] = 0; // adaptive filtering
  ihdr[12] = 0; // no interlace

  const parts = [
    new Uint8Array([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", await deflate(raw)),
    pngChunk("IEND", new Uint8Array(0)),
  ];
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Phase 0 — create a throwaway Cook
// ---------------------------------------------------------------------------

interface CookCtx {
  readonly userId: string;
  readonly userEmail: string;
  readonly userPassword: string;
  readonly userJwt: string;
}

async function createCook(
  supabaseUrl: string,
  serviceRoleKey: string,
  publishableKey: string,
): Promise<CookCtx> {
  const rand = crypto.randomUUID().replace(/-/g, "").slice(0, 8);
  const email = `measure-${rand}@kafoo.invalid`;
  const password = crypto.randomUUID();

  // Create auth user
  const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      "apikey": serviceRoleKey,
      "Authorization": `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!createRes.ok) {
    const body = await createRes.text();
    throw new Error(
      `Failed to create test Cook (HTTP ${createRes.status}): ${body}`,
    );
  }
  const createBody = await createRes.json() as { id: string };
  const userId = createBody.id;

  // Sign in to get user JWT
  const loginRes = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        "apikey": publishableKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ email, password }),
    },
  );
  if (!loginRes.ok) {
    const body = await loginRes.text();
    throw new Error(
      `Failed to sign in as test Cook (HTTP ${loginRes.status}): ${body}`,
    );
  }
  const loginBody = await loginRes.json() as { access_token: string };
  const userJwt = loginBody.access_token;

  return { userId, userEmail: email, userPassword: password, userJwt };
}

async function createKitchenProfile(
  supabaseUrl: string,
  publishableKey: string,
  userJwt: string,
  userId: string,
): Promise<void> {
  const res = await fetch(`${supabaseUrl}/rest/v1/kitchen_profiles`, {
    method: "POST",
    headers: {
      "apikey": publishableKey,
      "Authorization": `Bearer ${userJwt}`,
      "Content-Type": "application/json",
      "Prefer": "return=representation",
    },
    body: JSON.stringify({
      cook_id: userId,
      display_name: "Measurement Kitchen",
      story: "Temporary Kitchen Profile for performance measurement.",
      area: "Nasr City",
      delivery_terms: "Pickup only",
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(
      `Failed to create Kitchen Profile (HTTP ${res.status}): ${body}`,
    );
  }
}

// ---------------------------------------------------------------------------
// Phase 1 — description-finished to first estimate
// ---------------------------------------------------------------------------

async function runAnalysisPhase(
  supabaseUrl: string,
  publishableKey: string,
  userJwt: string,
  userId: string,
  fixtures: Fixture[],
  runs: number,
): Promise<AnalysisRun[]> {
  const results: AnalysisRun[] = [];
  const prompt = PROMPTS[PROMPT_ID];
  if (!prompt) throw new Error(`prompt ${PROMPT_ID} missing`);

  for (let i = 0; i < runs; i++) {
    if (i > 0) await new Promise((r) => setTimeout(r, SPACING_MS));

    const fixture = fixtures[i % fixtures.length];

    // Create a draft Meal (not timed)
    const draftRes = await fetch(`${supabaseUrl}/rest/v1/meals`, {
      method: "POST",
      headers: {
        "apikey": publishableKey,
        "Authorization": `Bearer ${userJwt}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
        "Accept": "application/vnd.pgrst.object+json",
      },
      body: JSON.stringify({
        cook_id: userId,
        title: fixture.name,
        status: "draft",
      }),
    });
    if (!draftRes.ok) {
      const body = await draftRes.text();
      throw new Error(
        `Failed to create draft Meal (HTTP ${draftRes.status}): ${body}`,
      );
    }
    const draftBody = await draftRes.json() as { id: string };
    const mealId = draftBody.id;

    // TIMED, and this is where the Cook's wait actually begins.
    //
    // It looks like setup and it is not. `MealConversationController.answer()` awaits
    // `_persistAnswer` and only calls `_startAnalysis` after it succeeds, so a Cook who has just
    // finished describing their Meal waits for this round trip and then for the analysis. Timing
    // only the second half would report a number no Cook experiences.
    const tPersist = performance.now();
    const descRes = await fetch(
      `${supabaseUrl}/rest/v1/meals?id=eq.${mealId}`,
      {
        method: "PATCH",
        headers: {
          "apikey": publishableKey,
          "Authorization": `Bearer ${userJwt}`,
          "Content-Type": "application/json",
          "Prefer": "return=representation",
          "Accept": "application/vnd.pgrst.object+json",
        },
        body: JSON.stringify({ description: fixture.said }),
      },
    );
    const descBody = await descRes.text();
    const persistMs = Math.round(performance.now() - tPersist);
    if (!descRes.ok) {
      throw new Error(
        `Failed to update draft Meal (HTTP ${descRes.status}): ${descBody}`,
      );
    }

    // TIMED: call analyze-meal
    const t0 = performance.now();
    const analyzeRes = await fetch(`${supabaseUrl}/functions/v1/analyze-meal`, {
      method: "POST",
      headers: {
        "apikey": publishableKey,
        "Authorization": `Bearer ${userJwt}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ said: fixture.said, meal_id: mealId }),
    });
    const bodyText = await analyzeRes.text();
    const analyzeMs = Math.round(performance.now() - t0);
    const elapsed = persistMs + analyzeMs;

    // Parse SSE frame
    let responseType = "unknown";
    let errorCode: string | null = null;
    // A failure detected BEFORE the provider is called (auth, validation, ownership, a missing
    // provider credential) is an ordinary status code with a plain JSON body — index.ts only opens
    // a stream once the provider has been reached. Parsing SSE alone left those runs labelled
    // "unknown" with a dash for the error, which is how twelve failed calls once got as far as a
    // PASS verdict in this report.
    const dataMatch = bodyText.match(/^data:\s*(\{.*\})/m);
    if (!dataMatch) {
      try {
        const plain = JSON.parse(bodyText) as Record<string, unknown>;
        if (typeof plain.error === "string") {
          responseType = "error";
          errorCode = plain.error;
        }
      } catch {
        // fall through to the SSE handling below
      }
    }
    if (dataMatch) {
      try {
        const parsed = JSON.parse(dataMatch[1]) as Record<string, unknown>;
        responseType = typeof parsed.type === "string"
          ? parsed.type
          : "unknown";
        if (responseType === "error" && typeof parsed.error === "string") {
          errorCode = parsed.error;
        }
      } catch {
        responseType = "parse_error";
      }
    }

    results.push({
      run: i + 1,
      fixture: fixture.name,
      persistMs,
      analyzeMs,
      elapsedMs: elapsed,
      status: analyzeRes.status,
      responseType,
      errorCode,
    });
    console.error(
      `  Phase 1 run ${i + 1}/${runs}: ${fixture.name} → ${elapsed} ms ` +
        `(persist ${persistMs} + analyze ${analyzeMs}) (${responseType})`,
    );

    // Clean up draft Meal
    await fetch(`${supabaseUrl}/rest/v1/meals?id=eq.${mealId}`, {
      method: "DELETE",
      headers: {
        "apikey": publishableKey,
        "Authorization": `Bearer ${userJwt}`,
      },
    });
  }

  return results;
}

// ---------------------------------------------------------------------------
// Phase 2 — confirm to on-offer
// ---------------------------------------------------------------------------

async function runPublishPhase(
  supabaseUrl: string,
  publishableKey: string,
  userJwt: string,
  userId: string,
  fixtures: Fixture[],
  runs: number,
): Promise<PublishRun[]> {
  const results: PublishRun[] = [];

  for (let i = 0; i < runs; i++) {
    const fixture = fixtures[i % fixtures.length];

    // Create a complete draft Meal (not timed)
    const createRes = await fetch(`${supabaseUrl}/rest/v1/meals`, {
      method: "POST",
      headers: {
        "apikey": publishableKey,
        "Authorization": `Bearer ${userJwt}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
        "Accept": "application/vnd.pgrst.object+json",
      },
      body: JSON.stringify({
        cook_id: userId,
        title: fixture.name,
        description: fixture.said,
        price: "50.00",
        cuisine: "egyptian",
        category: "main",
        status: "draft",
      }),
    });
    if (!createRes.ok) {
      const body = await createRes.text();
      throw new Error(
        `Failed to create complete draft Meal (HTTP ${createRes.status}): ${body}`,
      );
    }
    const createBody = await createRes.json() as { id: string };
    const mealId = createBody.id;

    // TIMED: publish
    const t0 = performance.now();
    const pubRes = await fetch(`${supabaseUrl}/rest/v1/meals?id=eq.${mealId}`, {
      method: "PATCH",
      headers: {
        "apikey": publishableKey,
        "Authorization": `Bearer ${userJwt}`,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
        "Accept": "application/vnd.pgrst.object+json",
      },
      body: JSON.stringify({ status: "published" }),
    });
    await pubRes.text(); // read to completion
    const elapsed = Math.round(performance.now() - t0);

    results.push({
      run: i + 1,
      mealId,
      elapsedMs: elapsed,
      status: pubRes.status,
    });
    console.error(
      `  Phase 2 run ${i + 1}/${runs}: Meal ${
        mealId.slice(0, 8)
      }… → ${elapsed} ms`,
    );
  }

  return results;
}

// ---------------------------------------------------------------------------
// Phase 3 — model cost of one analysis
// ---------------------------------------------------------------------------

interface RawUsageCapture {
  usageMetadata?: Record<string, unknown>;
  usage?: Record<string, unknown>;
}

async function runCostPhase(
  fixtures: Fixture[],
): Promise<TokenUsage[]> {
  const resolved = resolveProvider("fast", (k) => Deno.env.get(k));
  const prompt = PROMPTS[PROMPT_ID];
  if (!prompt) throw new Error(`prompt ${PROMPT_ID} missing`);

  const results: TokenUsage[] = [];
  const captured: RawUsageCapture[] = [];

  // Wrap fetch to capture raw provider response for token usage
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
      const response = await originalFetch(input, init);
      const cloned = response.clone();
      try {
        const json = await cloned.json() as Record<string, unknown>;
        captured.push({
          usageMetadata: json.usageMetadata as
            | Record<string, unknown>
            | undefined,
          usage: json.usage as Record<string, unknown> | undefined,
        });
      } catch {
        captured.push({});
      }
      return response;
    };

    for (let i = 0; i < fixtures.length; i++) {
      if (i > 0) await new Promise((r) => setTimeout(r, SPACING_MS));

      const fixture = fixtures[i];
      const request: ModelRequest = {
        system: prompt.body,
        user: fixture.said,
        model: resolved.model,
        maxTokens: MAX_TOKENS,
        responseSchema: MEAL_ANALYSIS_SCHEMA,
      };

      const t0 = performance.now();
      await resolved.adapter.complete(request, resolved.apiKey);
      const elapsed = Math.round(performance.now() - t0);

      const raw = captured[i] ?? {};
      const usage = raw.usageMetadata ?? raw.usage ?? {};

      // Read token counts defensively — field names vary by provider
      const promptTokens = extractToken(usage, [
        "promptTokenCount",
        "prompt_tokens",
        "input_tokens",
      ]);
      const outputTokens = extractToken(usage, [
        "candidatesTokenCount",
        "completion_tokens",
        "output_tokens",
      ]);
      const thinkingTokens = extractToken(usage, [
        "thoughtsTokenCount",
        "reasoning_tokens",
        "thinking_tokens",
      ]);
      const totalTokens = extractToken(usage, [
        "totalTokenCount",
        "total_tokens",
      ]);

      results.push({
        fixture: fixture.name,
        promptTokens,
        outputTokens,
        thinkingTokens,
        totalTokens,
        elapsedMs: elapsed,
        rawUsage: usage as Record<string, unknown>,
      });
      console.error(
        `  Phase 3 run ${
          i + 1
        }/${fixtures.length}: ${fixture.name} → ${elapsed} ms, ${
          totalTokens ?? "?"
        } tokens`,
      );
    }

    // Image cost: one call carrying a flat-colour image at the dimensions the app uploads.
    //
    // INSIDE the try, so the wrapped fetch is still installed. An earlier version restored the
    // original fetch just above this line, and the image call ran unwrapped: it succeeded, it was
    // timed, and its usage object came back `{}` — a measurement that looked like a result and
    // carried no number. The restore belongs after every call this phase makes, not after the
    // loop.
    console.error(
      "  Phase 3 image call: measuring token cost of a 1600×1200 flat-colour image",
    );
    try {
      const pngBytes = await createSolidGrayPng(1600, 1200);
      // Chunked: String.fromCharCode(...bytes) blows the argument limit on a 1600×1200 image.
      let binary = "";
      const chunk = 0x8000;
      for (let i = 0; i < pngBytes.length; i += chunk) {
        binary += String.fromCharCode(...pngBytes.subarray(i, i + chunk));
      }
      const base64 = btoa(binary);
      const image: ModelImage = { base64, mediaType: "image/png" };

      const imgFixture = fixtures[0]; // use first fixture's text + the image
      const imgRequest: ModelRequest = {
        system: prompt.body,
        user: imgFixture.said,
        image,
        model: resolved.model,
        maxTokens: MAX_TOKENS,
        responseSchema: MEAL_ANALYSIS_SCHEMA,
      };

      captured.length = 0; // reset capture
      const t0 = performance.now();
      await resolved.adapter.complete(imgRequest, resolved.apiKey);
      const elapsed = Math.round(performance.now() - t0);

      const raw = captured[0] ?? {};
      const usage = raw.usageMetadata ?? raw.usage ?? {};
      const promptTokens = extractToken(usage, [
        "promptTokenCount",
        "prompt_tokens",
        "input_tokens",
      ]);
      const outputTokens = extractToken(usage, [
        "candidatesTokenCount",
        "completion_tokens",
        "output_tokens",
      ]);
      const thinkingTokens = extractToken(usage, [
        "thoughtsTokenCount",
        "reasoning_tokens",
        "thinking_tokens",
      ]);
      const totalTokens = extractToken(usage, [
        "totalTokenCount",
        "total_tokens",
      ]);

      results.push({
        fixture: "IMAGE: 1600×1200 solid gray (flat colour, not food)",
        promptTokens,
        outputTokens,
        thinkingTokens,
        totalTokens,
        elapsedMs: elapsed,
        rawUsage: usage as Record<string, unknown>,
      });
      console.error(
        `  Phase 3 image call → ${elapsed} ms, ${totalTokens ?? "?"} tokens`,
      );
    } catch (err) {
      console.error(
        `  Phase 3 image call FAILED: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
      results.push({
        fixture: "IMAGE: 1600×1200 solid gray (flat colour, not food)",
        promptTokens: null,
        outputTokens: null,
        thinkingTokens: null,
        totalTokens: null,
        elapsedMs: 0,
        rawUsage: { error: err instanceof Error ? err.message : String(err) },
      });
    }
  } finally {
    globalThis.fetch = originalFetch;
  }

  return results;
}

function extractToken(
  usage: Record<string, unknown>,
  candidates: string[],
): number | null {
  for (const key of candidates) {
    const val = usage[key];
    if (typeof val === "number" && Number.isFinite(val)) return val;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Teardown
// ---------------------------------------------------------------------------

async function teardown(
  supabaseUrl: string,
  publishableKey: string,
  serviceRoleKey: string,
  userJwt: string,
  userId: string,
  userEmail: string,
  userPassword: string,
  mealIds: string[],
): Promise<string> {
  const lines: string[] = [];

  // 1. Best-effort delete of the drafts, as the Cook.
  //
  // This cannot remove a PUBLISHED Meal and is not meant to: the DELETE policy on `meals` allows a
  // Cook to delete drafts only, so Phase 2's published rows are filtered out and the statement
  // removes zero rows without erroring. Step 2 is what actually removes those.
  let draftDeleteFailures = 0;
  for (const mealId of mealIds) {
    try {
      await fetch(`${supabaseUrl}/rest/v1/meals?id=eq.${mealId}`, {
        method: "DELETE",
        headers: {
          "apikey": publishableKey,
          "Authorization": `Bearer ${userJwt}`,
        },
      });
    } catch {
      draftDeleteFailures++;
    }
  }
  if (draftDeleteFailures > 0) {
    lines.push(
      `  ${draftDeleteFailures} draft delete request(s) failed; the cascade below is the backstop.`,
    );
  }

  // 2. Delete the Cook. THIS is what removes every Meal, published ones included:
  //    meals.cook_id is `REFERENCES auth.users(id) ON DELETE CASCADE`.
  let cookDeleted = false;
  try {
    const delRes = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
      method: "DELETE",
      headers: {
        "apikey": serviceRoleKey,
        "Authorization": `Bearer ${serviceRoleKey}`,
      },
    });
    cookDeleted = delRes.ok;
    lines.push(
      cookDeleted
        ? "  Test Cook deleted; every Meal of theirs went with it by ON DELETE CASCADE."
        : `  LOUD WARNING: failed to delete test Cook (HTTP ${delRes.status}) — rows remain.`,
    );
  } catch (err) {
    lines.push(
      `  LOUD WARNING: failed to delete test Cook: ${
        err instanceof Error ? err.message : String(err)
      }`,
    );
  }

  // 3. Verify with a role that can actually read.
  //
  // `service_role` deliberately holds no SELECT on `meals`, so counting with it returns 42501 —
  // and an earlier version of this function treated that failed request as "0 rows remaining" and
  // printed success. A verification that reports clean when it could not look is worse than none.
  //
  // `anon` does hold SELECT, and RLS shows it exactly the published Meals. That is also the set
  // worth checking: a leftover draft is invisible to everyone, a leftover published Meal is a
  // synthetic Meal on a real marketplace.
  const publishedRes = await fetch(
    `${supabaseUrl}/rest/v1/meals?status=eq.published&select=id,cook_id`,
    { headers: { "apikey": publishableKey } },
  );
  if (!publishedRes.ok) {
    lines.push(
      `  LOUD WARNING: could not verify cleanup (HTTP ${publishedRes.status}). ` +
        `Check the Meals table by hand before trusting this run.`,
    );
  } else {
    const rows = await publishedRes.json() as { cook_id?: string }[];
    const ours = rows.filter((r) => r.cook_id === userId);
    lines.push(
      ours.length === 0
        ? `  Verified: 0 published Meals remain for the test Cook (${rows.length} published Meal(s) on the project in total).`
        : `  LOUD WARNING: ${ours.length} published Meal(s) still belong to the test Cook ${userId}.`,
    );
  }

  // 4. Verify the DRAFTS went too — which step 3 cannot see and must not pretend to.
  //
  // `anon` is shown published Meals only, so the check above proves nothing about a draft: a
  // leftover draft and a clean table look identical to it. Nothing that can read a draft is
  // available here either — the Cook's own JWT dies with the Cook, and `service_role` holds no
  // SELECT on `meals` by design (that is the trap WP-002 found, where a 42501 was read as "zero
  // rows").
  //
  // So prove the root of the cascade is gone instead of the leaves. `meals.cook_id` is
  // `REFERENCES auth.users(id) ON DELETE CASCADE`, so if the auth user no longer exists then no
  // Meal can still reference it — a foreign key is not a best effort. A sign-in that fails is that
  // proof, and it needs no SELECT privilege at all.
  const signInRes = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { "apikey": publishableKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email: userEmail, password: userPassword }),
    },
  );
  if (signInRes.status === 200) {
    lines.push(
      "  LOUD WARNING: the test Cook can still sign in, so the account was NOT deleted and its " +
        "draft Meals are still there. Delete it by hand.",
    );
  } else {
    lines.push(
      `  Verified: the test Cook can no longer sign in (HTTP ${signInRes.status}), so the account is ` +
        "gone — and every Meal of theirs with it, drafts included, by ON DELETE CASCADE.",
    );
  }
  await signInRes.body?.cancel();

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Report generation
// ---------------------------------------------------------------------------

function generateReport(
  _modelTier: string,
  runs: number,
  analysisRuns: AnalysisRun[],
  publishRuns: PublishRun[],
  costRuns: TokenUsage[],
  phases: Set<Phase>,
): string {
  const today = new Date().toISOString().slice(0, 10);
  const lines: string[] = [];

  // Header
  lines.push("# Measuring E2 performance and per-Meal model cost");
  lines.push("");
  lines.push(`Generated by \`scripts/measure-e2-performance.ts\` on ${today}.`);
  lines.push("");
  lines.push(
    `- **Model tier**: fast, resolved by the registry (the fast tier as the registry resolved it)`,
  );
  lines.push(
    `- **Analysis runs**: ${analysisRuns.length}${
      analysisRuns.length === 0 ? " (phase did not run)" : ""
    }`,
  );
  lines.push(
    `- **Publish runs**: ${publishRuns.length}${
      publishRuns.length === 0 ? " (phase did not run)" : ""
    }`,
  );
  lines.push(
    `- **Cost runs**: ${
      costRuns.filter((r) => !r.fixture.startsWith("IMAGE:")).length
    } fixtures + 1 image call`,
  );
  lines.push(
    `- **Request spacing**: ${SPACING_MS} ms (free tier allows 15 requests per minute)`,
  );
  lines.push("");

  // Where the numbers came from. Generated rather than hand-written, because this document is
  // rewritten in full on every run — a hand-added section survives exactly until the next one, and
  // the section this replaces was hand-added.
  lines.push("## Where these numbers came from");
  lines.push("");
  lines.push(
    `Phases run: **${
      [...phases].join(", ")
    }**. Neither the project URL nor the project ref is`,
  );
  lines.push(
    "printed here; this file is committed, and a measurement report has no business carrying either.",
  );
  lines.push("");
  lines.push(
    phases.has("latency")
      ? "- **Description-finished → first estimate**: measured in this run, against the live production project. Every Meal it created was a **draft**, and every draft was deleted as it went; the publish path was never called."
      : "- **Description-finished → first estimate**: not run. No figure in this document comes from this run.",
  );
  lines.push(
    publishRuns.length > 0
      ? "- **Confirm → on-offer**: measured in this run."
      : `- **Confirm → on-offer**: **not measured in this run, and deliberately not.** The phase creates a published Meal, which is refused against production — see below. The figure carried forward is from ${PRIOR_PUBLISH.where}, ${PRIOR_PUBLISH.measuredOn}.`,
  );
  lines.push(
    phases.has("cost")
      ? "- **Model cost**: measured in this run, calling the provider directly. No database row is involved."
      : "- **Model cost**: not run.",
  );
  lines.push("");

  // How this was measured
  lines.push("## How this was measured");
  lines.push("");
  lines.push(
    "**Description-finished → first estimate:** Two round trips, both timed. The app persists the",
  );
  lines.push(
    "description and only starts the analysis once that write succeeds, so the Cook waits for both:",
  );
  lines.push(
    "the PostgREST PATCH that stores the description, then the HTTPS POST to the `analyze-meal`",
  );
  lines.push(
    "Edge Function. The clock starts before the PATCH and stops after the analysis body is",
  );
  lines.push(
    "read to completion. This includes the full network round trip, the Edge Function",
  );
  lines.push(
    "cold start (if any), the model call, and Row Level Security on the Meal ownership",
  );
  lines.push(
    "check. It does NOT include the Flutter widget rebuild after the reply arrives, nor",
  );
  lines.push("the time the Cook spends reading the estimate.");
  lines.push("");
  lines.push(
    "**Confirm → on-offer:** The timer starts immediately before the PostgREST PATCH that",
  );
  lines.push(
    "sets the Meal status to `published` and stops after the response body is read to",
  );
  lines.push(
    "completion. This includes the full network round trip and Row Level Security. It does",
  );
  lines.push(
    "NOT include the Flutter widget rebuild or any database trigger work that fires after",
  );
  lines.push("the response is sent.");
  lines.push("");
  lines.push(
    "**Model cost:** The provider is called directly (not through the Edge Function) with",
  );
  lines.push(
    "the same request shape the Edge Function uses. A wrapped `fetch` captures the raw",
  );
  lines.push(
    "provider response to read token usage, which the adapter interface does not expose.",
  );
  lines.push("");
  lines.push("**Excluded from all measurements:**");
  lines.push("- Flutter widget rebuild time after each reply arrives");
  lines.push(
    "- Network latency from an Egyptian mobile network (runs execute from a cloud container)",
  );
  lines.push(
    "- The image call measures token cost of dimensions only — the image is a flat gray",
  );
  lines.push(
    "  colour, not food, because Kafoo's rules forbid synthetic food imagery.",
  );
  lines.push("");

  // Phase 1 summary.
  //
  // ONLY runs that actually produced an analysis count. A call that 502s is fast, and averaging it
  // in makes the number better the more often the feature is broken — this report printed
  // "Verdict: PASS" over twelve consecutive HTTP 502s before this filter existed. A failed run is
  // not a fast run.
  const okAnalysis = analysisRuns.filter((r) => r.responseType === "analysis");
  const failedAnalysis = analysisRuns.filter((r) =>
    r.responseType !== "analysis"
  );
  const analysisElapsed = okAnalysis.map((r) => r.elapsedMs);
  const aStats = stats(analysisElapsed);
  const aBudget = 2000;
  const aVerdict = aStats.median <= aBudget ? "PASS" : "OVER";
  const aOver = okAnalysis.filter((r) => r.elapsedMs > aBudget).length;
  const persistStats = stats(analysisRuns.map((r) => r.persistMs));
  const nStats = stats(okAnalysis.map((r) => r.analyzeMs));

  lines.push("## Description-finished → first estimate");
  lines.push("");
  if (okAnalysis.length === 0) {
    lines.push(
      `**NOT MEASURED in this run.** ${analysisRuns.length} run(s) were attempted and none returned`,
    );
    lines.push(
      "an analysis, so there is no number here \u2014 not a fast one and not a slow one. A call that",
    );
    lines.push(
      "fails is not a call that is quick, and averaging failures in would make this figure improve",
    );
    lines.push("the more broken the feature was.");
    if (failedAnalysis.length > 0) {
      lines.push("");
      lines.push("How they failed:");
      lines.push("");
      const byCode = new Map<string, number>();
      for (const r of failedAnalysis) {
        const key = `HTTP ${r.status}${
          r.errorCode ? ` \u2014 ${r.errorCode}` : ""
        }`;
        byCode.set(key, (byCode.get(key) ?? 0) + 1);
      }
      for (const [key, count] of byCode) {
        lines.push(`- ${count} run(s): ${key}`);
      }
      lines.push("");
      lines.push(
        "The persist half of the span still completed on every run, so it is reported below on its",
      );
      lines.push(
        "own. It is one half of a number, and it is labelled as one half.",
      );
      lines.push("");
      lines.push(
        `- **Persisting the description**: median ${
          persistStats.median.toFixed(1)
        } ms across ${analysisRuns.length} runs (${persistStats.min}\u2013${persistStats.max} ms)`,
      );

      // The failed calls are not wasted. Everything before the point of failure still ran, so their
      // timings measure that prefix — for a provider_misconfigured failure, that is the Edge
      // Function's auth verification and Meal ownership check with no model call in it.
      const failStats = stats(failedAnalysis.map((r) => r.analyzeMs));
      lines.push(
        `- **The failed call itself**: median ${
          failStats.median.toFixed(1)
        } ms across ${failedAnalysis.length} runs (${failStats.min}\u2013${failStats.max} ms). This`,
      );
      lines.push(
        "  is not the analysis time. It is how long the Edge Function took to reach the point where",
      );
      lines.push(
        "  it gave up, which for these failures is everything before the model call.",
      );
      lines.push("");
      lines.push(
        "| Run | Fixture | Persist (ms) | Failed call (ms) | HTTP | Error |",
      );
      lines.push("|---|---|---|---|---|---|");
      for (const r of analysisRuns) {
        lines.push(
          `| ${r.run} | ${r.fixture} | ${r.persistMs} | ${r.analyzeMs} | ${r.status} | ${
            r.errorCode ?? "\u2014"
          } |`,
        );
      }
    }
    lines.push("");
  } else {
    lines.push(
      "The span is two round trips, not one. The app persists the description and only starts the",
    );
    lines.push(
      "analysis once that write succeeds, so a Cook waits for both. They are reported separately",
    );
    lines.push(
      "below because they have different fixes if this ever goes over.",
    );
    lines.push("");
    lines.push(`- **Runs**: ${runs}`);
    lines.push(`- **Minimum**: ${aStats.min} ms`);
    lines.push(`- **Median**: ${aStats.median.toFixed(1)} ms`);
    lines.push(`- **Maximum**: ${aStats.max} ms`);
    lines.push(`- **Mean**: ${aStats.mean.toFixed(1)} ms`);
    lines.push(`- **Budget**: ${aBudget} ms`);
    lines.push(
      `- **Verdict**: **${aVerdict}** — median ${aStats.median.toFixed(1)} ms ${
        aVerdict === "PASS" ? "is within" : "exceeds"
      } the ${aBudget} ms budget across ${runs} runs.`,
    );
    // The qualifier depends on which way the verdict went. It read "a median inside the budget does
    // not mean every Cook is inside it" unconditionally, which is a sentence about a PASS printed
    // underneath an OVER — and the first real OVER put it there, saying the opposite of the row above.
    lines.push(
      `- **Runs over budget**: ${aOver} of ${runs}${
        aOver === 0
          ? "" // nothing to qualify
          : aVerdict === "PASS"
          ? ` — a median inside the budget does not mean every Cook is inside it, and ${aOver} of these would have waited longer than ${aBudget} ms.`
          : ` — the median is over, and so were ${aOver} of the individual runs. ${
            runs - aOver
          } came in under, so this is not a feature that is always slow; it is one that is slow more often than not.`
      }`,
    );
    lines.push("");
    lines.push("Where the time goes, across the same runs:");
    lines.push("");
    lines.push(
      `- **Persisting the description**: median ${
        persistStats.median.toFixed(1)
      } ms (${persistStats.min}–${persistStats.max} ms)`,
    );
    lines.push(
      `- **The analysis call**: median ${
        nStats.median.toFixed(1)
      } ms (${nStats.min}–${nStats.max} ms)`,
    );
    lines.push("");

    // Phase 1 per-run table
    lines.push(
      "| Run | Fixture | Persist (ms) | Analyse (ms) | Total (ms) | HTTP | Response | Error |",
    );
    lines.push("|---|---|---|---|---|---|---|---|");
    for (const r of analysisRuns) {
      lines.push(
        `| ${r.run} | ${r.fixture} | ${r.persistMs} | ${r.analyzeMs} | ${r.elapsedMs} | ${r.status} | ${r.responseType} | ${
          r.errorCode ?? "—"
        } |`,
      );
    }
    lines.push("");

    // What the estimate got wrong. Also generated, for the reason given above: a measurement that
    // silently replaces an estimate teaches nobody anything, and the next person to build an
    // estimate out of three medians has no way to find out how the last one went.
    const priorAnalyse = PRIOR_ESTIMATE.edgeBeforeModelMs +
      PRIOR_ESTIMATE.modelCallMs;
    lines.push("## What the estimate got wrong");
    lines.push("");
    lines.push(
      "This section replaces an estimate. Until this run the number above was arithmetic: three",
    );
    lines.push(
      "medians measured separately and added together, because the analysis phase could not run at",
    );
    lines.push(
      "all against a preview branch with no model credential. Its parts were",
    );
    lines.push(
      `${PRIOR_ESTIMATE.persistMs} ms to persist the description, ${PRIOR_ESTIMATE.edgeBeforeModelMs} ms for the Edge Function before the model call, and`,
    );
    lines.push(
      `${PRIOR_ESTIMATE.modelCallMs} ms for one model call — composed to ≈${
        (PRIOR_ESTIMATE.composedMs / 1000).toFixed(1)
      } s, with the verdict that it`,
    );
    lines.push(`${PRIOR_ESTIMATE.verdict}.`);
    lines.push("");
    lines.push("| Span | Estimated | Measured | Difference |");
    lines.push("|---|---|---|---|");
    lines.push(
      `| Whole span | ${PRIOR_ESTIMATE.composedMs} ms | ${
        aStats.median.toFixed(1)
      } ms | ${signedDelta(PRIOR_ESTIMATE.composedMs, aStats.median)} |`,
    );
    lines.push(
      `| Persisting the description | ${PRIOR_ESTIMATE.persistMs} ms | ${
        persistStats.median.toFixed(1)
      } ms | ${signedDelta(PRIOR_ESTIMATE.persistMs, persistStats.median)} |`,
    );
    lines.push(
      `| The analysis call | ${priorAnalyse} ms | ${
        nStats.median.toFixed(1)
      } ms | ${signedDelta(priorAnalyse, nStats.median)} |`,
    );
    lines.push("");
    lines.push(
      `The two halves of the estimated analysis call — ${PRIOR_ESTIMATE.edgeBeforeModelMs} ms of Edge Function and ${PRIOR_ESTIMATE.modelCallMs} ms of`,
    );
    lines.push(
      "model — cannot be compared on their own, and the table does not pretend otherwise. The model",
    );
    lines.push(
      "call was timed from a container straight to the provider; the measurement times it from inside",
    );
    lines.push(
      "the Edge Function, on Supabase's own network. Only their sum is comparable.",
    );
    lines.push("");
    lines.push(
      aVerdict === "OVER"
        ? `**The estimate's verdict held.** It said the budget is missed, and the measurement agrees: median ${
          aStats.median.toFixed(1)
        } ms against a ${aBudget} ms budget.`
        : `**The estimate's verdict did not hold.** It said the budget is missed. The measurement disagrees: median ${
          aStats.median.toFixed(1)
        } ms is inside the ${aBudget} ms budget.`,
    );
    lines.push("");
  }

  // Phase 2 summary
  const publishElapsed = publishRuns.map((r) => r.elapsedMs);
  const pStats = stats(publishElapsed);
  const pBudget = 3000;
  const pVerdict = pStats.median <= pBudget ? "PASS" : "OVER";

  lines.push("## Confirm → on-offer");
  lines.push("");
  if (publishRuns.length === 0) {
    // Carried forward rather than blanked. The generator used to print "NOT MEASURED in this run"
    // here, which is true of the run and false of the repository: the number exists, it was measured
    // over 12 runs, and rewriting this file would have deleted it. An honest report of a partial run
    // says which parts are fresh, not that the rest never happened.
    const priorVerdict = PRIOR_PUBLISH.medianMs <= PRIOR_PUBLISH.budgetMs
      ? "PASS"
      : "OVER";
    lines.push(
      "**Not measured in this run, and deliberately not.** This phase sets a Meal's status to",
    );
    lines.push(
      "`published`. On the production project that would put a Meal nobody cooks in front of real",
    );
    lines.push(
      "Customers, which `.claude/rules/business-rules.md` lists as product-fatal \u2014 so the phase is",
    );
    lines.push(
      "refused against production outright, not merely left out of the default. Running this script",
    );
    lines.push(
      "against production was approved on the condition that nothing it creates is ever",
    );
    lines.push(
      "discoverable, and that holds only while every Meal it makes stays a draft.",
    );
    lines.push("");
    lines.push(
      `**Carried forward from ${PRIOR_PUBLISH.measuredOn}, measured on ${PRIOR_PUBLISH.where}.** This is a real`,
    );
    lines.push(
      "measurement of the same stack, and it is not a production number:",
    );
    lines.push("");
    lines.push(`- **Runs**: ${PRIOR_PUBLISH.runs}`);
    lines.push(`- **Minimum**: ${PRIOR_PUBLISH.minMs} ms`);
    lines.push(`- **Median**: ${PRIOR_PUBLISH.medianMs.toFixed(1)} ms`);
    lines.push(`- **Maximum**: ${PRIOR_PUBLISH.maxMs} ms`);
    lines.push(`- **Mean**: ${PRIOR_PUBLISH.meanMs.toFixed(1)} ms`);
    lines.push(`- **Budget**: ${PRIOR_PUBLISH.budgetMs} ms`);
    lines.push(
      `- **Verdict**: **${priorVerdict}** \u2014 median ${
        PRIOR_PUBLISH.medianMs.toFixed(1)
      } ms ${
        priorVerdict === "PASS" ? "is within" : "exceeds"
      } the ${PRIOR_PUBLISH.budgetMs} ms budget across ${PRIOR_PUBLISH.runs} runs.`,
    );
    lines.push("");
    lines.push(
      "A preview branch is colder than a used production project, so if anything this is the",
    );
    lines.push(
      "pessimistic end of the range. It is one PostgREST PATCH; nothing in the grants or policies",
    );
    lines.push("since has changed what it does.");
    lines.push("");
  } else {
    lines.push(`- **Runs**: ${runs}`);
    lines.push(`- **Minimum**: ${pStats.min} ms`);
    lines.push(`- **Median**: ${pStats.median.toFixed(1)} ms`);
    lines.push(`- **Maximum**: ${pStats.max} ms`);
    lines.push(`- **Mean**: ${pStats.mean.toFixed(1)} ms`);
    lines.push(`- **Budget**: ${pBudget} ms`);
    lines.push(
      `- **Verdict**: **${pVerdict}** — median ${pStats.median.toFixed(1)} ms ${
        pVerdict === "PASS" ? "is within" : "exceeds"
      } the ${pBudget} ms budget across ${runs} runs.`,
    );
    lines.push("");

    // Phase 2 per-run table
    lines.push("| Run | Meal id (prefix) | Elapsed (ms) | HTTP |");
    lines.push("|---|---|---|---|");
    for (const r of publishRuns) {
      lines.push(
        `| ${r.run} | ${
          r.mealId.slice(0, 8)
        }… | ${r.elapsedMs} | ${r.status} |`,
      );
    }
    lines.push("");
  }

  // Phase 3 — cost
  const textRuns = costRuns.filter((r) => !r.fixture.startsWith("IMAGE:"));
  const imageRuns = costRuns.filter((r) => r.fixture.startsWith("IMAGE:"));

  lines.push("## Model cost per published Meal");
  lines.push("");
  if (costRuns.length === 0) {
    // An empty token table under a live-looking heading reads as "measured, and it was nothing".
    lines.push(
      "**Not run.** The cost phase was not selected, so this document carries no cost figure from",
    );
    lines.push(
      "this run. Re-run with `--phases=cost` to produce one; it touches no database.",
    );
    lines.push("");
  }
  lines.push(
    "**Assumption:** input $0.25 per 1M tokens, output $1.50 per 1M tokens (standard",
  );
  lines.push(
    "paid tier). The free tier currently bills nothing, so these are the costs once the",
  );
  lines.push("project moves to the paid tier.");
  lines.push("");

  // Per-call token table (text fixtures)
  lines.push("### Per-fixture token counts (text only)");
  lines.push("");
  lines.push(
    "| Fixture | Prompt tokens | Output tokens | Thinking tokens | Total | Latency (ms) |",
  );
  lines.push("|---|---|---|---|---|---|");
  for (const r of textRuns) {
    lines.push(
      `| ${r.fixture} | ${r.promptTokens ?? "—"} | ${r.outputTokens ?? "—"} | ${
        r.thinkingTokens ?? "—"
      } | ${r.totalTokens ?? "—"} | ${r.elapsedMs} |`,
    );
  }
  lines.push("");

  // Mean token counts
  const validTotals = textRuns.map((r) => r.totalTokens).filter((
    v,
  ): v is number => v !== null);
  const validPrompt = textRuns.map((r) => r.promptTokens).filter((
    v,
  ): v is number => v !== null);
  const validOutput = textRuns.map((r) => r.outputTokens).filter((
    v,
  ): v is number => v !== null);
  const validThinking = textRuns.map((r) => r.thinkingTokens).filter((
    v,
  ): v is number => v !== null);

  let meanPrompt: number | null = null;
  let meanOutput: number | null = null;

  if (validTotals.length > 0) {
    const meanTotal = validTotals.reduce((s, v) => s + v, 0) /
      validTotals.length;
    meanPrompt = validPrompt.length > 0
      ? validPrompt.reduce((s, v) => s + v, 0) / validPrompt.length
      : null;
    meanOutput = validOutput.length > 0
      ? validOutput.reduce((s, v) => s + v, 0) / validOutput.length
      : null;
    const meanThinking = validThinking.length > 0
      ? validThinking.reduce((s, v) => s + v, 0) / validThinking.length
      : null;

    lines.push(`**Mean across ${validTotals.length} fixtures:**`);
    lines.push(`- Prompt tokens: ${meanPrompt?.toFixed(1) ?? "—"}`);
    lines.push(`- Output tokens: ${meanOutput?.toFixed(1) ?? "—"}`);
    if (meanThinking !== null) {
      lines.push(`- Thinking tokens: ${meanThinking.toFixed(1)}`);
    }
    lines.push(`- Total tokens: ${meanTotal.toFixed(1)}`);
    lines.push("");
  }

  // Image cost
  if (imageRuns.length > 0) {
    lines.push("### Image call");
    lines.push("");
    lines.push(
      "The image is a flat solid grey at 1600×1200 — the dimensions the app uses when",
    );
    lines.push(
      "picking photos (`maxWidth: 1600`, `imageQuality: 85`). Token cost is a function of",
    );
    lines.push(
      "dimensions, not content. This is NOT a picture of food; Kafoo's rules forbid",
    );
    lines.push("synthetic food imagery.");
    lines.push("");
    for (const r of imageRuns) {
      lines.push(`- **Prompt tokens**: ${r.promptTokens ?? "—"}`);
      lines.push(`- **Output tokens**: ${r.outputTokens ?? "—"}`);
      if (r.thinkingTokens !== null) {
        lines.push(`- **Thinking tokens**: ${r.thinkingTokens}`);
      }
      lines.push(`- **Total tokens**: ${r.totalTokens ?? "—"}`);
      lines.push(`- **Latency**: ${r.elapsedMs} ms`);
      if (Object.keys(r.rawUsage).length > 0) {
        lines.push(`- **Raw usage object**: \`${JSON.stringify(r.rawUsage)}\``);
      }
    }
    lines.push("");
  }

  // Dollar cost
  lines.push("### Cost per published Meal");
  lines.push("");

  // Cost without photo (one analysis call)
  if (meanPrompt !== null && meanOutput !== null) {
    const costWithoutPhoto =
      (meanPrompt * INPUT_RATE_PER_M + meanOutput * OUTPUT_RATE_PER_M) /
      1_000_000;
    const costPer1000WithoutPhoto = costWithoutPhoto * 1000;
    lines.push(
      `**Without a photo** (one analysis call, mean of ${validTotals.length} fixtures):`,
    );
    lines.push(`- **Per Meal**: $${costWithoutPhoto.toFixed(6)}`);
    lines.push(
      `- **Per 1,000 published Meals**: $${costPer1000WithoutPhoto.toFixed(2)}`,
    );
    lines.push("");
  }

  // Cost with photo (two analysis calls)
  if (meanPrompt !== null && meanOutput !== null && imageRuns.length > 0) {
    const imgRun = imageRuns[0];
    const imgPrompt = imgRun.promptTokens ?? 0;
    const imgOutput = imgRun.outputTokens ?? 0;
    const costWithPhoto = ((meanPrompt + imgPrompt) * INPUT_RATE_PER_M +
      (meanOutput + imgOutput) * OUTPUT_RATE_PER_M) / 1_000_000;
    const costPer1000WithPhoto = costWithPhoto * 1000;
    lines.push(
      `**With a photo** (two analysis calls — text mean + one image call):`,
    );
    lines.push(`- **Per Meal**: $${costWithPhoto.toFixed(6)}`);
    lines.push(
      `- **Per 1,000 published Meals**: $${costPer1000WithPhoto.toFixed(2)}`,
    );
    lines.push("");
  }

  // Raw usage dump for human verification
  lines.push("### Raw usage objects (for human verification)");
  lines.push("");
  for (const r of costRuns) {
    lines.push(`**${r.fixture}:**`);
    lines.push("");
    lines.push("```json");
    lines.push(JSON.stringify(r.rawUsage, null, 2));
    lines.push("```");
    lines.push("");
  }

  // What this does not tell you
  lines.push("## Alongside this: E1's per-verification cost, still open");
  lines.push("");
  lines.push(
    "**This script did not measure it, and the figures below are list prices rather than",
  );
  lines.push(
    "measurements.** They are here because a per-Meal cost is only half of what a Cook costs to",
  );
  lines.push("serve, and the other half is larger.");
  lines.push("");
  lines.push(
    "Signing in is phone OTP (`sign_in_screen.dart` calls `signInWithOtp(phone:)`), delivered by",
  );
  lines.push(
    "Twilio Verify per E1's research. Published list prices, read on 2026-08-05:",
  );
  lines.push("");
  lines.push(
    "- Twilio Verify: **$0.05 per successful verification**, plus channel fees",
  );
  lines.push("- Twilio SMS to Egypt: **$0.3959 per message**");
  lines.push(
    "- So roughly **$0.45 per successful sign-in**, and a resend costs another message",
  );
  lines.push("");
  lines.push(
    "Set against the measured Meal cost, that is the number that decides things: **one sign-in",
  );
  lines.push(
    "costs about as much as 550 published Meals without a photo, or 225 with one.** Publishing",
  );
  lines.push("Meals is close to free. Letting people sign in is not.");
  lines.push("");
  lines.push(
    "This does not close E1's T073, and should not be recorded as though it had. A list price is",
  );
  lines.push(
    "not a delivered message: E1's research asks for real per-verification cost into Egyptian",
  );
  lines.push(
    "networks, which needs a real handset on a real Egyptian network — the same spike that answers",
  );
  lines.push(
    "whether sender-ID registration lets the message arrive at all. An undelivered SMS can still",
  );
  lines.push("be billed.");
  lines.push("");
  lines.push("## What this does not tell you");
  lines.push("");
  lines.push(
    "- **Mobile network latency.** Runs execute from a cloud container, not an Egyptian",
  );
  lines.push(
    "  mobile network. A real Cook on 3G or congested 4G will pay higher latency on top",
  );
  lines.push("  of these numbers.");
  lines.push(
    "- **Widget rebuild time.** The timer stops when the HTTP response is read. The Flutter",
  );
  lines.push(
    "  framework still needs to parse the JSON, rebuild the widget tree, and paint the",
  );
  lines.push("  estimate on screen.");
  lines.push(
    "- **Other model tiers.** Only the fast tier is measured. The reasoning tier would",
  );
  lines.push("  cost more and take longer.");
  lines.push(
    "- **Provider switch.** If `AI_PROVIDER` changes, the model — and therefore the token",
  );
  lines.push(
    "  counts and latency — will change. Re-run this script after any provider switch.",
  );
  lines.push(
    "- **Edge Function cold start.** The first run in each batch may include a cold start.",
  );
  lines.push(
    "  This is recorded, not discarded, because it is a real Cook's experience. But a",
  );
  lines.push(
    "  frequently-used project may have warm functions, making later runs more typical.",
  );
  lines.push(
    "- **Concurrent load.** These runs are serial. Under concurrent load the Edge Function,",
  );
  lines.push("  PostgREST, and the model provider may behave differently.");
  lines.push(
    "- **Image content.** The image token cost is measured with a flat grey square. Real",
  );
  lines.push(
    "  photos contain detail that may affect tokenisation, though the dominant factor is",
  );
  lines.push("  dimensions.");
  lines.push("");

  return lines.join("\n") + "\n";
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

export type Phase = "latency" | "cost" | "publish";

const ALL_PHASES: readonly Phase[] = ["latency", "cost", "publish"];
const DEFAULT_PHASES: readonly Phase[] = ["latency", "cost"];

/// Which phases this invocation may run, and the one it may never run against production.
///
/// THIS IS A GUARD, NOT A CONVENTION, and the difference is the reason the function exists. The
/// publish phase sets a Meal's status to `published`. On the live project that is a synthetic Meal
/// on a real marketplace, which `.claude/rules/business-rules.md` lists as product-fatal, and the
/// founder's approval to run this script against production on 2026-08-05 was given only on the
/// terms that nothing it creates is ever discoverable — true only while every Meal stays a draft.
///
/// So `publish` is absent from the default, must be named explicitly, AND is refused outright when
/// the target is production. There is deliberately no override flag and no environment variable
/// that grants it. "Remember not to publish" is what this repository has been burned by; a phase
/// nobody can reach cannot be reached by mistake either.
///
/// FAILS CLOSED. A missing or empty SUPABASE_PROJECT_REF refuses `publish` rather than allowing it:
/// without the production project's ref there is no way to prove the target is *not* production,
/// and an unprovable claim about a production write is a no.
///
/// Takes `env` as a parameter rather than reading Deno.env directly, so the guard is testable
/// without a live environment — see scripts/measure_e2_phases_test.ts, whose production case was
/// seen to fail before this text was written.
export function resolvePhases(
  args: string[],
  env: (key: string) => string | undefined,
): Set<Phase> {
  const flag = args.find((a) => a.startsWith("--phases="));
  const requested = flag === undefined
    ? [...DEFAULT_PHASES]
    : flag.slice("--phases=".length).split(",").map((p) => p.trim()).filter((
      p,
    ) => p.length > 0);

  if (requested.length === 0) {
    throw new Error(
      `--phases= needs at least one of ${ALL_PHASES.join(", ")}`,
    );
  }

  for (const p of requested) {
    if (!ALL_PHASES.includes(p as Phase)) {
      throw new Error(
        `--phases: unknown phase "${p}" (accepted: ${ALL_PHASES.join(", ")})`,
      );
    }
  }

  const phases = new Set(requested as Phase[]);

  if (phases.has("publish")) {
    const url = (env("SUPABASE_URL") ?? "").trim();
    const productionRef = (env("SUPABASE_PROJECT_REF") ?? "").trim();
    // Neither value is printed. This message can end up in a log or a report.
    const refusal =
      "refusing the publish phase: it sets a Meal to `published`, and a published Meal " +
      "nobody cooks is synthetic content on the real marketplace — product-fatal, not untidy. " +
      "Run it against a Supabase preview branch instead.";
    if (productionRef === "" || url === "") {
      throw new Error(
        `${refusal} SUPABASE_PROJECT_REF and SUPABASE_URL must both be set so the target can be ` +
          `proven not to be production; one of them is not.`,
      );
    }
    if (url.includes(productionRef)) {
      throw new Error(`${refusal} The target is the production project.`);
    }
  }

  return phases;
}

function printHelp(): void {
  console.log(`\
Usage: deno run --allow-net --allow-env --allow-read --allow-write scripts/measure-e2-performance.ts [options]

Measure Kafoo's E2 performance numbers and per-Meal model cost.

Options:
  --help          Show this help message and exit
  --phases=<list> Comma-separated: latency, cost, publish (default: ${
    DEFAULT_PHASES.join(",")
  })
                  latency  description-finished → first estimate. Writes draft Meals only.
                  cost     model token cost. Touches no database.
                  publish  confirm → on-offer. REFUSED against the production project, because
                           it creates a published Meal and a published Meal nobody cooks is
                           synthetic content on a real marketplace. Use a preview branch.
                           There is no override flag; that absence is deliberate.
  --runs=<n>      Number of runs per phase (default: ${DEFAULT_RUNS})
  --no-teardown   Skip cleanup of test data (for debugging — prints a prominent warning)
  --dry-run       Validate environment and print the plan without making any call that costs
                  money or writes a row

Environment variables:
  SUPABASE_URL              Supabase project URL
  SUPABASE_PUBLISHABLE_KEY  Supabase publishable (anon) key
  SUPABASE_SERVICE_ROLE_KEY Supabase service role key
  AI_PROVIDER               AI provider id (default: gemini)
  <provider API key>        API key for the resolved provider (e.g. GEMINI_API_KEY)

The script creates a throwaway Cook on the live Supabase project, runs the measurements,
tears the Cook and every test Meal down, and writes a report to docs/ops/measuring-e2.md.

Rate limit: model-touching calls are spaced ${SPACING_MS} ms apart (free tier allows 15/min).
`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const showHelp = Deno.args.includes("--help");
  if (showHelp) {
    printHelp();
    Deno.exit(0);
  }

  const noTeardown = Deno.args.includes("--no-teardown");
  const dryRun = Deno.args.includes("--dry-run");

  // Phase selection. `--phases=cost` alone still produces a real number when the Supabase side is
  // unavailable — it talks to the model provider and touches no database. That mattered on
  // 2026-08-05, when the live project had no table privileges (see the grant migration) and the
  // latency phase could not run while the cost figure could: half a measurement reported honestly
  // beats waiting for all of it.
  //
  // The refusal below is a hard stop rather than a warning. See `resolvePhases`.
  let phases: Set<Phase>;
  try {
    phases = resolvePhases(Deno.args, (k) => Deno.env.get(k));
  } catch (err) {
    console.error(err instanceof Error ? err.message : String(err));
    Deno.exit(2);
  }
  const wantLatency = phases.has("latency");
  const wantPublish = phases.has("publish");
  const wantCost = phases.has("cost");
  const needsCook = wantLatency || wantPublish;

  const runsArg = Deno.args.find((a) => a.startsWith("--runs="));
  const runs = runsArg ? Number(runsArg.slice("--runs=".length)) : DEFAULT_RUNS;
  if (!Number.isFinite(runs) || runs < 1 || !Number.isInteger(runs)) {
    console.error("--runs must be a positive integer");
    Deno.exit(2);
  }

  // Validate environment
  const requiredVars = [
    "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
  ];
  const missing = requiredVars.filter((v) => !Deno.env.get(v));
  if (missing.length > 0) {
    console.error(
      `Missing required environment variable(s): ${missing.join(", ")}`,
    );
    Deno.exit(2);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const publishableKey = Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // Resolve provider — this also validates the AI provider variables
  let resolvedModel: string;
  try {
    const resolved = resolveProvider("fast", (k) => Deno.env.get(k));
    resolvedModel = resolved.model;
  } catch (err) {
    console.error(
      `Failed to resolve AI provider: ${
        err instanceof Error ? err.message : String(err)
      }`,
    );
    Deno.exit(2);
  }

  const allFixtures = loadFixtures();
  const testFixtures = usableFixtures(allFixtures);

  if (dryRun) {
    console.error("DRY RUN — no calls will be made, no rows will be written.");
    console.error("");
    console.error(
      `Environment: OK (${requiredVars.length} variables present, AI provider resolved)`,
    );
    console.error(
      `Fixtures loaded: ${allFixtures.length} total, ${testFixtures.length} usable for E2`,
    );
    console.error(`Phases selected: ${[...phases].join(", ")}`);
    console.error(`Plan:`);
    console.error(
      needsCook
        ? `  Phase 0: create throwaway Cook (measure-XXXX@kafoo.invalid)`
        : `  Phase 0: SKIPPED — no Cook, no row written`,
    );
    console.error(
      wantLatency
        ? `  Phase 1: ${runs} analysis runs, cycling through ${testFixtures.length} fixtures, ${SPACING_MS} ms apart, draft Meals only`
        : `  Phase 1: SKIPPED`,
    );
    console.error(
      wantPublish
        ? `  Phase 2: ${runs} publish runs, one fresh Meal each`
        : `  Phase 2: SKIPPED — the publish phase was not asked for`,
    );
    console.error(
      wantCost
        ? `  Phase 3: ${allFixtures.length} cost calls (text) + 1 image call, ${SPACING_MS} ms apart`
        : `  Phase 3: SKIPPED`,
    );
    console.error(`  Phase 4: write report to ${REPORT_PATH}`);
    console.error(
      needsCook
        ? `  Teardown: delete the test Cook; every Meal of theirs goes with it`
        : `  Teardown: nothing to tear down`,
    );
    console.error("");
    console.error(
      "No model calls will be made. No Supabase rows will be written.",
    );
    Deno.exit(0);
  }

  if (noTeardown) {
    console.error(
      "⚠ WARNING: --no-teardown is set. Test data will NOT be cleaned up.",
    );
    console.error(
      "⚠ You must manually delete the test Cook and Meals afterwards.",
    );
    console.error("");
  }

  console.error(
    `Starting measurement: ${runs} runs per phase, model tier resolved by registry.`,
  );
  console.error("");

  const allMealIds: string[] = [];
  let cook: CookCtx | null = null;

  try {
    let analysisRuns: AnalysisRun[] = [];
    let publishRuns: PublishRun[] = [];

    if (!needsCook) {
      console.error(
        "No database phase selected: skipping Phases 0-2. No Cook is created and no row is written.",
      );
      console.error("");
    } else {
      // Phase 0
      console.error("Phase 0: creating throwaway Cook...");
      cook = await createCook(supabaseUrl, serviceRoleKey, publishableKey);
      console.error(
        `  Cook created: ${cook.userEmail} (id: ${cook.userId.slice(0, 8)}…)`,
      );

      console.error("  Creating Kitchen Profile...");
      await createKitchenProfile(
        supabaseUrl,
        publishableKey,
        cook.userJwt,
        cook.userId,
      );
      console.error("  Kitchen Profile created.");
      console.error("");

      // Phase 1
      if (wantLatency) {
        console.error(
          `Phase 1: description-finished → first estimate (${runs} runs)...`,
        );
        analysisRuns = await runAnalysisPhase(
          supabaseUrl,
          publishableKey,
          cook.userJwt,
          cook.userId,
          testFixtures,
          runs,
        );
        console.error("");
      }

      // Phase 2. Reachable only on a project `resolvePhases` proved is not production.
      if (wantPublish) {
        console.error(`Phase 2: confirm → on-offer (${runs} runs)...`);
        publishRuns = await runPublishPhase(
          supabaseUrl,
          publishableKey,
          cook.userJwt,
          cook.userId,
          testFixtures,
          runs,
        );
        for (const r of publishRuns) allMealIds.push(r.mealId);
        console.error("");
      }
    }

    // Phase 3
    let costRuns: TokenUsage[] = [];
    if (wantCost) {
      console.error(
        `Phase 3: model cost (${allFixtures.length} fixtures + 1 image)...`,
      );
      costRuns = await runCostPhase(allFixtures);
      console.error("");
    }

    // Phase 4
    console.error("Phase 4: writing report...");
    const report = generateReport(
      resolvedModel,
      runs,
      analysisRuns,
      publishRuns,
      costRuns,
      phases,
    );
    Deno.writeTextFileSync(REPORT_PATH, report);
    console.error(`  Wrote ${REPORT_PATH}`);
    console.error("");
  } finally {
    // Teardown
    if (cook && !noTeardown) {
      console.error("Teardown: cleaning up test data...");
      const summary = await teardown(
        supabaseUrl,
        publishableKey,
        serviceRoleKey,
        cook.userJwt,
        cook.userId,
        cook.userEmail,
        cook.userPassword,
        allMealIds,
      );
      console.error(summary);
    } else if (cook && noTeardown) {
      console.error(`Teardown SKIPPED (--no-teardown). Manual cleanup needed:`);
      console.error(
        `  - Delete ${allMealIds.length} Meal rows with cook_id = ${cook.userId}`,
      );
      console.error(
        `  - DELETE ${supabaseUrl}/auth/v1/admin/users/${cook.userId}`,
      );
    }
  }

  console.error("");
  console.error("Measurement complete.");
}

if (import.meta.main) {
  await main();
}
