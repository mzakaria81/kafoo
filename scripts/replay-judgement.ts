// Replays the discovery judgement against a REAL model, which the goldens deliberately do not.
//
// The goldens run against a stub, so they prove a correct judgement survives the pipeline. They say
// nothing about whether the judgement is correct — the burger fixture passes because the fixture
// says `false`, not because a model looked at four meat dishes and concluded none of them is a
// burger. This asks the model.
//
// SC-004: for requests that nothing on offer answers, Kafoo states this rather than presenting
// results as answers, in 100% of tested cases, and it does not degrade with corpus size.
//
//   deno run --allow-env --allow-read --allow-net scripts/replay-judgement.ts
//
// COSTS MONEY. Fast tier, roughly thirty calls. Founder's approval is required and was given on
// 2026-08-07.
//
// THE HANDED SETS ARE CONSTRUCTED, NOT RETRIEVED, and that is a stated limit rather than a
// shortcut. Running real retrieval would need the corpus embedded, which is a second paid step and
// a database; what this measures is the judgement, given Meals as close to the request as retrieval
// would plausibly return. Every unanswerable case below is built by REMOVING the food that would
// answer and keeping what a vector search would rank next — which is the hard case, not the easy
// one.

import { resolveProvider } from '../supabase/functions/_shared/ai/registry.ts';
import { parseAndValidate } from '../supabase/functions/_shared/ai/schema.ts';
import { ModelError } from '../supabase/functions/_shared/ai/types.ts';
import { PROMPTS } from '../supabase/functions/_shared/prompts.ts';
import {
  buildUserContent,
  type JudgeableMeal,
  JUDGEMENT_SCHEMA,
  toJudgement,
} from '../supabase/functions/judge-results/judge.ts';

interface CorpusMeal {
  readonly id: string;
  readonly name: string;
  readonly description: string;
}

const corpus: { meals: CorpusMeal[] } = JSON.parse(
  await Deno.readTextFile('docs/ops/discovery-corpus.json'),
);

const BY_ID = new Map(corpus.meals.map((m) => [m.id, m]));

function meals(...ids: string[]): JudgeableMeal[] {
  return ids.map((id) => {
    const meal = BY_ID.get(id);
    if (!meal) throw new Error(`no Meal "${id}" in the corpus`);
    return { id, title: meal.name, description: meal.description };
  });
}

interface Case {
  readonly id: string;
  readonly phrase: string;
  /// What the request is in English, for the report only.
  readonly gloss: string;
  /// True when something in the handed set genuinely answers.
  readonly answerable: boolean;
  readonly handed: JudgeableMeal[];
}

