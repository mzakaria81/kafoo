'use client';

import Link from 'next/link';
import { fill, messages, priceLabel } from '@/lib/messages';
import type { Backend, MealOpenSource } from '@/lib/discovery';
import { Discovery } from '@/lib/discovery';
import type { DiscoveredMeal } from '@/lib/supabase';
import { photoUrl } from '@/lib/supabase';

/**
 * A Meal as a Customer meets it, in a list.
 *
 * **One card, used by browsing and by search results.** FR-026 says what is
 * visible without installing is exactly what is visible inside Kafoo, and the
 * app renders both lists through one `discoveredMealCard`. Two card components
 * here would be the same drift one level down: a field added to one list and not
 * the other, noticed by nobody.
 *
 * **`MealOpened` is emitted here and not at the call sites**, for the same
 * reason the consent gate sits on the funnel rather than on the entrances: call
 * sites keep being added, and the one that forgets is invisible — a number that
 * is quietly low rather than a page that is quietly broken. `source` is required
 * so a new caller has to say where it is.
 *
 * **This is a client component, and that is what the event costs.** The card was
 * server-rendered until 2026-08-08 and browsing shipped no JavaScript for it.
 * The alternative — emitting server-side when the Meal page renders — counts
 * link prefetches and crawlers as opens, which is a number that looks like
 * demand and is not.
 */
export function MealCard({
  item,
  backend,
  source,
  onOpen,
}: {
  item: DiscoveredMeal;
  backend: Backend;
  source: MealOpenSource;
  /** Fired alongside the event. Only search results pass one. */
  onOpen?: () => void;
}) {
  const t = messages();
  const src = photoUrl('meal-photos', item.meal.photo_path);

  function opened() {
    // A fresh instance rather than a shared one: this component may be rendered
    // by a server component, which cannot hand a live object across. The
    // constructor does nothing but hold its dependencies.
    new Discovery({
      backend,
      storage: window.localStorage,
      fetch: window.fetch.bind(window),
    }).mealOpened(item.meal, source);
    onOpen?.();
  }

  return (
    <Link href={`/m/${item.meal.id}`} className="card" onClick={opened}>
      {src ? <img src={src} alt="" /> : null}
      <div>
        <h2>{item.meal.title}</h2>
        <p>{fill(t.browseKitchenLabel, { kitchen: item.kitchen.display_name })}</p>
        <p className="price">{priceLabel(item.meal.price)}</p>
      </div>
    </Link>
  );
}
