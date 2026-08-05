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
// Minimal baseline JPEG encoder for a solid gray image
//
// The image is a flat colour — token cost is a function of dimensions, not content.
// Gray = 128 (mid-gray), so after level-shift all pixel values are 0, all DCT
// coefficients are 0, and every 8×8 block encodes as DC(cat 0) + EOB = 6 bits.
// No 0xFF bytes appear in the scan data, so no byte stuffing is needed.
// ---------------------------------------------------------------------------

function createSolidGrayJpeg(width: number, height: number): Uint8Array {
  const mcuW = Math.ceil(width / 8);
  const mcuH = Math.ceil(height / 8);
  const numBlocks = mcuW * mcuH;
  const totalBits = numBlocks * 6;
  const scanBytes = Math.ceil(totalBits / 8);

  // Build scan data: each block = DC(cat 0) "00" + EOB "1010" = "001010"
  const scanData = new Uint8Array(scanBytes);
  let bitPos = 0;
  for (let i = 0; i < numBlocks; i++) {
    const pattern = 0b001010; // 6 bits
    for (let b = 5; b >= 0; b--) {
      const byteIdx = Math.floor(bitPos / 8);
      const bitIdx = 7 - (bitPos % 8);
      if (byteIdx < scanBytes) {
        scanData[byteIdx] |= ((pattern >> b) & 1) << bitIdx;
      }
      bitPos++;
    }
  }
  // Pad remaining bits with 1s (JPEG convention)
  if (bitPos % 8 !== 0) {
    const padBits = 8 - (bitPos % 8);
    const lastByte = Math.floor(bitPos / 8);
    if (lastByte < scanBytes) {
      for (let b = 0; b < padBits; b++) {
        scanData[lastByte] |= 1 << (7 - b);
      }
    }
  }

  // Quantization table: all 1s (valid, and irrelevant for a solid-gray image)
  const dqtValues = new Uint8Array(64).fill(1);

  // Standard JPEG DC Huffman table 0
  const dcBits = new Uint8Array([
    0,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    2,
    0,
    0,
    0,
    0,
    0,
  ]);
  const dcVals = new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);

  // Standard JPEG AC Huffman table 0
  const acBits = new Uint8Array([
    0,
    2,
    1,
    3,
    3,
    2,
    4,
    3,
    5,
    5,
    4,
    4,
    0,
    0,
    1,
    125,
  ]);
  const acVals = new Uint8Array([
    0x01,
    0x02,
    0x03,
    0x00,
    0x04,
    0x11,
    0x05,
    0x12,
    0x21,
    0x31,
    0x41,
    0x06,
    0x13,
    0x51,
    0x61,
    0x07,
    0x22,
    0x71,
    0x14,
    0x32,
    0x81,
    0x91,
    0xA1,
    0x08,
    0x23,
    0x42,
    0xB1,
    0xC1,
    0x15,
    0x52,
    0xD1,
    0xF0,
    0x24,
    0x33,
    0x62,
    0x72,
    0x82,
    0x09,
    0x0A,
    0x16,
    0x17,
    0x18,
    0x19,
    0x1A,
    0x25,
    0x26,
    0x27,
    0x28,
    0x29,
    0x2A,
    0x34,
    0x35,
    0x36,
    0x37,
    0x38,
    0x39,
    0x3A,
    0x43,
    0x44,
    0x45,
    0x46,
    0x47,
    0x48,
    0x49,
    0x4A,
    0x53,
    0x54,
    0x55,
    0x56,
    0x57,
    0x58,
    0x59,
    0x5A,
    0x63,
    0x64,
    0x65,
    0x66,
    0x67,
    0x68,
    0x69,
    0x6A,
    0x73,
    0x74,
    0x75,
    0x76,
    0x77,
    0x78,
    0x79,
    0x7A,
    0x83,
    0x84,
    0x85,
    0x86,
    0x87,
    0x88,
    0x89,
    0x8A,
    0x92,
    0x93,
    0x94,
    0x95,
    0x96,
    0x97,
    0x98,
    0x99,
    0x9A,
    0xA2,
    0xA3,
    0xA4,
    0xA5,
    0xA6,
    0xA7,
    0xA8,
    0xA9,
    0xAA,
    0xB2,
    0xB3,
    0xB4,
    0xB5,
    0xB6,
    0xB7,
    0xB8,
    0xB9,
    0xBA,
    0xC2,
    0xC3,
    0xC4,
    0xC5,
    0xC6,
    0xC7,
    0xC8,
    0xC9,
    0xCA,
    0xD2,
    0xD3,
    0xD4,
    0xD5,
    0xD6,
    0xD7,
    0xD8,
    0xD9,
    0xDA,
    0xE1,
    0xE2,
    0xE3,
    0xE4,
    0xE5,
    0xE6,
    0xE7,
    0xE8,
    0xE9,
    0xEA,
    0xF1,
    0xF2,
    0xF3,
    0xF4,
    0xF5,
    0xF6,
    0xF7,
    0xF8,
    0xF9,
    0xFA,
  ]);

  function u16(n: number): [number, number] {
    return [(n >> 8) & 0xFF, n & 0xFF];
  }

  const parts: Uint8Array[] = [];

  // SOI
  parts.push(new Uint8Array([0xFF, 0xD8]));

  // APP0 / JFIF
  parts.push(
    new Uint8Array([
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
    ]),
  );

  // DQT (table 0, 8-bit)
  const dqtLen = 1 + 64 + 2; // table info + values + length field
  parts.push(new Uint8Array([0xFF, 0xDB, ...u16(dqtLen), 0x00, ...dqtValues]));

  // SOF0 (baseline, grayscale)
  const [hh, hl] = u16(height);
  const [wh, wl] = u16(width);
  parts.push(
    new Uint8Array([
      0xFF,
      0xC0,
      0x00,
      0x11,
      0x08,
      hh,
      hl,
      wh,
      wl,
      0x01,
      0x01,
      0x11,
      0x00,
    ]),
  );

  // DHT — DC table 0
  const dcDataLen = 1 + dcBits.length + dcVals.length + 2;
  parts.push(
    new Uint8Array([0xFF, 0xC4, ...u16(dcDataLen), 0x00, ...dcBits, ...dcVals]),
  );

  // DHT — AC table 0
  const acDataLen = 1 + acBits.length + acVals.length + 2;
  parts.push(
    new Uint8Array([0xFF, 0xC4, ...u16(acDataLen), 0x10, ...acBits, ...acVals]),
  );

  // SOS (1 component)
  parts.push(
    new Uint8Array([0xFF, 0xDA, 0x00, 0x0C, 0x01, 0x00, 0x00, 0x3F, 0x00]),
  );

  // Scan data
  parts.push(scanData);

  // EOI
  parts.push(new Uint8Array([0xFF, 0xD9]));

  // Concatenate
  const total = parts.reduce((s, p) => s + p.length, 0);
  const result = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    result.set(p, off);
    off += p.length;
  }
  return result;
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
    const dataMatch = bodyText.match(/^data:\s*(\{.*\})/m);
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
  } finally {
    globalThis.fetch = originalFetch;
  }

  // Image cost: one call with a solid-color JPEG
  console.error(
    "  Phase 3 image call: measuring token cost of a 1600×1200 flat-colour image",
  );
  try {
    const jpegBytes = createSolidGrayJpeg(1600, 1200);
    const base64 = btoa(String.fromCharCode(...jpegBytes));
    const image: ModelImage = { base64, mediaType: "image/jpeg" };

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
  lines.push(`- **Analysis runs**: ${runs}`);
  lines.push(`- **Publish runs**: ${runs}`);
  lines.push(
    `- **Cost runs**: ${
      costRuns.filter((r) => !r.fixture.startsWith("IMAGE:")).length
    } fixtures + 1 image call`,
  );
  lines.push(
    `- **Request spacing**: ${SPACING_MS} ms (free tier allows 15 requests per minute)`,
  );
  lines.push("");

  // How this was measured
  lines.push("## How this was measured");
  lines.push("");
  lines.push(
    "**Description-finished → first estimate:** The timer starts immediately before the",
  );
  lines.push(
    "HTTPS POST to the `analyze-meal` Edge Function and stops after the response body is",
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

  // Phase 1 summary
  const analysisElapsed = analysisRuns.map((r) => r.elapsedMs);
  const aStats = stats(analysisElapsed);
  const aBudget = 2000;
  const aVerdict = aStats.median <= aBudget ? "PASS" : "OVER";
  const aOver = analysisRuns.filter((r) => r.elapsedMs > aBudget).length;
  const persistStats = stats(analysisRuns.map((r) => r.persistMs));
  const nStats = stats(analysisRuns.map((r) => r.analyzeMs));

  lines.push("## Description-finished → first estimate");
  lines.push("");
  lines.push(
    "The span is two round trips, not one. The app persists the description and only starts the",
  );
  lines.push(
    "analysis once that write succeeds, so a Cook waits for both. They are reported separately",
  );
  lines.push("below because they have different fixes if this ever goes over.");
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
  lines.push(
    `- **Runs over budget**: ${aOver} of ${runs}${
      aOver === 0
        ? "" // nothing to qualify
        : ` — a median inside the budget does not mean every Cook is inside it, and ${aOver} of these would have waited longer than ${aBudget} ms.`
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

  // Phase 2 summary
  const publishElapsed = publishRuns.map((r) => r.elapsedMs);
  const pStats = stats(publishElapsed);
  const pBudget = 3000;
  const pVerdict = pStats.median <= pBudget ? "PASS" : "OVER";

  lines.push("## Confirm → on-offer");
  lines.push("");
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
      `| ${r.run} | ${r.mealId.slice(0, 8)}… | ${r.elapsedMs} | ${r.status} |`,
    );
  }
  lines.push("");

  // Phase 3 — cost
  const textRuns = costRuns.filter((r) => !r.fixture.startsWith("IMAGE:"));
  const imageRuns = costRuns.filter((r) => r.fixture.startsWith("IMAGE:"));

  lines.push("## Model cost per published Meal");
  lines.push("");
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

function printHelp(): void {
  console.log(`\
Usage: deno run --allow-net --allow-env --allow-read --allow-write scripts/measure-e2-performance.ts [options]

Measure Kafoo's E2 performance numbers and per-Meal model cost.

Options:
  --help          Show this help message and exit
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
    console.error(`Plan:`);
    console.error(
      `  Phase 0: create throwaway Cook (measure-XXXX@kafoo.invalid)`,
    );
    console.error(
      `  Phase 1: ${runs} analysis runs, cycling through ${testFixtures.length} fixtures, ${SPACING_MS} ms apart`,
    );
    console.error(`  Phase 2: ${runs} publish runs, one fresh Meal each`);
    console.error(
      `  Phase 3: ${allFixtures.length} cost calls (text) + 1 image call, ${SPACING_MS} ms apart`,
    );
    console.error(`  Phase 4: write report to ${REPORT_PATH}`);
    console.error(`  Teardown: delete ${runs + runs} Meals and the test Cook`);
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
    console.error(
      `Phase 1: description-finished → first estimate (${runs} runs)...`,
    );
    const analysisRuns = await runAnalysisPhase(
      supabaseUrl,
      publishableKey,
      cook.userJwt,
      cook.userId,
      testFixtures,
      runs,
    );
    console.error("");

    // Phase 2
    console.error(`Phase 2: confirm → on-offer (${runs} runs)...`);
    const publishRuns = await runPublishPhase(
      supabaseUrl,
      publishableKey,
      cook.userJwt,
      cook.userId,
      testFixtures,
      runs,
    );
    for (const r of publishRuns) allMealIds.push(r.mealId);
    console.error("");

    // Phase 3
    console.error(
      `Phase 3: model cost (${allFixtures.length} fixtures + 1 image)...`,
    );
    const costRuns = await runCostPhase(allFixtures);
    console.error("");

    // Phase 4
    console.error("Phase 4: writing report...");
    const report = generateReport(
      resolvedModel,
      runs,
      analysisRuns,
      publishRuns,
      costRuns,
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
