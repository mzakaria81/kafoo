'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

import { messages } from '@/lib/messages';
import type { SearchConsent } from '@/lib/consent';
import { readConsent, writeConsent } from '@/lib/consent';

/**
 * Kafoo's Settings on the web, which is one switch.
 *
 * **It exists because FR-029c requires a Customer to be able to change their
 * answer at any time, in one place, in both directions** — and a question asked
 * once at the first search has nowhere else to live. T226 says it need not be
 * shaped like the app's screen, but it must be findable and it must work in both
 * directions; the link to it is in the page header, on every page.
 *
 * **Keep it to the one switch.** A Settings page is the most natural home in any
 * product for the next toggle somebody cannot decide about, and every toggle
 * added here is a decision handed to a Customer instead of made. The next one is
 * a stop-and-ask, not a follow-on.
 *
 * A plain checkbox rather than a styled switch. It is the platform's own
 * control, so it is keyboard-reachable, screen-reader-labelled and correctly
 * sized on a phone without any of that being re-implemented.
 */
export default function SettingsPage() {
  const t = messages();
  const [consent, setConsent] = useState<SearchConsent | null>(null);

  useEffect(() => setConsent(readConsent(window.localStorage)), []);

  function change(on: boolean) {
    const given: SearchConsent = on ? 'granted' : 'refused';
    // Optimistic on purpose: the answer is what the Customer just said, and the
    // write is bookkeeping. Waiting for it would leave the switch showing the
    // old position.
    setConsent(given);
    writeConsent(window.localStorage, given);
  }

  return (
    <main>
      <h1>{t.settingsTitle}</h1>

      {/* WHY THE CONTROL IS DISABLED, SAID OUT LOUD. A screen reader announced
          "Search with the AI Assistant, checkbox, unavailable" and offered no
          reason. The window is normally one frame — but Next server-renders this
          client component, so the shipped HTML has it disabled, and on a slow
          device or a failed hydration it stays that way. The Customer would be
          looking at the one control that turns search back on, dead and
          unexplained. */}
      {consent === null ? (
        <p className="fine" role="status" id="reading">
          {t.settingsReadingAnswer}
        </p>
      ) : null}

      <p>
        <label className="switch">
          <input
            type="checkbox"
            // The explanation IS the reason this control exists — turning it off
            // stops search working. As an unassociated sibling paragraph, a
            // screen reader user tabbing to the checkbox heard only its label
            // and had to leave the control to find out what it does.
            aria-describedby={
              consent === null
                ? 'reading explanation storage'
                : 'explanation storage'
            }
            // Unanswered reads as off, because nothing has been sent yet and
            // that is what the switch describes. Turning it on here IS an
            // answer — SC-015 then holds and the question never appears.
            checked={consent === 'granted'}
            // Disabled only while the browser's own answer is still being read.
            // A switch that could be flipped before the stored value arrived
            // would overwrite it with whatever it happened to show.
            disabled={consent === null}
            onChange={(event) => change(event.target.checked)}
          />
          <span>{t.settingsSearchTitle}</span>
        </label>
      </p>

      <p id="explanation">{t.settingsSearchExplanation}</p>

      {/* Says where the answer is kept, because "we do not store this" is the
          part a Customer has no way to verify and every reason to want told.
          FR-029d. */}
      <p className="fine" id="storage">{t.settingsSearchStorageNote}</p>

      <p className="bar">
        <Link href="/">{t.settingsBack}</Link>
      </p>
    </main>
  );
}
