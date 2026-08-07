// Tests for the provider registry.
//
// ADR-0005 Amendment 1 promises that switching model providers is one environment variable with no
// code diff. These assertions are what stop that promise from quietly becoming false — a
// half-added provider, a tier with no model, or a fallback that silently serves the wrong provider
// would all pass a build and fail a bill.
//
// Run with: deno test supabase/functions/_shared/ai/registry_test.ts

import { assertEquals, assertThrows } from 'jsr:@std/assert@1';
import {
  DEFAULT_PROVIDER,
  EMBEDDING_DIMENSIONS,
  PROVIDERS,
  resolveEmbedding,
  resolveProvider,
  TIERS,
} from './registry.ts';

/// Builds an env lookup from a plain object, so a test can describe a whole deployment's
/// configuration in one literal without touching process-wide state.
function envFrom(vars: Record<string, string>): (key: string) => string | undefined {
  return (key) => vars[key];
}

Deno.test('every provider resolves a model for every tier', () => {
  // The assertion that stops a provider being half-added. Adding an entry with one tier filled in
  // would work in development and fail the first time a reasoning-tier prompt ran.
  for (const [id, entry] of Object.entries(PROVIDERS)) {
    for (const tier of TIERS) {
      const model = entry.defaults[tier];
      assertEquals(
        typeof model === 'string' && model.length > 0,
        true,
        `provider "${id}" has no model for the "${tier}" tier`,
      );
    }
  }
});

Deno.test('every provider names a distinct key variable', () => {
  // Two providers reading the same variable would make "store several keys at once" impossible, and
  // switching provider would become a key rotation — which is the thing the amendment set out to
  // avoid.
  const seen = new Set<string>();
  for (const [id, entry] of Object.entries(PROVIDERS)) {
    const name = entry.adapter.apiKeyEnvVar;
    assertEquals(seen.has(name), false, `"${id}" reuses the key variable ${name}`);
    seen.add(name);
  }
});

Deno.test('a provider id matches the adapter it points at', () => {
  // A registry key that disagrees with its adapter's own id makes every error message name the
  // wrong provider, which is the kind of thing found at 2am rather than at review.
  for (const [id, entry] of Object.entries(PROVIDERS)) {
    assertEquals(entry.adapter.id, id);
  }
});

Deno.test('switching provider is one variable', () => {
  // The claim, asserted directly. Same environment, both keys present, AI_PROVIDER the only
  // difference — and the resolved model changes without anything else being set.
  const bothKeys = {
    ANTHROPIC_API_KEY: 'key-a',
    GEMINI_API_KEY: 'key-g',
  };

  const before = resolveProvider('fast', envFrom({ ...bothKeys, AI_PROVIDER: 'gemini' }));
  const after = resolveProvider('fast', envFrom({ ...bothKeys, AI_PROVIDER: 'anthropic' }));

  assertEquals(before.adapter.id, 'gemini');
  assertEquals(after.adapter.id, 'anthropic');
  assertEquals(before.model, PROVIDERS.gemini.defaults.fast);
  assertEquals(after.model, PROVIDERS.anthropic.defaults.fast);
  assertEquals(before.apiKey, 'key-g');
  assertEquals(after.apiKey, 'key-a');
});

Deno.test('an explicit model overrides the default', () => {
  const resolved = resolveProvider(
    'fast',
    envFrom({
      AI_PROVIDER: 'anthropic',
      ANTHROPIC_API_KEY: 'key-a',
      AI_MODEL_FAST: 'some-other-model',
    }),
  );

  assertEquals(resolved.model, 'some-other-model');
});

Deno.test('an override for one tier does not leak into the other', () => {
  const env = envFrom({
    AI_PROVIDER: 'anthropic',
    ANTHROPIC_API_KEY: 'key-a',
    AI_MODEL_FAST: 'some-other-model',
  });

  assertEquals(resolveProvider('fast', env).model, 'some-other-model');
  assertEquals(resolveProvider('reasoning', env).model, PROVIDERS.anthropic.defaults.reasoning);
});

Deno.test('a blank override falls back to the default rather than requesting an empty model', () => {
  // `supabase secrets set AI_MODEL_FAST=` is a plausible way to try to clear an override, and it
  // must not produce a request for a model named "".
  const resolved = resolveProvider(
    'fast',
    envFrom({
      AI_PROVIDER: 'anthropic',
      ANTHROPIC_API_KEY: 'key-a',
      AI_MODEL_FAST: '   ',
    }),
  );

  assertEquals(resolved.model, PROVIDERS.anthropic.defaults.fast);
});

Deno.test('an unknown provider fails loudly instead of falling back', () => {
  // The most important negative case here. A fallback would mean a deployment quietly serving a
  // provider nobody configured — invisible until someone read a bill, and exactly the failure the
  // configuration mechanism exists to prevent.
  assertThrows(
    () =>
      resolveProvider(
        'fast',
        envFrom({ AI_PROVIDER: 'anthropc', ANTHROPIC_API_KEY: 'key-a', GEMINI_API_KEY: 'key-g' }),
      ),
    Error,
    'not a known provider',
  );
});

