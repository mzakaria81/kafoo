// The two things about the backfill worth being sure of, without a database.
//
// Run with: deno test --allow-env scripts/backfill_meal_embeddings_test.ts

import { assertEquals } from 'jsr:@std/assert@1';

import {
  mealsNeedingVectors,
  writeVector,
} from './backfill-meal-embeddings.ts';

function capture(response: Response): { calls: Request[] } {
  const calls: Request[] = [];
  globalThis.fetch = (input: RequestInfo | URL, init?: RequestInit) => {
    calls.push(new Request(input as Request | URL | string, init));
    return Promise.resolve(response.clone());
  };
  return { calls };
}

const original = globalThis.fetch;

Deno.test('it asks only for Meals ON OFFER that have no vector', async () => {
  // A query that lost `status=eq.published` would spend a model call on every draft in the
  // marketplace, and drafts are not discoverable — so the money buys nothing.
  // A query that lost `embedding=is.null` would re-embed the whole corpus on every run.
  const { calls } = capture(new Response('[]', { status: 200 }));
  try {
    await mealsNeedingVectors('https://kafoo.test', 'key', null);
  } finally {
    globalThis.fetch = original;
  }

  const url = new URL(calls[0].url);
  assertEquals(url.searchParams.get('status'), 'eq.published');
  assertEquals(url.searchParams.get('embedding'), 'is.null');
  assertEquals(url.searchParams.get('select'), 'id,title,description');
});

Deno.test('IT WRITES EXACTLY ONE COLUMN', async () => {
  // The database refuses anything else from service_role — 20260807064927 grants
  // `UPDATE (embedding)` and nothing more. This asserts the statement stays inside that grant, so
  // the failure is caught here rather than as a permission error against production.
  const { calls } = capture(new Response(null, { status: 204 }));
  try {
    await writeVector('https://kafoo.test', 'key', 'meal-1', [0.1, 0.2]);
  } finally {
    globalThis.fetch = original;
  }

  assertEquals(calls[0].method, 'PATCH');
  const body = await calls[0].json();
  assertEquals(Object.keys(body), ['embedding']);
});
