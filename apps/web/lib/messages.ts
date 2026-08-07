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
