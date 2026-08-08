import Link from 'next/link';
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
      <body>
        {/* FR-029c: one place to change the answer, and it has to be findable
            from wherever a Customer happens to be. A plain link in the header on
            every page, which is this surface's equivalent of the Settings icon
            in the app's own bar. Server-rendered, so it works before and without
            JavaScript — the page it leads to is where the browser's answer
            lives. */}
        <header className="bar">
          <Link href="/">{messages().appTitle}</Link>
          <Link href="/settings">{messages().settingsTitle}</Link>
        </header>
        {children}
      </body>
    </html>
  );
}
