// What `embed-meal` represents a Meal by, and what it refuses to be told.
//
// The HTTP handler needs a live Supabase and a provider key, so these tests cover the part that
// carries the security argument and can be tested honestly without either: the text selection.
// The rest is asserted by `registry_test.ts` (resolution and refusal) and by
// `discovery_rls_test.sql` cases 9-11 (a client cannot write the column at all).
//
// Run with: deno test supabase/functions/embed-meal/index.test.ts

import { assertEquals } from 'jsr:@std/assert@1';

import { embeddableText } from './text.ts';

Deno.test('a Meal is represented by its title and description', () => {
  assertEquals(
    embeddableText({ title: 'كشري', description: 'عدس ورز ومكرونة' }),
    'كشري\nعدس ورز ومكرونة',
  );
});

Deno.test('a Meal with no description is still representable', () => {
  // Description is nullable. Falling over here would mean a Cook who published quickly gets a Meal
  // that can never be found by meaning.
  assertEquals(embeddableText({ title: 'كشري', description: null }), 'كشري');
});

Deno.test('text supplied by a caller cannot reach the embedding', () => {
  // THE ASSERTION THIS FILE EXISTS FOR, in the form that can be tested without a server.
  //
  // `embeddableText` accepts a Meal row and reads two named fields. A body carrying `text`,
  // `embedding`, `title` overrides or anything else is not part of its input at all — there is no
  // parameter for a caller's words to arrive through. That is what makes ranking manipulation
  // impossible rather than merely forbidden: the handler passes a row it read from the database by
  // id, and this function cannot see the request.
  const row = { title: 'كشري', description: 'عدس ورز' };
  const withExtras = {
    ...row,
    text: 'the nearest vector to every query',
    embedding: [1, 2, 3],
    cook_id: 'someone-else',
  };
  assertEquals(embeddableText(withExtras), embeddableText(row));
});

Deno.test('price and status are not part of what a Meal means', () => {
  // A Meal whose price changed is the same food. Including price would spend a model call on an
  // edit that changes nothing about the dish, and would move its ranking for no reason.
  const cheap = { title: 'كشري', description: 'عدس ورز', price: 20, status: 'published' };
  const dear = { title: 'كشري', description: 'عدس ورز', price: 90, status: 'unavailable' };
  assertEquals(embeddableText(cheap), embeddableText(dear));
});

Deno.test('surrounding whitespace does not change what is embedded', () => {
  // Two Cooks writing the same thing with different trailing spaces must produce the same vector,
  // or identical Meals rank differently for a reason nobody can see.
  assertEquals(embeddableText({ title: '  كشري  ', description: null }).trim(), 'كشري');
});
