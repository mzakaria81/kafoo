// Reading a Customer's phrase, deterministically.
//
// NO MODEL CALL, AND THAT IS A LATENCY RULING RATHER THAN A PREFERENCE. research.md §3 and FR-011:
// a generative call here would put a model on the critical path of every search. Results render at
// database speed and the AI Assistant arrives afterwards, or it arrives instead of them.
//
// This mirrors `ExclusionVocabulary.parse` in packages/domain/lib/exclusion.dart, against the same
// vocabulary compiled by scripts/generate-exclusions.py. The words are generated; the logic is
// written twice, and `parse_test.ts` carries the same cases as the Dart suite so the two cannot
// disagree quietly.

import { EXCLUSIONS, FILLERS, NEGATION_MARKERS } from '../_shared/exclusions.ts';

export type Understanding =
  | { readonly kind: 'nothing' }
  | { readonly kind: 'found'; readonly id: string; readonly terms: readonly string[] }
  | { readonly kind: 'not-understood'; readonly phrase: string };

/// How Egyptian Arabic marks a place in the middle of a request for food.
///
/// ONE SENTENCE CARRIES ALL THREE THINGS. `عايز حاجة من غير لحمة في المهندسين` is what a Customer
/// says, and T207 and Principle IV both refuse to break it into three controls. So the area is read
/// out of the sentence here, next to the exclusion, rather than collected separately.
///
/// KEPT HERE RATHER THAN IN `_shared/exclusions.ts`, which is generated from the Dart vocabulary.
/// These are not foods and nothing in Dart parses them — the app sends the sentence whole.
const AREA_MARKERS: readonly string[] = ['في', 'فى'];

export interface ParsedPhrase {
  /// What the Customer asked to avoid.
  readonly exclusion: Understanding;

  /// The area named inside the sentence, in the Customer's own words, or null.
  ///
  /// NEVER NORMALISED HERE. `normalise_area` lives in SQL and nowhere else — the migration that
  /// created it says so, and the reason is that the Cook's side already compares through it. A
  /// second folding written in TypeScript would be one rule in two languages, and the day they
  /// disagree a kitchen stops being findable.
  ///
  /// A phrase that is not an area — `في الشتا` — narrows to nothing and Kafoo says the area is
  /// empty. That is the visible direction to be wrong in, and it is the direction FR-024 exists to
  /// handle: the Customer is told, and named the areas that do have food. Guessing more cleverly
  /// would need a list of places Kafoo deliberately does not hold.
  readonly area: string | null;

  /// The text to embed. The phrase as said — the exclusion is NOT stripped out of it.
  ///
  /// Measured 2026-08-06: asking for food with no meat BY MEANING returned meat dishes, precision@5
  /// of 0.00, because the representation of "no meat" sits next to the representation of "meat".
  /// The exclusion is a database predicate; leaving the words in the embedded text costs nothing
  /// and removing them would silently change what the Customer asked for.
  readonly text: string;
}

/// Drops a leading `ال` from each word, so `اللحمة` reaches the form `لحمة`.
function withoutArticles(term: string): string {
  return term
    .split(/\s+/)
    .map((word) => (word.length > 3 && word.startsWith('ال') ? word.slice(2) : word))
    .join(' ');
}

