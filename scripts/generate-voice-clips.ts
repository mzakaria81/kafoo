// Buys every fixed Kafoo sentence once, in both Cairene voices, and writes them into the app.
//
// ────────────────────────────────────────────────────────────────────────────────────────────────
// WHY THIS EXISTS: KAFOO WAS RE-BUYING THE SAME SENTENCES FOREVER.
//
// `HostedSpeechOutput` cached audio in memory, so every app launch bought «تمام، شلتها من المنيو»
// again — the same bytes, at the same price, for a sentence that has never changed and never will.
// The provider bills per character generated. A sentence with no variable in it is a sentence that
// should be bought exactly once in the life of the product.
//
// Measured on 2026-08-12: **36 texts, 1,248 characters, 72 clips across the two voices.** Against
// the 40,000-character monthly allowance recorded in `docs/ops/measuring-spoken-arabic.md`, the
// entire fixed vocabulary of the product is roughly 3% of one month — spent once, then never again,
// no matter how many Cooks join.
//
// THE CLIPS ARE ALSO FASTER THAN ANYTHING THE NETWORK CAN DO. A bundled asset plays in
// milliseconds, needs no signal, and cannot lose the race that `_fetchTimeout` bounds. The Cook on
// the metro hears Ghozlan rather than the machine voice.
//
// WHAT IT REFUSES TO BUNDLE, AND WHY THAT IS THE IMPORTANT PART: any sentence with a placeholder
// left in it after the address form is resolved. Kafoo has exactly one — the Meal-list greeting,
// which carries the Cook's own Meal counts. Pre-rendering every version of that sentence would cost
// more than a month's allowance for a Cook with twenty Meals (231 count pairs x 2 grammars x 2
// voices), so it stays on the network and on the disk cache instead. A string that grows a
// placeholder later drops out of the bundle automatically rather than shipping a clip that says the
// wrong number.
//
// THE VOICE IDS ARE NOT IN THIS FILE AND MUST NEVER BE. They are imported from the `speak` Edge
// Function, which `specs/005-voice-system/plan.md` makes the single place they may live. The
// synthesis call is imported from there too — so a bundled clip is produced by the exact same code,
// model and audio format as a clip fetched at runtime, and the two cannot drift into sounding
// different from each other.
//
// Run with:
//   ELEVENLABS_API_KEY=... deno run --allow-read --allow-write --allow-net --allow-env \
//     scripts/generate-voice-clips.ts
//
// Idempotent: a clip already on disk is never re-bought, so re-running costs nothing. `--check`
// needs no key and no network — it only asks whether every expected clip exists, which is what the
// gate runs.
// ────────────────────────────────────────────────────────────────────────────────────────────────

import {
  createDefaultDeps,
  MAX_CHARACTERS,
  VOICES,
  type VoiceRole,
} from '../supabase/functions/speak/index.ts';

const ARB = new URL('../apps/mobile/lib/l10n/app_ar.arb', import.meta.url);
const OUT_DIR = new URL('../apps/mobile/assets/voice/', import.meta.url);

/// Every ARB key the assistant says aloud, or is designed to.
///
/// **THIRTEEN OF THESE ARE NOT SPOKEN BY ANY SCREEN TODAY, AND THEY ARE HERE ON PURPOSE.** The
/// assistant currently talks on three screens — the Meal list, the Meal conversation and the row
/// sheet. The Kitchen Profile conversation, the Meal summary, the cuisine and category questions
/// and the empty Meal list all have Egyptian Arabic written for them and say none of it; two of
/// those keys have the word `Spoken` in their own names. Closing those gaps is ADR-0013 work that
/// has not happened yet.
///
/// Bundling them now costs 1,440 characters once and means the day a screen is given its voice, the
/// voice is already in the app. Bundling only what speaks today would mean doing this twice.
/// Founder's decision, 2026-08-12.
const SPOKEN_KEYS = [
  // ── Said today, by the Meal list's row sheet ──────────────────────────────
  'mealSpokenTakenOffMenu',
  'mealSpokenBackOnMenu',
  'mealSpokenDraftDeleted',
  'mealSpokenRetired',
  // Read back in full before «أيوة» — an irreversible action's gate.
  'mealRetireWarning',
  'mealLastOnOfferWarning',
  'mealDeleteDraftWarning',
  // ── Said today, by the Meal conversation ──────────────────────────────────
  'mealConvPromptDish',
  'mealConvPromptPhoto',
  'mealConvPromptDescription',
  'mealConvPromptPrice',
  // ── Written, designed to be spoken, and silent. See the note above. ───────
  'mealConvPromptCuisine',
  'mealConvPromptCategory',
  'myMealsEmptySpoken',
  'kitchenConvPromptDisplayName',
  'kitchenConvPromptStory',
  'kitchenConvPromptArea',
  'kitchenConvPromptDeliveryTerms',
  'kitchenConvPromptAddressForm',
  'kitchenConvSummaryConfirm',
  'mealSummaryConfirm',
  'mealSummaryEstimatesNotice',
  'mealSummaryNoEstimates',
  'aiPromptNotStubbed',
] as const;

