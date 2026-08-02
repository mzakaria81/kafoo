// Tests for the provider-neutral response schema and local validator.
//
// The validator is what actually rejects a reply that does not match — adapters may ask a provider
// for JSON, but shape and bounds are enforced here before any caller sees the value.
//
// Run with: deno test supabase/functions/_shared/ai/schema_test.ts

import { assertEquals } from 'jsr:@std/assert@1';
import { parseAndValidate, ResponseSchema, validate } from './schema.ts';

const mealShape: ResponseSchema = {
  type: 'object',
  required: ['name', 'calories', 'ingredients'],
  properties: {
    name: { type: 'string' },
    calories: { type: 'integer', minimum: 0, maximum: 20000 },
    ingredients: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
    basis: {
      type: 'object',
      properties: {
        calories: { type: 'string' },
      },
    },
    status: {
      type: 'string',
      enum: ['draft', 'ready'],
    },
    flag: { type: 'boolean', nullable: true },
  },
};

Deno.test('a conforming object passes with zero errors', () => {
  const errors = validate(
    {
      name: 'koshari',
      calories: 450,
      ingredients: ['rice', 'lentils'],
      notes: 'optional',
    },
    mealShape,
  );
  assertEquals(errors, []);
});

Deno.test('a missing required property is reported', () => {
  const errors = validate(
    { name: 'koshari', ingredients: [] },
    mealShape,
  );
  assertEquals(errors.some((e) => e.includes('calories') && e.includes('required')), true);
});

Deno.test('an absent optional property is not reported', () => {
  const errors = validate(
    { name: 'koshari', calories: 100, ingredients: [] },
    mealShape,
  );
  assertEquals(errors.some((e) => e.includes('notes')), false);
  assertEquals(errors, []);
});

Deno.test('a wrong primitive type is reported with its path', () => {
  const errors = validate(
    { name: 'koshari', calories: 100, ingredients: [], basis: { calories: 12 } },
    mealShape,
  );
  assertEquals(
    errors.some((e) => e.includes('basis.calories') && e.includes('expected string')),
    true,
  );
});

Deno.test('an unexpected extra property is reported', () => {
  const errors = validate(
    { name: 'koshari', calories: 100, ingredients: [], invented: true },
    mealShape,
  );
  assertEquals(
    errors.some((e) => e.includes('unexpected property "invented"')),
    true,
  );
});

Deno.test('an out-of-bounds integer is reported', () => {
  // Real contract case: a nonsense calorie figure must never reach a Cook.
  const errors = validate(
    { name: 'koshari', calories: 190000, ingredients: [] },
    mealShape,
  );
  assertEquals(
    errors.some((e) => e.includes('calories') && e.includes('190000') && e.includes('20000')),
    true,
  );
});

Deno.test('a non-integer where an integer is required is reported', () => {
  const errors = validate(
    { name: 'koshari', calories: 12.5, ingredients: [] },
    mealShape,
  );
  assertEquals(
    errors.some((e) => e.includes('calories') && e.includes('integer')),
    true,
  );
});

Deno.test('a value outside an enum is reported', () => {
  const errors = validate(
    { name: 'koshari', calories: 100, ingredients: [], status: 'published' },
    mealShape,
  );
  assertEquals(
    errors.some((e) => e.includes('status') && e.includes('published')),
    true,
  );
});

Deno.test('nullable true accepts null; a non-nullable field does not', () => {
  const ok = validate(
    { name: 'koshari', calories: 100, ingredients: [], flag: null },
    mealShape,
  );
  assertEquals(ok, []);

  const bad = validate(
    { name: null, calories: 100, ingredients: [] },
    mealShape,
  );
  assertEquals(
    bad.some((e) => e.includes('name') && e.includes('null')),
    true,
  );
});

Deno.test('nested object and array paths are reported correctly', () => {
  const errors = validate(
    {
      name: 'koshari',
      calories: 100,
      ingredients: ['rice', 'lentils', 3],
      basis: { calories: 99 },
    },
    mealShape,
  );
  assertEquals(errors.some((e) => e.startsWith('ingredients[2]:')), true);
  assertEquals(errors.some((e) => e.startsWith('basis.calories:')), true);
});

Deno.test('multiple problems in one value are all reported', () => {
  const errors = validate(
    {
      name: 1,
      calories: 190000,
      ingredients: 'nope',
      invented: true,
    },
    mealShape,
  );
  assertEquals(errors.length >= 3, true, `expected several errors, got: ${JSON.stringify(errors)}`);
  assertEquals(errors.some((e) => e.includes('name')), true);
  assertEquals(errors.some((e) => e.includes('calories')), true);
  assertEquals(errors.some((e) => e.includes('ingredients')), true);
});

Deno.test('parseAndValidate on text that is not JSON returns an error and does not throw', () => {
  const result = parseAndValidate('this is not json', mealShape);
  assertEquals('errors' in result, true);
  if ('errors' in result) {
    assertEquals(result.errors.some((e) => e.includes('not valid JSON')), true);
  }
});

Deno.test('parseAndValidate on truncated JSON returns an error and does not throw', () => {
  // Measured real-world failure: a reply cut off mid-string at the token limit.
  const truncated = '{"name":"koshari","calories":100,"ingredients":["ri';
  const result = parseAndValidate(truncated, mealShape);
  assertEquals('errors' in result, true);
  if ('errors' in result) {
    assertEquals(result.errors.length > 0, true);
  }
});

Deno.test('parseAndValidate on conforming JSON returns the value', () => {
  const result = parseAndValidate(
    JSON.stringify({ name: 'koshari', calories: 100, ingredients: [] }),
    mealShape,
  );
  assertEquals('value' in result, true);
  if ('value' in result) {
    assertEquals((result.value as { name: string }).name, 'koshari');
  }
});

Deno.test('NaN and Infinity are rejected for numeric types', () => {
  const numberSchema: ResponseSchema = {
    type: 'object',
    required: ['n'],
    properties: { n: { type: 'number' } },
  };
  assertEquals(
    validate({ n: Number.NaN }, numberSchema).some((e) => e.includes('n')),
    true,
  );
  assertEquals(
    validate({ n: Number.POSITIVE_INFINITY }, numberSchema).some((e) => e.includes('n')),
    true,
  );
});