/// NOTHING ON OFFER ANSWERS. Each of these hands over the food a vector search would rank next
/// after removing the food that would have answered — so a wrong `true` here is Kafoo telling a
/// Customer that food which is not what they asked for is what they asked for.
const UNANSWERABLE: Case[] = [
  {
    id: 'sushi',
    phrase: 'سوشي ياباني',
    gloss: 'Japanese sushi, in a marketplace of Egyptian home cooking',
    answerable: false,
    handed: meals('koshari', 'samak', 'molokhia', 'gambari', 'firakh_mashwia'),
  },
  {
    id: 'burger',
    phrase: 'عايز برجر',
    gloss: 'a burger, against minced meat in bread — THE case',
    answerable: false,
    handed: meals('shawerma', 'tagen_batates', 'roqaq', 'mombar', 'hamam'),
  },
  {
    id: 'pizza',
    phrase: 'عايز بيتزا',
    gloss: 'pizza, against dough-and-cheese dishes that are not pizza',
    answerable: false,
    handed: meals('crepe', 'bechamel', 'pasta_white', 'roqaq'),
  },
  {
    id: 'mango_konafa',
    phrase: 'عايز كنافة بالمانجا',
    gloss: 'mango kunafa, when only pistachio kunafa is on offer — the near-miss',
    answerable: false,
    handed: meals('konafa', 'basbousa', 'atayef', 'om_ali'),
  },
  {
    id: 'smoked_salmon',
    phrase: 'عايز سلمون مدخن',
    gloss: 'smoked salmon, against baked tilapia and prawns',
    answerable: false,
    handed: meals('samak', 'gambari', 'firakh_mashwia'),
  },
  {
    id: 'bechamel',
    phrase: 'عايز مكرونة بالبشاميل',
    gloss: 'pasta with béchamel, when only white-sauce pasta is on offer',
    answerable: false,
    handed: meals('pasta_white', 'crepe', 'koshari'),
  },
  {
    id: 'fried_chicken',
    phrase: 'عايز فراخ مقلية',
    gloss: 'fried chicken, against grilled chicken',
    answerable: false,
    handed: meals('firakh_mashwia', 'sadr_firakh', 'shawerma', 'shorbet_firakh'),
  },
  {
    id: 'steak',
    phrase: 'عايز ستيك لحمة',
    gloss: 'a steak, against stewed and minced meat',
    answerable: false,
    handed: meals('bamya', 'fatta', 'tagen_batates', 'roqaq'),
  },
  {
    id: 'ice_cream',
    phrase: 'عايز آيس كريم',
    gloss: 'ice cream, against cold milk puddings',
    answerable: false,
    handed: meals('mahalabeya', 'roz_belaban', 'basbousa', 'om_ali'),
  },
  {
    id: 'crab',
    phrase: 'عايز كابوريا',
    gloss: 'crab, against prawns and fish',
    answerable: false,
    handed: meals('gambari', 'samak'),
  },
  {
    id: 'juice',
    phrase: 'عايز عصير مانجا',
    gloss: 'mango juice, in a marketplace with no drinks at all',
    answerable: false,
    handed: meals('om_ali', 'roz_belaban', 'salata_khadra', 'mahalabeya'),
  },
  {
    id: 'beef_shawerma',
    phrase: 'عايز شاورما لحمة',
    gloss: 'beef shawarma, when only chicken shawarma is on offer',
    answerable: false,
    handed: meals('shawerma', 'fatta', 'roqaq', 'kebda'),
  },
];

/// SOMETHING GENUINELY ANSWERS. A wrong `false` here costs a Customer a good answer they were about
/// to get, and fires a SearchFailed that makes the funnel wrong the same way. Cheaper than the
/// other direction, and still a direction.
const ANSWERABLE: Case[] = [
  {
    id: 'light',
    phrase: 'نفسي في حاجة خفيفة',
    gloss: 'something light',
    answerable: true,
    handed: meals('salata_khadra', 'shorbet_ads', 'sadr_firakh', 'koshari'),
  },
  {
    id: 'sweet',
    phrase: 'حاجة حلوة بعد الأكل',
    gloss: 'something sweet after the meal',
    answerable: true,
    handed: meals('basbousa', 'om_ali', 'mahalabeya', 'koshari'),
  },
  {
    id: 'breakfast',
    phrase: 'فطار الصبح',
    gloss: 'morning breakfast',
    answerable: true,
    handed: meals('fool', 'taameya', 'shakshouka', 'bamya'),
  },
  {
    id: 'seafood',
    phrase: 'عايز حاجة من البحر',
    gloss: 'something from the sea',
    answerable: true,
    handed: meals('samak', 'gambari', 'koshari'),
  },
  {
    id: 'chicken',
    phrase: 'حاجة فيها فراخ',
    gloss: 'something with chicken',
    answerable: true,
    handed: meals('firakh_mashwia', 'shawerma', 'shorbet_firakh', 'koshari'),
  },
  {
    id: 'warming',
    phrase: 'حاجة تدفي في البرد',
    gloss: 'something warming in the cold',
    answerable: true,
    handed: meals('shorbet_ads', 'shorbet_firakh', 'salata_khadra'),
  },
  {
    id: 'traditional',
    phrase: 'أكل مصري أصيل',
    gloss: 'authentic Egyptian food',
    answerable: true,
    handed: meals('koshari', 'molokhia', 'mahshi_khodar', 'burger'),
  },
  {
    id: 'grilled_chicken_en',
    phrase: 'grilled chicken',
    gloss: 'an English phrase against Arabic Meals',
    answerable: true,
    handed: meals('firakh_mashwia', 'sadr_firakh', 'koshari'),
  },
];

