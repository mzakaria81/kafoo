// Replay a golden corpus against a real model and score it — T086 for meal-analysis, T098 for
// meal-description.
//
// The golden tests in packages/ai/test/ run against a stub, which is what makes ADR-0005's
// provider-independence claim testable. What they cannot test is the prompt: whether the model
// writes Egyptian Arabic rather than Modern Standard, whether it holds allergens under a prompt
// injection, whether `basis` reads like a Cook or like a news anchor. Only a real call answers
// that, and `.claude/rules/ai.md` treats a prompt without a re-evaluation as an untested deploy.
//
// This goes through the SAME path analyze-meal uses — the same registry, the same compiled prompt,
// the same schema validator. An eval that re-implements the request shape measures the eval.
//
// No model name appears here. The registry resolves the tier, as it does in production.
//
//   DENO_CERT=/root/.ccr/ca-bundle.crt deno run \
//     --allow-net --allow-env --allow-read --allow-write scripts/replay-goldens.ts
//
//   # meal-description corpus (default is meal-analysis):
//   DENO_CERT=/root/.ccr/ca-bundle.crt deno run \
//     --allow-net --allow-env --allow-read --allow-write scripts/replay-goldens.ts \
//     --suite=meal-description
//
// RATE LIMIT: the Gemini free tier allows 15 requests per minute on the fast-tier model. The
// default spacing below stays under it with room for the one retry a fixture may trigger. Runs are
// spaced from each other only by the operator, so do not fire this repeatedly within a minute.

import { resolveProvider } from '../supabase/functions/_shared/ai/registry.ts';
import {
  parseAndValidate,
  type ResponseSchema,
} from '../supabase/functions/_shared/ai/schema.ts';
import { ModelError, type ModelRequest } from '../supabase/functions/_shared/ai/types.ts';
import { PROMPTS } from '../supabase/functions/_shared/prompts.ts';
import {
  MEAL_ANALYSIS_SCHEMA,
  MEAL_DESCRIPTION_SCHEMA,
} from '../supabase/functions/analyze-meal/schema.ts';

const MAX_TOKENS = 2048;

/// 15 requests per minute is one every 4 seconds. 4500 ms leaves headroom for a fixture that fails
/// validation and retries, which costs a second call inside the same window.
const DEFAULT_SPACING_MS = 4500;

export interface Fixture {
  readonly file: string;
  readonly name: string;
  readonly kind: string;
  readonly said: string;
  readonly expect: Record<string, unknown>;
}

export interface Check {
  readonly label: string;
  readonly pass: boolean;
  readonly detail: string;
}

export interface Note {
  readonly label: string;
  readonly text: string;
}

interface Outcome {
  readonly fixture: Fixture;
  readonly latencyMs: number;
  readonly attempts: number;
  readonly rawText: string;
  readonly value: Record<string, unknown> | null;
  readonly schemaErrors: string[];
  readonly checks: Check[];
  readonly notes: Note[];
  readonly msaMarkers: string[];
  readonly egyptianMarkers: string[];
  readonly droppedByParser: string[];
  readonly error: string | null;
}

export interface Suite {
  readonly name: string;
  readonly promptId: string;
  readonly goldensDir: string;
  readonly reportPath: string;
  readonly schema: ResponseSchema;
  readonly title: string;
  /// The task this suite's report answers. In the report rather than only in a commit message
  /// because the report is the artefact somebody reads a month later.
  readonly task: string;
  readonly preamble: readonly string[];
  gate(value: Record<string, unknown>): { gated: Record<string, unknown>; dropped: string[] };
  score(
    expect: Record<string, unknown>,
    gated: Record<string, unknown>,
    fixtureFile: string,
  ): { checks: Check[]; notes: Note[] };
}

// ---------------------------------------------------------------------------
// Dialect register
//
// The first version of this checked only the three vocabulary pairs the prompt names, and reported
// every fixture clean. It was wrong, and wrong in the direction that matters: the model gets the
// VOCABULARY right — it writes فراخ and رز and طماطم — and then writes the sentences around them in
// Modern Standard. "المكرونة تحتوي على جلوتين" contains no MSA food word and is not how anyone in
// Cairo speaks; a Cook says "المكرونة فيها جلوتين".
//
// So the markers below are constructions rather than nouns, and Egyptian markers are counted too.
// A register check that can only report "clean" tells you nothing when the answer is "mixed".
//
// This is a signal, not a verdict. The `basis` text is printed in full in the report because the
// judgement is a human one.
// The lists live in packages/ai/test/goldens/register_markers.json so the
// TypeScript replay and the Dart golden runner share one corpus. The comment
// above explains why the markers are constructions rather than nouns.
let _msaMarkers: ReadonlyArray<{ term: string; note: string }> | null = null;
let _egyptianMarkers: readonly string[] | null = null;

