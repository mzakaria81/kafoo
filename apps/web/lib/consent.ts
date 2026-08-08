/**
 * Where a Customer's answer about their own words is kept **on this surface**.
 *
 * **In the browser, and that is FR-029d rather than an implementation choice.**
 * Kafoo holds no record of a Customer — discovery works signed out, which is the
 * whole reason a shared link is worth anything — so there is no row to put this
 * on and nobody to put it against. An answer kept on Kafoo's side would be
 * unavailable to exactly the person who arrives by a WhatsApp link, who is the
 * person most likely to be asked.
 *
 * The app keeps the same answer in `SharedPreferences`
 * (`apps/mobile/lib/features/settings/data/search_consent_store.dart`). Same
 * question, same three states, same refusal to write `unanswered` — a different
 * store because a browser is not a phone, not a different rule.
 *
 * **`Storage` is passed in rather than reached for.** `localStorage` does not
 * exist while a page is server-rendered, and a module that touches it at import
 * time crashes the render. Passing it also lets a test drive every branch
 * without a browser.
 */

/** The three states. `unanswered` is the only one that may be asked about. */
export type SearchConsent = 'granted' | 'refused' | 'unanswered';

/**
 * Namespaced, because this browser holds one Kafoo answer and may hold anything
 * else. **Never renamed** — a renamed key is a Customer being asked a question
 * they already answered.
 */
export const CONSENT_KEY = 'kafoo.search_consent';

/** Whether a phrase may leave. Only an explicit yes says yes. */
export function allowsSearch(consent: SearchConsent): boolean {
  return consent === 'granted';
}

/** Whether the question is still owed. */
export function needsAsking(consent: SearchConsent): boolean {
  return consent === 'unanswered';
}

/** The stored answer, or `unanswered` if there is none. */
export function readConsent(storage: Storage | null | undefined): SearchConsent {
  if (!storage) return 'unanswered';
  try {
    const value = storage.getItem(CONSENT_KEY);
    if (value === 'granted') return 'granted';
    if (value === 'refused') return 'refused';
    // Anything else — absent, or a value written by a version that stored
    // something different — is unanswered. Reading an unrecognised value as
    // `granted` would send a Customer's words on the strength of a string
    // nobody can account for.
    return 'unanswered';
  } catch {
    // A browser with storage disabled, or a page in a partitioned third-party
    // context, throws here. Failing to read is unanswered, which asks the
    // question again — the safe direction, because the other one sends words on
    // the strength of a failed read.
    return 'unanswered';
  }
}

/**
 * Records an answer.
 *
 * **`unanswered` is not writable, and that is deliberate**: a Customer cannot
 * become un-asked. SC-015 says the question appears zero times after any answer,
 * and a code path that could restore the unanswered state is a code path that
 * could ask again.
 */
export function writeConsent(
  storage: Storage | null | undefined,
  consent: SearchConsent,
): void {
  if (!storage || consent === 'unanswered') return;
  try {
    storage.setItem(CONSENT_KEY, consent);
  } catch {
    // A write that fails means the question is asked again next time, which is
    // an annoyance. Throwing a Customer out of search would be worse.
  }
}
