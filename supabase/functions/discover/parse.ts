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

export interface ParsedPhrase {
  /// What the Customer asked to avoid.
  readonly exclusion: Understanding;

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

function lookUp(term: string): Understanding {
  const needle = term.trim();
  if (needle.length === 0) return { kind: 'nothing' };

  for (const candidate of new Set([needle, withoutArticles(needle)])) {
    for (const exclusion of EXCLUSIONS) {
      if (exclusion.surfaceForms.includes(candidate)) {
        return { kind: 'found', id: exclusion.id, terms: exclusion.surfaceForms };
      }
    }
  }
  return { kind: 'not-understood', phrase: needle };
}

export function parsePhrase(phrase: string): ParsedPhrase {
  const text = phrase.trim();
  if (text.length === 0) return { exclusion: { kind: 'nothing' }, text };

  for (const marker of NEGATION_MARKERS) {
    const at = text.indexOf(marker);
    if (at < 0) continue;

    const remainder = text.slice(at + marker.length).trim();
    // A marker with nothing after it — a cut-off recording — is still a Customer who asked to
    // exclude something. Never `nothing`.
    if (remainder.length === 0) {
      return { exclusion: { kind: 'not-understood', phrase: '' }, text };
    }

    const words = remainder.split(/\s+/);
    while (words.length > 1 && FILLERS.includes(words[0])) words.shift();

    // Longest run of words first, so a two-word food beats its first word.
    for (let take = words.length; take >= 1; take--) {
      const outcome = lookUp(words.slice(0, take).join(' '));
      if (outcome.kind === 'found') return { exclusion: outcome, text };
    }
    return { exclusion: { kind: 'not-understood', phrase: remainder }, text };
  }

  return { exclusion: { kind: 'nothing' }, text };
}
