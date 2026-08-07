// What the AI Assistant is allowed to say about a set of results, and how little of its reply is
// believed.
//
// The rules the contract states are enforced HERE, in code, rather than only in the prompt. A
// prompt is an instruction to a model; this is the part that holds when the model ignores it.

import type { ResponseSchema } from '../_shared/ai/schema.ts';

/// A Meal as the judgement sees it: what a Customer would read, and nothing else.
///
/// No price, no kitchen, no area, no ingredients. The model cannot claim proximity about an area it
/// was never given, and it cannot rank on a price it cannot see — FR-017 and FR-011 are enforced by
/// what is absent from this type as much as by the prompt.
export interface JudgeableMeal {
  readonly id: string;
  readonly title: string;
  readonly description: string;
}

/// What the function answers with.
export interface Judgement {
  readonly answers: boolean;
  /// Meal ids, always a subset of what was handed over, at most three.
  readonly alternatives: readonly string[];
}

/// At most three alternatives reach a Customer.
///
/// Not a model instruction — a ceiling applied after it answers. "Nothing here, but try these
/// eleven" is not an answer to somebody who asked for one thing.
const MAX_ALTERNATIVES = 3;

/// The shape a reply must have before any of it is used.
///
/// INDICES, NOT IDS, and that is a safety property rather than a token saving. A model that never
/// sees an id cannot invent one; the worst it can do is name a number, and a number outside the
/// range it was given is dropped by [toJudgement]. FR-015 says an alternative is a Meal genuinely on
/// offer, and this is what makes that structural instead of hoped for.
export const JUDGEMENT_SCHEMA: ResponseSchema = {
  type: 'object',
  properties: {
    answers: {
      type: 'boolean',
      description: 'True when at least one Meal is a fair answer to the request.',
    },
    alternatives: {
      type: 'array',
      items: { type: 'integer' },
      description: 'Numbers of Meals worth naming instead, from the list given.',
    },
  },
  required: ['answers'],
};

/// The Meals, numbered, in the order they were given.
///
/// NEVER RE-SORTED. The order is the database's ranking, and a second ordering applied here would
/// be a second ranking rule living somewhere the first one cannot see. The numbers exist so the
/// model can point at a Meal without holding its id.
export function buildUserContent(phrase: string, meals: readonly JudgeableMeal[]): string {
  const numbered = meals
    .map((meal, index) => `${index + 1}. ${meal.title} — ${meal.description}`)
    .join('\n');

  // Labelled and separated, so a request that reads like an instruction is visibly a quoted value
  // rather than a continuation of the prompt. The words themselves are passed through unchanged:
  // scrubbing them would change what the Customer asked for, and the prompt's own untrusted-input
  // rule is what handles them.
  return `The Customer asked for:\n${phrase}\n\nThe Meals that came back:\n${numbered}`;
}

/// Turns a validated reply into a judgement, believing as little of it as possible.
///
/// Everything here is a narrowing. A number outside the range is dropped, a repeated number is
/// dropped, more than three are cut, and any field the model invented — a reason, a note, a
/// recommendation written in prose — never had a place to land, because this builds a fresh object
/// rather than passing the model's own through.
///
/// **That last point is the popularity and proximity rule made structural.** FR-016 and FR-017
/// forbid claiming that a Meal is popular or nearby. A model asked about either reaches for the
/// claim unprompted and puts it in a field nobody asked for; a judgement assembled from scratch
/// leaves it on the floor.
export function toJudgement(
  value: Record<string, unknown>,
  meals: readonly JudgeableMeal[],
): Judgement {
  const answers = value.answers === true;
  if (answers) return { answers: true, alternatives: [] };

  const raw = Array.isArray(value.alternatives) ? value.alternatives : [];
  const seen = new Set<string>();
  const alternatives: string[] = [];

  for (const entry of raw) {
    if (typeof entry !== 'number' || !Number.isInteger(entry)) continue;
    const meal = meals[entry - 1];
    if (meal === undefined) continue;
    if (seen.has(meal.id)) continue;
    seen.add(meal.id);
    alternatives.push(meal.id);
    if (alternatives.length === MAX_ALTERNATIVES) break;
  }

  return { answers: false, alternatives };
}
