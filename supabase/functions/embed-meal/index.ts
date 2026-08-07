// Gives a Meal its vector.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THIS FUNCTION TAKES A MEAL ID AND NOTHING ELSE, AND THAT IS THE SECURITY DESIGN.
//
// The obvious shape — accept the text to embed — hands the ranking to the caller. A client that
// supplies the vector's source text can supply the text nearest every query, and that Cook's Meal
// ranks first for everything, permanently, invisibly, and against every other Cook. So the title
// and description are read FROM THE DATABASE by id, and any text in the request body is ignored.
//
// `index.test.ts` PROVES that by driving this handler with a fake database whose stored Meal differs
// from the one named in the request body. The first version of this file claimed the test proved it
// while the test only exercised a pure function that cannot see a request — a tautology, caught by
// ai-boundary-reviewer, which pointed out that changing the line below to
// `body.text ?? embeddableText(meal)` would have left every test and the whole gate green.
// `index.test.ts` proves the ignoring rather than asserting it.
//
// The database refuses a client-written vector too — see `protect_meal_embedding` — so this is the
// second of two guards rather than the only one. Both exist because each has a way of being
// bypassed that the other catches.
// ────────────────────────────────────────────────────────────────────────────────────────────────
//
// WHY THIS FUNCTION HOLDS A SERVICE-ROLE KEY WHEN `.claude/rules/ai.md` SAYS THE MODEL-CALLING
// FUNCTION MUST NOT.
//
// That rule is about the conversational path, and its reasoning is that a function which both talks
// to a model and can write is structurally able to let the model's output reach the database
// unreviewed. Kafoo's domain rule is that AI suggests and humans approve.
//
// An embedding is the one AI-derived value that rule cannot sensibly cover. It is not a claim, not
// content, and not shown to anybody — it is a machine representation of words a Cook already wrote
// and already approved. There is no human judgement to apply to 768 floating-point numbers, and
// requiring an approval step for them would be theatre.
//
// So the write path is kept as narrow as it can be made, AND POSTGRES IS WHAT KEEPS IT NARROW.
//
// `20260807064927` grants service_role `UPDATE (embedding)` and `SELECT (id, cook_id)` on meals and
// nothing else, over a role that holds no table-level privilege there. Measured:
//
//     UPDATE meals SET embedding = ...  -> succeeds
//     UPDATE meals SET status = ...     -> ERROR: permission denied for table meals
//     SELECT title FROM meals           -> ERROR: permission denied for table meals
//
// That matters because the first version of this exception was enforced by a script that reads this
// file, and ai-boundary-reviewer walked past it four ways — including by moving the update payload
// into a variable, which is what any implementer does when an object grows, and which would have
// let this function publish a Meal. A guard you can evade by refactoring is not a guard.
//
// The READ runs as the Cook rather than as service_role, so RLS decides what this function can see
// and the ownership check below is a second statement of the same rule rather than the only one.
//
// If a later change makes this function write a second column, the reasoning collapses AND the
// database refuses it. Widening it is an ADR and a migration, not a review comment.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

import { resolveEmbedding } from '../_shared/ai/registry.ts';
import { embeddableText } from './text.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

/// A Meal as this function needs to see it. Title and description, and nothing else — there is no
/// field here for a caller's words to arrive through.
export interface MealRow {
  readonly id: string;
  readonly title: string;
  readonly description: string | null;
}

/// Everything that touches the outside world, injected so the handler can be driven in a test.
///
/// Named individually rather than passed as a Supabase client, because the point of the seam is
/// that a test can hand this function a database whose Meal says something DIFFERENT from what the
/// request body says, and watch which one is embedded.
export interface EmbedMealDeps {
  /// The signed-in caller, or null. Never read from the body.
  verifyCaller(authHeader: string): Promise<{ id: string } | null>;

  /// The Meal, scoped to its owner. Null when it does not exist OR is not theirs — one answer, so
  /// a stranger cannot learn which ids exist.
  readMeal(mealId: string, cookId: string): Promise<MealRow | null>;

  /// Text in, vector out. Throws when the provider is unreachable.
  embed(text: string): Promise<readonly number[]>;

  /// The only write. Throws on refusal.
  writeVector(mealId: string, cookId: string, vector: readonly number[]): Promise<void>;
}

