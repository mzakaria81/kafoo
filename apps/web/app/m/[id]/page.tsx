import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { fill, messages } from '@/lib/messages';
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
  return {
    title: item.meal.title,
    description: fill(messages().browseKitchenLabel, {
      kitchen: item.kitchen.display_name,
    }),
    openGraph: {
      title: item.meal.title,
      description: item.kitchen.display_name,
      images: photoUrl('meal-photos', item.meal.photo_path) ?? undefined,
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
      <h1>{item.meal.title}</h1>
      <p className="price">{item.meal.price}</p>
      <p>{item.meal.description}</p>
      <p>
        <Link href={`/k/${item.kitchen.id}`}>
          {fill(t.browseKitchenLabel, { kitchen: item.kitchen.display_name })}
        </Link>
      </p>
    </main>
  );
}
