import Link from 'next/link';
import { fill, messages } from '@/lib/messages';
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
 * No hooks and no state, so the browse list stays server-rendered and the search
 * results — which cannot be — render the identical markup on the client.
 */
export function MealCard({
  item,
  onOpen,
}: {
  item: DiscoveredMeal;
  /** Fired before navigation. Only search results pass one. */
  onOpen?: () => void;
}) {
  const t = messages();
  const src = photoUrl('meal-photos', item.meal.photo_path);
  return (
    <Link href={`/m/${item.meal.id}`} className="card" onClick={onOpen}>
      {src ? <img src={src} alt="" /> : null}
      <div>
        <h2>{item.meal.title}</h2>
        <p>{fill(t.browseKitchenLabel, { kitchen: item.kitchen.display_name })}</p>
        <p className="price">{item.meal.price}</p>
      </div>
    </Link>
  );
}