/// One shape for a word Arabic writes several ways.
///
/// **THE THIRD COPY OF ONE RULE, and the copies must agree.** `foldArabic` in
/// packages/domain/lib/exclusion.dart recognises the Customer's word in the app; this one does it
/// in `discover`; `public.fold_arabic` matches the Cook's ingredient in `search_meals`. Measured
/// 2026-08-07 before any of them existed: 13 of 156 plausible Cook spellings reached nothing at
/// all, and one tatweel defeated all 93 forms.
///
/// **The character sets are written out rather than using `\\s`.** JavaScript's `\\s` is
/// Unicode-aware and Postgres' `[[:space:]]` under `COLLATE "C"` is ASCII only, so the two
/// disagreed on seventeen codepoints — a no-break space inside a two-word form folded on one side
/// and not the other, and walnut escaped a nut exclusion.
///
/// Invisible marks are stripped BEFORE whitespace is collapsed, because U+FEFF is whitespace to
/// JavaScript and is not whitespace to Postgres.
const INVISIBLE = /[\u0640\u064B-\u065F\u0670\u06D6-\u06ED\u200B-\u200F\u061C\uFEFF]/g;
const WHITESPACE =
  /[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/g;

export function foldArabic(value: string): string {
  return value
    .toLowerCase()
    .replace(INVISIBLE, '')
    .replace(WHITESPACE, ' ')
    // Trimmed AFTER collapsing. Postgres' one-argument btrim strips only U+0020, so trimming first
    // left a leading tab to become a space that nothing then removed.
    .trim()
    .replace(/[\u0623\u0625\u0622\u0671]/g, '\u0627')
    .replace(/\u0649/g, '\u064A')
    .replace(/\u0629/g, '\u0647');
}

/// Every form, folded, in vocabulary order. Order is a tie-break of last resort.
const FOLDED_FORMS: ReadonlyArray<{ id: string; terms: readonly string[]; folded: string }> =
  EXCLUSIONS.flatMap((exclusion) =>
    exclusion.surfaceForms.map((form) => ({
      id: exclusion.id,
      terms: exclusion.surfaceForms,
      folded: foldArabic(form),
    }))
  );

/// Words that end the food and begin something else.
///
/// Whole words. A bare waw is also a prefix, so splitting on the character would cut ordinary food
/// names in half \u2014 and `\u0628\u0633` is the front of `\u0628\u0633\u0637\u0631\u0645\u0629`, which is meat.
///
/// `\u0628\u0633` means "but", and what follows it is the food the Customer says they DO want. Without it,
/// `\u0645\u0628\u0643\u0644\u0634 \u0644\u062d\u0645\u0629 \u0628\u0633 \u0628\u062d\u0628 \u0627\u0644\u0641\u0631\u0627\u062e` took the whole tail as the food and excluded the CHICKEN, leaving the
/// meat on screen under a label naming chicken. Added 2026-08-10; the Dart side carries the same
/// entry and `index_test.ts` holds the shared case.
const CONJUNCTIONS: readonly string[] = ['\u0648\u0644\u0627', '\u0648', '\u0623\u0648', '\u0627\u0648', '\u0628\u0633'];

/// Where `form` begins a word in `text`, or -1.
function wordStartIndexOf(text: string, form: string): number {
  let from = 0;
  for (;;) {
    const at = text.indexOf(form, from);
    if (at < 0) return -1;
    if (at === 0 || text[at - 1] === ' ') return at;
    from = at + 1;
  }
}

interface FormMatch {
  readonly id: string;
  readonly terms: readonly string[];
  readonly folded: string;
  readonly at: number;
  readonly index: number;
}

/// The food a Customer named, matched where a WORD BEGINS.
///
/// **The word for white contains the word for eggs, and that is not a Customer asking about eggs.**
/// This side matched anywhere inside the string for one afternoon, and the ordinary way a Cairene
/// names white cheese answered `egg` — so the white cheese came back while the Customer was told
/// Kafoo had removed the food containing eggs. `search_meals` keeps matching anywhere, because a
/// Cook writes ingredients with prefixes attached and a word-start rule there would under-exclude.
///
/// **Longest first, then earliest, then vocabulary order.** Peanut butter starts with a dairy word
/// and is a peanut product. The comparison is TOTAL down to the index: ordering on length alone
/// left ties to the sort algorithm, and Dart's is not stable while JavaScript's is — so the two
/// sides answered the same phrase differently.
function matchAtWordStart(candidate: string): FormMatch | null {
  let best: FormMatch | null = null;

  for (const [index, entry] of FOLDED_FORMS.entries()) {
    const at = wordStartIndexOf(candidate, entry.folded);
    if (at < 0) continue;
    if (
      best === null ||
      entry.folded.length > best.folded.length ||
      (entry.folded.length === best.folded.length && at < best.at) ||
      (entry.folded.length === best.folded.length && at === best.at && index < best.index)
    ) {
      best = { ...entry, at, index };
    }
  }
  return best;
}

function lookUp(term: string): Understanding {
  const needle = term.trim();
  if (needle.length === 0) return { kind: 'nothing' };

  // BOTH READINGS ARE WEIGHED. Taking the first candidate that matched anything answered `dairy`
  // for peanut butter, because the article-stripped reading — where the peanut word finally begins
  // a word — was never reached.
  const matches: FormMatch[] = [];
  for (const candidate of new Set([foldArabic(needle), foldArabic(withoutArticles(needle))])) {
    const match = matchAtWordStart(candidate);
    if (match !== null) matches.push(match);
  }
  if (matches.length === 0) return { kind: 'not-understood', phrase: needle };
  matches.sort((a, b) => b.folded.length - a.folded.length);
  return { kind: 'found', id: matches[0].id, terms: matches[0].terms };
}

/// The words after the LAST locative marker, or null.
///
/// The last one, because a request names its place at the end — `حاجة في الفرن في المهندسين`. The
/// marker may not be the first word: a sentence opening with `في` is Egyptian for "is there any",
/// not a place.
///
/// The candidate is then cut at a negation marker, so `أكل في المهندسين من غير لحمة` narrows to
/// المهندسين rather than to the whole tail of the sentence.
function findArea(text: string): string | null {
  const words = text.split(/\s+/);

  // Scanned by whole word rather than by substring, so `فيه` and `الفيوم` are not locative markers.
  // Backwards, and never index 0.
  let at = -1;
  for (let i = words.length - 2; i >= 1; i--) {
    if (AREA_MARKERS.includes(words[i])) {
      at = i;
      break;
    }
  }
  if (at < 0) return null;

  let candidate = words.slice(at + 1).join(' ');
  for (const negation of NEGATION_MARKERS) {
    const cut = candidate.indexOf(negation);
    if (cut >= 0) candidate = candidate.slice(0, cut).trim();
  }

  return candidate.length === 0 ? null : candidate;
}

export function parsePhrase(phrase: string): ParsedPhrase {
  const text = phrase.trim();
  if (text.length === 0) {
    return { exclusion: { kind: 'nothing' }, area: null, text };
  }

  const area = findArea(text);

  // FOLDED, MARKERS INCLUDED. The foods were folded on 2026-08-07 and the markers were left raw
  // one line away. The allergy marker is the only one carrying a taa marbuta, and the other
  // spelling is at least as common — so a Customer stating a nut allergy got `nothing`: not
  // not-understood, NOTHING, with the screen saying nothing and the nuts coming back. That is
  // verbatim the failure this parser exists to prevent, closed for the marker list the same
  // morning and reopened by the marker spelling.
  const folded = foldArabic(text);

  for (const marker of NEGATION_MARKERS) {
    const foldedMarker = foldArabic(marker);
    const at = folded.indexOf(foldedMarker);
    if (at < 0) continue;

    const remainder = folded.slice(at + foldedMarker.length).trim();
    // A marker with nothing after it — a cut-off recording — is still a Customer who asked to
    // exclude something. Never `nothing`.
    if (remainder.length === 0) {
      return { exclusion: { kind: 'not-understood', phrase: '' }, area, text };
    }

    const words = remainder.split(' ').filter((w) => w.length > 0);
    while (words.length > 1 && FILLERS.includes(foldArabic(words[0]))) words.shift();

    // ONE BREATH, TWO FOODS: THE FIRST IS THE ONE HONOURED. Matching inside a phrase made the
    // SECOND food win whenever it sorted earlier, so a Customer naming milk had eggs excluded and
    // the milk came back. Two exclusions in one breath is the ordinary shape of an allergy
    // sentence. The second is still dropped — that is the documented smaller wrong — but the one
    // honoured is the one they said first.
    const conjunction = words.findIndex((w) => CONJUNCTIONS.includes(foldArabic(w)));
    const firstFood = conjunction < 0 ? words : words.slice(0, conjunction);
    if (firstFood.length === 0) {
      return { exclusion: { kind: 'not-understood', phrase: remainder }, area, text };
    }

    // Longest run of words first, so a two-word food beats its first word.
    for (let take = firstFood.length; take >= 1; take--) {
      const outcome = lookUp(firstFood.slice(0, take).join(' '));
      if (outcome.kind === 'found') return { exclusion: outcome, area, text };
    }
    return { exclusion: { kind: 'not-understood', phrase: remainder }, area, text };
  }

  return { exclusion: { kind: 'nothing' }, area, text };
}
