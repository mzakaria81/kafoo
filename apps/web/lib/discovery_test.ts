import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';

import type { Judgement, SearchOutcome } from './discovery.ts';
import { Discovery } from './discovery.ts';
import type { SearchConsent } from './consent.ts';
import { CONSENT_KEY, readConsent, writeConsent } from './consent.ts';
import type { KitchenRow, MealRow } from './supabase.ts';

// The modules are IMPORTED and RUN here, not read as text. `lib/preview_test.ts`
// reads its sources because its assertions are about what the source contains;
// these are about what actually leaves the browser, and SC-014 says so in terms:
// "verified by watching what leaves rather than by reading the code that
// decides". Node strips the types on the way in, and `tsc --noEmit` checks them
// — this file was `.mjs` until 2026-08-08 and therefore outside `tsconfig`'s
// `include`, so nothing checked that a test still matched the API it tested.

const PHRASE = 'عايز حاجة سخنة من غير لحمة في المهندسين';

/** A browser store, with the same three states and the same key. */
function fakeStorage(initial?: string): Storage {
  const map = new Map<string, string>(initial ? [[CONSENT_KEY, initial]] : []);
  return {
    getItem: (k: string) => map.get(k) ?? null,
    setItem: (k: string, v: string) => void map.set(k, String(v)),
    removeItem: (k: string) => void map.delete(k),
    clear: () => map.clear(),
    key: () => null,
    length: 0,
  };
}

/** One request that left: where it went and what it carried. */
type SentRequest = { url: string; init: RequestInit };

type Responder = (url: string, init: RequestInit) => Promise<Response>;

/** A `fetch` that records, plus the two readers the assertions use. */
type WatchedFetch = typeof globalThis.fetch & {
  sent: SentRequest[];
  everythingSent: () => string;
};

/**
 * A `fetch` that answers whatever it is told to and RECORDS EVERYTHING.
 *
 * `sent` is the evidence: every URL and every body that left. A test asserts
 * against it rather than against the branch that was supposed to prevent it.
 */
function watchedFetch(responder: Responder): WatchedFetch {
  const sent: SentRequest[] = [];
  const fn = (async (url: RequestInfo | URL, init?: RequestInit) => {
    sent.push({ url: String(url), init: init ?? {} });
    return responder(String(url), init ?? {});
  }) as WatchedFetch;
  fn.sent = sent;
  /** Everything that left, as one string, for "does the phrase appear anywhere". */
  fn.everythingSent = () =>
    sent.map((r) => `${r.url} ${r.init.body ?? ''}`).join('\n');
  return fn;
}

// `as unknown as Response` and nowhere else. `Discovery` reads exactly `ok` and
// `json()`, and a full `Response` here would be forty fields of ceremony for a
// two-field contract. Named once, so the cast is a decision rather than a habit.
const ok = (body: unknown) =>
  ({ ok: true, status: 200, json: async () => body }) as unknown as Response;

const failed = (status: number) =>
  ({
    ok: false,
    status,
    json: async () => ({ error: 'search is unavailable' }),
  }) as unknown as Response;

function discovery({
  consent,
  respond,
}: {
  consent?: SearchConsent;
  respond?: Responder;
}) {
  const fetch = watchedFetch(respond ?? (async () => ok({ meals: [] })));
  const instance = new Discovery({
    backend: { url: 'https://example.supabase.co', publishableKey: 'sb_publishable_x' },
    storage: fakeStorage(consent),
    fetch,
  });
  return { instance, fetch };
}

const MEAL: MealRow = {
  id: 'm1',
  cook_id: 'c1',
  title: 'كشري',
  description: 'كشري بلدي',
  price: '40',
  cuisine: 'egyptian',
  category: 'main',
  status: 'published',
  photo_path: null,
};
const KITCHEN: KitchenRow = {
  id: 'k1',
  cook_id: 'c1',
  display_name: 'مطبخ أم أحمد',
  story: 'بطبخ من عشرين سنة',
  area: 'المهندسين',
  delivery_terms: 'التوصيل بالاتفاق',
  photo_path: null,
};

