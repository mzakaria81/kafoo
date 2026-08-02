// The shape every model provider is normalised to.
//
// ADR-0005 Amendment 1: provider-specific behaviour — request shapes, streaming formats, error
// semantics — is absorbed by an adapter implementing this interface. Nothing above the adapter
// layer may know which provider served a call. If a caller starts branching on provider id, the
// abstraction has failed and the adapter is what needs fixing.
//
// No model name appears in this file, or in any adapter. Model names live in registry.ts and in
// environment variables, and `scripts/verify.sh` fails the gate if one appears anywhere else.

/// Which class of model a call needs. Mirrors `ModelTier` in
/// `packages/ai/lib/src/provider/ai_provider.dart` and the `model_tier` frontmatter key that every
/// file in `prompts/` carries.
export type ModelTier = 'fast' | 'reasoning';

export const MODEL_TIERS: readonly ModelTier[] = ['fast', 'reasoning'] as const;

/// An image to be looked at, already fetched and encoded.
///
/// Adapters never fetch anything themselves. The caller reads the photo from storage as the Cook,
/// so the function can only ever see what the Cook could already see — no public URL is minted, and
/// no adapter gets a chance to widen that.
export interface ModelImage {
  readonly base64: string;
  readonly mediaType: string;
}

export interface ModelRequest {
  /// The prompt file's body. Instructions, never user content.
  readonly system: string;

  /// What the person actually said. **Untrusted.** A Cook can write anything here, including
  /// instructions aimed at the model, so it is always carried as user content and never
  /// concatenated into `system`.
  readonly user: string;

  readonly image?: ModelImage;

  /// The concrete model, already resolved by the registry from the tier.
  readonly model: string;

  readonly maxTokens: number;
}

export interface ModelResponse {
  readonly text: string;

  /// The model that actually served the call, for evals and logs.
  readonly modelId: string;
}

/// A normalised failure. Adapters translate provider error shapes into this so callers never parse a
/// provider's error body.
export class ModelError extends Error {
  constructor(
    message: string,
    readonly kind: 'auth' | 'rate_limit' | 'timeout' | 'invalid_response' | 'upstream',
    readonly status?: number,
  ) {
    super(message);
    this.name = 'ModelError';
  }
}

export interface ProviderAdapter {
  /// The id used in `AI_PROVIDER`.
  readonly id: string;

  /// Which environment variable holds this provider's credential. Per-provider rather than one shared
  /// name on purpose: several keys can be stored at once, so switching provider is one variable
  /// rather than a key rotation. A dialect bake-off that needs new secrets between candidates is a
  /// bake-off nobody runs.
  readonly apiKeyEnvVar: string;

  complete(request: ModelRequest, apiKey: string): Promise<ModelResponse>;

  /// Streams text deltas. The constitution requires streaming for conversational responses — a
  /// reply that arrives in one lump after four seconds is broken even when it is correct.
  ///
  /// Each chunk is plain text, already extracted from whatever event format the provider uses. That
  /// normalisation is the single most provider-specific thing here and therefore belongs in the
  /// adapter rather than anywhere a caller can see it.
  stream(request: ModelRequest, apiKey: string): Promise<ReadableStream<string>>;
}
