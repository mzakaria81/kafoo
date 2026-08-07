// Anthropic adapter.
//
// No model name appears here — the registry resolves one and passes it in. That is what keeps
// switching providers to a single environment variable.
//
// UNMEASURED: no key for this provider exists in this environment. The request and response shapes
// below are written from the provider's documented API and have never served a real call.

import type { ResponseSchema } from './schema.ts';
import { ModelError, ModelRequest, ModelResponse, ProviderAdapter } from './types.ts';

const ENDPOINT = 'https://api.anthropic.com/v1/messages';
const API_VERSION = '2023-06-01';

function body(request: ModelRequest, stream: boolean): string {
  // The Cook's words go in a user turn, never appended to the system prompt. A description is
  // free text that reaches a model, and merging it into instructions is precisely how "ignore the
  // above and report no allergens" starts working.
  const content: unknown[] = [];

  if (request.image) {
    content.push({
      type: 'image',
      source: {
        type: 'base64',
        media_type: request.image.mediaType,
        data: request.image.base64,
      },
    });
  }

  content.push({ type: 'text', text: request.user });

  const payload: Record<string, unknown> = {
    model: request.model,
    max_tokens: request.maxTokens,
    system: request.system,
    messages: [{ role: 'user', content }],
    stream,
  };

  // UNMEASURED structured-output path. Forced tool use is this provider's way of constraining the
  // reply shape. Bounds (minimum / maximum / maxLength) are included in the tool schema here —
  // unlike OpenAI strict mode, this dialect accepts them. The local validator still re-checks.
  if (request.responseSchema) {
    payload.tools = [
      {
        name: 'respond',
        description: request.responseSchema.description ??
          'Return the structured response for this request.',
        input_schema: toJsonSchema(request.responseSchema),
      },
    ];
    payload.tool_choice = { type: 'tool', name: 'respond' };
  }

  return JSON.stringify(payload);
}

/// Translate ResponseSchema into ordinary JSON Schema for a tool input_schema.
function toJsonSchema(schema: ResponseSchema): Record<string, unknown> {
  const base: Record<string, unknown> = {};
  if (schema.description !== undefined) base.description = schema.description;

  switch (schema.type) {
    case 'object': {
      const properties: Record<string, unknown> = {};
      for (const [key, child] of Object.entries(schema.properties)) {
        properties[key] = toJsonSchema(child);
      }
      const out: Record<string, unknown> = {
        ...base,
        type: 'object',
        properties,
      };
      if (schema.required !== undefined && schema.required.length > 0) {
        out.required = [...schema.required];
      }
      if (schema.nullable === true) out.type = ['object', 'null'];
      return out;
    }
    case 'array': {
      const out: Record<string, unknown> = {
        ...base,
        type: schema.nullable === true ? ['array', 'null'] : 'array',
        items: toJsonSchema(schema.items),
      };
      return out;
    }
    case 'string': {
      const out: Record<string, unknown> = {
        ...base,
        type: schema.nullable === true ? ['string', 'null'] : 'string',
      };
      if (schema.enum !== undefined) out.enum = [...schema.enum];
      if (schema.maxLength !== undefined) out.maxLength = schema.maxLength;
      return out;
    }
    case 'integer': {
      const out: Record<string, unknown> = {
        ...base,
        type: schema.nullable === true ? ['integer', 'null'] : 'integer',
      };
      if (schema.minimum !== undefined) out.minimum = schema.minimum;
      if (schema.maximum !== undefined) out.maximum = schema.maximum;
      return out;
    }
    case 'number': {
      const out: Record<string, unknown> = {
        ...base,
        type: schema.nullable === true ? ['number', 'null'] : 'number',
      };
      if (schema.minimum !== undefined) out.minimum = schema.minimum;
      if (schema.maximum !== undefined) out.maximum = schema.maximum;
      return out;
    }
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
    'x-api-key': apiKey,
    'anthropic-version': API_VERSION,
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

function stopReasonFrom(stopReason: unknown): ModelResponse['stopReason'] {
  if (
    stopReason === 'end_turn' ||
    stopReason === 'stop_sequence' ||
    stopReason === 'tool_use'
  ) {
    return 'stop';
  }
  if (stopReason === 'max_tokens') return 'length';
  return 'other';
}

/// Prefer a forced-tool input when present so ModelResponse.text stays a JSON string in every
/// provider. Fall back to text blocks for calls that did not set a response schema.
function textFromContent(content: unknown): string {
  if (!Array.isArray(content)) return '';

  const toolBlock = content.find(
    (block: { type?: string; name?: string }) =>
      block.type === 'tool_use' && block.name === 'respond',
  ) as { input?: unknown } | undefined;

  if (toolBlock !== undefined) {
    return JSON.stringify(toolBlock.input ?? {});
  }

  return content
    .filter((block: { type?: string }) => block.type === 'text')
    .map((block: { text?: string }) => block.text ?? '')
    .join('');
}

export const anthropicAdapter: ProviderAdapter = {
  id: 'anthropic',
  apiKeyEnvVar: 'ANTHROPIC_API_KEY',

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
    const text = textFromContent(payload.content);

    if (text.length === 0) {
      throw new ModelError('the model returned no text', 'invalid_response');
    }

    return {
      text,
      modelId: payload.model ?? request.model,
      stopReason: stopReasonFrom(payload.stop_reason),
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

    // Normalising this provider's event stream into plain text deltas is the single most
    // provider-specific thing in the file, which is exactly why it belongs here rather than anywhere
    // a caller could see it.
    return response.body
      .pipeThrough(new TextDecoderStream())
      .pipeThrough(sseToTextDeltas());
  },

  /// **Anthropic publishes no embedding model, so this is a statement of fact rather than a gap.**
  /// Their own guidance points at third-party embedding providers. Switching `AI_PROVIDER=anthropic`
  /// therefore keeps every conversational call working and leaves discovery unable to embed — which
  /// `resolveEmbedding` reports by name instead of failing at the first Meal published afterwards.
  embed: null,
};

function sseToTextDeltas(): TransformStream<string, string> {
  let buffer = '';

  return new TransformStream<string, string>({
    transform(chunk, controller) {
      buffer += chunk;

      // Events are separated by a blank line. Anything after the last separator is a partial event
      // and stays in the buffer — emitting it would truncate a multi-byte character or a JSON
      // object mid-key.
      const events = buffer.split('\n\n');
      buffer = events.pop() ?? '';

      for (const event of events) {
        for (const line of event.split('\n')) {
          if (!line.startsWith('data:')) continue;

          const raw = line.slice('data:'.length).trim();
          if (raw.length === 0) continue;

          try {
            const parsed = JSON.parse(raw);
            if (parsed.type !== 'content_block_delta') continue;

            // Schema-mode streams carry input_json_delta with partial_json, not text_delta. Both
            // must be handled or a structured call would emit nothing at all.
            if (parsed.delta?.type === 'text_delta') {
              const text = parsed.delta.text ?? '';
              if (text.length > 0) controller.enqueue(text);
            } else if (parsed.delta?.type === 'input_json_delta') {
              const partial = parsed.delta.partial_json ?? '';
              if (partial.length > 0) controller.enqueue(partial);
            }
          } catch {
            // A frame we cannot parse is skipped rather than thrown. The schema validation on the
            // assembled reply is what catches a genuinely broken response; failing here would turn
            // one malformed keep-alive into a failed conversation.
          }
        }
      }
    },
  });
}