/** discover → meals, then the kitchens read. */
function respondWithOneMeal(extra: Record<string, unknown> = {}): Responder {
  return async (url) => {
    if (url.includes('/functions/v1/discover')) {
      return ok({ meals: [MEAL], excluded: null, notUnderstood: false, area: null, ...extra });
    }
    if (url.includes('/rest/v1/kitchen_profiles')) return ok([KITCHEN]);
    return failed(500);
  };
}

/**
 * Narrows a search response to its results, failing the test if it is not one.
 *
 * The union exists so a caller cannot read `outcome` off a refusal, and before
 * this file was type-checked the tests did exactly that — reaching through a
 * `SearchResponse` without asking which arm it was. It passed because the fake
 * always returned results; it would have thrown on the day one did not, blaming
 * the assertion rather than the change.
 */
function resultsOf(response: { kind: string } & Partial<{ outcome: SearchOutcome }>) {
  assert.equal(response.kind, 'results', `expected results, got ${response.kind}`);
  assert.ok(response.outcome, 'a results response with no outcome');
  return response.outcome!;
}

/** Narrows a judgement to the "nothing answers" arm. */
function nothingAnswers(judgement: Judgement | null) {
  assert.ok(judgement, 'expected a judgement, got none');
  assert.equal(judgement.answers, false, 'expected "nothing answers"');
  return judgement as Extract<Judgement, { answers: false }>;
}

// ─────────────────────────────────────────────────────────────────────────────
// SC-014 — a Customer who refused sends ZERO words to anything outside Kafoo.
// ─────────────────────────────────────────────────────────────────────────────

test('SC-014: a refused Customer sends zero words, by every entrance', async () => {
  const { instance, fetch } = discovery({ consent: 'refused' });

  // Every way a phrase can be asked to leave. `search` is the obvious one;
  // choosing an area re-sends the same sentence, and the judgement sends it a
  // second time one round trip later. The app shipped a gate that covered only
  // the first of these.
  assert.deepEqual(await instance.search(PHRASE, null), { kind: 'refused' });
  assert.deepEqual(await instance.search(PHRASE, 'الدقي'), { kind: 'refused' });
  assert.equal(await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]), null);

  assert.equal(fetch.sent.length, 0, `something left: ${fetch.everythingSent()}`);
  assert.ok(
    !fetch.everythingSent().includes('لحمة'),
    'a word the Customer said appeared in what left',
  );
});

test('SC-014: an unanswered Customer sends nothing either', async () => {
  // The question comes first. Nothing leaves on the strength of "not yet
  // refused" — an absent answer is not a yes.
  const { instance, fetch } = discovery({ consent: undefined });
  assert.deepEqual(await instance.search(PHRASE, null), { kind: 'refused' });
  assert.equal(fetch.sent.length, 0, fetch.everythingSent());
});

test('SC-011: the phrase leaves in a POST body and never in a URL', async () => {
  // A URL is written to Cloudflare's request log, to the browser's history, and
  // to `Referer` on every subresource. Any of those is FR-029 broken by a
  // mechanism nobody wrote.
  const { instance, fetch } = discovery({ consent: 'granted', respond: respondWithOneMeal() });
  await instance.search(PHRASE, null);

  assert.ok(fetch.sent.length > 0, 'nothing was sent at all');
  for (const { url, init } of fetch.sent) {
    assert.ok(!url.includes('لحمة'), `the phrase reached a URL: ${url}`);
    assert.ok(!url.includes('?phrase'), `the phrase reached a query string: ${url}`);
    if (init.body) assert.equal(init.method, 'POST');
  }
  const discover = fetch.sent.find((r) => r.url.includes('/functions/v1/discover'));
  assert.ok(discover, 'discover was not called');
  assert.equal(JSON.parse(bodyOf(discover)).phrase, PHRASE);
});

