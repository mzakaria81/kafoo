// The provider registry — the ONLY place in Kafoo where a model name is written down.
//
// ADR-0005 Amendment 1 makes switching model providers a configuration change with no code diff at
// all. That is only true while this file and the environment are the sole places a model is named,
// which is why `scripts/verify.sh` fails the gate on a model id found anywhere else.
//
// HOW TO SWITCH PROVIDER
//
//   supabase secrets set AI_PROVIDER=google
//
// That is the whole operation, provided GOOGLE_API_KEY is already stored. Secrets take effect
// without redeploying function code, so there is no build and no app release. To pin a specific
// model instead of the default below:
//
//   supabase secrets set AI_MODEL_FAST=<model>
//
// HOW TO ADD A PROVIDER
//
//   1. Write an adapter implementing ProviderAdapter.
//   2. Add one entry here with its defaults for both tiers.
//   3. Store its key.
//
// registry_test.ts asserts every entry resolves a model for every tier, so a half-added provider
// fails loudly at test time rather than at the first call.

import { anthropicAdapter } from './anthropic.ts';
import { googleAdapter } from './google.ts';
import { openaiAdapter } from './openai.ts';
import { MODEL_TIERS, ModelTier, ProviderAdapter } from './types.ts';

interface ProviderEntry {
  readonly adapter: ProviderAdapter;

  /// Which concrete model serves each tier for this provider.
  ///
  /// Defaults exist so that switching provider is genuinely ONE variable. Without them, changing
  /// `AI_PROVIDER` would also require knowing and setting that provider's model names, and a
  /// two-variable switch is one somebody gets half right.
  readonly defaults: Readonly<Record<ModelTier, string>>;
}

export const PROVIDERS: Readonly<Record<string, ProviderEntry>> = {
  anthropic: {
    adapter: anthropicAdapter,
    defaults: {
      fast: 'claude-haiku-4-5',
      reasoning: 'claude-sonnet-5',
    },
  },
  openai: {
    adapter: openaiAdapter,
    defaults: {
      fast: 'gpt-5-mini',
      reasoning: 'gpt-5',
    },
  },
  google: {
    adapter: googleAdapter,
    defaults: {
      fast: 'gemini-2.5-flash',
      reasoning: 'gemini-3-pro',
    },
  },
} as const;

export interface ResolvedProvider {
  readonly adapter: ProviderAdapter;
  readonly model: string;
  readonly apiKey: string;
}

/// Reads the environment and returns everything a call needs.
///
/// [env] is injected rather than read from `Deno.env` directly, so the tests can drive every
/// configuration without setting process-wide state.
///
/// Throws on misconfiguration rather than falling back to a default. A silent fallback here means
/// a deployment quietly serving a different provider than the one somebody configured, which is the
/// exact failure this whole mechanism exists to prevent — and it would be invisible until someone
/// read a bill.
export function resolveProvider(
  tier: ModelTier,
  env: (key: string) => string | undefined,
): ResolvedProvider {
  const providerId = env('AI_PROVIDER');
  if (!providerId) {
    throw new Error(
      'AI_PROVIDER is not set. Expected one of: ' + Object.keys(PROVIDERS).join(', '),
    );
  }

  const entry = PROVIDERS[providerId];
  if (!entry) {
    throw new Error(
      `AI_PROVIDER="${providerId}" is not a known provider. Expected one of: ` +
        Object.keys(PROVIDERS).join(', '),
    );
  }

  const override = env(tier === 'fast' ? 'AI_MODEL_FAST' : 'AI_MODEL_REASONING');
  const model = override && override.trim().length > 0 ? override.trim() : entry.defaults[tier];

  const apiKey = env(entry.adapter.apiKeyEnvVar);
  if (!apiKey) {
    throw new Error(
      `${entry.adapter.apiKeyEnvVar} is not set, and AI_PROVIDER is "${providerId}".`,
    );
  }

  return { adapter: entry.adapter, model, apiKey };
}

/// Every tier this registry can serve. Exported so tests can iterate without importing the tier
/// list from two places.
export const TIERS = MODEL_TIERS;
