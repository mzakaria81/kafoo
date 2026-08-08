// ADR-0012's open question 1, measured: how often does `analyze-meal` name the food a Meal plainly
// contains?
//
//   deno run --allow-env --allow-read --allow-write --allow-net scripts/measure-concept-recall.ts
//
// COSTS MONEY. Fast tier, one call per Meal, 36 calls. Founder's approval given 2026-08-08.
//
// WHY THIS NUMBER GATES THE REST OF ADR-0012. The design is: the AI proposes concepts, the Cook
// confirms or corrects, and the database filters on what was confirmed. That only holds if the AI
// is proposing. If it names the food in a dish nine times in ten, the Cook is checking. If it names
// it six times in ten, the Cook is doing the extraction by hand with a model guessing beside them —
// which is a different product, and one nobody has agreed to build.
//
// WHAT IS MEASURED, PRECISELY. Not "did the model pick the right category" — there is no taxonomy
// yet, and inventing one to grade against would grade the taxonomy. This measures the half that
// depends on the model: **given a Meal whose own text states a food, does the extracted
// `ingredients[] + allergens[]` contain a word for it?** The other half — word to concept to
// category — is a lookup, and a lookup is testable without spending anything.
//
// THE ALIAS MAP BELOW IS DELIBERATELY GENEROUS. It exists to recognise the model's answer, not to
// be Kafoo's vocabulary. A thin map would report the map's gaps as the model's misses. Every miss
// this script prints is listed individually so it can be read and confirmed as a real miss rather
// than a word nobody thought of.
//
// UPPER BOUND, NOT AN ESTIMATE. The corpus descriptions were written to exercise retrieval, so they
// already read as ingredient lists. Real Cook speech names less. See `known_limit` in the truth
// file.

import { resolveProvider } from '../supabase/functions/_shared/ai/registry.ts';
import { parseAndValidate } from '../supabase/functions/_shared/ai/schema.ts';
import { ModelError } from '../supabase/functions/_shared/ai/types.ts';
import { PROMPTS } from '../supabase/functions/_shared/prompts.ts';
import { MEAL_ANALYSIS_SCHEMA } from '../supabase/functions/analyze-meal/schema.ts';

interface CorpusMeal {
  readonly id: string;
  readonly name: string;
  readonly description: string;
}

interface TruthMeal {
  readonly id: string;
  readonly categories: string[];
  readonly why: string;
}

const corpus: { meals: CorpusMeal[] } = JSON.parse(
  await Deno.readTextFile('docs/ops/discovery-corpus.json'),
);
const truth: { meals: TruthMeal[] } = JSON.parse(
  await Deno.readTextFile('docs/ops/concept-recall-truth.json'),
);

const BY_ID = new Map(corpus.meals.map((m) => [m.id, m]));

