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
// So the write path is kept as narrow as it can be made, and the narrowness is the argument:
//
//   - ONE column. `meals.embedding` and nothing else, asserted by test.
//   - ONE row, identified by an id the caller already owns.
//   - NO text from the request reaches the database — only a vector, whose width is checked.
//   - The model's output can only ever be numbers. It has no path to a title, a price, a status or
//     a Review, because this function never writes those columns under any input.
//
// If a later change makes this function write a second column, that reasoning collapses and the
// change needs an ADR rather than a review comment.

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

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: { user }, error: authError } = await admin.auth.getUser(
    authHeader.slice('Bearer '.length),
  );
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
  //    THE OWNERSHIP CHECK IS NOT ABOUT SECRECY — a published Meal's title is public. It is about
  //    who may SPEND. Without it, anyone holding any account could walk every Meal id in the
  //    marketplace and force a model call for each, on Kafoo's key, and nothing in E3 rate-limits
  //    that. It also keeps the blast radius of this service-role client to rows the caller already
  //    controls.
  const { data: meal, error: readError } = await admin
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

  // 5. Write exactly one column.
  const { error: writeError } = await admin
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
