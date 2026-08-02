// The provider registry — the ONLY place in Kafoo where a model name is written down.
//
// ADR-0005 Amendment 1 makes switching model providers a configuration change with no code diff at
// all. That is only true while this file and the environment are the sole places a model is named,
// which is why `scripts/verify.sh` fails the gate on a model id found anywhere else.
//
// HOW TO SWITCH PROVIDER
//
//   supabase secrets set AI_PROVIDER=anthropic
//
// That is the whole operation, provided ANTHROPIC_API_KEY is already stored. Secrets take effect
// without redeploying function code, so there is no build and no app release. Unset it (or set it
// back to `gemini`) to return to the default. To pin a specific model instead of the default below:
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
import { geminiAdapter } from './gemini.ts';
import { openaiAdapter } from './openai.ts';
import { MODEL_TIERS, ModelTier, ProviderAdapter } from './types.ts';

/// The provider used when `AI_PROVIDER` is not set.
///
/// A named default is not the same thing as a silent fallback. This one is a decision, written
/// down, and the deployment that relies on it is running what somebody chose. What must never
/// happen is a *wrong* value quietly resolving to something that works — `AI_PROVIDER=anthropc`
/// throws rather than landing here, because that is the case where a deployment serves a provider
/// nobody picked and nobody finds out until the bill.
export const DEFAULT_PROVIDER = 'gemini';

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
  // MEASURED, not chosen from a pricing page. On 2026-08-02, against the real key, with the
  // meal-analysis prompt and a Cook's description containing a prompt-injection attempt:
  //
  //   gemini-3.1-flash-lite   645-1273 ms   0 thinking tokens   allergens correct
  //   gemini-3.6-flash        4.0-8.5 s     642-941 thinking    allergens correct
  //   gemini-3.5-flash        4.6 s         1150 thinking       INVALID JSON
  //
  // The first default written here was `gemini-2.5-flash`, taken from published pricing, and the
  // API refused it: "no longer available to new users". It is still listed by ListModels, so even
  // asking the provider what exists would not have caught it. Only a real call did.
  //
  // flash-lite is the fast tier because this is extraction and classification, and the heavier
  // models spend most of their latency budget "thinking" about a task that does not need it — 10x
  // slower for the same answer, and outside the 2-second voice budget rather than inside it.
  gemini: {
    adapter: geminiAdapter,
    defaults: {
      fast: 'gemini-3.1-flash-lite',
      // Reachable but unmeasured: the account is rate-limited on Pro-tier calls (HTTP 429 on the
      // first one). E2 uses no reasoning-tier prompt, so nothing depends on this yet — but do not
      // assume it works until something does.
      reasoning: 'gemini-3.1-pro-preview',
    },
  },
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
/// An unset `AI_PROVIDER` resolves to [DEFAULT_PROVIDER]. A *wrong* one throws.
///
/// That distinction is the whole of the safety argument. A named default is a decision somebody
/// made and wrote down; a typo resolving to something that happens to work is a deployment serving
/// a provider nobody picked, invisible until the bill arrives. The first is convenience, the second
/// is the failure this mechanism exists to prevent, and they must not be handled the same way.
export function resolveProvider(
  tier: ModelTier,
  env: (key: string) => string | undefined,
): ResolvedProvider {
  const configured = env('AI_PROVIDER');
  const providerId = configured && configured.trim().length > 0
    ? configured.trim()
    : DEFAULT_PROVIDER;

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