function _registry(): {
  msa: ReadonlyArray<{ term: string; note: string }>;
  egyptian: readonly string[];
} {
  if (_msaMarkers === null) {
    const raw = JSON.parse(
      Deno.readTextFileSync('packages/ai/test/goldens/register_markers.json'),
    ) as {
      msa: ReadonlyArray<{ term: string; note: string }>;
      egyptian: readonly string[];
    };
    _msaMarkers = raw.msa;
    _egyptianMarkers = raw.egyptian;
  }
  return { msa: _msaMarkers!, egyptian: _egyptianMarkers! };
}

function collectStrings(value: unknown, into: string[]): void {
  if (typeof value === 'string') into.push(value);
  else if (Array.isArray(value)) value.forEach((v) => collectStrings(v, into));
  else if (value !== null && typeof value === 'object') {
    Object.values(value).forEach((v) => collectStrings(v, into));
  }
}

/// Space-anchored on purpose. A bare substring test would count بيحتوي (Egyptian) as يحتوي (MSA),
/// which is the exact distinction being measured.
///
/// The optional `و` is a conjunction written joined to the next word, and leaving it out cost this
/// check two real hits in the version 1 replay: `وتعتبر` in two fixtures went unreported, and one
/// of them was scored "Modern Standard markers: none". Prefixes that change the register — the `ب`
/// on بيحتوي — still must not be skipped, so only the conjunction is optional.
function present(haystack: string, term: string): boolean {
  return new RegExp(`(^|\\s)و?${term}(\\s|$|[،.)(])`).test(haystack);
}

export function findRegisterMarkers(
  value: Record<string, unknown>,
): { msa: string[]; egyptian: string[] } {
  const texts: string[] = [];
  collectStrings(value, texts);
  const haystack = texts.join(' ');
  const reg = _registry();

  return {
    msa: reg.msa
      .filter(({ term }) => present(haystack, term))
      .map(({ term, note }) => `${term} (${note})`),
    egyptian: reg.egyptian.filter((term) => present(haystack, term)),
  };
}

// ---------------------------------------------------------------------------
// What the Cook actually sees
//
// The Dart golden test scores the parsed MealAnalysis, not the model's raw JSON, and the gap
// between the two is not cosmetic — parseMealAnalysis drops any field whose `basis` is missing or
// blank, drops a calorie figure outside 0..20000, and drops a cuisine or category outside the enum.
// Scoring raw JSON here would report failures no Cook could ever encounter, and would miss that the
// parser is the thing catching them. So mirror it.
const CUISINES = [
  'egyptian', 'levantine', 'gulf', 'sudanese', 'moroccan',
  'turkish', 'italian', 'asian', 'american', 'other',
];
const CATEGORIES = [
  'main', 'appetizer', 'soup', 'salad', 'side', 'dessert', 'bakery', 'drink', 'other',
];

/// Returns the value as `parseMealAnalysis` would leave it: every field the Dart parser would drop
/// is null here. Also reports which fields were dropped and why, because a field the model filled
/// and the parser discarded is the most interesting thing an eval can find.
export function gateMealAnalysis(
  value: Record<string, unknown>,
): { gated: Record<string, unknown>; dropped: string[] } {
  const rawBasis = (value.basis ?? {}) as Record<string, unknown>;
  const hasBasis = (field: string): boolean =>
    typeof rawBasis[field] === 'string' && (rawBasis[field] as string).trim().length > 0;

  const gated: Record<string, unknown> = { basis: value.basis };
  const dropped: string[] = [];

  const keep = (field: string, ok: boolean, why: string) => {
    if (!hasBasis(field)) {
      if (value[field] !== null && value[field] !== undefined) dropped.push(`${field} (no basis)`);
      gated[field] = null;
      return;
    }
    if (!ok) {
      dropped.push(`${field} (${why})`);
      gated[field] = null;
      return;
    }
    gated[field] = value[field];
  };

  const list = (field: string) => {
    const v = value[field];
    const cleaned = Array.isArray(v)
      ? v.filter((e): e is string => typeof e === 'string' && e.trim().length > 0)
      : [];
    keep(field, cleaned.length > 0, 'empty list');
    if (gated[field] !== null) gated[field] = cleaned;
    else gated[field] = [];
  };

  list('ingredients');
  list('allergens');

  const cal = value.calories;
  keep('calories', typeof cal === 'number' && Number.isInteger(cal) && cal >= 0 && cal <= 20000,
    'not an integer in 0..20000');
  keep('cuisine', typeof value.cuisine === 'string' && CUISINES.includes(value.cuisine),
    'not in the cuisine enum');
  keep('category', typeof value.category === 'string' && CATEGORIES.includes(value.category),
    'not in the category enum');

  return { gated, dropped };
}

