// OpenAI adapter.
//
// Present so that ADR-0005's claim is testable rather than aspirational: a second provider that
// nobody has switched to is how you find out the abstraction only ever fitted one. No model name
// here — the registry resolves one and passes it in.

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

  return JSON.stringify({
    model: request.model,
    max_completion_tokens: request.maxTokens,
    messages: [
      { role: 'system', content: request.system },
      { role: 'user', content },
    ],
    stream,
  });
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

    return { text, modelId: payload.model ?? request.model };
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
