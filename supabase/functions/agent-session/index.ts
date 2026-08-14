// Mints a short-lived URL the app uses to open one voice conversation.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THIS FUNCTION EXISTS SO THE KEY NEVER REACHES A HANDSET, AND THAT IS THE WHOLE DESIGN.
//
// ADR-0017 turns on exactly this question, and ADR-0009 died on it for a different provider: a
// provider key compiled into an APK is a published key, and rotating it does not reach handsets
// already installed. The provider's own documentation says the same thing in one line — "never expose
// your ElevenLabs API key client-side" — and provides the signed URL for this case.
//
// The app asks Kafoo for a URL. Kafoo asks the provider, holding the key. The URL the app receives
// starts one conversation and expires; the key stays here.
//
// THE CALLER NAMES NOTHING. No agent id in the body, no voice, no model. Same shape as `speak`,
// which takes a role rather than a voice id, and for the same reason: a client that can name the
// agent can name any agent on the account, including an expensive one, and iterate through them on
// Kafoo's bill.
//
// THERE IS NO DATABASE CLIENT HERE AND NO WRITE PATH. This function reads nothing and writes
// nothing. `.claude/rules/ai.md`'s rule that a model-calling function holds no service-role key is
// intact, and it has to be: the conversation this URL opens is the widest untrusted-input surface
// in the product.
//
// WHAT IT DELIBERATELY DOES NOT DO: log the signed URL, or the agent id, or the provider's error
// body. A signed URL is a bearer credential for fifteen minutes — a log line carrying one is a log
// line anyone who reads it can talk on Kafoo's account with. `discover` shipped exactly that shape
// as `detail: String(error)` and removed it on 2026-08-07.
// ────────────────────────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

/// How the provider names this endpoint. Kept here rather than inline so the one
/// place it is written is the one place it changes.
const SIGNED_URL_ENDPOINT =
  'https://api.elevenlabs.io/v1/convai/conversation/get-signed-url';

export interface AgentSessionDeps {
  /// Asks the provider for a signed URL. Injected so a test can watch what
  /// leaves without holding a key.
  signedUrl(): Promise<{ ok: true; url: string } | { ok: false }>;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

export async function handleAgentSession(
  req: Request,
  deps: AgentSessionDeps,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  // POST, not GET, and not because anything is written. A GET is cached by
  // proxies and logged with its query string by nearly everything in the path;
  // this response is a bearer credential and must be neither.
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const result = await deps.signedUrl();
  if (!result.ok) {
    // No detail and nothing logged. The app falls back to typing, which is a
    // complete alternative rather than a degraded one, and a diagnostic here
    // would carry a credential into a log line.
    return json({ error: 'voice unavailable' }, 503);
  }

  return json({ url: result.url }, 200);
}

export function createDefaultDeps(): AgentSessionDeps {
  return {
    async signedUrl() {
      const apiKey = Deno.env.get('ELEVENLABS_API_KEY');
      const agentId = Deno.env.get('ELEVENLABS_AGENT_ID');
      if (!apiKey || !agentId) return { ok: false };
      try {
        const response = await fetch(
          `${SIGNED_URL_ENDPOINT}?agent_id=${encodeURIComponent(agentId)}`,
          { headers: { 'xi-api-key': apiKey } },
        );
        if (!response.ok) return { ok: false };
        const body = await response.json() as { signed_url?: unknown };
        const url = body.signed_url;
        if (typeof url !== 'string' || url.length === 0) return { ok: false };
        return { ok: true, url };
      } catch {
        return { ok: false };
      }
    },
  };
}

// Deno.serve is the only top-level side effect, and it is guarded — same shape
// as `speak`, so the handler can be imported by a test without starting a
// server.
if (import.meta.main) {
  Deno.serve((req) => handleAgentSession(req, createDefaultDeps()));
}