/// Mirror `parseMealAnalysis` for the description field only: basis.description must be a
/// non-blank string, and description itself must be a non-blank string, or the description is
/// dropped. A meal-description reply has none of the meal-analysis fields.
export function gateMealDescription(
  value: Record<string, unknown>,
): { gated: Record<string, unknown>; dropped: string[] } {
  const rawBasis = (value.basis ?? {}) as Record<string, unknown>;
  const basisOk = typeof rawBasis.description === 'string' &&
    (rawBasis.description as string).trim().length > 0;

  const gated: Record<string, unknown> = { basis: value.basis };
  const dropped: string[] = [];

  const raw = value.description;
  const hasValue = raw !== null && raw !== undefined;

  if (!basisOk) {
    if (hasValue) dropped.push('description (no basis)');
    gated.description = null;
    return { gated, dropped };
  }

  if (typeof raw !== 'string' || raw.trim().length === 0) {
    if (hasValue) dropped.push('description (blank)');
    gated.description = null;
    return { gated, dropped };
  }

  gated.description = raw.trim();
  return { gated, dropped };
}

// ---------------------------------------------------------------------------
// Scoring
//
// Mirrors _assertExpect in meal_analysis_goldens_test.dart, with TWO deliberate divergences, both
// because the other side of the comparison is a live model rather than a stub replaying a literal:
//
//   1. Calories are reported, never asserted. A fixture records the exact number a stub returns;
//      a live model gives an estimate, so equality would measure the seed and nothing else.
//   2. `ingredientsContains` matches as a substring. The fixture says `لحمة`; a live model says
//      `لحمة مفرومة`, which is the same ingredient described better. Exact element equality would
//      score the model down for being more specific than the fixture author.
const CALORIE_BAND_LOW = 0.4;
const CALORIE_BAND_HIGH = 2.5;

const MEAL_ANALYSIS_EXPECT_KEYS = new Set([
  'isEmpty',
  'cuisine',
  'category',
  'ingredientsContains',
  'allergensContains',
  'allergensNotEmpty',
  'calories',
]);

const MEAL_DESCRIPTION_EXPECT_KEYS = new Set([
  'isEmpty',
  'descriptionContains',
  'descriptionNotContains',
  'descriptionInArabicScript',
  'maxSentences',
]);

function containsTerm(values: string[], wanted: string): boolean {
  return values.some((v) => v.includes(wanted));
}

function assertKnownKeys(
  expect: Record<string, unknown>,
  known: Set<string>,
  fixtureFile: string,
): void {
  for (const key of Object.keys(expect)) {
    if (!known.has(key)) {
      throw new Error(`${fixtureFile}: unknown expect key: ${key}`);
    }
  }
}

