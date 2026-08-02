// Tests for the provider registry.
//
// ADR-0005 Amendment 1 promises that switching model providers is one environment variable with no
// code diff. These assertions are what stop that promise from quietly becoming false — a
// half-added provider, a tier with no model, or a fallback that silently serves the wrong provider
// would all pass a build and fail a bill.
//
// Run with: deno test supabase/functions/_shared/ai/registry_test.ts

import { assertEquals, assertThrows } from 'jsr:@std/assert@1';
import { PROVIDERS, resolveProvider, TIERS } from './registry.ts';

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
    GOOGLE_API_KEY: 'key-g',
  };

  const before = resolveProvider('fast', envFrom({ ...bothKeys, AI_PROVIDER: 'anthropic' }));
  const after = resolveProvider('fast', envFrom({ ...bothKeys, AI_PROVIDER: 'google' }));

  assertEquals(before.adapter.id, 'anthropic');
  assertEquals(after.adapter.id, 'google');
  assertEquals(before.model, PROVIDERS.anthropic.defaults.fast);
  assertEquals(after.model, PROVIDERS.google.defaults.fast);
  assertEquals(before.apiKey, 'key-a');
  assertEquals(after.apiKey, 'key-g');
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
        envFrom({ AI_PROVIDER: 'anthropc', ANTHROPIC_API_KEY: 'key-a' }),
      ),
    Error,
    'not a known provider',
  );
});

Deno.test('an unset provider fails loudly', () => {
  assertThrows(
    () => resolveProvider('fast', envFrom({ ANTHROPIC_API_KEY: 'key-a' })),
    Error,
    'AI_PROVIDER is not set',
  );
});

Deno.test('a missing key fails before anything reaches the network', () => {
  // Named after the variable that is actually missing. "Unauthorized" from a provider at runtime is
  // a much worse way to learn that a secret was never set on this deployment.
  assertThrows(
    () => resolveProvider('fast', envFrom({ AI_PROVIDER: 'google', ANTHROPIC_API_KEY: 'key-a' })),
    Error,
    'GOOGLE_API_KEY is not set',
  );
});