/// Resolves `{addressForm, select, feminine{…} other{…}}` into its two sentences.
///
/// ADR-0010: Arabic conjugates the second person, so a line addressed to a Cook exists in two
/// grammars and both have to be bought. A line with no address form is one sentence, not two.
function addressFormVariants(template: string): string[] {
  const match = /\{addressForm, select, feminine\{(.*?)\} other\{(.*?)\}\}/s.exec(template);
  if (!match) return [template.trim()];
  const fill = (branch: string) =>
    (template.slice(0, match.index) + branch + template.slice(match.index + match[0].length)).trim();
  return [fill(match[1]), fill(match[2])];
}

/// The name a clip is filed under: the SHA-1 of the exact sentence.
///
/// **KEYED ON THE TEXT RATHER THAN ON THE ARB KEY, AND THAT IS WHAT MAKES IT SAFE TO EDIT COPY.**
/// `SpeechOutput.speak` receives a finished sentence and knows nothing about which key produced it,
/// so the app has to be able to ask "do I already own *these words*". The useful consequence is that
/// changing an Arabic string changes its hash, the lookup misses, and the app quietly buys the new
/// wording from the provider instead of playing the old one. A stale clip can never be spoken — the
/// worst case is that it is orphaned on disk until this script is re-run.
export async function clipName(line: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(line));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

interface Clip {
  key: string;
  line: string;
  role: VoiceRole;
  name: string;
}

/// Every clip the app should own, and the reason a string is left out when it is.
export async function plannedClips(arb: Record<string, unknown>): Promise<Clip[]> {
  const clips: Clip[] = [];
  for (const key of SPOKEN_KEYS) {
    const template = arb[key];
    if (typeof template !== 'string') {
      throw new Error(`${key} is not in app_ar.arb — a spoken key was renamed or removed`);
    }
    for (const line of addressFormVariants(template)) {
      // THE GUARD THAT KEEPS THE GREETING OUT. A placeholder still standing here means the sentence
      // differs per Cook, so there is no single clip that says it. Refused rather than bundled
      // wrong: a clip that reads «عندك {total} أكلة» aloud would be worse than any silence.
      if (line.includes('{')) {
        throw new Error(
          `${key} still carries a placeholder after the address form is resolved, so it cannot be ` +
            `bundled: ${line}`,
        );
      }
      if (line.length > MAX_CHARACTERS) {
        throw new Error(`${key} is longer than the ${MAX_CHARACTERS}-character limit speak enforces`);
      }
      const name = await clipName(line);
      for (const role of Object.keys(VOICES) as VoiceRole[]) {
        clips.push({ key, line, role, name });
      }
    }
  }

  // Two different sentences sharing a filename would play the wrong one aloud. SHA-1 makes that
  // vanishingly unlikely and this makes it impossible, at build time, where it is free to check.
  const seen = new Map<string, string>();
  for (const clip of clips) {
    const previous = seen.get(clip.name);
    if (previous !== undefined && previous !== clip.line) {
      throw new Error(`two sentences hash to ${clip.name}: "${previous}" and "${clip.line}"`);
    }
    seen.set(clip.name, clip.line);
  }
  return clips;
}

function clipPath(clip: Clip): URL {
  return new URL(`${clip.role}/${clip.name}.mp3`, OUT_DIR);
}

async function exists(path: URL): Promise<boolean> {
  try {
    await Deno.stat(path);
    return true;
  } catch {
    return false;
  }
}

if (import.meta.main) {
  const check = Deno.args.includes('--check');
  const arb = JSON.parse(await Deno.readTextFile(ARB)) as Record<string, unknown>;
  const clips = await plannedClips(arb);

  if (check) {
    const missing = [];
    for (const clip of clips) {
      if (!(await exists(clipPath(clip)))) missing.push(clip);
    }
    if (missing.length > 0) {
      console.error(
        `${missing.length} of ${clips.length} bundled voice clip(s) are missing. Kafoo will buy ` +
          `these sentences from the provider on every launch until they are generated:`,
      );
      for (const clip of missing) console.error(`  ${clip.role}  ${clip.key}  ${clip.line}`);
      console.error(
        '\nRegenerate with:\n  ELEVENLABS_API_KEY=... deno run --allow-read --allow-write ' +
          '--allow-net --allow-env scripts/generate-voice-clips.ts',
      );
      Deno.exit(1);
    }
    console.log(`ok — all ${clips.length} bundled voice clips present`);
    Deno.exit(0);
  }

  const { synthesize } = createDefaultDeps();
  let bought = 0;
  let characters = 0;
  let owned = 0;
  for (const clip of clips) {
    const path = clipPath(clip);
    if (await exists(path)) {
      owned++;
      continue;
    }
    await Deno.mkdir(new URL(`${clip.role}/`, OUT_DIR), { recursive: true });
    const result = await synthesize(VOICES[clip.role], clip.line);
    if (!result.ok) {
      console.error(`failed: ${clip.role} ${clip.key} — ${clip.line}`);
      Deno.exit(1);
    }
    await Deno.writeFile(path, new Uint8Array(result.audio));
    bought++;
    characters += clip.line.length;
    console.log(`bought ${clip.role.padEnd(6)} ${clip.name}  ${clip.line}`);
  }
  console.log(
    `\n${clips.length} clip(s) total: ${owned} already owned, ${bought} bought ` +
      `(${characters} characters).`,
  );
}