export function scoreMealAnalysis(
  expect: Record<string, unknown>,
  value: Record<string, unknown>,
  fixtureFile: string,
): { checks: Check[]; notes: Note[] } {
  assertKnownKeys(expect, MEAL_ANALYSIS_EXPECT_KEYS, fixtureFile);

  const checks: Check[] = [];
  const ingredients = (value.ingredients ?? []) as string[];
  const allergens = (value.allergens ?? []) as string[];

  if ('isEmpty' in expect) {
    // isEmpty means the model refused to invent a Meal from nothing. Every content field empty.
    const actuallyEmpty = ingredients.length === 0 &&
      allergens.length === 0 &&
      (value.calories === null || value.calories === undefined) &&
      (value.cuisine === null || value.cuisine === undefined) &&
      (value.category === null || value.category === undefined);
    checks.push({
      label: 'isEmpty',
      pass: actuallyEmpty === expect.isEmpty,
      detail: `expected ${expect.isEmpty}, got ${actuallyEmpty}`,
    });
  }

  for (const field of ['cuisine', 'category'] as const) {
    if (field in expect) {
      checks.push({
        label: field,
        pass: value[field] === expect[field],
        detail: `expected ${JSON.stringify(expect[field])}, got ${JSON.stringify(value[field])}`,
      });
    }
  }

  if ('ingredientsContains' in expect) {
    for (const wanted of expect.ingredientsContains as string[]) {
      const hit = containsTerm(ingredients, wanted);
      checks.push({
        label: `ingredients contains ${wanted}`,
        pass: hit,
        detail: hit ? 'present' : `got [${ingredients.join(', ')}]`,
      });
    }
  }

  if ('allergensContains' in expect) {
    for (const wanted of expect.allergensContains as string[]) {
      const hit = containsTerm(allergens, wanted);
      checks.push({
        label: `allergens contains ${wanted}`,
        pass: hit,
        detail: hit ? 'present' : `got [${allergens.join(', ')}]`,
      });
    }
  }

  if (expect.allergensNotEmpty === true) {
    checks.push({
      label: 'allergens not empty',
      pass: allergens.length > 0,
      detail: allergens.length > 0 ? `${allergens.length} listed` : 'EMPTY',
    });
  }

  let caloriesText = 'not asserted by this fixture';
  if ('calories' in expect) {
    const fixtureValue = expect.calories as number;
    const actual = value.calories;
    if (typeof actual !== 'number') {
      caloriesText =
        `MISSING — fixture records ${fixtureValue}, model returned ${JSON.stringify(actual)}`;
    } else {
      const ratio = actual / fixtureValue;
      const inBand = ratio >= CALORIE_BAND_LOW && ratio <= CALORIE_BAND_HIGH;
      caloriesText = `${actual} against the fixture's ${fixtureValue} (${ratio.toFixed(2)}x)` +
        (inBand ? '' : ' — OUTSIDE the plausibility band');
    }
  }

  return {
    checks,
    notes: [{ label: 'calories (reported, not asserted)', text: caloriesText }],
  };
}

/// Matches Dart's `_isArabicScript`: true when the description contains no Latin letter.
function isArabicScript(text: string): boolean {
  return !/[a-zA-Z]/.test(text);
}

/// Matches Dart's `_countSentences`: split on `.`, `؟`, and `!`, count non-blank pieces.
function countSentences(text: string): number {
  return text.split(/[.؟!]/).filter((p) => p.trim().length > 0).length;
}

export function scoreMealDescription(
  expect: Record<string, unknown>,
  value: Record<string, unknown>,
  fixtureFile: string,
): { checks: Check[]; notes: Note[] } {
  assertKnownKeys(expect, MEAL_DESCRIPTION_EXPECT_KEYS, fixtureFile);

  const checks: Check[] = [];
  // isEmpty: MealAnalysis.isEmpty is every suggestion null; for a meal-description reply the only
  // possible suggestion is the description, so this reduces to "no description survived the gate".
  const desc = typeof value.description === 'string' ? value.description : null;

  if ('isEmpty' in expect) {
    const actuallyEmpty = desc === null;
    checks.push({
      label: 'isEmpty',
      pass: actuallyEmpty === expect.isEmpty,
      detail: `expected ${expect.isEmpty}, got ${actuallyEmpty}`,
    });
  }

  if ('descriptionContains' in expect) {
    // Each of the four content checks demands a description before it checks anything.
    //
    // Guarding on `desc != null` instead would make every one of them pass when the parser dropped
    // the description entirely — and the fixtures that use them most are the adversarial pair,
    // where a vacuous pass says "the model did not write a gluten-free claim" about a draft that
    // does not exist. A check that cannot fail is worse than no check, because it answers.
    if (desc === null) {
      checks.push({
        label: 'descriptionContains',
        pass: false,
        detail: 'no description to check',
      });
    } else {
      for (const wanted of expect.descriptionContains as string[]) {
        const hit = desc.includes(wanted);
        checks.push({
          label: `description contains ${wanted}`,
          pass: hit,
          detail: hit ? 'present' : `got ${JSON.stringify(desc)}`,
        });
      }
    }
  }

  if ('descriptionNotContains' in expect) {
    if (desc === null) {
      checks.push({
        label: 'descriptionNotContains',
        pass: false,
        detail: 'no description to check for forbidden words',
      });
    } else {
      for (const forbidden of expect.descriptionNotContains as string[]) {
        const hit = desc.includes(forbidden);
        checks.push({
          label: `description does not contain ${forbidden}`,
          pass: !hit,
          detail: hit ? `found in ${JSON.stringify(desc)}` : 'absent',
        });
      }
    }
  }

  if ('descriptionInArabicScript' in expect) {
    if (desc === null) {
      checks.push({
        label: 'descriptionInArabicScript',
        pass: false,
        detail: 'no description to check the script of',
      });
    } else {
      const isArabic = isArabicScript(desc);
      checks.push({
        label: 'descriptionInArabicScript',
        pass: isArabic === expect.descriptionInArabicScript,
        detail: `expected ${expect.descriptionInArabicScript}, got ${isArabic}`,
      });
    }
  }

  if ('maxSentences' in expect) {
    if (desc === null) {
      checks.push({
        label: 'maxSentences',
        pass: false,
        detail: 'no description to count sentences in',
      });
    } else {
      const count = countSentences(desc);
      const max = expect.maxSentences as number;
      checks.push({
        label: 'maxSentences',
        pass: count <= max,
        detail: `${count} sentences, max ${max}`,
      });
    }
  }

  let descriptionText: string;
  if (desc === null) {
    descriptionText = 'dropped';
  } else {
    const sentences = countSentences(desc);
    descriptionText = `${sentences} sentence${sentences === 1 ? '' : 's'}, ${desc.length} characters`;
  }

  return {
    checks,
    notes: [{ label: 'description (reported, not asserted)', text: descriptionText }],
  };
}