Deno.test('an unset provider resolves to the documented default', () => {
  // Deliberately NOT an error. A named default is a decision somebody made; the founder chose
  // Gemini, and a deployment that sets nothing runs what was chosen. Contrast with the typo case
  // above, which must still throw — that is the one where nobody picked what is running.
  const resolved = resolveProvider('fast', envFrom({ GEMINI_API_KEY: 'key-g' }));

  assertEquals(resolved.adapter.id, DEFAULT_PROVIDER);
  assertEquals(resolved.adapter.id, 'gemini');
  assertEquals(resolved.model, PROVIDERS.gemini.defaults.fast);
});

Deno.test('a blank provider resolves to the default rather than failing', () => {
  // `supabase secrets set AI_PROVIDER=` is how somebody tries to clear the override.
  const resolved = resolveProvider('fast', envFrom({ AI_PROVIDER: '  ', GEMINI_API_KEY: 'key-g' }));

  assertEquals(resolved.adapter.id, DEFAULT_PROVIDER);
});

Deno.test('the default provider is actually in the registry', () => {
  // Guards the one-character typo that would make every unconfigured deployment throw.
  assertEquals(Object.keys(PROVIDERS).includes(DEFAULT_PROVIDER), true);
});

Deno.test('a missing key fails before anything reaches the network', () => {
  // Named after the variable that is actually missing. "Unauthorized" from a provider at runtime is
  // a much worse way to learn that a secret was never set on this deployment.
  assertThrows(
    () => resolveProvider('fast', envFrom({ AI_PROVIDER: 'gemini', ANTHROPIC_API_KEY: 'key-a' })),
    Error,
    'GEMINI_API_KEY is not set',
  );
});

// ────────────────────────────────────────────────────────────────────────────────────────────────
// Embeddings
//
// A different capability from the tiers above, and it fails differently. A provider that cannot
// complete a prompt is a broken deployment nobody can miss; a provider that cannot EMBED still
// serves every conversational call in Kafoo perfectly, and only discovery stops working — which is
// exactly the shape of failure that reaches production.
// ────────────────────────────────────────────────────────────────────────────────────────────────

Deno.test('every provider declares whether it can embed, in both places', () => {
  // THE HALF-ADDED PROVIDER, in its embedding form. A model name with no implementation resolves a
  // model and then calls null; an implementation with no model name is a capability nobody can
  // reach. Both are silent, and both are one forgetful edit away.
  for (const [id, entry] of Object.entries(PROVIDERS)) {
    const hasImplementation = entry.adapter.embed !== null;
    const hasModel = entry.embeddingModel !== null;
    assertEquals(
      hasImplementation,
      hasModel,
      `${id} declares embed=${hasImplementation ? 'a function' : 'null'} but embeddingModel=` +
        `${hasModel ? entry.embeddingModel : 'null'}. They must agree.`,
    );
  }
});

Deno.test('at least one provider can actually embed', () => {
  // Otherwise every assertion above is satisfied by a registry where nothing works.
  const able = Object.values(PROVIDERS).filter((e) => e.adapter.embed !== null);
  assertEquals(able.length > 0, true, 'no provider can produce embeddings');
});

Deno.test('a provider that cannot embed refuses instead of falling back', () => {
  // THE WRONG-PROVIDER FALLBACK. AI_PROVIDER=anthropic is a valid, working configuration for every
  // conversational call, and Anthropic has no embedding model. The tempting behaviour is to quietly
  // use Gemini anyway — which spends a key nobody selected, on a provider nobody chose, discovered
  // at the bill. Same argument as the unknown-provider case, one level in.
  const error = assertThrows(
    () =>
      resolveEmbedding(envFrom({
        AI_PROVIDER: 'anthropic',
        ANTHROPIC_API_KEY: 'k',
        GEMINI_API_KEY: 'k',
      })),
    Error,
  );
  assertEquals(error.message.includes('cannot produce embeddings'), true, error.message);
  // The message names who CAN, because "embedding failed" sends the reader nowhere.
  assertEquals(error.message.includes('gemini'), true, error.message);
});

Deno.test('an unknown provider fails the same way for embeddings as for completions', () => {
  assertThrows(
    () => resolveEmbedding(envFrom({ AI_PROVIDER: 'gemni', GEMINI_API_KEY: 'k' })),
    Error,
    'is not a known provider',
  );
});

Deno.test('embedding resolves the measured model and width by default', () => {
  const resolved = resolveEmbedding(envFrom({ GEMINI_API_KEY: 'k' }));
  assertEquals(resolved.model, PROVIDERS[DEFAULT_PROVIDER].embeddingModel);
  assertEquals(resolved.dimensions, EMBEDDING_DIMENSIONS);
  assertEquals(resolved.apiKey, 'k');
});

