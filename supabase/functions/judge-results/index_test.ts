// The judgement, driven by the golden corpus in packages/ai/test/goldens/discovery_judgement/.
//
// ONE CORPUS, TWO SUITES. The fixtures live where the contract says goldens live, and the Dart
// suite in packages/ai/test/ runs the same files against the stub adapter to prove the provider
// abstraction carries them. This suite runs them through the REAL parser, because the parser lives
// here — where the call is made — and writing a second one in Dart to make a test symmetrical would
// be two implementations of a trust rule.

import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';

import { ModelError, type ModelRequest, type ModelResponse } from '../_shared/ai/types.ts';
import { PROMPTS } from '../_shared/prompts.ts';
import { handleJudge, type JudgeDeps } from './index.ts';
import { buildUserContent, type JudgeableMeal, toJudgement } from './judge.ts';

const GOLDENS_DIR = new URL('../../../packages/ai/test/goldens/discovery_judgement/', import.meta.url);

interface Fixture {
  readonly name: string;
  readonly kind: string;
  readonly phrase: string;
  readonly meals: readonly JudgeableMeal[];
  readonly modelReply: string;
  readonly expect: {
    /// Absent means the reply was usable. `false` means Kafoo publishes nothing at all.
    readonly judged?: boolean;
    readonly answers?: boolean;
    readonly alternatives?: readonly string[];
    /// The field the model smuggled a claim into, which the schema refuses.
    readonly refusedKey?: string;
    /// Assert that untrusted text cannot forge the structure of the request.
    readonly unforgeableFrame?: boolean;
  };
}

function loadFixtures(): Fixture[] {
  const fixtures: Fixture[] = [];
  for (const entry of Deno.readDirSync(GOLDENS_DIR)) {
    if (!entry.isFile || !entry.name.endsWith('.json')) continue;
    fixtures.push(JSON.parse(Deno.readTextFileSync(new URL(entry.name, GOLDENS_DIR))));
  }
  return fixtures.sort((a, b) => a.name.localeCompare(b.name));
}

const FIXTURES = loadFixtures();