interface Outcome {
  readonly caseId: string;
  readonly size: number;
  /// null when the reply was refused before a verdict existed.
  readonly answers: boolean | null;
  readonly alternatives: readonly string[];
  readonly refusal: string | null;
  readonly correct: boolean;
}

/// PACED, BECAUSE THE FREE TIER RATE-LIMITS AND A RATE LIMIT IS NOT A MEASUREMENT.
///
/// The first run hit `rate_limit` on the thirteenth call and recorded twelve cases as failures that
/// had never been judged. That would have read as "SC-004 is 60%" when the truth was "60% of the
/// cases got an answer at all" — a measurement that reports the harness as though it were the model
/// is worse than no measurement.
const PAUSE_MS = 6000;
const RATE_LIMIT_BACKOFF_MS = [20000, 45000, 90000];

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function judge(c: Case, handed: JudgeableMeal[]): Promise<Outcome> {
  const provider = resolveProvider(PROMPTS['discovery-judgement'].modelTier, (k) => Deno.env.get(k));

  let text: string | null = null;
  let lastKind = 'threw';
  for (let attempt = 0; attempt <= RATE_LIMIT_BACKOFF_MS.length; attempt++) {
    try {
      const response = await provider.adapter.complete({
        model: provider.model,
        system: PROMPTS['discovery-judgement'].body,
        user: buildUserContent(c.phrase, handed),
        maxTokens: 256,
        responseSchema: JUDGEMENT_SCHEMA,
      }, provider.apiKey);
      text = response.text;
      break;
    } catch (error) {
      lastKind = error instanceof ModelError ? error.kind : 'threw';
      if (lastKind !== 'rate_limit' || attempt === RATE_LIMIT_BACKOFF_MS.length) break;
      const wait = RATE_LIMIT_BACKOFF_MS[attempt];
      console.log(`     rate limited on ${c.id}, waiting ${wait / 1000}s`);
      await sleep(wait);
    }
  }

  if (text === null) {
    return {
      caseId: c.id,
      size: handed.length,
      answers: null,
      alternatives: [],
      refusal: `provider:${lastKind}`,
      correct: false,
    };
  }

  const parsed = parseAndValidate(text, JUDGEMENT_SCHEMA);
  if ('errors' in parsed) {
    // Counted as a first-class number rather than folded into "wrong". A refusal costs the Customer
    // a sentence and never a wrong claim, but a HIGH refusal rate means the feature is dead in
    // production while every dashboard looks healthy.
    return {
      caseId: c.id,
      size: handed.length,
      answers: null,
      alternatives: [],
      refusal: parsed.errors[0],
      correct: false,
    };
  }

  const judgement = toJudgement(parsed.value as Record<string, unknown>, handed);
  return {
    caseId: c.id,
    size: handed.length,
    answers: judgement.answers,
    alternatives: judgement.alternatives,
    refusal: null,
    correct: judgement.answers === c.answerable,
  };
}

/// Pads a handed set up to `size` with Meals that do not answer the request.
///
/// The padding never includes anything the request asks for — it is corpus noise, which is what a
/// wider retrieval returns. The question being asked is whether the model grows more agreeable as
/// the list in front of it gets longer.
function padTo(c: Case, size: number, exclude: Set<string>): JudgeableMeal[] {
  const handed = [...c.handed];
  const held = new Set(handed.map((m) => m.id));
  for (const meal of corpus.meals) {
    if (handed.length >= size) break;
    if (held.has(meal.id) || exclude.has(meal.id)) continue;
    handed.push({ id: meal.id, title: meal.name, description: meal.description });
    held.add(meal.id);
  }
  return handed;
}

/// RESUMES rather than re-paying. An outcome already recorded with a real verdict — or a refusal
/// the MODEL produced rather than the transport — is a measurement and is kept. Only the cases the
/// rate limit ate are asked again.
const RESULT_PATH = 'docs/ops/replay-judgement-result.json';
const previous: Outcome[] = await Deno.readTextFile(RESULT_PATH)
  .then((t) => (JSON.parse(t) as { outcomes: Outcome[] }).outcomes ?? [])
  .catch(() => []);

function measured(caseId: string, size: number): Outcome | undefined {
  return previous.find((o) =>
    o.caseId === caseId && o.size === size && !(o.refusal ?? '').startsWith('provider:')
  );
}

