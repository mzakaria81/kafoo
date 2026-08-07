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
/// 2026-08-07 before any of them existed: 13 of 156 plausible Cook spellings — `مكرونه`, `بسطرمه`,
/// `قشده` — reached nothing at all, and one tatweel defeated all 93 forms.
///
/// Spelling only, never meaning. The definite article is deliberately NOT stripped here: substring
/// matching already reaches `اللحمة` from `لحم`, and `withoutArticles` handles the Customer's side.
export function foldArabic(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/[ً-ْـ]/g, '');
}

/// Every form, folded, longest first — so `كابوريا` is crab rather than the `بوري` inside it.
///
/// Sorted rather than left in list order, because the order of a list is not a decision anybody
/// made. Same rule as `ExclusionVocabulary._formsLongestFirst` in Dart.
const FORMS_LONGEST_FIRST: ReadonlyArray<{ id: string; terms: readonly string[]; folded: string }> =
  EXCLUSIONS
    .flatMap((exclusion) =>
      exclusion.surfaceForms.map((form) => ({
        id: exclusion.id,
        terms: exclusion.surfaceForms,
        folded: foldArabic(form),
      }))
    )
    .sort((a, b) => b.folded.length - a.folded.length);

function lookUp(term: string): Understanding {
  const needle = term.trim();
  if (needle.length === 0) return { kind: 'nothing' };

  for (const candidate of new Set([foldArabic(needle), foldArabic(withoutArticles(needle))])) {
    // CONTAINS, NOT EQUALS. `search_meals` matches a form as a substring of what the Cook typed, so
    // `لحم` reaches `لحمة مفرومة`; this side compared for equality, so the same list did not reach
    // a Customer who said `لحمة`. Over-matching is the safe direction after a negation marker.
    for (const entry of FORMS_LONGEST_FIRST) {
      if (candidate.includes(entry.folded)) {
        return { kind: 'found', id: entry.id, terms: entry.terms };
      }
    }
  }
  return { kind: 'not-understood', phrase: needle };
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

  for (const marker of NEGATION_MARKERS) {
    const at = text.indexOf(marker);
    if (at < 0) continue;

    const remainder = text.slice(at + marker.length).trim();
    // A marker with nothing after it — a cut-off recording — is still a Customer who asked to
    // exclude something. Never `nothing`.
    if (remainder.length === 0) {
      return { exclusion: { kind: 'not-understood', phrase: '' }, area, text };
    }

    const words = remainder.split(/\s+/);
    while (words.length > 1 && FILLERS.includes(words[0])) words.shift();

    // Longest run of words first, so a two-word food beats its first word.
    for (let take = words.length; take >= 1; take--) {
      const outcome = lookUp(words.slice(0, take).join(' '));
      if (outcome.kind === 'found') return { exclusion: outcome, area, text };
    }
    return { exclusion: { kind: 'not-understood', phrase: remainder }, area, text };
  }

  return { exclusion: { kind: 'nothing' }, area, text };
}
