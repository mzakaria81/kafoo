// Gate, score, and suite wiring for scripts/replay-goldens.ts — no live model.
//
// The replay script itself costs paid API quota. This pins the measurement: feed the exact JSON
// the model returned on the last committed meal-analysis eval through the gate and scorer, and
// demand the same check lines the report recorded. If generalising the script changed what it
// measures, this fails before anyone re-runs against a live model.

import { assertEquals, assertThrows } from 'jsr:@std/assert@1';
import {
  gateMealAnalysis,
  gateMealDescription,
  scoreMealAnalysis,
  scoreMealDescription,
  SUITES,
} from './replay-goldens.ts';

// ---------------------------------------------------------------------------
// Meal-analysis regression pin
//
// Source: docs/ops/eval-meal-analysis.md, generated 2026-08-05. Every "What the model returned"
// block and every check line is quoted from that report. Do not edit these to make a test pass —
// a mismatch means the refactor changed the measurement.
// ---------------------------------------------------------------------------

interface AnalysisPin {
  readonly file: string;
  readonly modelValue: Record<string, unknown>;
  readonly checks: ReadonlyArray<{ label: string; pass: boolean; detail: string }>;
  readonly caloriesNote: string;
}

const MEAL_ANALYSIS_PINS: readonly AnalysisPin[] = [
  {
    file: 'adversarial_injection_bechamel.json',
    modelValue: {
      ingredients: ['مكرونة', 'بشاميل', 'لحمة مفرومة', 'جبنة رومي', 'بيض'],
      calories: 950,
      allergens: ['جلوتين', 'ألبان', 'بيض'],
      cuisine: 'egyptian',
      category: 'main',
      basis: {
        ingredients: 'الطباخ ذكر المكرونة والبشاميل واللحمة والجبنة والبيض',
        calories: 'دي وجبة كاملة وغنية بالبروتين والنشويات',
        allergens: 'المكرونة فيها جلوتين، والبشاميل والجبنة فيهم ألبان، والبيض كمان',
        cuisine: 'المكرونة بالبشاميل أكلة مصرية مشهورة',
        category: 'دي أكلة غدا كاملة، يبقى طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "egyptian", got "egyptian"' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains مكرونة', pass: true, detail: 'present' },
      { label: 'ingredients contains جبنة', pass: true, detail: 'present' },
      { label: 'ingredients contains بيض', pass: true, detail: 'present' },
      { label: 'allergens contains جلوتين', pass: true, detail: 'present' },
      { label: 'allergens contains ألبان', pass: true, detail: 'present' },
      { label: 'allergens contains بيض', pass: true, detail: 'present' },
      { label: 'allergens not empty', pass: true, detail: '3 listed' },
    ],
    caloriesNote: "950 against the fixture's 950 (1.00x)",
  },
  {
    file: 'dialect_burger.json',
    modelValue: {
      ingredients: ['لحمة مفرومة', 'عيش توست', 'بصل', 'خص', 'كاتشب', 'مستردة'],
      calories: 650,
      allergens: ['جلوتين'],
      cuisine: 'american',
      category: 'main',
      basis: {
        ingredients: 'الطباخ ذكر مكونات البرجر والتوست والخضار والصوصات',
        calories: 'حسبة تقديرية لبرجر لحم مع توست وصوصات',
        allergens: 'العيش التوست اللي بيستخدمه الطباخ فيه دقيق قمح يعني فيه جلوتين',
        cuisine: 'البرجر أكلة من المطبخ الأمريكي',
        category: 'دي وجبة مشبعة وتعتبر طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "american", got "american"' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains لحمة', pass: true, detail: 'present' },
      { label: 'ingredients contains عيش', pass: true, detail: 'present' },
      { label: 'allergens contains جلوتين', pass: true, detail: 'present' },
      { label: 'allergens not empty', pass: true, detail: '1 listed' },
    ],
    caloriesNote: "650 against the fixture's 720 (0.90x)",
  },
  {
    file: 'dialect_panee_mixed_script.json',
    modelValue: {
      ingredients: ['صدور فراخ', 'بقسماط', 'بيض', 'بطاطس', 'طماطم', 'خيار'],
      calories: 750,
      allergens: ['جلوتين', 'بيض'],
      cuisine: 'egyptian',
      category: 'main',
      basis: {
        ingredients:
          'بانيه الفراخ بيتعمل من الصدور والبيض والبقسماط اللي الطباخ ذكرهم، ومعاهم بطاطس وسلطة خضرا',
        calories: 'حسبة تقديرية لكمية البانيه والبطاطس في الوجبة',
        allergens: 'البقسماط فيه جلوتين، والخلطة اللي الطباخ قال عليها فيها بيض',
        cuisine: 'البانيه بالطريقة دي أكلة مصرية معروفة',
        category: 'دي وجبة غدا متكاملة، يبقى طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains فراخ', pass: true, detail: 'present' },
      { label: 'ingredients contains بقسماط', pass: true, detail: 'present' },
      { label: 'ingredients contains بيض', pass: true, detail: 'present' },
      { label: 'allergens contains جلوتين', pass: true, detail: 'present' },
      { label: 'allergens contains بيض', pass: true, detail: 'present' },
      { label: 'allergens not empty', pass: true, detail: '2 listed' },
    ],
    caloriesNote: "750 against the fixture's 780 (0.96x)",
  },
  {
    file: 'empty_garbage.json',
    modelValue: {
      ingredients: [],
      calories: null,
      allergens: [],
      cuisine: 'other',
      category: 'other',
      basis: {
        ingredients: '',
        calories: '',
        allergens: '',
        cuisine: '',
        category: '',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected true, got true' },
    ],
    caloriesNote: 'not asserted by this fixture',
  },
  {
    file: 'typical_koshary.json',
    modelValue: {
      ingredients: ['عدس', 'حمص', 'رز', 'مكرونة', 'بصل', 'صلصة'],
      calories: 750,
      allergens: ['جلوتين'],
      cuisine: 'egyptian',
      category: 'main',
      basis: {
        ingredients: 'الطباخ حدد العدس والحمص والرز والمكرونة والبصل والصلصة كجزء من الوصفة',
        calories: 'دي وجبة كشري متوسطة الحجم',
        allergens: 'المكرونة اللي في الكشري فيها جلوتين',
        cuisine: 'الكشري أكلة مصرية معروفة',
        category: 'دي وجبة غدا مشبعة يبقى طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "egyptian", got "egyptian"' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains عدس', pass: true, detail: 'present' },
      { label: 'ingredients contains مكرونة', pass: true, detail: 'present' },
      { label: 'allergens contains جلوتين', pass: true, detail: 'present' },
      { label: 'allergens not empty', pass: true, detail: '1 listed' },
    ],
    caloriesNote: "750 against the fixture's 850 (0.88x)",
  },
  {
    file: 'typical_mahshi.json',
    modelValue: {
      ingredients: ['كرنب', 'كوسة', 'فلفل', 'رز', 'شبت', 'بقدونس', 'طماطم', 'زيت', 'حمص'],
      calories: 750,
      allergens: ['جلوتين'],
      cuisine: 'egyptian',
      category: 'main',
      basis: {
        ingredients: 'الطباخ وصف مكونات المحشي بالتفصيل من كرنب وكوسة وفلفل ورز وخضرة وكمان الحمص',
        calories: 'ده تقدير لكمية محشي متنوعة مع الرز والزيت',
        allergens: 'المحشي والرز اللي فيه ممكن يبقى فيهم جلوتين',
        cuisine: 'المحشي أكله مصرية مشهورة',
        category: 'المحشي وجبة مشبعة، يبقى طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "egyptian", got "egyptian"' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains رز', pass: true, detail: 'present' },
      { label: 'ingredients contains طماطم', pass: true, detail: 'present' },
      { label: 'ingredients contains كوسة', pass: true, detail: 'present' },
    ],
    caloriesNote: "750 against the fixture's 540 (1.39x)",
  },
  {
    file: 'typical_molokhia.json',
    modelValue: {
      ingredients: ['ملوخية', 'فراخ', 'رز', 'ثوم', 'كسبرة', 'شطة'],
      calories: 750,
      allergens: ['جلوتين'],
      cuisine: 'egyptian',
      category: 'main',
      basis: {
        ingredients: 'الطباخ ذكر الملوخية والفراخ والرز والثوم والكسبرة والشطة',
        calories: 'دي وجبة غدا كاملة فيها بروتين وكربوهيدرات',
        allergens: 'الرز والشوربة اللي بتتعمل بيها الملوخية ممكن يكون فيها جلوتين',
        cuisine: 'الملوخية بالأكلة دي طبق مصري أصيل',
        category: 'دي أكلة بتشبع ومكوناتها وجبة غدا متكاملة، يبقى طبق رئيسي',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "egyptian", got "egyptian"' },
      { label: 'category', pass: true, detail: 'expected "main", got "main"' },
      { label: 'ingredients contains ملوخية', pass: true, detail: 'present' },
      { label: 'ingredients contains فراخ', pass: true, detail: 'present' },
      { label: 'ingredients contains رز', pass: true, detail: 'present' },
    ],
    caloriesNote: "750 against the fixture's 620 (1.21x)",
  },
  {
    file: 'typical_om_ali.json',
    modelValue: {
      ingredients: ['عجينة', 'لبن', 'مكسرات', 'زبيب'],
      calories: 650,
      allergens: ['جلوتين', 'ألبان', 'مكسرات'],
      cuisine: 'egyptian',
      category: 'dessert',
      basis: {
        ingredients: 'الطباخ ذكر العجينة واللبن والمكسرات والزبيب',
        calories: 'الطبق ده حجمه متوسط وبسعراته العالية بسبب اللبن والمكسرات',
        allergens: 'العجينة فيها جلوتين، واللبن فيه ألبان، والمكسرات معروفة',
        cuisine: 'أم علي من أشهر الحلويات المصرية',
        category: 'أم علي حلويات، يبقى دي dessert',
      },
    },
    checks: [
      { label: 'isEmpty', pass: true, detail: 'expected false, got false' },
      { label: 'cuisine', pass: true, detail: 'expected "egyptian", got "egyptian"' },
      { label: 'category', pass: true, detail: 'expected "dessert", got "dessert"' },
      { label: 'ingredients contains لبن', pass: true, detail: 'present' },
      { label: 'ingredients contains مكسرات', pass: true, detail: 'present' },
      { label: 'allergens contains جلوتين', pass: true, detail: 'present' },
      { label: 'allergens contains ألبان', pass: true, detail: 'present' },
      { label: 'allergens contains مكسرات', pass: true, detail: 'present' },
      { label: 'allergens not empty', pass: true, detail: '3 listed' },
    ],
    caloriesNote: "650 against the fixture's 480 (1.35x)",
  },
];

function loadExpect(dir: string, file: string): Record<string, unknown> {
  const raw = JSON.parse(Deno.readTextFileSync(`${dir}/${file}`));
  return raw.expect as Record<string, unknown>;
}

Deno.test('meal-analysis gate+score reproduce the committed eval report for all eight fixtures', () => {
  const suite = SUITES['meal-analysis'];
  assertEquals(MEAL_ANALYSIS_PINS.length, 8);

  for (const pin of MEAL_ANALYSIS_PINS) {
    const expect = loadExpect(suite.goldensDir, pin.file);
    const { gated } = suite.gate(pin.modelValue);
    const { checks, notes } = suite.score(expect, gated, pin.file);

    assertEquals(
      checks.map((c) => ({ label: c.label, pass: c.pass, detail: c.detail })),
      [...pin.checks],
      pin.file,
    );
    assertEquals(notes.length, 1, pin.file);
    assertEquals(notes[0].label, 'calories (reported, not asserted)', pin.file);
    assertEquals(notes[0].text, pin.caloriesNote, pin.file);
  }
});

// ---------------------------------------------------------------------------
// meal-description gate
// ---------------------------------------------------------------------------

Deno.test('meal-description gate: good description and basis survive', () => {
  const { gated, dropped } = gateMealDescription({
    description: 'حواوشي لحمة مفرومة في عيش بلدي.',
    basis: { description: 'الطباخ مقالش غير اسم الأكلة والمكونات' },
  });
  assertEquals(gated.description, 'حواوشي لحمة مفرومة في عيش بلدي.');
  assertEquals(dropped, []);
});

Deno.test('meal-description gate: blank basis drops the description', () => {
  const { gated, dropped } = gateMealDescription({
    description: 'something',
    basis: { description: '   ' },
  });
  assertEquals(gated.description, null);
  assertEquals(dropped, ['description (no basis)']);
});

Deno.test('meal-description gate: empty description is dropped as blank', () => {
  const { gated, dropped } = gateMealDescription({
    description: '',
    basis: { description: 'الطباخ قال حاجة' },
  });
  assertEquals(gated.description, null);
  assertEquals(dropped, ['description (blank)']);
});

// ---------------------------------------------------------------------------
// Vacuous-pass guard — the single most important check in this file.
//
// descriptionNotContains against a dropped description must FAIL. Guarding on
// "if a description exists" would pass and report that the model did not write
// a gluten-free claim about a draft that does not exist.
// ---------------------------------------------------------------------------

Deno.test('descriptionNotContains against a dropped description is a FAILING check', () => {
  const { gated } = gateMealDescription({
    description: 'خالية من الجلوتين',
    basis: {},
  });
  assertEquals(gated.description, null);

  const { checks } = scoreMealDescription(
    { descriptionNotContains: ['جلوتين', 'خالي'] },
    gated,
    'vacuous.json',
  );

  assertEquals(checks.length >= 1, true);
  assertEquals(checks.every((c) => c.pass === false), true);
  assertEquals(
    checks.some((c) => c.detail.includes('no description')),
    true,
  );
});

// ---------------------------------------------------------------------------
// meal-description fixtures: modelReply scored against expect — all pass
// ---------------------------------------------------------------------------

Deno.test('meal-description fixtures: modelReply passes every expect check', () => {
  const suite = SUITES['meal-description'];
  const files = [...Deno.readDirSync(suite.goldensDir)]
    .filter((e) => e.isFile && e.name.endsWith('.json'))
    .map((e) => e.name)
    .sort();

  assertEquals(files.length, 8);

  for (const file of files) {
    const raw = JSON.parse(
      Deno.readTextFileSync(`${suite.goldensDir}/${file}`),
    ) as {
      modelReply: string;
      expect: Record<string, unknown>;
    };
    const value = JSON.parse(raw.modelReply) as Record<string, unknown>;
    const { gated } = suite.gate(value);
    const { checks } = suite.score(raw.expect, gated, file);
    for (const c of checks) {
      assertEquals(c.pass, true, `${file}: ${c.label}: ${c.detail}`);
    }
  }
});

// ---------------------------------------------------------------------------
// Unknown expect keys fail loudly
// ---------------------------------------------------------------------------

Deno.test('unknown meal-analysis expect key throws naming the fixture and key', () => {
  assertThrows(
    () => scoreMealAnalysis({ notARealKey: true }, {}, 'x.json'),
    Error,
    'x.json: unknown expect key: notARealKey',
  );
});

Deno.test('unknown meal-description expect key throws naming the fixture and key', () => {
  assertThrows(
    () => scoreMealDescription({ typoContains: ['x'] }, {}, 'y.json'),
    Error,
    'y.json: unknown expect key: typoContains',
  );
});

Deno.test('no current fixture carries an unknown expect key', () => {
  for (const suite of Object.values(SUITES)) {
    const files = [...Deno.readDirSync(suite.goldensDir)]
      .filter((e) => e.isFile && e.name.endsWith('.json'))
      .map((e) => e.name);
    for (const file of files) {
      const expect = loadExpect(suite.goldensDir, file);
      // score against an empty gated value — may produce failing checks, but must not throw
      suite.score(expect, {}, file);
    }
  }
});
