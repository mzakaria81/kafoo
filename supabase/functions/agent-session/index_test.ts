import { assertEquals } from 'jsr:@std/assert@1';
import { type ConversationKind, handleAgentSession } from './index.ts';

/// A request the way the app sends one.
function ask(body: unknown, method = 'POST'): Request {
  return new Request('http://x', {
    method,
    body: method === 'GET' ? undefined : JSON.stringify(body),
  });
}

/// A source that records which conversation it was asked for.
function source(url = 'wss://ours') {
  const asked: ConversationKind[] = [];
  return {
    asked,
    deps: {
      signedUrl: (kind: ConversationKind) => {
        asked.push(kind);
        return Promise.resolve({ ok: true as const, url });
      },
    },
  };
}

Deno.test('a GET is refused — a signed URL must not sit in a proxy log', async () => {
  const res = await handleAgentSession(ask(null, 'GET'), source().deps);
  assertEquals(res.status, 405);
});

Deno.test('a session is returned and nothing else is', async () => {
  const res = await handleAgentSession(
    ask({ kind: 'meal' }),
    source('wss://example/x?token=y').deps,
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), {
    url: 'wss://example/x?token=y',
    voiceId: 'ihycSANIrpHfhWoaq1g3',
  });
});

Deno.test('a provider failure says nothing about why', async () => {
  const res = await handleAgentSession(ask({ kind: 'meal' }), {
    signedUrl: () => Promise.resolve({ ok: false as const }),
  });
  assertEquals(res.status, 503);
  assertEquals(await res.json(), { error: 'voice unavailable' });
});

Deno.test('the caller cannot name an agent', async () => {
  const s = source();
  const res = await handleAgentSession(
    ask({ kind: 'meal', agent_id: 'somebody-elses-expensive-agent' }),
    s.deps,
  );
  assertEquals(res.status, 200);
  // The id in the body is never read. A client that can name the agent can name
  // any agent on the account and spend the allowance on it.
  assertEquals(s.asked, ['meal']);
});

Deno.test('the caller cannot name a voice id either', async () => {
  const res = await handleAgentSession(
    ask({ kind: 'meal', voice: 'some-expensive-voice-id' }),
    source().deps,
  );
  // An unrecognised role falls back to Kafoo's default rather than being
  // forwarded. A role, never an id — the same rule `speak` holds.
  assertEquals(await res.json(), {
    url: 'wss://ours',
    voiceId: 'ihycSANIrpHfhWoaq1g3',
  });
});

Deno.test('the voice she chose is the one that comes back', async () => {
  const res = await handleAgentSession(
    ask({ kind: 'meal', voice: 'female' }),
    source().deps,
  );
  assertEquals(await res.json(), {
    url: 'wss://ours',
    voiceId: 'xPcC3nehhziQaOrIeAwv',
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// THE KIND, WHICH IS WHY THIS PARAMETER EXISTS. Kafoo has two conversations and
// had one agent, so a Cook setting up her kitchen was greeted with «قوليلي عملتي
// إيه النهاردة؟» and asked about a dish.
// ─────────────────────────────────────────────────────────────────────────────

Deno.test('the kitchen conversation asks for the kitchen agent', async () => {
  const s = source();
  const res = await handleAgentSession(ask({ kind: 'kitchen' }), s.deps);
  assertEquals(res.status, 200);
  assertEquals(s.asked, ['kitchen']);
});

Deno.test('a missing kind is refused rather than defaulted', async () => {
  const s = source();
  const res = await handleAgentSession(ask({}), s.deps);
  assertEquals(res.status, 400);
  assertEquals(
    s.asked,
    [],
    'Defaulting is what opened the wrong conversation in the first place.',
  );
});

Deno.test('an unrecognised kind is refused rather than defaulted', async () => {
  const s = source();
  const res = await handleAgentSession(ask({ kind: 'kitchn' }), s.deps);
  assertEquals(res.status, 400);
  assertEquals(await res.json(), { error: 'unknown kind' });
  assertEquals(s.asked, []);
});

Deno.test('a body that is not JSON is refused', async () => {
  const res = await handleAgentSession(
    new Request('http://x', { method: 'POST', body: 'not json' }),
    source().deps,
  );
  assertEquals(res.status, 400);
});