/// Words that mean a category, in the forms a model plausibly returns. Arabic and English, because
/// `analyze-meal` is free to answer in either and this is recognition rather than vocabulary.
///
/// Matched against the FOLDED extracted text as a substring, which is the loose direction on
/// purpose: over-recognising inflates recall, and an inflated recall would be caught by reading the
/// per-Meal detail this script prints. Under-recognising would silently blame the model.
const RECOGNISE: Record<string, string[]> = {
  MILK: [
    'لبن', 'حليب', 'جبن', 'زبادي', 'قشطة', 'قشده', 'زبدة', 'سمن', 'كريمة', 'كريم', 'قريش',
    'موتزاريلا', 'موزاريلا', 'بشاميل', 'ألبان', 'البان', 'milk', 'dairy', 'cheese', 'cream',
    'yoghurt', 'yogurt', 'butter', 'ghee', 'mozzarella', 'bechamel',
  ],
  EGG: ['بيض', 'egg'],
  PEANUT: ['سوداني', 'peanut'],
  TREE_NUT: [
    'مكسرات', 'لوز', 'عين جمل', 'بندق', 'فستق', 'كاجو', 'صنوبر', 'بيكان', 'جوز',
    'nut', 'almond', 'walnut', 'pistachio', 'hazelnut', 'cashew', 'pine',
  ],
  SESAME: ['سمسم', 'طحينة', 'طحينه', 'sesame', 'tahini'],
  GLUTEN_CEREAL: [
    'قمح', 'دقيق', 'جلوتين', 'غلوتين', 'سميد', 'بقسماط', 'مكرونة', 'معكرونة', 'عيش', 'خبز',
    'رقاق', 'فريك', 'شعرية', 'عجين', 'شوفان', 'كنافة', 'قطايف', 'بيني', 'كريب', 'باستا',
    'gluten', 'flour', 'bread', 'pasta', 'semolina', 'wheat', 'oat', 'penne', 'dough', 'crepe',
    'kunafa', 'freekeh', 'vermicelli', 'noodle',
  ],
  WHEAT: [
    'قمح', 'دقيق', 'سميد', 'بقسماط', 'مكرونة', 'معكرونة', 'عيش', 'خبز', 'رقاق', 'فريك',
    'شعرية', 'عجين', 'كنافة', 'قطايف', 'بيني', 'كريب', 'باستا',
    'wheat', 'flour', 'bread', 'pasta', 'semolina', 'penne', 'dough', 'crepe', 'kunafa',
    'freekeh', 'vermicelli', 'noodle',
  ],
  SOY: ['صويا', 'soy'],
  FISH: [
    'سمك', 'أسماك', 'اسماك', 'سلمون', 'رنجة', 'فسيخ', 'بلطي', 'بوري', 'سردين', 'تونة',
    'fish', 'tilapia', 'salmon', 'tuna', 'sardine', 'herring', 'mullet',
  ],
  CRUSTACEAN: ['جمبري', 'قريدس', 'استاكوزا', 'كابوريا', 'shrimp', 'prawn', 'crab', 'lobster'],
  MOLLUSC: ['محار', 'سبيط', 'كاليماري', 'حبار', 'جندوفلي', 'squid', 'calamari', 'clam', 'mussel', 'oyster'],
  MUSTARD: ['مستردة', 'خردل', 'mustard'],
  CELERY: ['كرفس', 'celery'],
  LUPIN: ['ترمس', 'lupin'],
  SULPHITES: ['كبريت', 'sulphite', 'sulfite'],
  MEAT: [
    'لحم', 'لحوم', 'كبد', 'سجق', 'بسطرمة', 'لانشون', 'ضاني', 'كندوز', 'أرانب', 'ارانب',
    'أرنب', 'ارنب', 'ممبار', 'بقري',
    'meat', 'beef', 'lamb', 'mutton', 'liver', 'rabbit', 'veal', 'sausage', 'offal', 'tripe',
  ],
  PORK: ['خنزير', 'pork', 'bacon', 'ham'],
  POULTRY: [
    'فراخ', 'فرخة', 'فرخ', 'دجاج', 'بانيه', 'حمام', 'بط', 'ديك رومي',
    'chicken', 'poultry', 'pigeon', 'duck', 'turkey',
  ],
  ALCOHOL: ['كحول', 'نبيذ', 'بيرة', 'alcohol', 'wine', 'beer', 'rum'],
  ONION: ['بصل', 'onion'],
  GARLIC: ['توم', 'ثوم', 'garlic'],
};