const report: Outcome[] = [];

console.log(`model: ${resolveProvider('fast', (k) => Deno.env.get(k)).model}`);
console.log('');
console.log('── run 1: every case at its natural size');

for (const c of [...UNANSWERABLE, ...ANSWERABLE]) {
  const done = measured(c.id, c.handed.length);
  const outcome = done ?? await judge(c, c.handed);
  if (!done) await sleep(PAUSE_MS);
  report.push(outcome);
  const verdict = outcome.refusal !== null
    ? `REFUSED (${outcome.refusal.slice(0, 60)})`
    : `answers=${outcome.answers}`;
  const mark = outcome.correct ? 'ok  ' : 'MISS';
  console.log(
    `${mark} ${c.id.padEnd(18)} n=${String(c.handed.length).padStart(2)} ${verdict}` +
      (outcome.alternatives.length > 0 ? `  named: ${outcome.alternatives.join(', ')}` : ''),
  );
}

// ── run 2: does it degrade as the list gets longer ────────────────────────────────────────────
//
// `search_meals` caps at 50 and the corpus holds 36, so 36 is the ceiling here. The four cases are
// the hardest unanswerable ones — if agreeableness grows with list length, it shows first where the
//handed set is already close.
console.log('');
console.log('── run 2: the same requests with a longer list');

const SWEEP = ['burger', 'mango_konafa', 'fried_chicken', 'beef_shawerma'];
for (const id of SWEEP) {
  const c = UNANSWERABLE.find((x) => x.id === id)!;
  // Never pad with the food that would answer the request.
  const exclude = new Set(['burger', 'konafa', 'shawerma']);
  for (const size of [15, 36]) {
    const handed = padTo(c, size, exclude);
    const done = measured(c.id, handed.length);
    const outcome = done ?? await judge(c, handed);
    if (!done) await sleep(PAUSE_MS);
    report.push(outcome);
    const verdict = outcome.refusal !== null ? 'REFUSED' : `answers=${outcome.answers}`;
    console.log(
      `${outcome.correct ? 'ok  ' : 'MISS'} ${c.id.padEnd(18)} n=${String(handed.length).padStart(2)} ${verdict}`,
    );
  }
}

// ── the numbers ───────────────────────────────────────────────────────────────────────────────
const unanswerable = report.filter((o) =>
  [...UNANSWERABLE].some((c) => c.id === o.caseId)
);
const answerable = report.filter((o) => ANSWERABLE.some((c) => c.id === o.caseId));
const statedNothing = unanswerable.filter((o) => o.answers === false).length;
const refusals = report.filter((o) => o.refusal !== null).length;
const falseRefusals = answerable.filter((o) => o.answers === false).length;
const invented = report.filter((o) => o.alternatives.length > 3).length;

console.log('');
console.log('── SC-004');
console.log(
  `   nothing-answers cases stated correctly: ${statedNothing}/${unanswerable.length} ` +
    `(${Math.round((statedNothing / unanswerable.length) * 100)}%) — the criterion is 100%`,
);
console.log(`   by size: ${
  [5, 15, 36].map((s) => {
    const at = unanswerable.filter((o) => o.size <= s && o.size > (s === 5 ? 0 : s === 15 ? 5 : 15));
    return at.length === 0
      ? `n≤${s}: —`
      : `n≤${s}: ${at.filter((o) => o.answers === false).length}/${at.length}`;
  }).join('   ')
}`);
console.log(`   false refusals on answerable cases: ${falseRefusals}/${answerable.length}`);
console.log(`   replies refused before a verdict: ${refusals}/${report.length}`);
console.log(`   alternatives outside the handed set: ${invented}`);

// The model id lives HERE rather than in the prompt file: a model name belongs in the registry or
// an environment variable, and the gate enforces that over prompts/. A measurement without the
// model it measured is not a measurement, and docs/ is where the record goes.
await Deno.writeTextFile(
  RESULT_PATH,
  JSON.stringify({
    model: resolveProvider('fast', (k) => Deno.env.get(k)).model,
    criterion: 'SC-004',
    outcomes: report,
  }, null, 2) + '\n',
);
console.log('');
console.log('raw outcomes: docs/ops/replay-judgement-result.json');
