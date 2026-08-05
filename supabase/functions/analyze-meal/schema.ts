// Response schema for meal analysis. Matches what prompts/meal-analysis.md promises to return.
//
// The 20000 calorie ceiling is load-bearing: a model that returns 190000 must be rejected here
// before a Cook ever sees it. The meals table CHECK is the second line of the same defence; this
// is the first, and the only one that runs before anything is shown.

import type { ResponseSchema } from '../_shared/ai/schema.ts';

export const MEAL_ANALYSIS_SCHEMA: ResponseSchema = {
  type: 'object',
  required: ['ingredients', 'allergens', 'cuisine', 'category', 'basis'],
  properties: {
    ingredients: {
      type: 'array',
      items: { type: 'string' },
    },
    calories: {
      type: 'integer',
      minimum: 0,
      maximum: 20000,
      nullable: true,
    },
    allergens: {
      type: 'array',
      items: { type: 'string' },
    },
    cuisine: {
      type: 'string',
      enum: [
        'egyptian',
        'levantine',
        'gulf',
        'sudanese',
        'moroccan',
        'turkish',
        'italian',
        'asian',
        'american',
        'other',
      ],
    },
    category: {
      type: 'string',
      enum: [
        'main',
        'appetizer',
        'soup',
        'salad',
        'side',
        'dessert',
        'bakery',
        'drink',
        'other',
      ],
    },
    // Individual basis keys are optional: the prompt says write a reason only for fields actually
    // filled. Requiring them would force the model to invent reasons for empty fields.
    basis: {
      type: 'object',
      properties: {
        ingredients: { type: 'string' },
        calories: { type: 'string' },
        allergens: { type: 'string' },
        cuisine: { type: 'string' },
        category: { type: 'string' },
      },
    },
  },
};

// Nothing calls this yet — no Edge Function drafts a description. It lives beside
// MEAL_ANALYSIS_SCHEMA so the day one does, it imports the same shape rather than writing a second.
export const MEAL_DESCRIPTION_SCHEMA: ResponseSchema = {
  type: 'object',
  required: ['description', 'basis'],
  properties: {
    description: { type: 'string' },
    basis: {
      type: 'object',
      properties: {
        description: { type: 'string' },
      },
    },
  },
};
