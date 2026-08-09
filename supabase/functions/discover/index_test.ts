// What `discover` does with a phrase, and what it must never do with one.
//
// Run with: deno test --allow-read supabase/functions/discover/

import { assertEquals } from 'jsr:@std/assert@1';

import { DiscoverDeps, handleDiscover } from './index.ts';
import { foldArabic, parsePhrase } from './parse.ts';

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
  assertEquals(body.notUnderstood, false);
  // `لحم` rather than `لحمة`: the vocabulary carries one spelling per word now, and the database
  // folds both sides before matching, so `لحم` reaches a Cook who typed `لحمة مفرومة`.
  assertEquals((recorder.searched[0].exclude ?? []).includes('لحم'), true);
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
  assertEquals(body.notUnderstood, true);
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
  assertEquals(body.notUnderstood, true);
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

Deno.test('a spelling nobody enumerated is still understood, on this side too', () => {
  // The same five cases the Dart suite carries. Folding lives in three places — Dart, here, and
  // `public.fold_arabic` — and the failure when they disagree is silent: a Customer's word is
  // recognised in the app and matches no Meal in the database, or the reverse.
  const cases: ReadonlyArray<readonly [string, string]> = [
    ['من غير مكرونه', 'gluten'],
    ['من غير بسطرمه', 'meat'],
    ['من غير قشده', 'dairy'],
    ['عندي حساسية من جندوفلى', 'shellfish'],
    ['من غير لحـمة', 'meat'],
    // Crab, not the mullet whose name is inside it.
    ['من غير كابوريا', 'shellfish'],
  ];
  for (const [phrase, id] of cases) {
    const outcome = parsePhrase(phrase).exclusion;
    assertEquals(outcome.kind, 'found', phrase);
    assertEquals(outcome.kind === 'found' ? outcome.id : '', id, phrase);
  }
});


Deno.test('THE FOLD AGREES WITH THE SHARED CASE FILE', () => {
  // The TypeScript third of a three-way agreement. packages/domain holds Dart to this same file,
  // and supabase/tests/arabic_folding_test.sql — generated from it — holds Postgres.
  //
  // The three disagreed on seventeen whitespace codepoints on 2026-08-07 and nothing noticed,
  // because each side had cases somebody had written for it and each side passed its own. The
  // failure that produces is silent: a Customer's word recognised here and matching no Meal in the
  // database, or the reverse.
  const file = new URL(
    '../../../packages/domain/test/goldens/arabic_folding.json',
    import.meta.url,
  );
  const cases = (JSON.parse(Deno.readTextFileSync(file)) as {
    cases: { id: string; input: string; folded: string; why: string }[];
  }).cases;

  assertEquals(cases.length >= 25, true, 'the shared case file shrank');

  for (const c of cases) {
    assertEquals(
      foldArabic(c.input),
      c.folded,
      `${c.id}: ${c.why} — TypeScript disagrees with the shared expectation. If the fold changed ` +
        `on purpose, change the file and re-run scripts/generate-folding-cases.py.`,
    );
    // Idempotent, for the same reason the Dart suite checks it.
    assertEquals(foldArabic(foldArabic(c.input)), foldArabic(c.input), c.id);
  }
});

