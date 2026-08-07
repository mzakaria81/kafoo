import type { KitchenRow, MealRow } from './supabase';

/**
 * What a shared reference reveals **before anyone opens it**.
 *
 * Pure functions, separated from the pages, because this is the one part of the
 * web surface with a hard numeric cap on it and a cap nobody can test is a cap
 * nobody keeps. FR-027a allows a kitchen preview exactly three things — name,
 * area, photo — and this is what reaches every member of a group chat who never
 * taps the link.
 *
 * Adding a field here is a change to ADR-0008's second open dependency, which
 * the founder settled on 2026-08-06. It is not a layout decision.
 */

/** The three things, and nothing else. */
export type KitchenPreview = {
  title: string;
  area: string;
  image: string | null;
};

export function kitchenPreview(
  kitchen: KitchenRow,
  image: string | null,
): KitchenPreview {
  // Built field by field rather than spread from the row. A spread would carry
  // the story and the delivery terms into the preview the moment the row type
  // grew, silently, and the failure would be personal information in a chat
  // Kafoo cannot see.
  return {
    title: kitchen.display_name,
    area: kitchen.area,
    image,
  };
}

/** A Meal preview: what it is, whose kitchen, and the photograph. */
export type MealPreview = {
  title: string;
  kitchen: string;
  image: string | null;
};

export function mealPreview(
  meal: MealRow,
  kitchen: KitchenRow,
  image: string | null,
): MealPreview {
  return {
    title: meal.title,
    kitchen: kitchen.display_name,
    image,
  };
}

/**
 * The five details of a Kitchen Profile's public face, in order.
 *
 * Named here so the page renders a list rather than deciding what is public one
 * `<p>` at a time. `docs/product/domain-model.md`: adding a sixth is a change to
 * the rule.
 */
export const PUBLIC_KITCHEN_FIELDS = [
  'display_name',
  'story',
  'area',
  'delivery_terms',
  'photo_path',
] as const;

/**
 * Things Kafoo does not measure and must never display.
 *
 * There are no Reviews and no Orders yet, so a rating or a count on this
 * surface would be a fabricated measurement rather than an empty field —
 * FR-027c. Listed rather than remembered, so the test can assert on it.
 */
export const FORBIDDEN_CLAIMS = [
  'rating',
  'reviews',
  'review_count',
  'order_count',
  'popular',
  'distance',
  'km',
] as const;
