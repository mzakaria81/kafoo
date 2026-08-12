import { arabicIndic } from '@/lib/numerals';
import ar from '@/messages/ar.json';
import en from '@/messages/en.json';

/**
 * Egyptian Arabic is the **source** locale, not the fallback.
 *
 * `ar` is what a string is written in first; `en` is the translation. Same rule
 * as the app's ARB files, and the gate checks both files carry the same keys.
 */
export type Messages = typeof ar;

const LOCALES = { ar, en } as const;
export type Locale = keyof typeof LOCALES;

export const DEFAULT_LOCALE: Locale = 'ar';

export function messages(locale: Locale = DEFAULT_LOCALE): Messages {
  return LOCALES[locale];
}

/** Fills `{name}` placeholders. Never string-concatenates around a value. */
export function fill(template: string, values: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in values ? values[key] : match,
  );
}

/**
 * A price as a Customer reads it, **with its currency**.
 *
 * `Meal.price` is the exact string the Cook typed — `numeric(10,2)`, never a
 * double — and it is passed through, never reformatted and never rounded. The
 * currency comes from the messages file because it is a word, and it differs by
 * locale.
 *
 * **Every price on this surface goes through here, and until 2026-08-08 none of
 * them did.** Three pages rendered `{meal.price}` bare, so a Meal that said
 * `٣٥ جنيه` in the app said `35` on the web. The app had already shipped and
 * fixed exactly this. SC-009 says what is visible without installing is
 * identical to what is visible inside, and money a Customer reads is never a
 * naked number.
 */
export function priceLabel(price: string, locale: Locale = DEFAULT_LOCALE): string {
  return fill(messages(locale).publicMealPriceValue, {
    // Arabic reads ٣٥; English reads 35. Glyphs only — see lib/numerals.ts for
    // why a transliteration is the only price formatting that cannot lose a
    // piastre, and why phone numbers and codes are excluded from it.
    price: locale === 'ar' ? arabicIndic(price) : price,
  });
}
