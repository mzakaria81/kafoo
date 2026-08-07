// Gives a Meal its vector.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THIS FUNCTION TAKES A MEAL ID AND NOTHING ELSE, AND THAT IS THE SECURITY DESIGN.
//
// The obvious shape — accept the text to embed — hands the ranking to the caller. A client that
// supplies the vector's source text can supply the text nearest every query, and that Cook's Meal
// ranks first for everything, permanently, invisibly, and against every other Cook. So the title
// and description are read FROM THE DATABASE by id, and any text in the request body is ignored.
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

import { createClient } from 'jsr:@supabase/supabase-js@2';

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

Deno.serve(async (req) => {
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

  // Publishable key first; the platform still injects SUPABASE_ANON_KEY under the older name.
  // Both are the same low-privilege key.
  const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    Deno.env.get('SUPABASE_ANON_KEY')!;

  // The Cook's own client. Every read below runs under RLS as them.
  const asCook = createClient(Deno.env.get('SUPABASE_URL')!, publishableKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await asCook.auth.getUser();
  if (authError || !user) {
    return json({ error: 'unauthorized' }, 401);
  }

  // 2. The id, and only the id.
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
  //    READ AS THE COOK, so `cook reads own meals` does the work and this cannot see a Meal the
  //    caller could not already open. The `cook_id` predicate is kept as well, because RLS lets a
  //    Cook read their own draft and a stranger read anything published — without it, any account
  //    could walk every published Meal id and force a model call for each, on Kafoo's key, with
  //    nothing in E3 rate-limiting it. Two statements of one rule, and the database owns the
  //    stronger one.
  const { data: meal, error: readError } = await asCook
    .from('meals')
    .select('id, title, description')
    .eq('id', mealId)
    .eq('cook_id', user.id)
    .maybeSingle();

  if (readError) {
    return json({ error: 'could not read the meal' }, 500);
  }
  // Not found and not-yours are one answer on purpose: distinguishing them tells a stranger which
  // ids exist.
  if (!meal) {
    return json({ error: 'no such meal' }, 404);
  }

  const text = embeddableText(meal);
  if (text.length === 0) {
    return json({ error: 'the meal has no text to represent' }, 422);
  }

  // 4. Embed.
  //
  //    A FAILURE HERE IS NOT A FAILURE OF PUBLISHING, and the separation is deliberate. Publishing
  //    a Meal does not call this function inline — `meals.embedding` is nullable and a Meal without
  //    one is invisible to search and fully visible to browsing. So an unreachable provider, an
  //    exhausted quota or a bad key makes a Meal HARDER TO FIND, never lost, and never a Cook who
  //    cannot publish because a model provider is down.
  let vector: readonly number[];
  try {
    const { embed, model, apiKey, dimensions } = resolveEmbedding((key) => Deno.env.get(key));
    const response = await embed({ model, text, task: 'document', dimensions }, apiKey);
    vector = response.vector;
  } catch (error) {
    // 503 rather than 500: this is "come back later", and a caller that retries on 5xx should.
    return json({ error: 'the model provider is unavailable', detail: String(error) }, 503);
  }

  // 5. Write exactly one column, with the only credential that may.
  //
  //    This client can do nothing else to `meals` — not because the code declines to, but because
  //    the grant does not exist. See the migration named above.
  const writer = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { error: writeError } = await writer
    .from('meals')
    .update({ embedding: JSON.stringify(vector) })
    .eq('id', meal.id)
    .eq('cook_id', user.id);

  if (writeError) {
    return json({ error: 'could not store the vector' }, 500);
  }

  // The vector is not returned. Nothing renders it, it is 8 KB of JSON, and handing it back would
  // make it look like something a client is meant to hold.
  return json({ mealId: meal.id, dimensions: vector.length }, 200);
});