export const SUITES: Record<string, Suite> = {
  'meal-analysis': {
    name: 'meal-analysis',
    promptId: 'meal-analysis',
    goldensDir: 'packages/ai/test/goldens/meal_analysis',
    reportPath: 'docs/ops/eval-meal-analysis.md',
    schema: MEAL_ANALYSIS_SCHEMA,
    title: '# Eval: meal-analysis against a real model',
    task: 'T086',
    preamble: [
      'Calories are reported rather than asserted. A fixture records the exact number a stub',
      'returns; a live model gives an estimate, so equality would measure the seed and',
      'nothing else. Everything else is asserted exactly as the Dart golden test asserts it.',
    ],
    gate: gateMealAnalysis,
    score: scoreMealAnalysis,
  },
  'meal-description': {
    name: 'meal-description',
    promptId: 'meal-description',
    goldensDir: 'packages/ai/test/goldens/meal_description',
    reportPath: 'docs/ops/eval-meal-description.md',
    schema: MEAL_DESCRIPTION_SCHEMA,
    title: '# Eval: meal-description against a real model',
    task: 'T098',
    preamble: [
      'Sentence count and character length are reported rather than asserted — a human signal,',
      'not a check. Everything else is asserted exactly as the Dart golden test asserts it.',
    ],
    gate: gateMealDescription,
    score: scoreMealDescription,
  },
};

// ---------------------------------------------------------------------------

function loadFixtures(suite: Suite): Fixture[] {
  const files = [...Deno.readDirSync(suite.goldensDir)]
    .filter((e) => e.isFile && e.name.endsWith('.json'))
    .map((e) => e.name)
    .sort();

  if (files.length === 0) throw new Error(`no fixtures in ${suite.goldensDir}`);

  return files.map((file) => {
    const raw = JSON.parse(Deno.readTextFileSync(`${suite.goldensDir}/${file}`));
    return {
      file,
      name: raw.name as string,
      kind: raw.kind as string,
      said: raw.said as string,
      expect: raw.expect as Record<string, unknown>,
    };
  });
}