test('the web calls the same discover function — no endpoint of its own', async () => {
  const { instance, fetch } = discovery({ consent: 'granted', respond: respondWithOneMeal() });
  const outcome = resultsOf(await instance.search(PHRASE, null));
  assert.equal(outcome.results.length, 1);
  assert.equal(outcome.results[0].kitchen.display_name, KITCHEN.display_name);
  assert.ok(
    fetch.sent[0].url.endsWith('/functions/v1/discover'),
    `first call went to ${fetch.sent[0].url}`,
  );
});

test('an area a Customer chose is sent, and wins over the sentence', async () => {
  // FR-024a. Widening is the Customer's action, and this is what makes the
  // offer act-on-able rather than decorative.
  const { instance, fetch } = discovery({ consent: 'granted', respond: respondWithOneMeal() });
  await instance.search(PHRASE, 'الدقي');
  const body = JSON.parse(bodyOf(fetch.sent[0]));
  assert.equal(body.area, 'الدقي');
  assert.equal(body.phrase, PHRASE);
});

test('search failing is unavailable, and never an empty marketplace', async () => {
  // The two must not arrive looking the same: one of them means "no Cook has
  // anything", and that is a thing Kafoo would be saying without knowing it.
  const { instance } = discovery({
    consent: 'granted',
    respond: async () => failed(503),
  });
  assert.deepEqual(await instance.search(PHRASE, null), { kind: 'unavailable' });
});

test('an empty result in a named area is distinguishable from an empty marketplace', async () => {
  // FR-024. `discover` echoes the area it narrowed on, and that echo is the only
  // thing that tells the two apart.
  const { instance } = discovery({
    consent: 'granted',
    respond: async () => ok({ meals: [], excluded: null, notUnderstood: false, area: 'المهندسين' }),
  });
  const response = await instance.search(PHRASE, null);
  assert.equal(response.kind, 'results');
  assert.equal(response.outcome.area, 'المهندسين');
  assert.equal(response.outcome.results.length, 0);
});

test('a recognised negation with an unrecognised food reaches the surface as a flag', async () => {
  const { instance } = discovery({
    consent: 'granted',
    respond: async () => ok({ meals: [], excluded: null, notUnderstood: true, area: null }),
  });
  const outcome = resultsOf(await instance.search(PHRASE, null));
  assert.equal(outcome.notUnderstood, true);
});

// ─────────────────────────────────────────────────────────────────────────────
// FR-026 / T218 — the honesty layer, on this surface too.
// ─────────────────────────────────────────────────────────────────────────────

test('the judgement is asked for, with ids and the phrase and nothing else', async () => {
  const { instance, fetch } = discovery({
    consent: 'granted',
    respond: async () => ok({ answers: true }),
  });
  const judgement = await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]);
  assert.deepEqual(judgement, { answers: true });

  const call = fetch.sent.find((r) => r.url.includes('/functions/v1/judge-results'));
  assert.ok(call, 'judge-results was not called — the surface would ship results with nothing checking them');
  assert.deepEqual(Object.keys(JSON.parse(bodyOf(call))).sort(), ['mealIds', 'phrase']);
  assert.deepEqual(JSON.parse(bodyOf(call)).mealIds, ['m1']);
});

test('a Meal the AI Assistant invented is dropped, not looked up', async () => {
  // FR-015: an alternative is a Meal genuinely on offer. Matching against the
  // set that was handed over is what makes that true even when the model
  // invents an id.
  const { instance } = discovery({
    consent: 'granted',
    respond: async () => ok({ answers: false, alternatives: ['m1', 'nonexistent'] }),
  });
  const judgement = nothingAnswers(
    await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]),
  );
  assert.deepEqual(judgement.alternatives.map((m) => m.id), ['m1']);
});

