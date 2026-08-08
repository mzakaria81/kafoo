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
 * **Everything in this file runs on the server, and the publishable key stays
 * there.** Browsing, kitchens and Meal pages are all server-rendered, so nothing
 * here puts a key in a bundle.
 *
 * **Searching is the exception, and it is deliberate.** `lib/discovery.ts` runs
 * in the browser and takes the key with it, because a Customer's phrase must not
 * pass through Kafoo's own Worker — see [publicBackend] and the note at the top
 * of that file. ADR-0008 Amendment 1 settles the cost in terms: the publishable
 * key belongs in the bundle.
 *
 * This paragraph said "the key never reaches the browser" until 2026-08-08, and
 * it was true when it was written. A doc comment that describes a property the
 * code stopped having is worse than none, because the next person reads it as a
 * rule and works around a constraint nobody is keeping.
 *
 * The service-role key must never reach this surface in any form. `npm run
 * check:no-secret` fails the build if it appears in the output.
 */
export function createReadClient() {
  const { url, publishableKey } = publicBackend();
  return createClient(url, publishableKey, { auth: { persistSession: false } });
}

/**
 * The URL and the **publishable** key, for the one thing that runs in a browser.
 *
 * Browsing is server-rendered and needs none of this. Searching does: a
 * Customer's phrase must not pass through Kafoo's own Worker, because a Worker
 * logs the request line and a URL is written into history and into `Referer`.
 * So the words go from the browser straight to the `discover` Edge Function,
 * exactly as they go from the phone in the app, and the key travels with them.
 *
 * ADR-0008 Amendment 1 settles the cost: "The publishable key belongs in the
 * bundle; the service-role key never reaches any client." RLS is the
 * authorization story on both surfaces, so a publishable key buys a reader
 * nothing an anonymous Customer does not already have.
 *
 * **This is read on the server and passed down as a prop, never inlined as a
 * `NEXT_PUBLIC_` variable.** The unsuffixed names are the ones `docs/HANDOFF.md`
 * records; a second, differently-spelled copy of the same secret is how the
 * name mismatch that cost a day happens again.
 */
export function publicBackend(): { url: string; publishableKey: string } {
  const url = process.env.SUPABASE_URL;
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;

  // Fail loudly at the first request rather than returning empty lists that
  // look exactly like an empty marketplace. An unset variable expands to
  // undefined, and Kafoo has already lost a day to a name mismatch that failed
  // silently — see docs/HANDOFF.md.
  if (!url || !publishableKey) {
    throw new Error(
      'Kafoo web is not configured. Set SUPABASE_URL and ' +
        'SUPABASE_PUBLISHABLE_KEY (unsuffixed names — see docs/HANDOFF.md).',
    );
  }

  return { url, publishableKey };
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
  /**
   * The domain's fixed vocabularies — `packages/domain/lib/meal.dart`.
   *
   * **Nothing renders these.** They are here because `MealOpened` carries them,
   * and they are the one kind of thing that event may carry: chosen from a list
   * by the Cook, keys rather than copy, and never a word anybody typed. Two
   * short strings a row is what that costs.
   */
  cuisine: string;
  category: string;
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

const MEAL_COLUMNS =
  'id, cook_id, title, description, price, cuisine, category, status, photo_path';
const KITCHEN_COLUMNS =
  'id, cook_id, display_name, story, area, delivery_terms, photo_path';

/**
 * Every Meal on offer, with the kitchen behind it. Newest first.
 *
 * **`failed` is not tidiness, and this function used to conflate it with
 * empty.** A read that errors produced `[]`, which the page rendered as "no food
 * is on offer right now" — Kafoo telling a Customer that no Cook anywhere has
 * anything, on the strength of a network error. `loadError` has sat in both
 * message files unused since this surface shipped, waiting for the caller to be
 * able to tell the two apart.
 *
 * Search made it load-bearing rather than merely wrong: when a Customer's own
 * area comes back empty, FR-024a says Kafoo names the areas that do have food.
 * The areas come from this list, so a failed read that looks empty would say
 * "there is nothing anywhere" at exactly the moment the Customer is owed
 * somewhere else to look.
 */
export async function mealsOnOffer(): Promise<{
  meals: DiscoveredMeal[];
  failed: boolean;
}> {
  const supabase = createReadClient();

  const { data: meals, error } = await supabase
    .from('meals')
    .select(MEAL_COLUMNS)
    .eq('status', 'published')
    .order('published_at', { ascending: false });

  if (error) return { meals: [], failed: true };
  if (!meals?.length) return { meals: [], failed: false };

  // Two queries, not a join: `meals` and `kitchen_profiles` both reference
  // auth.users and neither references the other, so there is no relationship to
  // traverse. Same reasoning as the app's repository.
  const cookIds = [...new Set(meals.map((m) => m.cook_id))];
  const { data: kitchens, error: kitchenError } = await supabase
    .from('kitchen_profiles')
    .select(KITCHEN_COLUMNS)
    .in('cook_id', cookIds);

  if (kitchenError) return { meals: [], failed: true };

  const byCook = new Map((kitchens ?? []).map((k) => [k.cook_id, k]));

  // A Meal whose kitchen did not come back is dropped rather than shown with
  // nobody behind it. Showing a Customer food with no cook is worse than
  // showing less.
  return {
    meals: meals.flatMap((meal) => {
      const kitchen = byCook.get(meal.cook_id);
      return kitchen ? [{ meal, kitchen }] : [];
    }),
    failed: false,
  };
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
