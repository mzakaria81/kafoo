// OpenAI adapter.
//
// Present so that ADR-0005's claim is testable rather than aspirational: a second provider that
// nobody has switched to is how you find out the abstraction only ever fitted one. No model name
// here — the registry resolves one and passes it in.
//
// UNMEASURED: no key for this provider exists in this environment. The request and response shapes
// below are written from the provider's documented API and have never served a real call.

import type { ResponseSchema } from './schema.ts';
import { ModelError, ModelRequest, ModelResponse, ProviderAdapter } from './types.ts';

const ENDPOINT = 'https://api.openai.com/v1/chat/completions';

function body(request: ModelRequest, stream: boolean): string {
  // The Cook's words stay in a user turn. Same reasoning as every other adapter: merging untrusted
  // text into the instructions is how prompt injection starts working.
  const content: unknown[] = [{ type: 'text', text: request.user }];

  if (request.image) {
    content.unshift({
      type: 'image_url',
      image_url: {
        url: `data:${request.image.mediaType};base64,${request.image.base64}`,
      },
    });
  }

  const payload: Record<string, unknown> = {
    model: request.model,
    max_completion_tokens: request.maxTokens,
    messages: [
      { role: 'system', content: request.system },
      { role: 'user', content },
    ],
    stream,
  };

  // UNMEASURED structured-output path. Strict mode requires every property in `required` and
  // `additionalProperties: false` on every object. Optional fields are therefore expressed as
  // nullable rather than omitted from required. minimum / maximum / maxLength are not supported by
  // strict mode — they are dropped here and enforced by the local validator in schema.ts instead.
  if (request.responseSchema) {
    payload.response_format = {
      type: 'json_schema',
      json_schema: {
        name: 'response',
        strict: true,
        schema: toStrictJsonSchema(request.responseSchema),
      },
    };
  }

  return JSON.stringify(payload);
}

/// Translate ResponseSchema into the JSON Schema that OpenAI strict structured outputs accepts.
function toStrictJsonSchema(schema: ResponseSchema): Record<string, unknown> {
  const base: Record<string, unknown> = {};
  if (schema.description !== undefined) base.description = schema.description;

  switch (schema.type) {
    case 'object': {
      const properties: Record<string, unknown> = {};
      for (const [key, child] of Object.entries(schema.properties)) {
        properties[key] = toStrictJsonSchema(child);
      }
      // Strict mode demands every property appear in required. A field that is optional in our
      // schema is sent as nullable instead of being left out of required.
      const required = Object.keys(schema.properties);
      for (const key of required) {
        const child = schema.properties[key];
        const isRequired = (schema.required ?? []).includes(key);
        if (!isRequired && child.nullable !== true) {
          properties[key] = toStrictJsonSchema({ ...child, nullable: true });
        }
      }
      return {
        ...base,
        type: schema.nullable === true ? ['object', 'null'] : 'object',
        properties,
        required,
        additionalProperties: false,
      };
    }
    case 'array':
      return {
        ...base,
        type: schema.nullable === true ? ['array', 'null'] : 'array',
        items: toStrictJsonSchema(schema.items),
      };
    case 'string': {
      const out: Record<string, unknown> = {
        ...base,
        type: schema.nullable === true ? ['string', 'null'] : 'string',
      };
      if (schema.enum !== undefined) out.enum = [...schema.enum];
      // maxLength deliberately omitted — not supported in strict mode; local validator enforces it.
      return out;
    }
    case 'integer':
      // minimum / maximum deliberately omitted — not supported in strict mode.
      return {
        ...base,
        type: schema.nullable === true ? ['integer', 'null'] : 'integer',
      };
    case 'number':
      // minimum / maximum deliberately omitted — not supported in strict mode.
      return {
        ...base,
        type: schema.nullable === true ? ['number', 'null'] : 'number',
      };
    case 'boolean':
      return {
        ...base,
        type: schema.nullable === true ? ['boolean', 'null'] : 'boolean',
      };
  }
}

function headers(apiKey: string): HeadersInit {
  return {
    'content-type': 'application/json',
    authorization: `Bearer ${apiKey}`,
  };
}

function translateFailure(status: number, detail: string): ModelError {
  if (status === 401 || status === 403) {
    return new ModelError('the model provider rejected our credential', 'auth', status);
  }
  if (status === 429) {
    return new ModelError('the model provider is rate limiting us', 'rate_limit', status);
  }
  if (status === 408 || status === 504) {
    return new ModelError('the model provider timed out', 'timeout', status);
  }
  return new ModelError(`the model provider failed: ${detail}`, 'upstream', status);
}

function stopReasonFrom(finishReason: unknown): ModelResponse['stopReason'] {
  if (finishReason === 'stop') return 'stop';
  if (finishReason === 'length') return 'length';
  return 'other';
}

export const openaiAdapter: ProviderAdapter = {
  id: 'openai',
  apiKeyEnvVar: 'OPENAI_API_KEY',

  async complete(request: ModelRequest, apiKey: string): Promise<ModelResponse> {
    const response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: headers(apiKey),
      body: body(request, false),
    });

    if (!response.ok) {
      throw translateFailure(response.status, await response.text());
    }

    const payload = await response.json();
    const text = payload.choices?.[0]?.message?.content ?? '';

    if (text.length === 0) {
      throw new ModelError('the model returned no text', 'invalid_response');
    }

    return {
      text,
      modelId: payload.model ?? request.model,
      stopReason: stopReasonFrom(payload.choices?.[0]?.finish_reason),
    };
  },

  async stream(request: ModelRequest, apiKey: string): Promise<ReadableStream<string>> {
    const response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: headers(apiKey),
      body: body(request, true),
    });

    if (!response.ok || !response.body) {
      throw translateFailure(response.status, await response.text());
    }

    return response.body
      .pipeThrough(new TextDecoderStream())
      .pipeThrough(sseToTextDeltas());
  },

  /// **`null` because Kafoo has not measured OpenAI's embeddings, not because they do not exist.**
  ///
  /// They do, and wiring them up is a small change. What is missing is the evidence: the 768
  /// dimensions this schema stores, the Egyptian Arabic retrieval quality, and the cross-language
  /// behaviour were all measured against Gemini and none of them transfer by assumption. Declaring
  /// support the registry cannot back would make `AI_PROVIDER=openai` silently produce vectors of
  /// unknown quality in the same column as the measured ones, which is worse than refusing.
  ///
  /// To implement: add `embed`, add an `embeddingModel` to this provider's registry entry, and
  /// re-run the spike in `scripts/spike-discovery-embeddings.py` against it before trusting it.
  embed: null,
};

function sseToTextDeltas(): TransformStream<string, string> {
  let buffer = '';

  return new TransformStream<string, string>({
    transform(chunk, controller) {
      buffer += chunk;

      const events = buffer.split('\n\n');
      buffer = events.pop() ?? '';

      for (const event of events) {
        for (const line of event.split('\n')) {
          if (!line.startsWith('data:')) continue;

          const raw = line.slice('data:'.length).trim();
          if (raw.length === 0 || raw === '[DONE]') continue;

          try {
            const delta = JSON.parse(raw).choices?.[0]?.delta?.content;
            if (typeof delta === 'string' && delta.length > 0) {
              controller.enqueue(delta);
            }
          } catch {
            // Skipped rather than thrown — see the note in anthropic.ts.
          }
        }
      }
    },
  });
}
