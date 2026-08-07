// judge-results — whether the Meals Kafoo found honestly answer what the Customer asked for.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// OFF THE CRITICAL PATH BY CONSTRUCTION. The Customer already has their results on screen when this
// is called; `search_controller` does not await it. A judgement that fails, hangs, or returns
// nonsense costs the Customer A SENTENCE and never their results.
//
// THIS FUNCTION HOLDS NO SERVICE-ROLE KEY AND WRITES NOTHING. Like `discover`, it reads with the
// caller's own credentials and gains no authority of its own — so RLS decides which Meals it can
// see, and an unpublished Meal is invisible to the judgement exactly as it is to the Customer.
// index_test.ts asserts both properties against this directory's sources rather than trusting the
// sentence above (FR-018, T217). The filename is `_test` and not `.test`: the gate globs the first
// and the second means "needs a live stack", which scripts/verify.sh now says out loud.
//
// IT NEVER RECORDS THE PHRASE. Not a log line, not a cache keyed on it, not an analytics attribute.
// FR-029 and SC-011, the same rule `discover` carries — a cache keyed on what somebody said is a
// recording of what they said, however it is described. Note what is NOT logged below when the
// model reply fails validation: the errors, never the request.
//
// WHY IT EXISTS AT ALL. Matching by meaning never returns nothing — it returns everything, ordered.
// Something has to decide that nothing matched, and research.md §4 measured that no score can: a
// query the corpus could not answer scored HIGHER than one it answered correctly, on both an
// absolute and a relative rule. Inside a corpus that is entirely food, every food query is
// topically close to everything, and a better model does not fix that.
// ────────────────────────────────────────────────────────────────────────────────────────────────

import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

import { resolveProvider, type ResolvedProvider } from '../_shared/ai/registry.ts';
import { parseAndValidate } from '../_shared/ai/schema.ts';
import { ModelError, type ModelRequest } from '../_shared/ai/types.ts';
import { PROMPTS } from '../_shared/prompts.ts';
import {
  buildUserContent,
  type JudgeableMeal,
  type Judgement,
  JUDGEMENT_SCHEMA,
  toJudgement,
} from './judge.ts';

const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PROMPT_ID = 'discovery-judgement';
const MAX_TOKENS = 256;

/// `search_meals` returns at most 50, so a longer list is not a bigger search — it is a caller
/// sending something else.
const MAX_MEALS = 50;
const PHRASE_MAX_CHARS = 500;

export interface JudgeDeps {
  /// The Meals, read AS THE CALLER, in the order their ids were given.
  readMeals(mealIds: readonly string[]): Promise<readonly JudgeableMeal[]>;

  resolveProvider: (
    tier: 'fast' | 'reasoning',
    env: (key: string) => string | undefined,
  ) => ResolvedProvider;

  env(key: string): string | undefined;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

/// NOTHING TO SAY, AND IT MUST BE A FAILURE STATUS RATHER THAN AN EMPTY BODY.
///
/// The client reads any 200 whose `answers` is not `true` as "nothing matched" — see
/// `SupabaseDiscoveryRepository.judge`. So a 200 meaning "I could not judge" would put the words
/// "nothing here answers you" in front of a Customer whose results were fine, which is a false
/// SearchFailed manufactured by a network error. A non-2xx makes `invoke` throw, the repository
/// answers `null`, and the Customer keeps their results with no sentence attached.
function nothingToSay(): Response {
  return json({ error: 'no judgement' }, 503);
}

export async function handleJudge(req: Request, deps: JudgeDeps): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  let phrase: unknown;
  let mealIds: unknown;
  try {
    const body = await req.json();
    phrase = body?.phrase;
    mealIds = body?.mealIds;
  } catch {
    return json({ error: 'malformed body' }, 400);
  }

  if (typeof phrase !== 'string' || phrase.trim().length === 0) {
    return json({ error: 'phrase is required' }, 400);
  }
  if (phrase.length > PHRASE_MAX_CHARS) {
    return json({ error: 'phrase is too long' }, 400);
  }
  if (!Array.isArray(mealIds) || mealIds.some((id) => typeof id !== 'string')) {
    return json({ error: 'mealIds must be a list of ids' }, 400);
  }
  if (mealIds.length === 0 || mealIds.length > MAX_MEALS) {
    return json({ error: 'mealIds must name between 1 and 50 Meals' }, 400);
  }

