import type { Metadata } from 'next';
import { DEFAULT_LOCALE, messages } from '@/lib/messages';
import './globals.css';

export const metadata: Metadata = {
  title: messages().appTitle,
};

/**
 * `ar` is the default locale and right-to-left is the default direction.
 *
 * Not a fallback and not a toggle: Kafoo is Egyptian Arabic first on every
 * surface, and this attribute is what makes a browser lay the page out the way
 * a Customer reads it.
 */
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang={DEFAULT_LOCALE} dir="rtl">
      <body>{children}</body>
    </html>
  );
}
