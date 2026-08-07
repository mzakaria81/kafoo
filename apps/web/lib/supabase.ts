import { createClient } from '@supabase/supabase-js';

/**
 * Kafoo's data, read as an anonymous Customer.
 *
 * **RLS is the whole authorization story here, exactly as in the app.** The
 * `anyone reads a published meal` policy is granted to `anon`, and E2's
 * widening policy makes a Kitchen Profile readable exactly while its Cook has a
 * Meal on offer. This surface adds no policy and gets no data path of its own —
 * a second one would be a second place for the visibility rules to be
 * approximated, and they would drift.
 *
 * **The key never reaches the browser.** Every page here is server-rendered and
 * nothing client-side talks to Supabase, so the publishable key stays on the
 * worker. ADR-0008 says a publishable key in a client bundle is fine by design;
 * not shipping one at all is simply better, and it is free here.
 *
 * The service-role key must never reach this surface in any form. `npm run
 * check:no-secret` fails the build if it appears in the output.
 */
export function createReadClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;

  // Fail loudly at the first request rather than returning empty lists that
  // look exactly like an empty marketplace. An unset variable expands to
  // undefined, and Kafoo has already lost a day to a name mismatch that failed
  // silently — see docs/HANDOFF.md.
  if (!url || !key) {
    throw new Error(
      'Kafoo web is not configured. Set SUPABASE_URL and ' +
        'SUPABASE_PUBLISHABLE_KEY (unsuffixed names — see docs/HANDOFF.md).',
    );
  }

  return createClient(url, key, { auth: { persistSession: false } });
}

/** A Meal as a Customer meets it. Mirrors the app's `DiscoveredMeal`. */
export type DiscoveredMeal = {
  meal: MealRow;
  kitchen: KitchenRow;
};

export type MealRow = {
  id: string;
  cook_id: string;
  title: string;
  description: string;
  price: string;
  status: string;
  photo_path: string | null;
};

/**
 * A Kitchen Profile's public face — **exactly five details and no sixth.**
 *
 * This type is the enforcement. `docs/product/domain-model.md` says adding a
 * sixth is a change to the rule rather than a layout decision, so a field added
 * here without that decision is the regression, not the page that renders it.
 */
export type KitchenRow = {
  id: string;
  cook_id: string;
  display_name: string;
  story: string;
  area: string;
  delivery_terms: string;
  photo_path: string | null;
};

const MEAL_COLUMNS = 'id, cook_id, title, description, price, status, photo_path';
const KITCHEN_COLUMNS =
  'id, cook_id, display_name, story, area, delivery_terms, photo_path';

/** Every Meal on offer, with the kitchen behind it. Newest first. */
export async function mealsOnOffer(): Promise<DiscoveredMeal[]> {
  const supabase = createReadClient();

  const { data: meals } = await supabase
    .from('meals')
    .select(MEAL_COLUMNS)
    .eq('status', 'published')
    .order('published_at', { ascending: false });

  if (!meals?.length) return [];

  // Two queries, not a join: `meals` and `kitchen_profiles` both reference
  // auth.users and neither references the other, so there is no relationship to
  // traverse. Same reasoning as the app's repository.
  const cookIds = [...new Set(meals.map((m) => m.cook_id))];
  const { data: kitchens } = await supabase
    .from('kitchen_profiles')
    .select(KITCHEN_COLUMNS)
    .in('cook_id', cookIds);

  const byCook = new Map((kitchens ?? []).map((k) => [k.cook_id, k]));

  // A Meal whose kitchen did not come back is dropped rather than shown with
  // nobody behind it. Showing a Customer food with no cook is worse than
  // showing less.
  return meals.flatMap((meal) => {
    const kitchen = byCook.get(meal.cook_id);
    return kitchen ? [{ meal, kitchen }] : [];
  });
}

/**
 * A kitchen, **only while it has something on offer.**
 *
 * Returns null for a kitchen with nothing on the menu, which is FR-004 and
 * FR-027 on this surface. The database would already refuse it — the widening
 * policy is what makes a kitchen readable at all — and this asks the second
 * question anyway, because a kitchen that is readable through some future
 * policy change must still not be reachable with an empty shopfront.
 */
export async function kitchenOnOffer(
  id: string,
): Promise<{ kitchen: KitchenRow; meals: MealRow[] } | null> {
  const supabase = createReadClient();

  const { data: kitchen } = await supabase
    .from('kitchen_profiles')
    .select(KITCHEN_COLUMNS)
    .eq('id', id)
    .maybeSingle();

  if (!kitchen) return null;

  const { data: meals } = await supabase
    .from('meals')
    .select(MEAL_COLUMNS)
    .eq('cook_id', kitchen.cook_id)
    .eq('status', 'published')
    .order('published_at', { ascending: false });

  if (!meals?.length) return null;
  return { kitchen, meals };
}

/** A single Meal on offer, with its kitchen. Null when it is not on offer. */
export async function mealOnOffer(id: string): Promise<DiscoveredMeal | null> {
  const supabase = createReadClient();

  const { data: meal } = await supabase
    .from('meals')
    .select(MEAL_COLUMNS)
    .eq('id', id)
    .eq('status', 'published')
    .maybeSingle();

  if (!meal) return null;

  const { data: kitchen } = await supabase
    .from('kitchen_profiles')
    .select(KITCHEN_COLUMNS)
    .eq('cook_id', meal.cook_id)
    .maybeSingle();

  return kitchen ? { meal, kitchen } : null;
}

/** Public URL for a storage path, or null. Buckets are public by design. */
export function photoUrl(bucket: string, path: string | null): string | null {
  if (!path) return null;
  const url = process.env.SUPABASE_URL;
  return url ? `${url}/storage/v1/object/public/${bucket}/${path}` : null;
}