async function replay(suite: Suite, fixture: Fixture): Promise<Outcome> {
  const prompt = PROMPTS[suite.promptId];
  if (!prompt) throw new Error(`prompt ${suite.promptId} missing from the compiled prompts`);

  const resolved = resolveProvider('fast', (k) => Deno.env.get(k));

  const base: ModelRequest = {
    system: prompt.body,
    user: fixture.said,
    model: resolved.model,
    maxTokens: MAX_TOKENS,
    responseSchema: suite.schema,
  };

  const started = performance.now();
  let userContent = base.user;
  let lastText = '';
  let lastErrors: string[] = [];

  // The same retry-once policy analyze-meal applies. Recording the attempt count is the point:
  // a fixture that only passes on the retry is a prompt weakness, not a success.
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const response = await resolved.adapter.complete(
        { ...base, user: userContent },
        resolved.apiKey,
      );
      lastText = response.text;

      const parsed = parseAndValidate(response.text, suite.schema);
      if (!('errors' in parsed)) {
        const value = parsed.value as Record<string, unknown>;
        // Score what a Cook would see, not what the model emitted — the parser sits between them.
        const { gated, dropped } = suite.gate(value);
        const { checks, notes } = suite.score(fixture.expect, gated, fixture.file);
        return {
          fixture,
          latencyMs: Math.round(performance.now() - started),
          attempts: attempt,
          rawText: response.text,
          value,
          schemaErrors: [],
          checks,
          notes,
          msaMarkers: findRegisterMarkers(value).msa,
          egyptianMarkers: findRegisterMarkers(value).egyptian,
          droppedByParser: dropped,
          error: null,
        };
      }

      lastErrors = parsed.errors;
      if (attempt === 1) {
        userContent = `${base.user}\n\n` +
          `Your previous reply failed validation. Correct these problems and reply with valid JSON only:\n` +
          parsed.errors.map((e) => `- ${e}`).join('\n');
      }
    } catch (error) {
      const message = error instanceof ModelError
        ? `${error.kind}: ${error.message}`
        : error instanceof Error
        ? error.message
        : String(error);
      return {
        fixture,
        latencyMs: Math.round(performance.now() - started),
        attempts: attempt,
        rawText: lastText,
        value: null,
        schemaErrors: [],
        checks: [],
        notes: [],
        msaMarkers: [],
        egyptianMarkers: [],
        droppedByParser: [],
        error: message,
      };
    }
  }

  return {
    fixture,
    latencyMs: Math.round(performance.now() - started),
    attempts: 2,
    rawText: lastText,
    value: null,
    schemaErrors: lastErrors,
    checks: [],
    notes: [],
    msaMarkers: [],
    egyptianMarkers: [],
    droppedByParser: [],
    error: 'reply never validated against the schema',
  };
}

function report(suite: Suite, outcomes: Outcome[], modelId: string, spacingMs: number): string {
  const today = new Date().toISOString().slice(0, 10);
  const lines: string[] = [];

  const failed = outcomes.filter((o) =>
    o.error !== null || o.checks.some((c) => !c.pass)
  );

  lines.push(suite.title);
  lines.push('');
  lines.push(
    `Generated by \`scripts/replay-goldens.ts\` on ${today}. This is ${suite.task} — the half of`,
  );
  lines.push('the golden corpus that the stub provider cannot cover.');
  lines.push('');
  lines.push(`- **Model tier**: fast, resolved by the registry to \`${modelId}\``);
  lines.push(
    `- **Prompt**: \`prompts/${suite.promptId}.md\` version ${
      PROMPTS[suite.promptId]?.version ?? '?'
    }`,
  );
  lines.push(`- **Fixtures**: ${outcomes.length}`);
  lines.push(`- **Request spacing**: ${spacingMs} ms, to stay inside the free tier's 15 per minute`);
  lines.push(`- **Fixtures with a failing check**: ${failed.length}`);
  lines.push('');
  for (const p of suite.preamble) lines.push(p);
  lines.push('');

  const latencies = outcomes.filter((o) => o.error === null).map((o) => o.latencyMs).sort((a, b) =>
    a - b
  );
  if (latencies.length > 0) {
    lines.push(
      `Latency across successful calls: ${latencies[0]}–${latencies[latencies.length - 1]} ms ` +
        `(median ${latencies[Math.floor(latencies.length / 2)]} ms), against a 2-second voice budget.`,
    );
    lines.push('');
  }

  lines.push('---');
  lines.push('');

  for (const o of outcomes) {
    const bad = o.error !== null || o.checks.some((c) => !c.pass);
    lines.push(`## ${bad ? 'FAIL' : 'PASS'} — ${o.fixture.name}`);
    lines.push('');
    lines.push(
      `\`${o.fixture.file}\` · kind: ${o.fixture.kind} · ${o.latencyMs} ms · attempt(s): ${o.attempts}`,
    );
    lines.push('');
    lines.push('**Cook said:**');
    lines.push('');
    lines.push(`> ${o.fixture.said}`);
    lines.push('');

    if (o.error !== null) {
      lines.push(`**Error:** ${o.error}`);
      if (o.schemaErrors.length > 0) {
        lines.push('');
        lines.push('Schema errors:');
        for (const e of o.schemaErrors) lines.push(`- ${e}`);
      }
      if (o.rawText.length > 0) {
        lines.push('');
        lines.push('Raw reply:');
        lines.push('');
        lines.push('```');
        lines.push(o.rawText);
        lines.push('```');
      }
      lines.push('');
      continue;
    }

    lines.push('**Checks:**');
    lines.push('');
    for (const c of o.checks) {
      lines.push(`- ${c.pass ? 'pass' : '**FAIL**'} — ${c.label}: ${c.detail}`);
    }
    for (const n of o.notes) {
      lines.push(`- ${n.label}: ${n.text}`);
    }
    lines.push('');

    lines.push('**Register:**');
    lines.push('');
    lines.push(
      o.msaMarkers.length === 0
        ? '- Modern Standard markers: none'
        : `- **Modern Standard markers (${o.msaMarkers.length})**: ${o.msaMarkers.join(', ')}`,
    );
    lines.push(
      o.egyptianMarkers.length === 0
        ? '- **Egyptian markers: none**'
        : `- Egyptian markers (${o.egyptianMarkers.length}): ${o.egyptianMarkers.join(', ')}`,
    );
    lines.push('');

    if (o.droppedByParser.length > 0) {
      lines.push(
        `**Dropped before the Cook sees them:** ${o.droppedByParser.join(', ')} — ` +
          '`parseMealAnalysis` discards these, so the model filled a field that never arrives. ' +
          'Scoring above is done AFTER this gate, which is what a Cook actually gets.',
      );
      lines.push('');
    }

    lines.push('**What the model returned:**');
    lines.push('');
    lines.push('```json');
    lines.push(JSON.stringify(o.value, null, 2));
    lines.push('```');
    lines.push('');
  }

  return lines.join('\n') + '\n';
}

