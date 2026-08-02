// Google adapter.
//
// The third provider, and the one whose request shape differs most — different envelope, different
// name for the system prompt, different streaming format. That is the point: an abstraction proven
// against two similar providers has not been proven. No model name here; the registry passes one in.

import { ModelError, ModelRequest, ModelResponse, ProviderAdapter } from './types.ts';

const BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

function endpoint(model: string, stream: boolean): string {
  const method = stream ? 'streamGenerateContent?alt=sse' : 'generateContent';
  return `${BASE}/${encodeURIComponent(model)}:${method}`;
}

function body(request: ModelRequest): string {
  // The Cook's words stay in the user parts; the prompt goes in systemInstruction. Same rule as
  // everywhere else, expressed in this provider's vocabulary.
  const parts: unknown[] = [];

  if (request.image) {
    parts.push({
      inlineData: {
        mimeType: request.image.mediaType,
        data: request.image.base64,
      },
    });
  }

  parts.push({ text: request.user });

  return JSON.stringify({
    systemInstruction: { parts: [{ text: request.system }] },
    contents: [{ role: 'user', parts }],
    generationConfig: { maxOutputTokens: request.maxTokens },
  });
}

function headers(apiKey: string): HeadersInit {
  return {
    'content-type': 'application/json',
    'x-goog-api-key': apiKey,
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

function textFromCandidates(payload: {
  candidates?: { content?: { parts?: { text?: string }[] } }[];
}): string {
  return (payload.candidates?.[0]?.content?.parts ?? [])
    .map((part) => part.text ?? '')
    .join('');
}

export const googleAdapter: ProviderAdapter = {
  id: 'google',
  apiKeyEnvVar: 'GOOGLE_API_KEY',

  async complete(request: ModelRequest, apiKey: string): Promise<ModelResponse> {
    const response = await fetch(endpoint(request.model, false), {
      method: 'POST',
      headers: headers(apiKey),
      body: body(request),
    });

    if (!response.ok) {
      throw translateFailure(response.status, await response.text());
    }

    const text = textFromCandidates(await response.json());

    if (text.length === 0) {
      throw new ModelError('the model returned no text', 'invalid_response');
    }

    return { text, modelId: request.model };
  },

  async stream(request: ModelRequest, apiKey: string): Promise<ReadableStream<string>> {
    const response = await fetch(endpoint(request.model, true), {
      method: 'POST',
      headers: headers(apiKey),
      body: body(request),
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
          if (raw.length === 0) continue;

          try {
            const text = textFromCandidates(JSON.parse(raw));
            if (text.length > 0) controller.enqueue(text);
          } catch {
            // Skipped rather than thrown — see the note in anthropic.ts.
          }
        }
      }
    },
  });
}
