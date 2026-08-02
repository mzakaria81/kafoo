// analyze-meal — the single place Kafoo talks to a language model.
//
// A Cook describes a Meal they cooked; this function returns suggested ingredients, calories,
// allergens, cuisine, category, and a short reason for each. Every field is a SUGGESTION shown to
// the Cook for approval. Nothing is written to any database.
//
// Two properties are structural, not careful coding:
//   1. This function holds no service-role key. It cannot mint one and it never reads one.
//   2. This function performs no database write. Reads only.
//
// Identity comes from the verified JWT and from nowhere else. A cook_id in the body would be a
// vulnerability, not a feature.

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { resolveProvider, type ResolvedProvider } from '../_shared/ai/registry.ts';
import { parseAndValidate } from '../_shared/ai/schema.ts';
import {
  ModelError,
  type ModelImage,
  type ModelRequest,
  type ModelResponse,
  type ProviderAdapter,
} from '../_shared/ai/types.ts';
import { PROMPTS } from '../_shared/prompts.ts';
import { MEAL_ANALYSIS_SCHEMA } from './schema.ts';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SAID_MAX_CHARS = 4000;
const MAX_TOKENS = 2048;
const PROMPT_ID = 'meal-analysis';

export type CreateUserClient = (authHeader: string) => SupabaseClient;

export type ResolveProviderFn = (
  tier: 'fast' | 'reasoning',
  env: (key: string) => string | undefined,
) => ResolvedProvider;

export interface AnalyzeMealDeps {
  readonly createUserClient: CreateUserClient;
  readonly resolveProvider: ResolveProviderFn;
  readonly env: (key: string) => string | undefined;
}

function jsonError(status: number, code: string): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function sseHeaders(): Record<string, string> {
  return {
    ...corsHeaders,
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  };
}

function sseEvent(payload: unknown): string {
  return `data: ${JSON.stringify(payload)}\n\n`;
}

