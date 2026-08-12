// What `speak` will say, and what it refuses to be told.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THE TEST THAT MATTERS IS ASSERTION 4: a voice id in the request body is IGNORED.
//
// The reasoning is `embed-meal`'s, applied to spending instead of ranking. A client that can name a
// voice can name any voice in the provider's library, and iterate the catalogue on Kafoo's bill. So
// the body carries `female` or `male`, and these tests drive the handler with a body that carries
// BOTH a role and a hostile `voiceId`, then assert on what actually reached the provider.
//
// That is the shape `embed-meal`'s first test got wrong: it exercised a pure function that could not
// see a request, so the assertion was a tautology and the real defect would have left the gate
// green. These drive the handler.
// ────────────────────────────────────────────────────────────────────────────────────────────────

import { assert, assertEquals } from 'jsr:@std/assert@1';

import {
  handleSpeak,
  MAX_CHARACTERS,
  SpeakDeps,
  VOICES,
} from './index.ts';

interface Recorder {
  deps: SpeakDeps;
  calls: { voiceId: string; line: string }[];
}

function recorder({ fail = false }: { fail?: boolean } = {}): Recorder {
  const calls: { voiceId: string; line: string }[] = [];
  return {
    calls,
    deps: {
      synthesize(voiceId, line) {
        calls.push({ voiceId, line });
        return Promise.resolve(
          fail
            ? { ok: false as const }
            : { ok: true as const, audio: new Uint8Array([0x49, 0x44, 0x33]).buffer },
        );
      },
    },
  };
}

function post(body: unknown): Request {
  return new Request('http://localhost/speak', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
}

Deno.test('1. a sentence in the female voice comes back as audio', async () => {
  const r = recorder();
  const response = await handleSpeak(
    post({ line: 'تمام، الأكلة منشورة', voice: 'female' }),
    r.deps,
  );

  assertEquals(response.status, 200);
  // Octet-stream deliberately — `audio/mpeg` is what this is, and it is the
  // one value that makes the Dart client utf8-decode the bytes. See the note
  // in index.ts.
  assertEquals(
    response.headers.get('content-type'),
    'application/octet-stream',
  );
  assertEquals(r.calls.length, 1);
  assertEquals(r.calls[0].voiceId, VOICES.female);
  assertEquals(r.calls[0].line, 'تمام، الأكلة منشورة');
});

Deno.test('2. the male role maps to the other voice', async () => {
  const r = recorder();
  await handleSpeak(post({ line: 'أيوة', voice: 'male' }), r.deps);
  assertEquals(r.calls[0].voiceId, VOICES.male);
});

Deno.test('3. the two voices are different, or the setting is decoration', () => {
  // Widened deliberately: comparing the two literal types is a compile error,
  // and the thing worth asserting is that the map has two distinct entries.
  const ids: string[] = Object.values(VOICES);
  assertEquals(new Set(ids).size, 2);
});

Deno.test('4. A VOICE ID IN THE BODY IS IGNORED — the caller cannot pick', async () => {
  const r = recorder();
  const response = await handleSpeak(
    post({
      line: 'أيوة',
      voice: 'female',
      // Hostile: a real-looking id the caller would rather Kafoo paid for.
      voiceId: 'pNInz6obpgDQGcFmaJgB',
      voice_id: 'pNInz6obpgDQGcFmaJgB',
    }),
    r.deps,
  );

  assertEquals(response.status, 200);
  assertEquals(
    r.calls[0].voiceId,
    VOICES.female,
    'the request body chose the voice — the caller can now spend on any voice',
  );
});

Deno.test('5. an unknown role is refused rather than defaulted', async () => {
  for (const voice of ['narrator', '', null, 42, VOICES.female]) {
    const r = recorder();
    const response = await handleSpeak(post({ line: 'أيوة', voice }), r.deps);
    assertEquals(response.status, 400, `voice ${JSON.stringify(voice)}`);
    assertEquals(r.calls.length, 0, 'nothing should have been billed');
  }
});

Deno.test('6. an empty or missing line is refused before anything is billed', async () => {
  for (const line of ['', '   ', null, undefined, 7]) {
    const r = recorder();
    const response = await handleSpeak(post({ line, voice: 'female' }), r.deps);
    assertEquals(response.status, 400, `line ${JSON.stringify(line)}`);
    assertEquals(r.calls.length, 0);
  }
});

Deno.test('7. an over-long line is refused, not truncated', async () => {
  // A half-said sentence is worse than a refusal, and the cap is what stops one
  // request spending a month's allowance.
  const r = recorder();
  const response = await handleSpeak(
    post({ line: 'ا'.repeat(MAX_CHARACTERS + 1), voice: 'female' }),
    r.deps,
  );
  assertEquals(response.status, 413);
  assertEquals(r.calls.length, 0);
});

Deno.test('8. a line exactly at the cap is allowed', async () => {
  const r = recorder();
  const response = await handleSpeak(
    post({ line: 'ا'.repeat(MAX_CHARACTERS), voice: 'female' }),
    r.deps,
  );
  assertEquals(response.status, 200);
});

Deno.test('9. a provider failure says nothing about the sentence', async () => {
  const r = recorder({ fail: true });
  const secret = 'محشي ورق عنب بمية وعشرين';
  const response = await handleSpeak(
    post({ line: secret, voice: 'female' }),
    r.deps,
  );

  assertEquals(response.status, 503);
  const text = await response.text();
  assert(
    !text.includes(secret),
    'the failure body carried the sentence — that is how words reach a log',
  );
  assert(!text.includes('elevenlabs'), 'the failure body named the provider');
});

Deno.test('10. the audio is cacheable, so a repeated line is billed once', async () => {
  const r = recorder();
  const response = await handleSpeak(
    post({ line: 'تمام', voice: 'female' }),
    r.deps,
  );
  const cache = response.headers.get('cache-control') ?? '';
  assert(cache.includes('immutable'), `cache-control was "${cache}"`);
  assert(cache.includes('max-age='), `cache-control was "${cache}"`);
});

Deno.test('11. a malformed body is a 400 and not a crash', async () => {
  const r = recorder();
  const response = await handleSpeak(
    new Request('http://localhost/speak', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: 'not json',
    }),
    r.deps,
  );
  assertEquals(response.status, 400);
  assertEquals(r.calls.length, 0);
});

Deno.test('12. a GET is refused — nothing here is safe to link to', async () => {
  const r = recorder();
  const response = await handleSpeak(
    new Request('http://localhost/speak', { method: 'GET' }),
    r.deps,
  );
  assertEquals(response.status, 405);
  assertEquals(r.calls.length, 0);
});

Deno.test('13. the browser preflight is answered', async () => {
  const r = recorder();
  const response = await handleSpeak(
    new Request('http://localhost/speak', { method: 'OPTIONS' }),
    r.deps,
  );
  assertEquals(response.status, 200);
  assertEquals(r.calls.length, 0);
  await response.text();
});
