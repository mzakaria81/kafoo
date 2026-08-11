import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { fill, messages, priceLabel } from '@/lib/messages';
import { mealPreview } from '@/lib/preview';
import { mealOnOffer, photoUrl } from '@/lib/supabase';

export const dynamic = 'force-dynamic';

type Params = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const { id } = await params;
  const item = await mealOnOffer(id);
  if (!item) return {};

  // What a shared reference reveals BEFORE it is opened. FR-027a caps it at
  // three things, and this is the whole of the enforcement — everything below
  // renders on the page, which only someone who tapped it ever sees.
  const preview = mealPreview(
    item.meal,
    item.kitchen,
    photoUrl('meal-photos', item.meal.photo_path),
  );
  return {
    title: preview.title,
    description: fill(messages().browseKitchenLabel, {
      kitchen: preview.kitchen,
    }),
    openGraph: {
      title: preview.title,
      description: preview.kitchen,
      images: preview.image ?? undefined,
    },
  };
}

export default async function MealPage({ params }: Params) {
  const { id } = await params;
  const t = messages();
  const item = await mealOnOffer(id);

  // A Meal not on offer is not found, rather than shown as unavailable. The
  // database already refuses it; this is what a Customer sees when it does.
  if (!item) notFound();

  const src = photoUrl('meal-photos', item.meal.photo_path);
  return (
    <main>
      {src ? <img src={src} alt="" style={{ maxInlineSize: '100%' }} /> : null}
      {/* Cook-authored — see the note in app/meal-card.tsx. */}
      <h1 dir="auto">{item.meal.title}</h1>
      <p className="price">{priceLabel(item.meal.price)}</p>
      <p dir="auto">{item.meal.description}</p>
      <p>
        <Link href={`/k/${item.kitchen.id}`}>
          {fill(t.browseKitchenLabel, {
            kitchen: `⁨${item.kitchen.display_name}⁩`,
          })}
        </Link>
      </p>
    </main>
  );
}
