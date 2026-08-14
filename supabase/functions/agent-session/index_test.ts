import { assertEquals } from 'jsr:@std/assert@1';
import { handleAgentSession } from './index.ts';

Deno.test('a GET is refused — a signed URL must not sit in a proxy log', async () => {
  const res = await handleAgentSession(
    new Request('http://x', { method: 'GET' }),
    { signedUrl: () => Promise.resolve({ ok: true as const, url: 'wss://x' }) },
  );
  assertEquals(res.status, 405);
});

Deno.test('a signed URL is returned and nothing else is', async () => {
  const res = await handleAgentSession(
    new Request('http://x', { method: 'POST' }),
    {
      signedUrl: () =>
        Promise.resolve({ ok: true as const, url: 'wss://example/x?token=y' }),
    },
  );
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { url: 'wss://example/x?token=y' });
});

Deno.test('a provider failure says nothing about why', async () => {
  const res = await handleAgentSession(
    new Request('http://x', { method: 'POST' }),
    { signedUrl: () => Promise.resolve({ ok: false as const }) },
  );
  assertEquals(res.status, 503);
  assertEquals(await res.json(), { error: 'voice unavailable' });
});

Deno.test('the caller cannot name an agent', async () => {
  let asked = 0;
  const res = await handleAgentSession(
    new Request('http://x', {
      method: 'POST',
      body: JSON.stringify({ agent_id: 'somebody-elses-expensive-agent' }),
    }),
    {
      signedUrl: () => {
        asked++;
        return Promise.resolve({ ok: true as const, url: 'wss://ours' });
      },
    },
  );
  assertEquals(res.status, 200);
  assertEquals(asked, 1);
  // The body is never read. A client that can name the agent can name any
  // agent on the account and spend the allowance on it.
  assertEquals(await res.json(), { url: 'wss://ours' });
});
