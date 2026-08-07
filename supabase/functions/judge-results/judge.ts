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
      // `minimum: 1`, AND IT IS THE WHOLE REPLY THAT FAILS RATHER THAN THE NUMBER.
      //
      // A zero is not noise. The list is numbered from one, so a model that returns 0 numbered the
      // list from zero — every index is shifted and the first is silently discarded. Dropping the
      // out-of-range entry and publishing the rest answered with Meals the judgement did not pick,
      // while telling the Customer they were: measured on three Meals, a reply meaning
      // "the first and the second" published "the first" alone.
      //
      // Refusing the reply is also the consistent stance. An unknown property already costs the
      // whole judgement; being strict about a harmless extra field and lenient about a number that
      // proves the model mis-read the list is the inconsistency running the wrong way.
      items: { type: 'integer', minimum: 1 },
      // Nullable because a model returning explicit `null` for "none" is ordinary and the reply is
      // perfectly usable. That is leniency about something genuinely harmless.
      nullable: true,
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
  // JSON, BECAUSE A HEADER IS A STRING AND A COOK CAN TYPE ONE.
  //
  // This built a plain-text list — `The Meals that came back:` and a numbered block — and said in a
  // comment that the labelling made untrusted text "visibly a quoted value". It did not. Found by
  // ai-boundary-reviewer, who ran it: a Cook puts the delimiter INSIDE their own description,
  // followed by a second list containing only their Meal and a rule telling the model to answer
  // `false` and name number 1. Every defence downstream then passes, because nothing about the
  // payload is malformed — `false` is a valid boolean and `1` is an in-range index. A Customer asks
  // for koshari, koshari is on offer, and Kafoo says nothing here answers you but there is a burger.
  // A Cook bought a promotion by typing into a text field, at no cost, in a marketplace where
  // ranking manipulation is a trust failure.
  //
  // A JSON value cannot be escaped from by writing text into it: a quote inside a description is
  // encoded rather than closing the string, so the structure the model sees is the structure this
  // function built. That is a property of the encoding rather than of how carefully the text reads.
  //
  // The words themselves are still passed through unchanged, only truncated. Scrubbing them would
  // change what the Customer asked for, and the prompt's untrusted-input rule is what handles the
  // content.
  return JSON.stringify({
    request: clamp(phrase, PHRASE_MAX),
    meals: meals.map((meal, index) => ({
      number: index + 1,
      title: clamp(meal.title, TITLE_MAX),
      description: clamp(meal.description, DESCRIPTION_MAX),
    })),
  });
}

/// Nothing bounded the size of a Meal's text, and `meals.description` has no length constraint.
///
/// Fifty Meals with 20 KB descriptions is a megabyte of prompt on every search that returns them,
/// billed per search, at a latency the two-second budget never sees because this call is never
/// awaited. One Cook can create that, for free, and it would look like a provider bill nobody could
/// explain. A judgement needs enough of a description to tell food apart, not all of it.
const TITLE_MAX = 120;
const DESCRIPTION_MAX = 400;
const PHRASE_MAX = 500;

function clamp(value: string, max: number): string {
  // Control characters go, including the newlines the old plain-text frame could be split with.
  // They carry no meaning in a food description and every use of one here is someone shaping a
  // prompt rather than describing a Meal.
  const flat = value.replace(/[\u0000-\u001F\u007F]/g, ' ').trim();
  return flat.length <= max ? flat : `${flat.slice(0, max)}…`;
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