Deno.test('THE SHARED CORPUS: this side answers exactly what the Dart side answers', () => {
  // Every case here was found by localization-reviewer running both sides on 2026-08-07 against
  // suites that were green. `exclusion_vocabulary_test.dart` carries the identical list. The app
  // and this function parse the same sentence, and a silent disagreement is a Customer's exclusion
  // understood on one side and matching nothing on the other.
  const cases: ReadonlyArray<readonly [string, string]> = [
    // An allergy spelled with the other letter. Returned `nothing` — not not-understood, NOTHING.
    ['\u0639\u0646\u062F\u064A \u062D\u0633\u0627\u0633\u064A\u0647 \u0645\u0646 \u0627\u0644\u0645\u0643\u0633\u0631\u0627\u062A', 'nuts'],
    ['\u062D\u0633\u0627\u0633\u064A\u0647 \u0645\u0646 \u0627\u0644\u0644\u0628\u0646', 'dairy'],
    // Two foods in one breath: the first is the one honoured.
    ['\u0645\u0646 \u063A\u064A\u0631 \u0644\u0628\u0646 \u0648\u0644\u0627 \u0628\u064A\u0636', 'dairy'],
    ['\u0645\u0634 \u0639\u0627\u064A\u0632 \u0633\u0645\u0643 \u0648\u0644\u0627 \u0644\u062D\u0645\u0629', 'fish'],
    ['\u0645\u0646 \u063A\u064A\u0631 \u0644\u062D\u0645\u0629 \u0648\u0644\u0627 \u0641\u0631\u0627\u062E', 'meat'],
    // White cheese is dairy, not eggs.
    ['\u0645\u0646 \u063A\u064A\u0631 \u062C\u0628\u0646\u0629 \u0628\u064A\u0636\u0627\u0621', 'dairy'],
    // Peanut butter is peanut, not butter.
    ['\u0645\u0646 \u063A\u064A\u0631 \u0632\u0628\u062F\u0629 \u0627\u0644\u0641\u0648\u0644 \u0627\u0644\u0633\u0648\u062F\u0627\u0646\u064A', 'peanut'],
    // Crab, not the mullet inside it.
    ['\u0645\u0646 \u063A\u064A\u0631 \u0643\u0627\u0628\u0648\u0631\u064A\u0627', 'shellfish'],
    // The bare stem an ingredient list actually carries.
    ['\u0628\u062F\u0648\u0646 \u0633\u0645\u0646', 'dairy'],
    ['\u0645\u0646 \u063A\u064A\u0631 \u0645\u0639\u0643\u0631\u0648\u0646\u0629', 'gluten'],
    // An invisible character changes nothing: zero-width non-joiner, then a no-break space.
    ['\u0645\u0646 \u063A\u064A\u0631 \u0644\u200C\u062D\u0645\u0629', 'meat'],
    ['\u0645\u0646 \u063A\u064A\u0631\u00A0\u0644\u062D\u0645\u0629', 'meat'],
    // The founder's vocabulary decisions of 2026-08-10. Here as well as in Dart because this is
    // the corpus that proves the two parsers agree, and a decision honoured on one surface only is
    // the failure this test exists for. Mayonnaise is egg; tuna is fish.
    ['\u0645\u0646 \u063A\u064A\u0631 \u0645\u0627\u064A\u0648\u0646\u064A\u0632', 'egg'],
    ['\u0645\u0646 \u063A\u064A\u0631 \u062A\u0648\u0646\u0629', 'fish'],
    // "I don't eat X" is a negation. Both returned NOTHING before this \u2014 no marker matched, so the
    // phrase read as an ordinary request and the food came back with nothing said.
    ['\u0645\u0628\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    ['\u0645\u0628\u0627\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    // The spellings the first pass missed. The negation particle \u0645\u0627 is written apart as often as
    // it is joined, and all four of these said NOTHING while the suite was green for the two above.
    ['\u0645\u0627\u0628\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    ['\u0645\u0627\u0628\u0627\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    ['\u0645\u0627 \u0628\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    ['\u0645\u0627 \u0628\u0627\u0643\u0644\u0634 \u0644\u062D\u0645\u0629', 'meat'],
    // `\u062A\u0648\u0646\u0629` is the tin and `\u062A\u0648\u0646\u0627` is the menu board. Shipping only the first meant a Customer
    // excluding fish was TOLD the fish was removed and then served a tuna salad.
    ['\u0645\u0646 \u063A\u064A\u0631 \u062A\u0648\u0646\u0627', 'fish'],
  ];
  for (const [phrase, id] of cases) {
    const outcome = parsePhrase(phrase).exclusion;
    assertEquals(outcome.kind, 'found', phrase);
    assertEquals(outcome.kind === 'found' ? outcome.id : '', id, phrase);
  }

  // A food name inside another word is not the food. Kafoo says it did not understand rather than
  // guessing, which is the visible failure rather than the silent one.
  for (const phrase of [
    '\u0645\u0634 \u0639\u0627\u064A\u0632 \u0641\u0644\u0641\u0644 \u0623\u0628\u064A\u0636',
    '\u0645\u0646 \u063A\u064A\u0631 \u0631\u0632 \u0623\u0628\u064A\u0636',
    '\u0645\u0646 \u063A\u064A\u0631 \u0645\u0644\u0628\u0646',
  ]) {
    assertEquals(parsePhrase(phrase).exclusion.kind, 'not-understood', phrase);
  }
});

Deno.test('ONE SENTENCE CARRIES THE PHRASE, THE EXCLUSION AND THE AREA', async () => {
  // T207 and Principle IV. `عايز حاجة من غير لحمة في المهندسين` is what a Customer says; three
  // controls to collect it would be the form the rules forbid at exactly this point.
  const [d, recorder] = deps();
  const body = await (await handleDiscover(
    post({ phrase: 'عايز حاجة من غير لحمة في المهندسين' }),
    d,
  )).json();

  assertEquals(body.excluded, 'meat');
  assertEquals(recorder.searched[0].area, 'المهندسين');
  assertEquals(body.area, 'المهندسين');
  // The sentence is embedded whole. The area is a database predicate as well as words in the text,
  // for the same reason the exclusion is: removing it would change what the Customer asked for.
  assertEquals(recorder.embedded[0], 'عايز حاجة من غير لحمة في المهندسين');
});

Deno.test('an area the Customer CHOSE overrides the one in their sentence', async () => {
  // FR-024a. The area they named was empty, Kafoo offered the areas that are not, and they picked
  // one. That choice arrives on top of the same sentence — if the sentence won, it would be
  // unreachable and the offer would be decoration.
  const [d, recorder] = deps();
  const body = await (await handleDiscover(
    post({ phrase: 'كشري في أسوان', area: 'المهندسين' }),
    d,
  )).json();

  assertEquals(recorder.searched[0].area, 'المهندسين');
  assertEquals(body.area, 'المهندسين');
});

Deno.test('a locative marker is a whole word and never the first one', () => {
  // `في` opening a sentence is Egyptian for "is there any", not a place. And `فيه` and `الفيوم`
  // contain the marker without being it — a substring scan would narrow every one of them to
  // nothing and then tell the Customer their area is empty.
  assertEquals(parsePhrase('في حاجة سخنة').area, null);
  assertEquals(parsePhrase('عايز أكل فيه فراخ').area, null);
  assertEquals(parsePhrase('عايز أكل في المهندسين').area, 'المهندسين');
  assertEquals(parsePhrase('عايزة حاجة في الفرن في مصر الجديدة').area, 'مصر الجديدة');
  // Nothing after the marker is not an area.
  assertEquals(parsePhrase('عايز أكل في').area, null);
});

Deno.test('the area is never normalised here', () => {
  // `normalise_area` lives in SQL and nowhere else — the migration that created it says so, and the
  // Cook's side already compares through it. Folding here too would be one rule in two languages.
  assertEquals(parsePhrase('كشري في العجوزة').area, 'العجوزة');
  assertEquals(parsePhrase('كشري في العجوزه').area, 'العجوزه');
});

Deno.test('NO WORD OF THE PHRASE COMES BACK EXCEPT THE AREA', async () => {
  // TIGHTENED 2026-08-07 after trust-reviewer walked past the test below. That one asserts the
  // WHOLE phrase is absent, and `notUnderstood` was returning the entire tail of the sentence after
  // the negation marker — most of a phrase, which is not the whole of it, so it passed while
  // `المايونيز بتاع محل عمو سيد جنب بيتي` sat in a 503 body.
  //
  // A test that asserts on the exact input string can only catch a verbatim echo. This asserts word
  // by word, which is what "the phrase does not come back" actually means.
  //
  // The area IS returned, and deliberately: the interface says "results from المهندسين only", so it
  // needs the word. It is one token a Cook also wrote about their own kitchen, not the sentence.
  const phrase = 'عايز حاجة من غير المايونيز بتاع محل عمو سيد جنب بيتي في المهندسين';
  const [d] = deps();
  const responses = [
    await handleDiscover(post({ phrase }), d),
    await handleDiscover(
      post({ phrase }),
      deps({ embedQuery: () => Promise.reject(new Error('down')) })[0],
    ),
  ];

  for (const response of responses) {
    const text = await response.text();
    for (const word of phrase.split(/\s+/)) {
      if (word === 'المهندسين') continue;
      assertEquals(text.includes(word), false, `"${word}" came back in ${text}`);
    }
  }
});

Deno.test('AN ERROR NEVER CARRIES THE PHRASE OUT', async () => {
  // FR-029 and SC-011 name "an error carrying the request" by name. This response carried
  // `String(error)` until 2026-08-07, and a provider rejecting a request answers with a body that
  // quotes the request back — _shared/ai/gemini.ts puts that body straight into the message.
  const phrase = 'عايز فراخ مشوية في المهندسين';
  for (const broken of [
    { embedQuery: () => Promise.reject(new Error(`400 invalid input: ${phrase}`)) },
    { search: () => Promise.reject(new Error(`syntax error near "${phrase}"`)) },
  ]) {
    const [d] = deps(broken);
    const response = await handleDiscover(post({ phrase }), d);
    const text = await response.text();
    assertEquals(response.status, 503);
    assertEquals(text.includes(phrase), false, text);
  }
});
