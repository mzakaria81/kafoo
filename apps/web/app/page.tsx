import { messages } from '@/lib/messages';
import { mealsOnOffer, publicBackend } from '@/lib/supabase';
import { MealCard } from './meal-card';
import { SearchPanel } from './search-panel';

// Rendered per request. What is on offer changes through the day — a home
// cook's Meal is up for a window — so a cached page would show food that is no
// longer available, which is the one thing discovery must not do.
//
// **Searching is never cached either, and for a different reason.** A cache
// keyed on what somebody said is a recording of what they said, however it is
// described (FR-029, SC-011). Nothing here caches a phrase because nothing here
// ever sees one: the words go from the Customer's own browser straight to the
// `discover` Edge Function.
export const dynamic = 'force-dynamic';

export default async function BrowsePage() {
  const t = messages();
  const backend = publicBackend();
  const { meals: items, failed } = await mealsOnOffer();

  // The areas that have food right now, in the order the Cooks' Meals came back
  // — newest first — because any other order would be Kafoo ranking places
  // (FR-024b). Handed to the panel so that a Customer whose own area is empty
  // can be offered somewhere that is not.
  const areas = [
    ...new Set(
      items
        .map((item) => item.kitchen.area.trim())
        .filter((area) => area.length > 0),
    ),
  ];

  return (
    <main>
      <h1>{t.browseTitle}</h1>

      <SearchPanel
        backend={backend}
        areas={areas}
        browseFailed={failed}
        browseIsEmpty={!failed && items.length === 0}
      >
        {/* Browsing: the zero state, and every fallback. Server-rendered, so it
            works with no JavaScript at all — searching is the part that needs
            it. Words, never a blank page: the same rule as the app's FR-006.

            `loadError` and `browseNothingOnOffer` are DIFFERENT SENTENCES and
            only one of them is true. Saying "no food is on offer" because a read
            failed would be Kafoo telling a Customer that no Cook anywhere has
            anything, which it does not know. */}
        {failed ? (
          <p className="empty">{t.loadError}</p>
        ) : items.length === 0 ? (
          <p className="empty">{t.browseNothingOnOffer}</p>
        ) : (
          items.map((item) => (
            <MealCard
              key={item.meal.id}
              item={item}
              backend={backend}
              source="browse"
            />
          ))
        )}
      </SearchPanel>
    </main>
  );
}