function sseResponse(payload: unknown): Response {
  // Streaming is required by the constitution for conversational responses. What streams here is
  // the transport, not half-parsed JSON: the model reply is a single structured object that must
  // be schema-valid before a Cook sees any of it, so we emit one complete event after validation
  // (or one error event) and close. Partial tokens would be streaming something nobody can render.
  //
  // Failures detected BEFORE the provider is called (auth, validation, ownership) stay ordinary
  // status codes — those never open a stream. Failures during or after the provider call ride the
  // stream as error events with HTTP 200 on the envelope, because the headers are already sent.
  const body = sseEvent(payload);
  return new Response(body, { status: 200, headers: sseHeaders() });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

/// photo_path must be exactly meal-photos/{callerUid}/{mealId}.jpg.
///
/// Compared segment-by-segment rather than with startsWith or a loose regex, because a crafted
/// path like meal-photos/{uid}/../{other}/x.jpg would otherwise slip through. Any ".." is rejected.
function parsePhotoPath(
  photoPath: string,
  callerUid: string,
  mealId: string,
): { objectPath: string } | { error: 'forbidden' } {
  if (photoPath.includes('..')) return { error: 'forbidden' };

  const segments = photoPath.split('/');
  if (segments.length !== 3) return { error: 'forbidden' };

  const [bucket, uid, file] = segments;
  if (bucket !== 'meal-photos') return { error: 'forbidden' };
  if (uid !== callerUid) return { error: 'forbidden' };
  if (file !== `${mealId}.jpg`) return { error: 'forbidden' };

  return { objectPath: `${uid}/${file}` };
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function modelErrorCode(kind: ModelError['kind']): { status: number; code: string } {
  switch (kind) {
    case 'auth':
      return { status: 502, code: 'provider_auth' };
    case 'rate_limit':
      return { status: 429, code: 'rate_limit' };
    case 'timeout':
      return { status: 504, code: 'timeout' };
    case 'invalid_response':
      return { status: 502, code: 'invalid_response' };
    case 'upstream':
      return { status: 502, code: 'upstream' };
  }
}

async function callProviderWithRetry(
  adapter: ProviderAdapter,
  apiKey: string,
  baseRequest: ModelRequest,
): Promise<
  | { ok: true; response: ModelResponse; value: Record<string, unknown> }
  | { ok: false; code: string; status: number }
> {
  let userContent = baseRequest.user;

  for (let attempt = 0; attempt < 2; attempt++) {
    const request: ModelRequest = {
      ...baseRequest,
      user: userContent,
    };

    let response: ModelResponse;
    try {
      response = await adapter.complete(request, apiKey);
    } catch (error) {
      if (error instanceof ModelError) {
        const mapped = modelErrorCode(error.kind);
        return { ok: false, code: mapped.code, status: mapped.status };
      }
      throw error;
    }

    if (response.stopReason === 'length') {
      // A reply cut off at the token limit and a reply that is nonsense are different problems
      // with different fixes; both surface as parse failures, so the stop reason must be logged
      // distinctly or the two stay indistinguishable.
      console.error(
        JSON.stringify({
          event: 'analyze_meal_truncated',
          stopReason: response.stopReason,
          modelId: response.modelId,
          attempt,
        }),
      );
    }

    const parsed = parseAndValidate(response.text, MEAL_ANALYSIS_SCHEMA);
    if (!('errors' in parsed)) {
      return {
        ok: true,
        response,
        value: parsed.value as Record<string, unknown>,
      };
    }

    if (attempt === 0) {
      // Retry exactly once. Validation errors go on the user content, never the system prompt —
      // the system prompt is the trusted instruction set and must not absorb untrusted correction
      // text that could itself be shaped by a previous bad reply.
      userContent =
        `${baseRequest.user}\n\n` +
        `Your previous reply failed validation. Correct these problems and reply with valid JSON only:\n` +
        parsed.errors.map((e) => `- ${e}`).join('\n');
      continue;
    }

    console.error(
      JSON.stringify({
        event: 'analyze_meal_validation_failed',
        errors: parsed.errors,
        stopReason: response.stopReason,
        modelId: response.modelId,
      }),
    );
    return { ok: false, code: 'invalid_response', status: 502 };
  }

  return { ok: false, code: 'invalid_response', status: 502 };
}

export function createDefaultDeps(): AnalyzeMealDeps {
  return {
    env: (key) => Deno.env.get(key),
    resolveProvider,
    createUserClient: (authHeader: string) => {
      const url = Deno.env.get('SUPABASE_URL');
      // Publishable key first; the platform still injects SUPABASE_ANON_KEY under the older name.
      // Both are the same low-privilege key.
      const key = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY');
      if (!url || !key) {
        throw new Error('SUPABASE_URL and publishable key are required');
      }
      return createClient(url, key, {
        global: { headers: { Authorization: authHeader } },
      });
    },
  };
}

export async function handleAnalyzeMeal(
  req: Request,
  deps: AnalyzeMealDeps = createDefaultDeps(),
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonError(405, 'method_not_allowed');
  }

  // 1. Auth header required before anything else — including provider resolution.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return jsonError(401, 'unauthorized');
  }

  // 2. Verify the token via a caller-scoped client. Every later Supabase call uses this client so
  //    the database and storage see the Cook, and RLS applies exactly as it applies to them.
  let supabase: SupabaseClient;
  try {
    supabase = deps.createUserClient(authHeader);
  } catch (_) {
    return jsonError(500, 'misconfigured');
  }

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return jsonError(401, 'unauthorized');
  }

  // 3. Parse and validate the body BEFORE any provider call, so a bad request never costs money.
  let body: unknown;
  try {
    body = await req.json();
  } catch (_) {
    return jsonError(400, 'invalid_json');
  }

  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    return jsonError(400, 'invalid_body');
  }

  const record = body as Record<string, unknown>;

  if (typeof record.said !== 'string') {
    return jsonError(400, 'said_required');
  }
  const said = record.said;
  if (said.length > SAID_MAX_CHARS) {
    return jsonError(400, 'said_too_long');
  }
  if (said.trim().length === 0) {
    return jsonError(400, 'said_empty');
  }

  if (typeof record.meal_id !== 'string' || !isUuid(record.meal_id)) {
    return jsonError(400, 'meal_id_invalid');
  }
  const mealId = record.meal_id;

  let photoObjectPath: string | undefined;
  if (record.photo_path !== undefined && record.photo_path !== null) {
    if (typeof record.photo_path !== 'string') {
      return jsonError(400, 'photo_path_invalid');
    }
    const parsed = parsePhotoPath(record.photo_path, user.id, mealId);
    if ('error' in parsed) {
      return jsonError(403, 'photo_path_forbidden');
    }
    photoObjectPath = parsed.objectPath;
  }

  // 4. Confirm the caller owns the Meal.
  //
  // The explicit cook_id predicate is required even though RLS is on. The meals SELECT policies
  // also allow ANYONE to read a PUBLISHED Meal, so a query filtered only by id would happily
  // return another Cook's published Meal. Filtering on cook_id = caller is what makes ownership
  // enforcement real here.
  const { data: mealRow, error: mealError } = await supabase
    .from('meals')
    .select('id')
    .eq('id', mealId)
    .eq('cook_id', user.id)
    .maybeSingle();

  if (mealError) {
    console.error(JSON.stringify({ event: 'analyze_meal_meal_lookup_failed', message: mealError.message }));
    return jsonError(500, 'meal_lookup_failed');
  }
  if (!mealRow) {
    return jsonError(403, 'meal_not_owned');
  }

  // 5. Fetch the photo if a path was given. Download failure is not fatal — fall back to words.
  let image: ModelImage | undefined;
  let usedPhoto = false;

  if (photoObjectPath) {
    const { data: blob, error: downloadError } = await supabase.storage
      .from('meal-photos')
      .download(photoObjectPath);

    if (!downloadError && blob) {
      try {
        const buffer = new Uint8Array(await blob.arrayBuffer());
        const mediaType = blob.type && blob.type.length > 0 ? blob.type : 'image/jpeg';
        image = { base64: bytesToBase64(buffer), mediaType };
        usedPhoto = true;
      } catch (error) {
        console.error(
          JSON.stringify({
            event: 'analyze_meal_photo_encode_failed',
            message: error instanceof Error ? error.message : String(error),
          }),
        );
      }
    } else {
      console.error(
        JSON.stringify({
          event: 'analyze_meal_photo_download_failed',
          message: downloadError?.message ?? 'empty',
        }),
      );
    }
  }

  // 6. Resolve provider and call. System prompt from the versioned prompt file; Cook words as user.
  const prompt = PROMPTS[PROMPT_ID];
  if (!prompt) {
    return jsonError(500, 'prompt_missing');
  }

  let resolved: ResolvedProvider;
  try {
    resolved = deps.resolveProvider('fast', deps.env);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'analyze_meal_provider_resolve_failed',
        message: error instanceof Error ? error.message : String(error),
      }),
    );
    return jsonError(502, 'provider_misconfigured');
  }

  const baseRequest: ModelRequest = {
    system: prompt.body,
    user: said,
    image,
    model: resolved.model,
    maxTokens: MAX_TOKENS,
    responseSchema: MEAL_ANALYSIS_SCHEMA,
  };

  let result: Awaited<ReturnType<typeof callProviderWithRetry>>;
  try {
    result = await callProviderWithRetry(resolved.adapter, resolved.apiKey, baseRequest);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'analyze_meal_provider_unexpected',
        message: error instanceof Error ? error.message : String(error),
      }),
    );
    return sseResponse({ type: 'error', error: 'upstream' });
  }

  if (!result.ok) {
    // The provider was reached, so the outcome rides the stream and the app has one consumption
    // path for every post-call failure. The mapped status stays on the envelope as well: a Cook
    // whose request timed out needs a 504 the client can act on, not a 200 carrying bad news.
    return new Response(sseEvent({ type: 'error', error: result.code }), {
      status: result.status,
      headers: sseHeaders(),
    });
  }

  const analysis = result.value;
  const payload = {
    type: 'analysis' as const,
    ingredients: analysis.ingredients,
    calories: analysis.calories ?? null,
    allergens: analysis.allergens,
    cuisine: analysis.cuisine,
    category: analysis.category,
    basis: analysis.basis,
    model_id: result.response.modelId,
    used_photo: usedPhoto,
  };

  return sseResponse(payload);
}

// Deno.serve is the only top-level side effect. Tests import handleAnalyzeMeal with injected deps.
if (import.meta.main) {
  Deno.serve((req) => handleAnalyzeMeal(req));
}
