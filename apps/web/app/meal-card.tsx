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
        {/* `dir="auto"` on everything a COOK wrote, and nothing else.
            The page is `dir="rtl"`, so without this a Latin-script title gets an
            RTL paragraph direction: `Mama's Kitchen (Maadi)` renders with its
            closing parenthesis detached and thrown to the far left, and an
            English description throws every sentence-final full stop the same
            way. `auto` takes the direction from the first strong character,
            which is the same rule the U+2068 isolates apply inline.
            Kafoo's own copy stays undecorated — it is Arabic and the page
            direction is already right for it. */}
        <h2 dir="auto">{item.meal.title}</h2>
        <p>
          {/* The Cook's name sits at the END of an Arabic sentence, so it needs
              isolating rather than a paragraph direction — the same fix, and the
              same characters, as `namedAlternatives`. */}
          {fill(t.browseKitchenLabel, {
            kitchen: `⁨${item.kitchen.display_name}⁩`,
          })}
        </p>
        <p className="price">{priceLabel(item.meal.price)}</p>
      </div>
    </Link>
  );
}