test('a 200 whose `answers` is not a boolean says nothing at all', async () => {
  // Reading "not true" as "nothing answers you" would put that sentence in
  // front of a Customer whose results were fine, on the strength of any body
  // that reached here wearing a 200.
  for (const body of [{ error: 'no judgement' }, { answers: 'yes' }, {}, []]) {
    const { instance } = discovery({ consent: 'granted', respond: async () => ok(body) });
    assert.equal(
      await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]),
      null,
      `body ${JSON.stringify(body)} was read as a judgement`,
    );
  }
});

test('every judgement failure is "nothing to say" — the Customer keeps their results', async () => {
  for (const respond of [
    async () => failed(503),
    async () => {
      throw new Error('network');
    },
    // A 200 whose body is not JSON. Cast because the point is a response that
    // does NOT honour the contract.
    async () =>
      ({
        ok: true,
        status: 200,
        json: async () => {
          throw new Error('not json');
        },
      }) as unknown as Response,
  ] satisfies Responder[]) {
    const { instance } = discovery({ consent: 'granted', respond });
    assert.equal(await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]), null);
  }
});

test('no results means no judgement call — there is nothing to judge', async () => {
  const { instance, fetch } = discovery({ consent: 'granted' });
  assert.equal(await instance.judge(PHRASE, []), null);
  assert.equal(fetch.sent.length, 0);
});

// ─────────────────────────────────────────────────────────────────────────────
// FR-029, FR-030 — what is recorded, and what is never recorded.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * The body of a request that left, as the string it always is.
 *
 * `RequestInit.body` is a `BodyInit` union covering streams and blobs. Nothing
 * in `Discovery` sends anything but `JSON.stringify`, so this asserts that
 * rather than casting past it — if a future caller sends a stream, the test says
 * so instead of parsing `undefined`.
 */
function bodyOf(request: SentRequest): string {
  assert.equal(typeof request.init.body, 'string', `${request.url} sent a non-string body`);
  return request.init.body as string;
}

/** Every analytics row that left, parsed. */
const eventsIn = (fetch: WatchedFetch) =>
  fetch.sent
    .filter((r) => r.url.includes('/rest/v1/analytics_events'))
    .map((r) => JSON.parse(bodyOf(r)) as { name: string; attributes: Record<string, unknown> });

test('SearchPerformed carries what Kafoo chose, never what was said', async () => {
  // Asserted on the attribute SET rather than on the values: a test that checks
  // only the ones it knows about stays green the day a phrase is added beside
  // them, which is the exact way this requirement would be lost.
  const { instance, fetch } = discovery({ consent: 'granted', respond: respondWithOneMeal() });
  await instance.search(PHRASE, null);

  const events = eventsIn(fetch);
  assert.equal(events.length, 1, `expected one event, got ${JSON.stringify(events)}`);
  assert.equal(events[0].name, 'SearchPerformed');
  assert.deepEqual(
    Object.keys(events[0].attributes).sort(),
    ['area_narrowed', 'result_count', 'top_category', 'top_cuisine'],
  );
  assert.equal(events[0].attributes.result_count, 1);
  // The domain enums off the first result — what Kafoo SERVED.
  assert.equal(events[0].attributes.top_cuisine, MEAL.cuisine);
  assert.equal(events[0].attributes.top_category, MEAL.category);
  assert.equal(events[0].attributes.area_narrowed, false);
  assert.ok(!fetch.everythingSent().includes('"person_id"'), 'this surface has no session to attach');
});

test('a search narrowed to an area says SO, and never which area', async () => {
  // With result_count 0 this separates "no Cooks near this person" from "nothing
  // like this on the menu". A boolean, because the area is a phrase the Customer
  // said.
  const { instance, fetch } = discovery({
    consent: 'granted',
    respond: async (url) =>
      url.includes('/functions/v1/discover')
        ? ok({ meals: [], excluded: null, notUnderstood: false, area: 'الزمالك' })
        : ok({}),
  });
  await instance.search(PHRASE, null);

  const [event] = eventsIn(fetch);
  assert.equal(event.attributes.area_narrowed, true);
  assert.equal(event.attributes.result_count, 0);
  // Nothing served, so there is no cuisine to name. A literal rather than an
  // absent key, so every SearchPerformed is the same shape.
  assert.equal(event.attributes.top_cuisine, 'none');
  assert.equal(event.attributes.top_category, 'none');
  assert.ok(
    !JSON.stringify(event).includes('الزمالك'),
    'the area the Customer named reached an event',
  );
});

