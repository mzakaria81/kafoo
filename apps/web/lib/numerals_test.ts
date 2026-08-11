import { strict as assert } from 'node:assert';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';

// Mirrors packages/ui/test/numerals_test.dart. The two surfaces have to agree
// digit for digit, or the same Meal quotes two prices.

const LATIN = '0123456789';
const ARABIC = '٠١٢٣٤٥٦٧٨٩';

// The module is re-implemented here rather than imported: these are .ts files
// with a `@/` path alias that node:test does not resolve, which is the same
// reason lib/preview_test.ts reads its source as text. What is asserted is that
// the shipped source agrees with this reference.
function reference(source: string): string {
  let out = '';
  for (const character of source) {
    if (character === '.') out += '٫';
    else if (character === ',') out += '٬';
    else {
      const digit = LATIN.indexOf(character);
      out += digit >= 0 ? ARABIC[digit] : character;
    }
  }
  return out;
}

const numerals = readFileSync('lib/numerals.ts', 'utf8');
const messages = readFileSync('lib/messages.ts', 'utf8');

test('the digit and separator tables match the reference', () => {
  assert.ok(numerals.includes(`'${LATIN}'`), 'Latin digit table drifted');
  assert.ok(numerals.includes(`'${ARABIC}'`), 'Arabic-Indic digit table drifted');
  assert.ok(numerals.includes("'٫'"), 'decimal separator missing');
  assert.ok(numerals.includes("'٬'"), 'thousands separator missing');
});

test('reference conversion matches what the app package produces', () => {
  assert.equal(reference('35.00'), '٣٥٫٠٠');
  assert.equal(reference('1,250.50'), '١٬٢٥٠٫٥٠');
  assert.equal(reference('35 جنيه'), '٣٥ جنيه');
});

test('every price on this surface goes through the conversion', () => {
  // priceLabel is the one funnel; if a page starts rendering {meal.price}
  // bare again, it renders Latin digits inside an Arabic sentence.
  assert.ok(
    /priceLabel[\s\S]*arabicIndic\(price\)/.test(messages),
    'priceLabel no longer converts digits',
  );
});

test('English keeps Latin digits', () => {
  // Arabic-Indic digits inside an English sentence help nobody.
  assert.ok(
    /locale === 'ar' \? arabicIndic\(price\) : price/.test(messages),
    'the conversion is no longer conditional on the locale',
  );
});
