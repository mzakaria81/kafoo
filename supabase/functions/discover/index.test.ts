// What `discover` does with a phrase, and what it must never do with one.
//
// Run with: deno test --allow-read supabase/functions/discover/

import { assertEquals } from 'jsr:@std/assert@1';

import { DiscoverDeps, handleDiscover } from './index.ts';
import { parsePhrase } from './parse.ts';

interface Recorder {
  embedded: string[];
  searched: {
    exclude: readonly string[] | null;
    area: string | null;
    vector: readonly number[];
  }[];
}

const MEALS = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];

function deps(overrides: Partial<DiscoverDeps> = {}): [DiscoverDeps, Recorder] {
  const recorder: Recorder = { embedded: [], searched: [] };
  const base: DiscoverDeps = {
    embedQuery: (text) => {
      recorder.embedded.push(text);
      return Promise.resolve(new Array(768).fill(0.1));
    },
    search: (vector, exclude, area) => {
      recorder.searched.push({ vector, exclude, area });
      return Promise.resolve(MEALS);
    },
  };
  const built: DiscoverDeps = { ...base, ...overrides };
  return [built, recorder];
}

function post(body: unknown): Request {
  return new Request('https://kafoo.test/discover', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

Deno.test('a plain phrase reaches search unfiltered and comes back unreordered', async () => {
  const [d, recorder] = deps();
  const response = await handleDiscover(post({ phrase: 'حاجة خفيفة' }), d);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(recorder.embedded, ['حاجة خفيفة']);
  assertEquals(recorder.searched[0].exclude, null);
  // Ranking is search_meals' job. A second sort here is a second ranking rule in a second place.
  assertEquals(body.meals, MEALS);
});

Deno.test('a recognised exclusion becomes a predicate, not a phrase for the model', async () => {
  // Measured 2026-08-06: asking for food with no meat BY MEANING returned meat dishes, first
  // correct answer at rank 6, precision@5 of 0.00.
  const [d, recorder] = deps();
  const response = await handleDiscover(post({ phrase: 'أكل من غير لحمة خالص' }), d);
  const body = await response.json();

  assertEquals(body.excluded, 'meat');
  assertEquals(body.notUnderstood, null);
  assertEquals((recorder.searched[0].exclude ?? []).includes('لحمة'), true);
  // The words stay in the embedded text. Stripping them would silently change the request.
  assertEquals(recorder.embedded[0], 'أكل من غير لحمة خالص');
});

Deno.test('AN EXCLUSION KAFOO DID NOT UNDERSTAND IS REPORTED, NEVER DROPPED', async () => {
  // THE ASSERTION THE CONTRACT CALLS OUT. A dropped exclusion is indistinguishable from no
  // exclusion in the response, and the Customer is served the thing they asked to avoid while the
  // interface has no way to know it should say anything.
  const [d, recorder] = deps();
  const response = await handleDiscover(post({ phrase: 'من غير كافيار' }), d);
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.notUnderstood, 'كافيار');
  assertEquals(body.excluded, null);
  // And nothing was filtered on, because Kafoo does not know what to filter on — which is exactly
  // why the interface must say so.
  assertEquals(recorder.searched[0].exclude, null);
});

Deno.test('an allergy stated plainly is an exclusion', async () => {
  const [d] = deps();
  const body = await (await handleDiscover(post({ phrase: 'عندي حساسية من المكسرات' }), d)).json();
  assertEquals(body.excluded, 'nuts');
});

Deno.test('an area narrows and is never widened here', async () => {
  const [d, recorder] = deps();
  // An area with nothing on offer. Overridden so it still records what it was asked.
  d.search = (vector, exclude, area) => {
    recorder.searched.push({ vector, exclude, area });
    return Promise.resolve([]);
  };
  const body = await (await handleDiscover(post({ phrase: 'كشري', area: 'أسوان' }), d)).json();

  assertEquals(recorder.searched[0].area, 'أسوان');
  // Empty is an ordinary outcome, not an error, and not a reason to search again more widely.
  // Widening is the Customer's action — FR-024a.
  assertEquals(body.meals, []);
});

Deno.test('an unreachable provider fails search without taking browsing with it', async () => {
  const [d, recorder] = deps({
    embedQuery: () => Promise.reject(new Error('rate limited')),
  });
  const response = await handleDiscover(post({ phrase: 'كشري' }), d);

  assertEquals(response.status, 503);
  // Nothing was searched, and nothing was written anywhere — the Customer simply cannot search
  // right now. The interface keeps browse working.
  assertEquals(recorder.searched, []);
});

Deno.test('a failure still reports what was understood', async () => {
  // Otherwise a Customer who excluded something, and hit an outage, gets an error that looks
  // identical to one from a request with no exclusion in it.
  const [d] = deps({ search: () => Promise.reject(new Error('down')) });
  const body = await (await handleDiscover(post({ phrase: 'من غير كافيار' }), d)).json();
  assertEquals(body.notUnderstood, 'كافيار');
});

Deno.test('an empty or missing phrase is refused before anything is spent', async () => {
  const [d, recorder] = deps();
  for (const body of [{}, { phrase: '' }, { phrase: '   ' }, { phrase: 42 }]) {
    const response = await handleDiscover(post(body), d);
    assertEquals(response.status, 400, `${JSON.stringify(body)} was accepted`);
  }
  assertEquals(recorder.embedded, []);
});

Deno.test('the response carries no trace of the phrase beyond what was understood', async () => {
  // FR-029 and SC-011. The response names an exclusion id — `meat` — and the unrecognised noun,
  // because the interface has to say those. It does not echo the sentence.
  const [d] = deps();
  const response = await handleDiscover(post({ phrase: 'أكل من غير لحمة خالص' }), d);
  const text = await response.text();

  assertEquals(text.includes('أكل من غير لحمة خالص'), false, text);
});

Deno.test('the parser agrees with the Dart vocabulary it was generated from', () => {
  // The words are generated from packages/domain/lib/exclusion.dart; the logic is written twice.
  // These are the cases the Dart suite carries, so the two cannot disagree quietly.
  assertEquals(parsePhrase('عايز حاجة سخنة').exclusion.kind, 'nothing');
  assertEquals(parsePhrase('مش عايزة لحمة').exclusion.kind, 'found');
  assertEquals(parsePhrase('من غير اللحمة').exclusion.kind, 'found');
  assertEquals(parsePhrase('من غير أي لحمة').exclusion.kind, 'found');
  assertEquals(parsePhrase('من غير فول سوداني').exclusion.kind, 'found');
  assertEquals(parsePhrase('عايز أكل من غير').exclusion.kind, 'not-understood');
});