const INVISIBLE = /[\u0640\u064B-\u065F\u0670\u06D6-\u06ED\u200B-\u200F\u061C\uFEFF]/g;
const WHITESPACE =
  /[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/g;
 
/// The same fold as `ExclusionVocabulary.foldArabic` and `public.fold_arabic`. Reused rather than
/// imported because those live in Dart and SQL; `discover/parse.ts` has the TypeScript one, and
/// importing it here would drag the whole discover module into a script.
function fold(value: string): string {
  return value
    .toLowerCase()
    .replace(INVISIBLE, '')
    .replace(WHITESPACE, ' ')
    .trim()
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه');
}

function names(extracted: string[], category: string): boolean {
  const haystack = fold(extracted.join(' | '));
  return (RECOGNISE[category] ?? []).some((alias) => haystack.includes(fold(alias)));
}

/// PACED. The free tier rate-limits, and a rate limit recorded as a wrong answer is a measurement of
/// the harness. Same shape as scripts/replay-judgement.ts, for the same reason.
const PAUSE_MS = 6000;
const RATE_LIMIT_BACKOFF_MS = [20000, 45000, 90000];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

interface Outcome {
  readonly id: string;
  readonly ingredients: string[];
  readonly allergens: string[];
  readonly found: string[];
  readonly missed: string[];
  readonly refusal: string | null;
}

async function analyse(meal: CorpusMeal): Promise<{ ingredients: string[]; allergens: string[] } | string> {
  const prompt = PROMPTS['meal-analysis'];
  const provider = resolveProvider(prompt.modelTier, (k) => Deno.env.get(k));

  // What a Cook would have said, as close as this corpus gets: the Meal's name and its description.
  const said = `${meal.name}. ${meal.description}`;

  let text: string | null = null;
  let lastKind = 'threw';
  for (let attempt = 0; attempt <= RATE_LIMIT_BACKOFF_MS.length; attempt++) {
    try {
      const response = await provider.adapter.complete({
        model: provider.model,
        system: prompt.body,
        user: said,
        maxTokens: 1024,
        responseSchema: MEAL_ANALYSIS_SCHEMA,
      }, provider.apiKey);
      text = response.text;
      break;
    } catch (error) {
      lastKind = error instanceof ModelError ? error.kind : 'threw';
      if (lastKind !== 'rate_limit' || attempt === RATE_LIMIT_BACKOFF_MS.length) break;
      const wait = RATE_LIMIT_BACKOFF_MS[attempt];
      console.log(`     rate limited on ${meal.id}, waiting ${wait / 1000}s`);
      await sleep(wait);
    }
  }

  if (text === null) return `provider:${lastKind}`;

  const parsed = parseAndValidate(text, MEAL_ANALYSIS_SCHEMA);
  // The MESSAGES, not the reply. A schema message names a path and an expected type; the reply
  // is a Cook's Meal text reflected back and does not belong in a committed report.
  if ('errors' in parsed) return `invalid: ${parsed.errors.join('; ')}`;

  const value = parsed.value as { ingredients?: unknown; allergens?: unknown };
  return {
    ingredients: Array.isArray(value.ingredients) ? value.ingredients.map(String) : [],
    allergens: Array.isArray(value.allergens) ? value.allergens.map(String) : [],
  };
}

const RESULT_PATH = 'docs/ops/concept-recall-result.json';

// Resume, so a rate limit does not mean paying for the first thirty again.
const previous: Outcome[] = await Deno.readTextFile(RESULT_PATH)
  .then((t) => JSON.parse(t).outcomes as Outcome[])
  .catch(() => []);
const done = new Map(previous.filter((o) => o.refusal === null).map((o) => [o.id, o]));

const outcomes: Outcome[] = [];

for (const t of truth.meals) {
  const meal = BY_ID.get(t.id);
  if (!meal) throw new Error(`no Meal "${t.id}" in the corpus`);

  const cached = done.get(t.id);
  if (cached) {
    outcomes.push(cached);
    console.log(`  = ${t.id} (cached)`);
    continue;
  }

  const result = await analyse(meal);
  if (typeof result === 'string') {
    outcomes.push({ id: t.id, ingredients: [], allergens: [], found: [], missed: t.categories, refusal: result });
    console.log(`  ! ${t.id}: ${result}`);
  } else {
    const extracted = [...result.ingredients, ...result.allergens];
    const found = t.categories.filter((c) => names(extracted, c));
    const missed = t.categories.filter((c) => !names(extracted, c));
    outcomes.push({ ...result, id: t.id, found, missed, refusal: null });
    const mark = missed.length === 0 ? '✓' : '✗';
    console.log(`  ${mark} ${t.id}: ${found.length}/${t.categories.length}${missed.length ? '  missed ' + missed.join(', ') : ''}`);
  }

  await sleep(PAUSE_MS);
}

const graded = outcomes.filter((o) => o.refusal === null);
const expected = graded.reduce((n, o) => n + o.found.length + o.missed.length, 0);
const found = graded.reduce((n, o) => n + o.found.length, 0);

// Per category, because an average hides the one that matters. A model that names dairy every time
// and nuts never has a fine overall number and a nut allergy problem.
const perCategory: Record<string, { expected: number; found: number }> = {};
for (const o of graded) {
  for (const c of o.found) {
    perCategory[c] ??= { expected: 0, found: 0 };
    perCategory[c].expected++;
    perCategory[c].found++;
  }
  for (const c of o.missed) {
    perCategory[c] ??= { expected: 0, found: 0 };
    perCategory[c].expected++;
  }
}

const pct = (n: number, d: number) => (d === 0 ? '—' : `${((100 * n) / d).toFixed(1)}%`);

console.log('');
console.log(`Meals graded          ${graded.length} of ${truth.meals.length}`);
console.log(`Refusals              ${outcomes.length - graded.length}`);
console.log(`Category instances    ${expected}`);
console.log(`RECALL                ${pct(found, expected)}  (${found}/${expected})`);
console.log('');
for (const [c, v] of Object.entries(perCategory).sort((a, b) => a[0].localeCompare(b[0]))) {
  console.log(`  ${c.padEnd(16)} ${pct(v.found, v.expected).padStart(6)}  (${v.found}/${v.expected})`);
}

const misses = graded.flatMap((o) => o.missed.map((c) => ({ id: o.id, category: c, extracted: [...o.ingredients, ...o.allergens] })));
if (misses.length > 0) {
  console.log('\nEvery miss, so each can be read and confirmed as the model rather than the alias map:');
  for (const m of misses) console.log(`  ${m.id.padEnd(18)} ${m.category.padEnd(16)} extracted: ${m.extracted.join(', ')}`);
}

await Deno.writeTextFile(
  RESULT_PATH,
  JSON.stringify(
    {
      measured: '2026-08-08',
      question: "ADR-0012 open question 1 — does analyze-meal name the food a Meal plainly contains?",
      model: resolveProvider(PROMPTS['meal-analysis'].modelTier, (k) => Deno.env.get(k)).model,
      graded: graded.length,
      refusals: outcomes.length - graded.length,
      categoryInstances: expected,
      recall: expected === 0 ? null : found / expected,
      perCategory,
      outcomes,
    },
    null,
    2,
  ) + '\n',
);
console.log(`\nwrote ${RESULT_PATH}`);