test('MealOpened says where it was opened from, and what kind of food', async () => {
  const { instance, fetch } = discovery({ consent: 'granted' });
  instance.mealOpened(MEAL, 'browse');
  await new Promise((r) => setTimeout(r, 0));

  const [event] = eventsIn(fetch);
  assert.equal(event.name, 'MealOpened');
  assert.deepEqual(Object.keys(event.attributes).sort(), ['category', 'cuisine', 'source']);
  assert.equal(event.attributes.source, 'browse');
  assert.equal(event.attributes.cuisine, MEAL.cuisine);
  assert.equal(event.attributes.category, MEAL.category);
  // NEVER THE MEAL'S ID. An id and a timestamp together are a search somebody
  // could reconstruct.
  assert.ok(!JSON.stringify(event).includes(MEAL.id), 'MealOpened carries the Meal id');
  // And never the Cook's own words — the title and description are what a Cook
  // typed; cuisine and category are chosen from a list.
  assert.ok(!JSON.stringify(event).includes(MEAL.title), 'MealOpened carries the title');
});

test('MealOpened is emitted whether or not a search ran', async () => {
  // It is not behind the consent gate, and that is deliberate: the gate exists
  // for a Customer's WORDS leaving Kafoo for an outside service. This is Kafoo
  // recording, in its own database, that a Meal was opened — the same thing the
  // app does from browse, where no consent question has ever been asked.
  const { instance, fetch } = discovery({ consent: 'refused' });
  instance.mealOpened(MEAL, 'browse');
  await new Promise((r) => setTimeout(r, 0));
  assert.equal(eventsIn(fetch).length, 1);
  assert.ok(!fetch.everythingSent().includes('/functions/v1/'), 'no phrase left');
});

test('a search that never ran emits nothing at all', async () => {
  // Not an event with a count of zero. Kafoo records searches, and what did not
  // happen is not one.
  for (const consent of ['refused', undefined] satisfies (SearchConsent | undefined)[]) {
    const { instance, fetch } = discovery({ consent });
    await instance.search(PHRASE, null);
    assert.deepEqual(eventsIn(fetch), []);
  }
});

test('a search that ran and found nothing still emits, with a count of zero', async () => {
  const { instance, fetch } = discovery({
    consent: 'granted',
    respond: async (url) =>
      url.includes('/functions/v1/discover')
        ? ok({ meals: [], excluded: null, notUnderstood: false, area: null })
        : ok({}),
  });
  await instance.search(PHRASE, null);
  const events = eventsIn(fetch);
  assert.equal(events.length, 1);
  assert.equal(events[0].attributes.result_count, 0);
});

test('SearchFailed is emitted where the judgement said nothing answers, and carries nothing', async () => {
  const { instance, fetch } = discovery({
    consent: 'granted',
    respond: async (url) =>
      url.includes('/functions/v1/judge-results')
        ? ok({ answers: false, alternatives: [] })
        : ok({}),
  });
  await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]);
  const events = eventsIn(fetch);
  assert.equal(events.length, 1);
  assert.equal(events[0].name, 'SearchFailed');
  assert.deepEqual(events[0].attributes, {});
});

test('a judgement that answers emits no SearchFailed', async () => {
  const { instance, fetch } = discovery({ consent: 'granted', respond: async () => ok({ answers: true }) });
  await instance.judge(PHRASE, [{ meal: MEAL, kitchen: KITCHEN }]);
  assert.deepEqual(eventsIn(fetch), []);
});