function resolveSuite(args: string[]): Suite {
  const suiteArg = args.find((a) => a.startsWith('--suite='));
  const name = suiteArg ? suiteArg.slice('--suite='.length) : 'meal-analysis';
  const suite = SUITES[name];
  if (!suite) {
    const valid = Object.keys(SUITES).sort().join(', ');
    console.error(`Unknown suite "${name}". Valid suites: ${valid}`);
    Deno.exit(2);
  }
  return suite;
}

async function main(): Promise<void> {
  const suite = resolveSuite(Deno.args);
  const spacingArg = Deno.args.find((a) => a.startsWith('--spacing='));
  const spacingMs = spacingArg ? Number(spacingArg.slice('--spacing='.length)) : DEFAULT_SPACING_MS;

  if (!Number.isFinite(spacingMs) || spacingMs < 4000) {
    console.error(
      `Refusing to run with ${spacingMs} ms spacing. The free tier allows 15 requests per minute; ` +
        'anything under 4000 ms risks a 429 mid-corpus and a partial eval.',
    );
    Deno.exit(2);
  }

  const fixtures = loadFixtures(suite);
  const resolved = resolveProvider('fast', (k) => Deno.env.get(k));
  console.error(
    `Replaying ${fixtures.length} ${suite.name} fixtures against ${resolved.model}, ${spacingMs} ms apart.`,
  );

  const outcomes: Outcome[] = [];
  for (const [i, fixture] of fixtures.entries()) {
    if (i > 0) await new Promise((r) => setTimeout(r, spacingMs));
    const outcome = await replay(suite, fixture);
    outcomes.push(outcome);
    const bad = outcome.error !== null || outcome.checks.some((c) => !c.pass);
    console.error(`  ${bad ? 'FAIL' : 'pass'}  ${fixture.file}  ${outcome.latencyMs} ms`);
  }

  Deno.writeTextFileSync(suite.reportPath, report(suite, outcomes, resolved.model, spacingMs));
  console.error(`\nWrote ${suite.reportPath}`);

  const failures = outcomes.filter((o) => o.error !== null || o.checks.some((c) => !c.pass)).length;
  console.error(failures === 0 ? 'All fixtures passed.' : `${failures} fixture(s) failed.`);
  Deno.exit(failures === 0 ? 0 : 1);
}

if (import.meta.main) {
  await main();
}
