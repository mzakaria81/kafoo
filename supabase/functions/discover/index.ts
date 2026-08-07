// Turns a phrase into ranked Meals. ON THE CRITICAL PATH.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THIS FUNCTION HOLDS NO WRITE CREDENTIAL AND WRITES NOTHING.
//
// It is reachable by anyone, signed in or not — that is what makes discovery work without an
// account, which is the whole point of E3 and a decision the founder took on 2026-08-07 with its
// cost accepted. A function reachable by anyone must therefore be unable to do anything.
//
// It also NEVER RECORDS THE PHRASE. Not a log line, not a cache keyed on it, not an analytics
// attribute. FR-029 and SC-011. The cache is the subtle one: a cache keyed on what somebody said is
// a recording of what they said, however it is described. `SearchPerformed` carries a count and
// never the words.
// ────────────────────────────────────────────────────────────────────────────────────────────────
//
// IT CALLS search_meals AS THE CALLER. The caller's Authorization header is passed straight
// through, so RLS decides what comes back and this function gains no authority of its own. A
// service-role client here would make every Meal findable regardless of status, and
// `discovery_rls_test` case 14 is the only thing that would notice.
//
// IT NEVER REORDERS WHAT THE DATABASE RETURNED. Ranking is `search_meals`' job; a second sort here
// is a second ranking rule in a second place, and the two would disagree the first time either
// changed.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

import { resolveEmbedding } from '../_shared/ai/registry.ts';
import { parsePhrase, Understanding } from './parse.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

export interface DiscoverDeps {
  /// Text in, unit vector out, typed as a QUERY rather than a document — the provider treats the
  /// two differently and research.md §1 measured the difference.
  embedQuery(text: string): Promise<readonly number[]>;

  /// `search_meals`, called as the caller.
  search(
    vector: readonly number[],
    excludeTerms: readonly string[] | null,
    area: string | null,
  ): Promise<unknown[]>;
}

/// What Kafoo understood, in the response, so the interface can say it.
///
/// **A dropped exclusion is indistinguishable from no exclusion unless this is here.** That is the
/// failure the whole exclusion design exists to prevent: the Customer said "without prawns", Kafoo
/// did not recognise the word, and the results arrive looking exactly like results for a request
/// with no exclusion in it.
function understandingForResponse(exclusion: Understanding) {
  switch (exclusion.kind) {
    case 'nothing':
      return { excluded: null, notUnderstood: null };
    case 'found':
      return { excluded: exclusion.id, notUnderstood: null };
    case 'not-understood':
      return { excluded: null, notUnderstood: exclusion.phrase };
  }
}

export async function handleDiscover(req: Request, deps: DiscoverDeps): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  let phrase: unknown;
  let area: unknown;
  try {
    const body = await req.json();
    phrase = body?.phrase;
    area = body?.area ?? null;
  } catch {
    return json({ error: 'malformed body' }, 400);
  }

  if (typeof phrase !== 'string' || phrase.trim().length === 0) {
    return json({ error: 'phrase is required' }, 400);
  }
  if (area !== null && typeof area !== 'string') {
    return json({ error: 'area must be text' }, 400);
  }

  const parsed = parsePhrase(phrase);
  const understood = understandingForResponse(parsed.exclusion);

  let vector: readonly number[];
  try {
    vector = await deps.embedQuery(parsed.text);
  } catch (error) {
    // 503, and the interface must keep browsing working. Search failing may not take browsing with
    // it — a Customer who cannot search can still be shown what is on offer.
    return json(
      { error: 'search is unavailable', detail: String(error), ...understood },
      503,
    );
  }

  const excludeTerms = parsed.exclusion.kind === 'found' ? parsed.exclusion.terms : null;

  let meals: unknown[];
  try {
    meals = await deps.search(vector, excludeTerms, (area as string | null) ?? null);
  } catch (error) {
    return json({ error: 'search is unavailable', detail: String(error), ...understood }, 503);
  }

  // Returned exactly as they came back. Empty is an ordinary outcome, not an error — `judge-results`
  // decides what to SAY about nothing, and that is a different function on purpose.
  return json({ meals, ...understood }, 200);
}

export function createDefaultDeps(authHeader: string | null): DiscoverDeps {
  const url = Deno.env.get('SUPABASE_URL')!;
  const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY')!;

  // The caller's own client. Signed in or not, RLS answers for them and not for us.
  const asCaller: SupabaseClient = createClient(url, publishableKey, {
    global: authHeader ? { headers: { Authorization: authHeader } } : {},
  });

  return {
    async embedQuery(text) {
      const { embed, model, apiKey, dimensions } = resolveEmbedding((key) => Deno.env.get(key));
      const { vector } = await embed({ model, text, task: 'query', dimensions }, apiKey);
      return vector;
    },

    async search(vector, excludeTerms, area) {
      const { data, error } = await asCaller.rpc('search_meals', {
        query_embedding: JSON.stringify(vector),
        exclude_terms: excludeTerms,
        area_query: area,
      });
      if (error) throw error;
      return (data ?? []) as unknown[];
    },
  };
}

if (import.meta.main) {
  Deno.serve((req) => handleDiscover(req, createDefaultDeps(req.headers.get('Authorization'))));
}