test('RecommendationAccepted carries a rank and never an id', async () => {
  // An id plus a timestamp is a search somebody could reconstruct.
  const { instance, fetch } = discovery({ consent: 'granted' });
  instance.recommendationAccepted(2);
  await new Promise((r) => setTimeout(r, 0));
  const events = eventsIn(fetch);
  assert.equal(events[0].name, 'RecommendationAccepted');
  assert.deepEqual(events[0].attributes, { rank: 2 });
  assert.ok(!fetch.everythingSent().includes(MEAL.id));
});

test('no event carries a word the Customer said', async () => {
  // The sweep that matters, now that attributes may be strings. Every word of a
  // phrase naming a food and an area is checked against every value that left.
  const { instance, fetch } = discovery({ consent: 'granted', respond: respondWithOneMeal() });
  await instance.search(PHRASE, 'الدقي');
  instance.mealOpened(MEAL, 'search');
  await new Promise((r) => setTimeout(r, 0));

  const words = [...PHRASE.split(/\s+/), 'الدقي'].filter((w) => w.length > 2);
  for (const event of eventsIn(fetch)) {
    const values = Object.values(event.attributes).map(String).join(' ');
    for (const word of words) {
      assert.ok(
        !values.includes(word),
        `${event.name} carries "${word}" — a word the Customer typed`,
      );
    }
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// The gate is one door, and stays one door.
// ─────────────────────────────────────────────────────────────────────────────

test('every phrase-carrying call goes through the one gate', () => {
  // A behavioural test above proves the gate holds for the three entrances that
  // exist today. This one is about the fourth: the app's gate sat on `search`,
  // `chooseArea` called the sender directly, and a refused Customer's sentence
  // went out anyway. `deps.fetch` is reachable from exactly two places — the
  // gated sender, and the kitchens read, which carries cook ids and no word
  // anybody said.
  const source = readFileSync('lib/discovery.ts', 'utf8');
  const calls = source.match(/this\.deps\.fetch\(/g) ?? [];
  assert.equal(
    calls.length,
    3,
    `deps.fetch is called ${calls.length} times; the three are send(), readKitchens() and emit(). ` +
      'A new caller must either go through send() or carry no word anybody said.',
  );
  // The gate is the sender's first statement, before anything is on the wire.
  const send = source.slice(source.indexOf('private async send('));
  const gate = send.indexOf('allowsSearch(readConsent');
  const request = send.indexOf('this.deps.fetch(');
  assert.ok(gate > 0 && gate < request, 'the consent check must precede the request');
});

test('SC-009: every price a Customer reads carries its currency', () => {
  // The app renders `٣٥ جنيه`; this surface rendered `35` on three pages. Money
  // a Customer reads is never a naked number, and "identical to what is visible
  // inside" is the criterion rather than a preference.
  for (const file of [
    'app/meal-card.tsx',
    'app/m/[id]/page.tsx',
    'app/k/[id]/page.tsx',
  ]) {
    const source = readFileSync(file, 'utf8');
    const prices = source.match(/className="price">\{[^}]*\}/g) ?? [];
    assert.ok(prices.length > 0, `${file} renders no price at all`);
    for (const rendered of prices) {
      assert.ok(
        rendered.includes('priceLabel('),
        `${file} renders a bare price: ${rendered}`,
      );
    }
  }
});

test('no user-facing string is written into the code', () => {
  // FR-028 and ADR-0008: every string a Customer reads lives in the messages
  // files, on this surface exactly as in the app.
  for (const file of ['lib/discovery.ts', 'app/search-panel.tsx', 'app/settings/page.tsx']) {
    const source = readFileSync(file, 'utf8')
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/^\s*\/\/.*$/gm, '');
    assert.ok(
      !/[؀-ۿ]/.test(source),
      `${file} contains Arabic text outside the messages files`,
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// The answer, kept in the browser — FR-029b, FR-029d, SC-015.
// ─────────────────────────────────────────────────────────────────────────────

test('an unrecognised stored value is unanswered, never granted', () => {
  assert.equal(readConsent(fakeStorage('yes')), 'unanswered');
  assert.equal(readConsent(fakeStorage()), 'unanswered');
  assert.equal(readConsent(null), 'unanswered');
  assert.equal(readConsent(fakeStorage('granted')), 'granted');
  assert.equal(readConsent(fakeStorage('refused')), 'refused');
});

test('a Customer cannot become un-asked', () => {
  // SC-015. A code path that could restore the unanswered state is a code path
  // that could ask the question again.
  const storage = fakeStorage('granted');
  writeConsent(storage, 'unanswered');
  assert.equal(readConsent(storage), 'granted');
});

test('the answer survives in both directions — FR-029c', () => {
  const storage = fakeStorage();
  writeConsent(storage, 'granted');
  assert.equal(readConsent(storage), 'granted');
  writeConsent(storage, 'refused');
  assert.equal(readConsent(storage), 'refused');
  writeConsent(storage, 'granted');
  assert.equal(readConsent(storage), 'granted');
});

test('storage that throws reads as unanswered rather than as permission', () => {
  // A browser with storage disabled, or a page in a partitioned third-party
  // context. Only the two methods `readConsent` and `writeConsent` touch are
  // defined — a full `Storage` here would be four more members of ceremony to
  // say "this one throws".
  const hostile = {
    getItem() {
      throw new Error('storage disabled');
    },
    setItem() {
      throw new Error('storage disabled');
    },
  } as unknown as Storage;
  assert.equal(readConsent(hostile), 'unanswered');
  writeConsent(hostile, 'granted'); // must not throw
});

test('the key is the one the browser already holds', () => {
  // Never renamed: a renamed key is a Customer being asked a question they
  // already answered.
  assert.equal(CONSENT_KEY, 'kafoo.search_consent');
});

// ─────────────────────────────────────────────────────────────────────────────
// The accessibility and RTL fixes, asserted on the source.
//
// These are markup and CSS properties, not behaviour, so a source assertion is
// the honest tool — the same one `preview_test.ts` uses for the preview cap.
// It is NOT as good as rendering: every defect below was found by building the
// real component and measuring it in a browser, which nothing in this repository
// can currently do. A DOM harness is the real fix and is not in this change.
// ─────────────────────────────────────────────────────────────────────────────

/** Comments stripped, for the same reason `preview_test.ts` strips them: a
 *  comment naming what it enforces is exactly what should be kept, and it must
 *  not be counted as markup. Counting `role="alert"` without this found three
 *  occurrences for two elements. */
const withoutComments = (src: string) =>
  src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/\{\s*\/\*[\s\S]*?\*\/\s*\}/g, '');

const panel = withoutComments(readFileSync('app/search-panel.tsx', 'utf8'));
const css = readFileSync('app/globals.css', 'utf8');

test('the status region exists before its text, and there is exactly one', () => {
  // A live region inserted in the same mutation as its content is not reliably
  // announced — VoiceOver and JAWS frequently miss it. All three original
  // regions were created already populated, and six of nine sentences had no
  // region at all.
  const polite = panel.match(/aria-live="polite"/g) ?? [];
  assert.equal(polite.length, 1, `expected one polite live region, found ${polite.length}`);
  assert.match(panel, /role="status" aria-live="polite">\s*\n\s*\{statusLine\(/,
    'the status region must be rendered unconditionally with its text as a child');
});

test('every search outcome has something to announce', () => {
  const body = panel.slice(panel.indexOf('function statusLine'));
  for (const key of [
    'searchIsOff', 'searchRunning', 'searchUnavailable',
    'searchAreaEmpty', 'searchFoundNothing', 'searchResultCount',
  ]) {
    assert.ok(body.includes(key), `statusLine says nothing for ${key}`);
  }
});

test('the exclusion sentence interrupts rather than waits', () => {
  // The allergy-adjacent one: Kafoo could not identify what to leave out, so a
  // list that honoured nothing sounds exactly like a list that honoured it.
  const alerts = panel.match(/role="alert"/g) ?? [];
  assert.equal(alerts.length, 2, 'both branches that render it need role="alert"');
  for (const match of panel.matchAll(/role="alert">\s*\n\s*\{([\w.]+)\}/g)) {
    assert.equal(match[1], 't.searchExclusionNotUnderstood');
  }
});

test('the search row cannot push its button off the screen', () => {
  // Measured at 200% text on a 412px viewport: left:-77 right:-29, entirely
  // outside the viewport. `min-inline-size` defaults to `auto` on a flex item,
  // which for an <input> is its intrinsic 20-character width.
  const rule = css.slice(css.indexOf('.search input {'), css.indexOf('.search button'));
  assert.ok(rule.includes('min-inline-size: 0'), '.search input needs min-inline-size: 0');
  assert.match(css, /\.search-row \{[^}]*flex-wrap: wrap/, '.search-row needs to wrap at 320px');
});

test('every tap target reaches the token', () => {
  for (const selector of ['.bar a {', '.switch {', '.search input {', '.choice {']) {
    const rule = css.slice(css.indexOf(selector));
    const block = rule.slice(0, rule.indexOf('}'));
    assert.ok(
      block.includes('--kafoo-tap-target'),
      `${selector} does not reach the 48px tap target`,
    );
  }
  // The checkbox must not shrink as the Customer scales text UP.
  assert.match(css, /\.switch input \{[^}]*flex: none/);
});

test('a control boundary is visible, not a hairline', () => {
  // WCAG 1.4.11 wants 3:1 for the visual boundary of a control. The literal it
  // replaced measured 2.10:1 and was the only thing marking the search box.
  assert.ok(!css.includes('rgba(0, 0, 0, 0.3)'), 'the 2.10:1 border is back');
  assert.match(css, /--kafoo-border:/);
  assert.match(css, /\.search input \{[^}]*border: 1px solid var\(--kafoo-border\)/);
});

test('focus is moved rather than destroyed', () => {
  // Measured `activeElement === BODY` at both consent transitions: the form
  // holding the focused button unmounts and the Customer lands at the top of
  // the document.
  assert.match(panel, /consentRef\.current\?\.focus\(\)|innerRef\.current\?\.focus\(\)/);
  assert.match(panel, /resultsRef\.current\?\.focus\(\)/);
  assert.match(css, /:focus-visible \{/, 'a moved focus must be visible to a sighted user');
});

test("every element holding a Cook's own words carries dir=auto", () => {
  // The page is dir="rtl", so a Latin-script title inherits an RTL paragraph
  // direction and its trailing punctuation is thrown to the far left.
  for (const [file, fields] of [
    ['app/meal-card.tsx', ['item.meal.title']],
    ['app/m/[id]/page.tsx', ['item.meal.title', 'item.meal.description']],
    ['app/k/[id]/page.tsx', ['kitchen.display_name', 'kitchen.story', 'kitchen.area', 'kitchen.delivery_terms', 'meal.title']],
  ] as const) {
    const source = readFileSync(file, 'utf8');
    for (const field of fields) {
      const rendered = new RegExp(`dir="auto"[^>]*>\\{${field.replace(/\./g, '\\.')}\\}`);
      assert.match(source, rendered, `${file}: {${field}} renders without dir="auto"`);
    }
  }
  // The kitchen name sits at the END of an Arabic sentence, so it is isolated
  // rather than given a paragraph direction.
  assert.match(readFileSync('app/meal-card.tsx', 'utf8'), /kitchen: `⁨\$\{item\.kitchen\.display_name\}⁩`/);
});

test('the Settings control explains itself', () => {
  const settings = readFileSync('app/settings/page.tsx', 'utf8');
  assert.match(settings, /aria-describedby=/, 'the toggle must point at its explanation');
  assert.ok(settings.includes('id="explanation"') && settings.includes('id="storage"'));
  assert.match(settings, /role="status"/, 'a disabled control must say why it is disabled');
});
