// Says a Kafoo sentence in a Cairene voice.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// THIS FUNCTION EXISTS BECAUSE THE KEY CANNOT SHIP IN THE APP, AND THAT IS NOT A PREFERENCE.
//
// An API key inside an APK is a published key. Anyone can unzip a release build and read it, and
// every sentence they then generate is billed to Kafoo. ADR-0005 already says feature code never
// calls a model provider directly; this is the same rule applied to a provider that returns audio
// instead of text. The app asks Kafoo to speak; Kafoo asks the provider.
//
// THE CALLER NAMES A ROLE, NEVER A VOICE ID, and that is the security design — the same shape
// `embed-meal` uses for its Meal id.
//
// The obvious interface — accept a voice id — hands the spending to the caller. A client that picks
// the voice can pick any voice in the provider's library, including ones that cost more, and can
// iterate through the whole catalogue on Kafoo's bill. So the body carries `female` or `male` and
// this file maps those two words to the two ids the founder chose by ear on 2026-08-11
// (`docs/ops/measuring-spoken-arabic.md`). Any other value is a 400, and a voice id in the body is
// ignored rather than honoured.
//
// THERE IS NO WRITE PATH HERE AND NO DATABASE CLIENT AT ALL. This function reads a sentence out of
// the request and returns audio. It holds no service-role key, touches no table, and cannot be made
// to — which is what keeps `.claude/rules/ai.md`'s rule about model-calling functions intact.
//
// WHAT IT DELIBERATELY DOES NOT DO: log the sentence. A Cook's Meal title and a Customer's message
// both come through here, and a provider error that quoted the request back is how the text would
// escape into a log line. `discover` shipped exactly that defect as `detail: String(error)` and
// removed it on 2026-08-07.
// ────────────────────────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

/// The two voices the founder chose, by ear, from the twenty-five Egyptian
/// voices in the provider's library.
///
/// **Ids live here and nowhere else.** `specs/005-voice-system/plan.md` makes
/// that a constraint rather than a habit: a voice id in application code is a
/// defect, because it is what makes swapping a voice a refactor instead of a
/// one-line change.
export const VOICES = {
  female: 'xPcC3nehhziQaOrIeAwv',
  male: 'ihycSANIrpHfhWoaq1g3',
} as const;

export type VoiceRole = keyof typeof VOICES;

/// The model. Multilingual v2 reads Egyptian Arabic correctly — measured
/// 2026-08-11, and the finding was that the Egyptian pronunciation comes from
/// the model reading Egyptian text rather than from the voice.
const MODEL = 'eleven_multilingual_v2';

/// 128 kbps mono mp3. Speech, on an Egyptian mobile connection: higher costs
/// bytes nobody can hear the benefit of.
const FORMAT = 'mp3_44100_128';

/// The longest sentence Kafoo will say.
///
/// §10.2 caps a reply at three sentences and the glance words are single words,
/// so nothing legitimate comes close. The limit is here because the caller is
/// the one billed per character: without it, one request can spend a month's
/// allowance.
export const MAX_CHARACTERS = 400;

export interface SpeakDeps {
  /// Asks the provider for audio. Injected so a test can watch what leaves.
  synthesize(
    voiceId: string,
    line: string,
  ): Promise<{ ok: true; audio: ArrayBuffer } | { ok: false }>;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}

function isVoiceRole(value: unknown): value is VoiceRole {
  return value === 'female' || value === 'male';
}

export async function handleSpeak(
  req: Request,
  deps: SpeakDeps,
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad request' }, 400);
  }
  if (body === null || typeof body !== 'object') {
    return json({ error: 'bad request' }, 400);
  }

  const record = body as Record<string, unknown>;
  const line = typeof record.line === 'string' ? record.line.trim() : '';
  if (line.length === 0) {
    return json({ error: 'bad request' }, 400);
  }
  if (line.length > MAX_CHARACTERS) {
    // Not truncated. A half-said sentence is worse than a refusal, and the
    // caller is the only thing that knows what it meant to say.
    return json({ error: 'line too long' }, 413);
  }

  // A ROLE, NEVER AN ID. `record.voiceId` is not read anywhere in this file.
  if (!isVoiceRole(record.voice)) {
    return json({ error: 'unknown voice' }, 400);
  }

  const result = await deps.synthesize(VOICES[record.voice], line);
  if (!result.ok) {
    // No detail, and nothing logged. The app falls back to the device's own
    // voice, which is a better answer than a diagnostic that carries the
    // sentence into a log.
    return json({ error: 'speech unavailable' }, 503);
  }

  return new Response(result.audio, {
    status: 200,
    headers: {
      ...corsHeaders,
      // OCTET-STREAM AND NOT `audio/mpeg`, AND THE HONEST-LOOKING VALUE IS THE
      // BUG. `functions_client` returns raw bytes for exactly one content type:
      // `application/octet-stream`. Anything else — including `audio/mpeg`,
      // which is what this response actually is — falls to its default branch
      // and comes back `utf8.decode(bodyBytes)`, so the mp3 arrives mangled or
      // throws on the first byte that is not valid UTF-8. Read at
      // functions_client-2.7.1/lib/src/functions_client.dart:242.
      'content-type': 'application/octet-stream',
      // The same sentence in the same voice is the same audio, forever. A Cook
      // hears «تمام، الأكلة منشورة» many times a week, and every cache hit is a
      // character nobody is billed for.
      'cache-control': 'public, max-age=31536000, immutable',
    },
  });
}

export function createDefaultDeps(): SpeakDeps {
  return {
    async synthesize(voiceId, line) {
      const apiKey = Deno.env.get('ELEVENLABS_API_KEY');
      if (!apiKey) return { ok: false };
      try {
        const response = await fetch(
          `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=${FORMAT}`,
          {
            method: 'POST',
            headers: {
              'xi-api-key': apiKey,
              'content-type': 'application/json',
            },
            body: JSON.stringify({ text: line, model_id: MODEL }),
          },
        );
        if (!response.ok) return { ok: false };
        return { ok: true, audio: await response.arrayBuffer() };
      } catch {
        return { ok: false };
      }
    },
  };
}

// Deno.serve is the only top-level side effect, and it is guarded — same shape
// as embed-meal, so the handler can be imported by a test without starting a
// server.
if (import.meta.main) {
  Deno.serve((req) => handleSpeak(req, createDefaultDeps()));
}
