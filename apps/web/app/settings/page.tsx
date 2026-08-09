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

      <p>
        <label className="switch">
          <input
            type="checkbox"
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

      <p>{t.settingsSearchExplanation}</p>

      {/* Says where the answer is kept, because "we do not store this" is the
          part a Customer has no way to verify and every reason to want told.
          FR-029d. */}
      <p className="fine">{t.settingsSearchStorageNote}</p>

      <p>
        <Link href="/">{t.settingsBack}</Link>
      </p>
    </main>
  );
}