export async function handleEmbedMeal(req: Request, deps: EmbedMealDeps): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  // 1. Verify the token and take the user id from it. Never from anywhere else.
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return json({ error: 'unauthorized' }, 401);
  }

  const caller = await deps.verifyCaller(authHeader);
  if (!caller) {
    return json({ error: 'unauthorized' }, 401);
  }

  // 2. The id, and only the id. Every other field in the body is read by nothing.
  let mealId: unknown;
  try {
    mealId = (await req.json())?.mealId;
  } catch {
    return json({ error: 'malformed body' }, 400);
  }

  if (typeof mealId !== 'string' || mealId.length === 0) {
    return json({ error: 'mealId is required' }, 400);
  }

  // 3. Read the Meal, scoped to its owner.
  //
  //    The ownership predicate is not about secrecy — a published Meal's title is public. It is
  //    about who may SPEND. Without it, any account could walk every published Meal id and force a
  //    model call for each, on Kafoo's key, with nothing in E3 rate-limiting it.
  let meal: MealRow | null;
  try {
    meal = await deps.readMeal(mealId, caller.id);
  } catch {
    return json({ error: 'could not read the meal' }, 500);
  }
  if (!meal) {
    return json({ error: 'no such meal' }, 404);
  }

  const text = embeddableText(meal);
  if (text.length === 0) {
    return json({ error: 'the meal has no text to represent' }, 422);
  }

  // 4. Embed.
  //
  //    A FAILURE HERE IS NOT A FAILURE OF PUBLISHING. Publishing does not call this function
  //    inline — `meals.embedding` is nullable and a Meal without one is invisible to search and
  //    fully visible to browsing. So an unreachable provider, an exhausted quota or a bad key makes
  //    a Meal HARDER TO FIND, never lost, and never a Cook who cannot publish.
  let vector: readonly number[];
  try {
    vector = await deps.embed(text);
  } catch (error) {
    // 503 rather than 500: this is "come back later", and a caller that retries on 5xx should.
    return json({ error: 'the model provider is unavailable', detail: String(error) }, 503);
  }

  // 5. Write exactly one column, with the only credential that may.
  try {
    await deps.writeVector(meal.id, caller.id, vector);
  } catch {
    return json({ error: 'could not store the vector' }, 500);
  }

  // The vector is not returned. Nothing renders it, it is 8 KB of JSON, and handing it back would
  // make it look like something a client is meant to hold.
  return json({ mealId: meal.id, dimensions: vector.length }, 200);
}

/// The real world. Every Supabase call in this function lives here, in one place a reader can check
/// against ADR-0011 and `scripts/check-ai-write-boundary.py`.
export function createDefaultDeps(): EmbedMealDeps {
  const url = Deno.env.get('SUPABASE_URL')!;
  // Publishable key first; the platform still injects SUPABASE_ANON_KEY under the older name.
  // Both are the same low-privilege key.
  const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY')!;

  const asCook = (authHeader: string): SupabaseClient =>
    createClient(url, publishableKey, {
      global: { headers: { Authorization: authHeader } },
    });

  // The narrow credential. Postgres grants it UPDATE (embedding) and SELECT (id, cook_id) on meals
  // and nothing else — see migration 20260807064927. It cannot publish a Meal, change a price or
  // read a title, and that is a property of the grant rather than of this code.
  const writer = (): SupabaseClient =>
    createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  let header = '';

  return {
    async verifyCaller(authHeader) {
      header = authHeader;
      const { data, error } = await asCook(authHeader).auth.getUser();
      if (error || !data.user) return null;
      return { id: data.user.id };
    },

    async readMeal(mealId, cookId) {
      // Read as the Cook, so RLS decides what this function can see.
      const { data, error } = await asCook(header)
        .from('meals')
        .select('id, title, description')
        .eq('id', mealId)
        .eq('cook_id', cookId)
        .maybeSingle();
      if (error) throw error;
      return data as MealRow | null;
    },

    async embed(text) {
      const { embed, model, apiKey, dimensions } = resolveEmbedding((key) => Deno.env.get(key));
      const response = await embed({ model, text, task: 'document', dimensions }, apiKey);
      return response.vector;
    },

    async writeVector(mealId, cookId, vector) {
      const { error } = await writer()
        .from('meals')
        .update({ embedding: JSON.stringify(vector) })
        .eq('id', mealId)
        .eq('cook_id', cookId);
      if (error) throw error;
    },
  };
}

// Deno.serve is the only top-level side effect, and it is guarded — same shape as analyze-meal.
// Without the guard, importing this module to test the handler starts a server and the test fails
// with "Requires net access" instead of an assertion, which is how the tautological test got
// written in the first place.
if (import.meta.main) {
  Deno.serve((req) => handleEmbedMeal(req, createDefaultDeps()));
}
