import Link from 'next/link';
import { fill, messages } from '@/lib/messages';
import { mealsOnOffer, photoUrl } from '@/lib/supabase';

// Rendered per request. What is on offer changes through the day — a home
// cook's Meal is up for a window — so a cached page would show food that is no
// longer available, which is the one thing discovery must not do.
export const dynamic = 'force-dynamic';

export default async function BrowsePage() {
  const t = messages();
  const items = await mealsOnOffer();

  return (
    <main>
      <h1>{t.browseTitle}</h1>

      {/* Words, never a blank page. Same rule as the app's FR-006. */}
      {items.length === 0 ? (
        <p className="empty">{t.browseNothingOnOffer}</p>
      ) : (
        items.map(({ meal, kitchen }) => {
          const src = photoUrl('meal-photos', meal.photo_path);
          return (
            <Link key={meal.id} href={`/m/${meal.id}`} className="card">
              {src ? <img src={src} alt="" /> : null}
              <div>
                <h2>{meal.title}</h2>
                <p>{fill(t.browseKitchenLabel, { kitchen: kitchen.display_name })}</p>
                <p className="price">{meal.price}</p>
              </div>
            </Link>
          );
        })
      )}
    </main>
  );
}