Deno.test('the embedding width matches what the database column stores', () => {
  // If these drift, every write fails at the column — loudly, but only in production, and only
  // once a Meal is published. The migration is the source of truth; this is the second copy, so it
  // is asserted against the migration text rather than against a number typed twice.
  const migration = Deno.readTextFileSync(
    new URL('../../../migrations/20260806231625_add_meal_embeddings.sql', import.meta.url),
  );
  assertEquals(
    migration.includes(`vector(${EMBEDDING_DIMENSIONS})`),
    true,
    `the migration does not declare vector(${EMBEDDING_DIMENSIONS})`,
  );
});

Deno.test('an explicit embedding model overrides the default', () => {
  const resolved = resolveEmbedding(
    envFrom({ GEMINI_API_KEY: 'k', AI_MODEL_EMBEDDING: 'something-else' }),
  );
  assertEquals(resolved.model, 'something-else');
});

Deno.test('a missing key is reported before any call is attempted', () => {
  assertThrows(
    () => resolveEmbedding(envFrom({})),
    Error,
    'GEMINI_API_KEY is not set',
  );
});

// ────────────────────────────────────────────────────────────────────────────────────────────────
// The guard around an adapter's embed
//
// ADR-0011 says "the model's output reaches the database only as numbers, whose width is checked
// before the write". That was true of gemini.ts and of nothing else, so the next adapter would have
// inherited the claim without the code. These assert it at the seam.
// ────────────────────────────────────────────────────────────────────────────────────────────────

/// Swaps in a fake embed so the guard can be driven without a provider.
function withFakeEmbed<T>(vector: readonly number[], run: (resolved: unknown) => T): T {
  const entry = PROVIDERS[DEFAULT_PROVIDER] as unknown as {
    adapter: { embed: unknown };
  };
  const real = entry.adapter.embed;
  entry.adapter.embed = () => Promise.resolve({ vector });
  try {
    return run(resolveEmbedding(envFrom({ GEMINI_API_KEY: 'k' })));
  } finally {
    entry.adapter.embed = real;
  }
}

Deno.test('a vector of the wrong width is refused at the seam, not at the column', async () => {
  // Postgres would reject it anyway, but as a failed write inside a function holding a write
  // credential, reported as a database error. The provider ignoring outputDimensionality is the
  // thing a person needs to be told.
  const resolved = withFakeEmbed(new Array(1536).fill(0.1), (r) => r) as {
    embed: (r: unknown, k: string) => Promise<unknown>;
    model: string;
    dimensions: number;
  };
  let message = '';
  try {
    await resolved.embed(
      { model: resolved.model, text: 'كشري', task: 'document', dimensions: resolved.dimensions },
      'k',
    );
  } catch (error) {
    message = String(error);
  }
  assertEquals(message.includes('1536-dimension'), true, message);
});

Deno.test('a vector carrying something that is not a number is refused', async () => {
  const resolved = withFakeEmbed([...new Array(767).fill(0.1), Number.NaN], (r) => r) as {
    embed: (r: unknown, k: string) => Promise<unknown>;
    model: string;
    dimensions: number;
  };
  let message = '';
  try {
    await resolved.embed(
      { model: resolved.model, text: 'كشري', task: 'document', dimensions: resolved.dimensions },
      'k',
    );
  } catch (error) {
    message = String(error);
  }
  assertEquals(message.includes('not a number'), true, message);
});

Deno.test('a zero vector is refused rather than stored at the origin', async () => {
  // A zero vector has no direction, and normalising it divides by zero. Stored, it would sit
  // equidistant from every query — a Meal that is equally irrelevant to everything, forever.
  const resolved = withFakeEmbed(new Array(768).fill(0), (r) => r) as {
    embed: (r: unknown, k: string) => Promise<unknown>;
    model: string;
    dimensions: number;
  };
  let message = '';
  try {
    await resolved.embed(
      { model: resolved.model, text: 'كشري', task: 'document', dimensions: resolved.dimensions },
      'k',
    );
  } catch (error) {
    message = String(error);
  }
  assertEquals(message.includes('zero vector'), true, message);
});

Deno.test('what reaches the caller is normalised', async () => {
  // Three documents claimed this and nothing did it — the migration's index comment, the
  // embed-meal contract, and T133. Harmless under cosine distance, silently wrong the day somebody
  // switches to inner product for speed.
  const resolved = withFakeEmbed(new Array(768).fill(2), (r) => r) as {
    embed: (r: unknown, k: string) => Promise<{ vector: readonly number[] }>;
    model: string;
    dimensions: number;
  };
  const { vector } = await resolved.embed(
    { model: resolved.model, text: 'كشري', task: 'document', dimensions: resolved.dimensions },
    'k',
  );
  const magnitude = Math.sqrt(vector.reduce((sum, v) => sum + v * v, 0));
  assertEquals(Math.abs(magnitude - 1) < 1e-9, true, `magnitude was ${magnitude}`);
});