  // READ AS THE CALLER. The judgement may only speak about Meals the Customer can already see, and
  // that is enforced by whose credentials do the reading rather than by a status filter here.
  let meals: readonly JudgeableMeal[];
  try {
    meals = await deps.readMeals(mealIds as string[]);
  } catch {
    return nothingToSay();
  }

  // Every Meal gone between the search and now — a Cook clearing their menu, or a caller naming ids
  // nobody can read. There is nothing to judge, and saying "nothing answers you" on the strength of
  // an empty read would be a judgement nobody made.
  if (meals.length === 0) return nothingToSay();

  let provider: ResolvedProvider;
  try {
    provider = deps.resolveProvider(PROMPTS[PROMPT_ID].modelTier, deps.env);
  } catch {
    return nothingToSay();
  }

  const request: ModelRequest = {
    model: provider.model,
    system: PROMPTS[PROMPT_ID].body,
    user: buildUserContent(phrase, meals),
    maxTokens: MAX_TOKENS,
    responseSchema: JUDGEMENT_SCHEMA,
  };

  let judgement: Judgement;
  try {
    const response = await provider.adapter.complete(request, provider.apiKey);
    const parsed = parseAndValidate(response.text, JUDGEMENT_SCHEMA);
    if ('errors' in parsed) {
      // NO RETRY, AND THAT IS THE ONE PLACE THIS FUNCTION DIFFERS FROM `analyze-meal` ON PURPOSE.
      // There, a Cook is waiting on a draft and a second attempt is worth the seconds. Here the
      // Customer has their results already and the reply is worth one sentence — so a second call
      // spends money and latency to maybe add a sentence to a screen the Customer may have left.
      //
      // A COUNT, AND NOT THE ERRORS THEMSELVES. Written the obvious way first — logging
      // `parsed.errors` — and caught by the test below, which ran it: a JSON parse failure quotes
      // the reply verbatim into the message, and a model reply routinely restates the request it
      // was given. So the Customer's words ride out through a diagnostic. Schema errors leak the
      // same way one step further in, naming a property the model invented.
      //
      // Same defect `discover` shipped as `detail: String(error)` and removed on 2026-08-07. FR-029
      // says a log line specifically, and a log line is what this was.
      console.error(
        JSON.stringify({ event: 'judge_invalid_response', errorCount: parsed.errors.length }),
      );
      return nothingToSay();
    }
    judgement = toJudgement(parsed.value as Record<string, unknown>, meals);
  } catch (error) {
    if (error instanceof ModelError) {
      console.error(JSON.stringify({ event: 'judge_provider_failed', kind: error.kind }));
      return nothingToSay();
    }
    throw error;
  }

  return json(judgement, 200);
}

export function createDefaultDeps(authHeader: string | null): JudgeDeps {
  const url = Deno.env.get('SUPABASE_URL')!;
  const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY')!;

  const asCaller: SupabaseClient = createClient(url, publishableKey, {
    global: authHeader ? { headers: { Authorization: authHeader } } : {},
  });

  return {
    env: (key) => Deno.env.get(key),
    resolveProvider,

    async readMeals(mealIds) {
      const { data, error } = await asCaller
        .from('meals')
        .select('id, title, description')
        .in('id', mealIds);
      if (error) throw error;

      // Returned in the order the ids arrived, which is the order the database ranked them. `in`
      // does not promise an order, and the numbering the model sees must match the Customer's
      // screen — otherwise "number 2" names a different Meal at each end.
      const byId = new Map(
        (data ?? []).map((row) => [
          row.id as string,
          {
            id: row.id as string,
            title: (row.title ?? '') as string,
            description: (row.description ?? '') as string,
          },
        ]),
      );
      return mealIds.map((id) => byId.get(id)).filter((meal): meal is JudgeableMeal =>
        meal !== undefined
      );
    },
  };
}

if (import.meta.main) {
  Deno.serve((req) => handleJudge(req, createDefaultDeps(req.headers.get('Authorization'))));
}
