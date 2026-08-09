import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';

// The source is read rather than imported: these are .ts modules and the point
// of most of these assertions is what the SOURCE contains, not what it returns.

const preview = readFileSync('lib/preview.ts', 'utf8');
const supabase = readFileSync('lib/supabase.ts', 'utf8');

/**
 * Comments are stripped before the forbidden-claim scan.
 *
 * The first version failed on the kitchen page's own comment explaining that a
 * rating must never appear — the check was reading prose ABOUT the code as
 * though it were code. A comment naming what is forbidden is exactly what
 * should be kept; it is the rendered output that must not carry it.
 */
const code = (src: string) =>
  src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/\{\s*\/\*[\s\S]*?\*\/\s*\}/g, '');

const kitchenPage = code(readFileSync('app/k/[id]/page.tsx', 'utf8'));
const mealPage = code(readFileSync('app/m/[id]/page.tsx', 'utf8'));

/**
 * The one capture group of a pattern that must match, or a named failure.
 *
 * `preview.match(...)[1]` crashes with a TypeError when the pattern stops
 * matching — which is exactly what happens when somebody renames the thing being
 * asserted about. The test then blames itself rather than saying the cap it
 * guards has moved. Caught by the compiler once this file became `.ts`.
 */
function captured(source: string, pattern: RegExp, what: string): string {
  const match = source.match(pattern);
  assert.ok(match, `${what} not found — has it been renamed? ${pattern}`);
  return match[1];
}

test('a kitchen preview reveals exactly three things (FR-027a, SC-012)', () => {
  const type = captured(preview, /export type KitchenPreview = \{([^}]*)\}/, 'KitchenPreview');
  const fields = type.split('\n').map((l) => l.trim()).filter(Boolean);
  assert.equal(fields.length, 3, `KitchenPreview has ${fields.length} fields: ${fields}`);
  assert.ok(type.includes('title'));
  assert.ok(type.includes('area'));
  assert.ok(type.includes('image'));
  // The story and the delivery terms render on the page and must not preview.
  assert.ok(!type.includes('story'), 'the Cook’s story must not leave in a preview');
  assert.ok(!type.includes('delivery'), 'delivery terms must not leave in a preview');
});

test('the preview is built field by field, never spread from a row', () => {
  // A spread would carry whatever the row type grows into the preview,
  // silently, and the failure mode is personal information in a group chat.
  assert.ok(!/\.\.\.kitchen/.test(preview), 'no spread of a kitchen row into a preview');
  assert.ok(!/\.\.\.meal/.test(preview), 'no spread of a meal row into a preview');
});

test('a Kitchen Profile has exactly five public details', () => {
  const list = captured(preview, /PUBLIC_KITCHEN_FIELDS = \[([^\]]*)\]/, 'PUBLIC_KITCHEN_FIELDS');
  const count = list.split(',').filter((s) => s.trim()).length;
  assert.equal(count, 5, `expected 5 public details, found ${count}`);
});

test('the surface never displays a measurement Kafoo does not have', () => {
  // FR-027c. No rating, no review count, no order count, no distance — none of
  // these exist, and a placeholder for one is a fabricated measurement.
  for (const claim of ['rating', 'review_count', 'order_count', 'popular']) {
    for (const [name, src] of [['kitchen page', kitchenPage], ['meal page', mealPage]]) {
      assert.ok(!new RegExp(`\\b${claim}\\b`).test(src), `${name} references ${claim}`);
    }
  }
});

test('the read layer selects named columns, never *', () => {
  // `select()` with no argument returns every column, so a column added later —
  // a phone number, an internal note — would reach this surface without anyone
  // choosing to publish it.
  assert.ok(!/\.select\(\)/.test(supabase), 'no bare select() on a public surface');
  assert.ok(/MEAL_COLUMNS/.test(supabase) && /KITCHEN_COLUMNS/.test(supabase));
});

test('a kitchen with nothing on offer is not reachable', () => {
  // FR-004 and FR-027: an empty shopfront is a small betrayal repeated at
  // scale, so the page 404s rather than rendering a kitchen with no food.
  assert.ok(/if \(!meals\?\.length\) return null;/.test(supabase));
  assert.ok(/notFound\(\)/.test(kitchenPage));
});
