import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { fill, messages, priceLabel } from '@/lib/messages';
import { kitchenPreview } from '@/lib/preview';
import { kitchenOnOffer, photoUrl } from '@/lib/supabase';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { id } = await params;
  const found = await kitchenOnOffer(id);
  if (!found) return {};

  // FR-027a: a shared reference reveals EXACTLY three things before it is
  // opened — the kitchen's name, its area, and its photo. Not the story, not
  // the delivery terms, not how many Meals there are. A fourth here is a
  // failure of the feature even if the page below is correct, because this is
  // what reaches every member of a group chat who never taps the link.
  const preview = kitchenPreview(
    found.kitchen,
    photoUrl('kitchen-photos', found.kitchen.photo_path),
  );
  return {
    title: preview.title,
    description: preview.area,
    openGraph: {
      title: preview.title,
      description: preview.area,
      images: preview.image ?? undefined,
    },
  };
}

export default async function KitchenPage({ params }: Params) {
  const { id } = await params;
  const t = messages();
  const found = await kitchenOnOffer(id);

  // A kitchen with nothing on offer is NOT reachable — FR-004 and FR-027. An
  // empty shopfront is a small betrayal repeated at scale, and Kafoo never
  // shows a Customer a kitchen they cannot order from.
  if (!found) notFound();

  const { kitchen, meals } = found;
  const src = photoUrl('kitchen-photos', kitchen.photo_path);

  return (
    <main>
      {src ? <img src={src} alt="" style={{ maxInlineSize: '100%' }} /> : null}

      {/* Exactly the five public details, and no sixth: display name, story,
          area, delivery terms, photo. No rating, no review count, no order
          count, no Meal count — none of those exist, and a placeholder for one
          is a fabricated measurement rather than an empty field (FR-027c). */}
      <h1>{kitchen.display_name}</h1>
      <p>{kitchen.story}</p>
      <p>
        {t.kitchenArea}: {kitchen.area}
      </p>
      <p>
        {t.kitchenDeliveryTerms}: {kitchen.delivery_terms}
      </p>

      <h2>{t.kitchenMealsTitle}</h2>
      {meals.map((meal) => {
        const photo = photoUrl('meal-photos', meal.photo_path);
        return (
          <Link key={meal.id} href={`/m/${meal.id}`} className="card">
            {photo ? <img src={photo} alt="" /> : null}
            <div>
              <h2>{meal.title}</h2>
              <p className="price">{priceLabel(meal.price)}</p>
            </div>
          </Link>
        );
      })}
    </main>
  );
}