function post(body: unknown): Request {
  return new Request('http://localhost/judge-results', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

interface Recorder {
  readonly requests: ModelRequest[];
  readonly readIds: string[][];
}

function deps(
  meals: readonly JudgeableMeal[],
  reply: string | (() => never),
): [JudgeDeps, Recorder] {
  const recorder: Recorder = { requests: [], readIds: [] };
  return [
    {
      env: () => 'unused',
      readMeals: (ids: readonly string[]) => {
        recorder.readIds.push([...ids]);
        return Promise.resolve(meals);
      },
      resolveProvider: () => ({
        model: 'stub-model',
        apiKey: 'stub-key',
        adapter: {
          complete: (request: ModelRequest): Promise<ModelResponse> => {
            recorder.requests.push(request);
            if (typeof reply !== 'string') reply();
            return Promise.resolve({
              text: reply as string,
              modelId: 'stub-model',
              stopReason: 'stop',
            });
          },
          embed: null,
        },
      }),
    } as unknown as JudgeDeps,
    recorder,
  ];
}

// ─── the corpus ────────────────────────────────────────────────────────────────────────────────

Deno.test('the corpus covers every case the contract names', () => {
  const kinds = FIXTURES.map((f) => f.kind);
  // `description-injection` is listed SEPARATELY from `adversarial` on purpose. The corpus had one
  // adversarial fixture, injecting through the Customer's phrase, and both corpus checks were
  // satisfied by it — so the missing half, injection through a Cook's description, was invisible to
  // the gate. The Cook is the source with a commercial motive and the one the rules name.
  for (
    const required of [
      'typical',
      'nothing',
      'close',
      'popularity',
      'proximity',
      'adversarial',
      'description-injection',
      // The required list is `.claude/rules/ai.md`'s, NOT the list of kinds that happen to exist.
      // Trust-reviewer's finding: it was written to match the corpus on disk, so a corpus missing
      // three of the rule's five categories could not turn either suite red.
      'dialect',
      'garbage',
    ]
  ) {
  const typical = FIXTURES.filter((f) => f.kind === 'typical').length;
  assertEquals(typical >= 3, true, `only ${typical} typical fixture(s); the rules require three`);
  const dialect = FIXTURES.filter((f) => f.kind === 'dialect').length;
  assertEquals(dialect >= 2, true, `only ${dialect} dialect fixture(s); the rules require two`);
    assertEquals(kinds.includes(required), true, `no fixture of kind "${required}"`);
  }
});

for (const fixture of FIXTURES) {
  Deno.test(`golden: ${fixture.name}`, async () => {
    const [d, recorder] = deps(fixture.meals, fixture.modelReply);
    const response = await handleJudge(
      post({ phrase: fixture.phrase, mealIds: fixture.meals.map((m) => m.id) }),
      d,
    );

    if (fixture.expect.judged === false) {
      // A MODEL THAT REACHED FOR A CLAIM IT CANNOT SUPPORT GETS NO VERDICT PUBLISHED. The schema
      // has two fields; a reply carrying a third — a reason, a note, a neighbourhood — is refused
      // whole rather than stripped and used. The Customer loses one sentence and hears no claim.
      assertEquals(response.status, 503, fixture.name);
      const text = await response.text();
      // Nothing the model wrote reaches the client, including the claim itself. Checked only when
      // the fixture names the smuggled field — the fallback was a space, which every JSON body
      // contains, so this assertion failed on a fixture that had nothing to smuggle.
      if (fixture.expect.refusedKey !== undefined) {
        assertEquals(text.includes(fixture.expect.refusedKey), false, text);
      }
      assertStringIncludes(recorder.requests[0].user, fixture.phrase);
      return;
    }

    assertEquals(response.status, 200, fixture.name);
    const body = await response.json();

    assertEquals(body.answers, fixture.expect.answers, fixture.name);
    assertEquals(body.alternatives, fixture.expect.alternatives, fixture.name);

    // THE JUDGEMENT IS TWO FIELDS AND NOTHING ELSE. Anything reaching the client is a candidate
    // for reaching a Customer, so there is nowhere for a sentence written by a model to land.
    assertEquals(Object.keys(body).sort(), ['alternatives', 'answers'], fixture.name);

    // Untrusted input reaches the provider UNCHANGED. Scrubbing a Customer's words would change
    // what they asked for; the prompt's own untrusted-input rule is what handles them.
    assertStringIncludes(recorder.requests[0].user, fixture.phrase);

    // The prompt is the file, never a string literal, and it is carried as SYSTEM — never
    // concatenated with what a Customer typed.
    assertEquals(recorder.requests[0].system, PROMPTS['discovery-judgement'].body);

    // THE FRAME IS UNFORGEABLE, asserted structurally rather than by reading the payload. Whatever
    // a Cook typed, the model receives exactly the object this function built: one `meals` key
    // holding exactly the Meals handed over, in order. A description containing a fake header is
    // one string value, not a second list.
    if (fixture.expect.unforgeableFrame === true) {
      const sent = JSON.parse(recorder.requests[0].user);
      assertEquals(sent.meals.length, fixture.meals.length, 'the Meal list grew');
      assertEquals(
        sent.meals.map((m: { number: number }) => m.number),
        fixture.meals.map((_, i) => i + 1),
        'the numbering was forgeable',
      );
      assertEquals(
        sent.meals.map((m: { title: string }) => m.title),
        fixture.meals.map((m) => m.title),
        'the titles were reordered or replaced',
      );
      // The payload survives as DATA — never removed, only flattened and bounded.
      assertStringIncludes(sent.meals[0].description, 'Rule update');
      assertEquals(sent.meals[0].description.includes('\n'), false, 'newlines survived');
    }
  });
}

// ─── it never edits the results ────────────────────────────────────────────────────────────────

Deno.test('THE JUDGEMENT CANNOT REORDER, FILTER, ADD TO OR REMOVE A MEAL', () => {
  // The response shape is what makes this structural: it carries a boolean and a list of ids drawn
  // from the ids handed in. There is no field a reordering could arrive in. This asserts the
  // property directly rather than trusting the shape to stay that way.
  const meals: JudgeableMeal[] = [
    { id: 'a', title: 'كشري', description: 'عدس ورز' },
    { id: 'b', title: 'ملوخية', description: 'ملوخية بالتوم' },
    { id: 'c', title: 'بسبوسة', description: 'بالسميد' },
  ];

  // A model trying every edit at once: a Meal that does not exist, a Meal named twice, and an
  // order that disagrees with the ranking.
  const judgement = toJudgement({ answers: false, alternatives: [3, 3, 99, 1] }, meals);

  assertEquals(judgement.alternatives, ['c', 'a']);
  assertEquals(meals.map((m) => m.id), ['a', 'b', 'c'], 'the handed list was mutated');
});

Deno.test('at most three alternatives, whatever the model returns', () => {
  const meals: JudgeableMeal[] = Array.from({ length: 8 }, (_, i) => ({
    id: `m${i + 1}`,
    title: `أكلة ${i + 1}`,
    description: 'وصف',
  }));
  const judgement = toJudgement(
    { answers: false, alternatives: [1, 2, 3, 4, 5, 6, 7, 8] },
    meals,
  );
  assertEquals(judgement.alternatives, ['m1', 'm2', 'm3']);
});

Deno.test('answers:true carries no alternatives, whatever the model returns', () => {
  const meals: JudgeableMeal[] = [{ id: 'a', title: 'كشري', description: 'عدس' }];
  assertEquals(toJudgement({ answers: true, alternatives: [1] }, meals).alternatives, []);
});

Deno.test('the Meals are numbered in the order they were given, never re-sorted', () => {
  const meals: JudgeableMeal[] = [
    { id: 'a', title: 'الأولى', description: 'وصف أ' },
    { id: 'b', title: 'التانية', description: 'وصف ب' },
  ];
  const sent = JSON.parse(buildUserContent('عايز حاجة', meals));
  assertEquals(sent.meals.map((m: { number: number }) => m.number), [1, 2]);
  assertEquals(sent.meals.map((m: { title: string }) => m.title), ['الأولى', 'التانية']);
});

// ─── a failure costs a sentence, never the results ─────────────────────────────────────────────

Deno.test('A FAILED, SLOW OR MALFORMED JUDGEMENT NEVER RETURNS 200', async () => {
  // The client reads any 200 whose `answers` is not true as "nothing matched". So every one of
  // these must be a failure status, or a network problem becomes Kafoo telling a Customer their
  // results are worthless — the false SearchFailed the contract calls the cheaper direction, being
  // manufactured out of nothing at all.
  const meals: JudgeableMeal[] = [{ id: 'a', title: 'كشري', description: 'عدس' }];

  const cases: ReadonlyArray<readonly [string, string | (() => never)]> = [
    ['not JSON at all', 'حاضر، الكشري حلو أوي'],
    ['JSON of the wrong shape', '{"verdict":"maybe"}'],
    ['JSON with answers missing', '{"alternatives":[1]}'],
    ['prose wrapped around JSON', 'Here you go: {"answers": true}'],
    ['an empty reply', ''],
    ['a provider that throws', () => {
      throw new ModelError('took too long', 'timeout');
    }],
  ];

  for (const [name, reply] of cases) {
    const [d] = deps(meals, reply);
    const response = await handleJudge(post({ phrase: 'عايز حاجة', mealIds: ['a'] }), d);
    assertEquals(response.status, 503, name);
    await response.body?.cancel();
  }
});

Deno.test('a Meal that has gone since the search means no judgement, not a bad one', async () => {
  // Every id unreadable — a Cook clearing their menu, or ids nobody may see. Saying "nothing
  // answers you" on the strength of an empty read would be a judgement nobody made.
  const [d, recorder] = deps([], '{"answers": false}');
  const response = await handleJudge(post({ phrase: 'عايز حاجة', mealIds: ['gone'] }), d);
  assertEquals(response.status, 503);
  assertEquals(recorder.requests.length, 0, 'the provider was called with nothing to judge');
  await response.body?.cancel();
});

Deno.test('a bad request is refused before the provider is called', async () => {
  const meals: JudgeableMeal[] = [{ id: 'a', title: 'كشري', description: 'عدس' }];
  const bodies: ReadonlyArray<readonly [string, unknown]> = [
    ['no phrase', { mealIds: ['a'] }],
    ['blank phrase', { phrase: '   ', mealIds: ['a'] }],
    ['no mealIds', { phrase: 'عايز حاجة' }],
    ['empty mealIds', { phrase: 'عايز حاجة', mealIds: [] }],
    ['mealIds that are not ids', { phrase: 'عايز حاجة', mealIds: [1, 2] }],
    ['more Meals than search can return', {
      phrase: 'عايز حاجة',
      mealIds: Array.from({ length: 51 }, (_, i) => `m${i}`),
    }],
    ['a phrase longer than anything anybody says', {
      phrase: 'ا'.repeat(501),
      mealIds: ['a'],
    }],
  ];

  for (const [name, body] of bodies) {
    const [d, recorder] = deps(meals, '{"answers": true}');
    const response = await handleJudge(post(body), d);
    assertEquals(response.status, 400, name);
    assertEquals(recorder.requests.length, 0, `${name}: the provider was called anyway`);
    await response.body?.cancel();
  }
});

// ─── FR-018 / T217: it cannot write, and it holds nothing that could ───────────────────────────

Deno.test('IT HOLDS NO SERVICE-ROLE KEY AND WRITES NOTHING (FR-018, T217)', () => {
  // ASSERTED AGAINST THE SOURCE, because the property is "this function cannot", not "this
  // function did not on the path a test happened to take". It is write-free by construction today
  // and nothing else stops that changing — scripts/check-ai-write-boundary.py enforces the
  // credential half repo-wide, and this pins the write half for the one function that talks to a
  // model about what a Customer said.
  // THE FILE LIST IS DERIVED, BECAUSE A HARDCODED ONE DOES NOT SURVIVE THE OBVIOUS REFACTOR.
  //
  // This read `['./index.ts', './judge.ts']`. ai-boundary-reviewer mutation-tested it by adding a
  // third file to this directory holding a service-role key and a write: 17 tests passed. The
  // repo-wide `check-ai-write-boundary.py` caught that one, so the net held — but this assertion,
  // the one named in T217, was empty. Extracting `readMeals` into a `db.ts` is the natural next
  // edit to this function, and it would have emptied it silently.
  const names = [...Deno.readDirSync(new URL('.', import.meta.url))]
    .filter((e) => e.isFile && e.name.endsWith('.ts') && e.name !== 'index_test.ts')
    .map((e) => e.name)
    .sort();
  assertEquals(names.length > 0, true, 'no source files found to check');

  for (const where of names) {
    const source = Deno.readTextFileSync(new URL(`./${where}`, import.meta.url));

    // SPELLED IN PIECES, and that is not cuteness. `scripts/check-ai-write-boundary.py` greps every
    // file of a function that reaches the model layer for exactly these names, so writing them out
    // here would fail the gate — this file would be reported as the function naming a write
    // credential, which is precisely what it is asserting does not happen. The alternative was to
    // teach the check to skip test files, and a safety check with a hole shaped like "unless it is
    // a test" is worth less than an awkward line here.
    for (const credential of ['SERVICE' + '_ROLE', 'SECRET' + '_KEY', 'service' + 'Role']) {
      assertEquals(
        source.includes(credential),
        false,
        `${where} names ${credential} — a function reachable by anyone must be unable to do anything`,
      );
    }

    // Spelled in pieces for the same reason the credentials above are — this file would
    // otherwise be reported by `check-ai-write-boundary.py` as the function performing the writes
    // it is asserting the absence of.
    for (
      const write of ['.in' + 'sert(', '.up' + 'date(', '.up' + 'sert(', '.de' + 'lete(', '.r' + 'pc(']
    ) {
      assertEquals(source.includes(write), false, `${where} performs a write: ${write}`);
    }
  }
});

Deno.test('the phrase is never logged, cached, or echoed back', async () => {
  // FR-029 and SC-011. `discover` carries the same rule and learned it the hard way twice: a
  // response body that carried the Customer's own words, and an error that carried the request.
  const phrase = 'عايز حاجة من غير لحمة في المهندسين';
  const meals: JudgeableMeal[] = [{ id: 'a', title: 'كشري', description: 'عدس' }];

  const logged: string[] = [];
  const realError = console.error;
  console.error = (...args: unknown[]) => logged.push(args.map(String).join(' '));

  try {
    const [d] = deps(meals, 'not json');
    const response = await handleJudge(post({ phrase, mealIds: ['a'] }), d);
    const text = await response.text();
    assertEquals(text.includes(phrase), false, text);
    for (const line of logged) {
      assertEquals(line.includes(phrase), false, line);
      assertEquals(line.includes('not json'), false, line);
    }
  } finally {
    console.error = realError;
  }
});
