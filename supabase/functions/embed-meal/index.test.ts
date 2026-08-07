// What `embed-meal` embeds, and what it refuses to be told.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THE FIRST VERSION OF THIS FILE PROVED A TAUTOLOGY, and that is worth recording rather than
// quietly replacing. It imported `embeddableText` — a pure function taking a database row, which
// cannot see a request by construction — and asserted that extra fields on the row changed nothing.
// The file's own banner claimed this "proves the ignoring rather than asserting it".
//
// ai-boundary-reviewer showed what that bought: changing the handler to
// `const text = body.text ?? embeddableText(meal)` would have handed ranking to the caller and left
// every test AND the whole gate green. A test that cannot fail for the thing it names is worse than
// no test, because it stops anybody writing the real one.
//
// So these drive the handler, through a fake database whose stored Meal says something DIFFERENT
// from the request body. If the body ever wins, assertion 3 goes red.
// ────────────────────────────────────────────────────────────────────────────────────────────────

import { assertEquals } from 'jsr:@std/assert@1';

import { EmbedMealDeps, handleEmbedMeal, MealRow } from './index.ts';
import { embeddableText } from './text.ts';

const COOK = 'cook-1';
const MEAL: MealRow = { id: 'meal-1', title: 'كشري', description: 'عدس ورز' };

interface Recorder {
  embedded: string[];
  written: { mealId: string; cookId: string; length: number }[];
}

function deps(overrides: Partial<EmbedMealDeps> = {}): [EmbedMealDeps, Recorder] {
  const recorder: Recorder = { embedded: [], written: [] };
  const base: EmbedMealDeps = {
    verifyCaller: () => Promise.resolve({ id: COOK }),
    readMeal: (mealId, cookId) =>
      Promise.resolve(mealId === MEAL.id && cookId === COOK ? MEAL : null),
    embed: (text) => {
      recorder.embedded.push(text);
      return Promise.resolve(new Array(768).fill(0.1));
    },
    writeVector: (mealId, cookId, vector) => {
      recorder.written.push({ mealId, cookId, length: vector.length });
      return Promise.resolve();
    },
  };
  return [{ ...base, ...overrides }, recorder];
}

function post(body: unknown, auth = 'Bearer token'): Request {
  return new Request('https://kafoo.test/embed-meal', {
    method: 'POST',
    headers: { Authorization: auth, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

Deno.test('a Meal is embedded from what the database holds', async () => {
  const [d, recorder] = deps();
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);

  assertEquals(response.status, 200);
  assertEquals(recorder.embedded, [embeddableText(MEAL)]);
  assertEquals(recorder.written, [{ mealId: MEAL.id, cookId: COOK, length: 768 }]);
});

Deno.test('text in the request body NEVER reaches the model', async () => {
  // THE ASSERTION THIS FILE EXISTS FOR. A caller who can choose the text can choose the text
  // nearest every query, and their Meal ranks first for everything — permanently, invisibly, and
  // against every other Cook. The body below tries every name the handler might plausibly read.
  const [d, recorder] = deps();
  const response = await handleEmbedMeal(
    post({
      mealId: MEAL.id,
      text: 'the nearest vector to every query',
      title: 'الأفضل في مصر',
      description: 'كشري برجر بيتزا فراخ لحمة سمك',
      embedding: [1, 2, 3],
    }),
    d,
  );

  assertEquals(response.status, 200);
  assertEquals(recorder.embedded, [embeddableText(MEAL)]);
  assertEquals(recorder.embedded[0].includes('برجر'), false);
});

Deno.test('a Meal belonging to someone else is not embedded, and is not distinguished from a missing one', async () => {
  const [d, recorder] = deps();
  const response = await handleEmbedMeal(post({ mealId: 'someone-elses-meal' }), d);

  assertEquals(response.status, 404);
  assertEquals(recorder.embedded, []);
  assertEquals(recorder.written, []);

  // A different status for "exists but not yours" would let a stranger enumerate the marketplace.
  const missing = await handleEmbedMeal(post({ mealId: 'no-such-meal' }), d);
  assertEquals(missing.status, 404);
});

Deno.test('an unreachable provider writes nothing and says come back later', async () => {
  // The acceptance criterion behind this: publishing a Meal must succeed when the provider is
  // down. It does, because publishing never calls this — and when this does fail, it must fail
  // WITHOUT writing, or a Meal ends up with a vector from a half-finished call.
  const [d, recorder] = deps({
    embed: () => Promise.reject(new Error('the model provider is rate limiting us')),
  });
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);

  assertEquals(response.status, 503);
  assertEquals(recorder.written, []);
});

Deno.test('a refused write is reported rather than swallowed', async () => {
  const [d] = deps({ writeVector: () => Promise.reject(new Error('permission denied')) });
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);
  assertEquals(response.status, 500);
});

Deno.test('no token means no model call', async () => {
  // Spend is the reason this matters as much as authorization: an unauthenticated caller who
  // reached the provider would be spending Kafoo's quota.
  const [d, recorder] = deps();
  for (const auth of ['', 'token', 'Basic abc']) {
    const response = await handleEmbedMeal(post({ mealId: MEAL.id }, auth), d);
    assertEquals(response.status, 401, `"${auth}" was accepted`);
  }
  assertEquals(recorder.embedded, []);
});

Deno.test('a token the platform rejects means no model call', async () => {
  const [d, recorder] = deps({ verifyCaller: () => Promise.resolve(null) });
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);
  assertEquals(response.status, 401);
  assertEquals(recorder.embedded, []);
});

Deno.test('a body without a mealId is refused before anything is spent', async () => {
  const [d, recorder] = deps();
  for (const body of [{}, { mealId: '' }, { mealId: 42 }, { mealId: null }]) {
    const response = await handleEmbedMeal(post(body), d);
    assertEquals(response.status, 400, `${JSON.stringify(body)} was accepted`);
  }
  assertEquals(recorder.embedded, []);
});

Deno.test('a Meal with nothing written about it is not sent to the provider', async () => {
  const [d, recorder] = deps({
    readMeal: () => Promise.resolve({ id: MEAL.id, title: '   ', description: null }),
  });
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);

  assertEquals(response.status, 422);
  assertEquals(recorder.embedded, []);
});

Deno.test('the response hands back no vector', async () => {
  const [d] = deps();
  const response = await handleEmbedMeal(post({ mealId: MEAL.id }), d);
  const body = await response.json();

  assertEquals(body.dimensions, 768);
  assertEquals('embedding' in body, false);
  assertEquals('vector' in body, false);
});
