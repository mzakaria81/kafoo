import { allowsSearch, readConsent } from './consent.ts';
import type { DiscoveredMeal, KitchenRow, MealRow } from './supabase.ts';

/**
 * Searching, from the browser, through **the same `discover` function the app
 * calls**.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * NO SECOND DATA PATH AND NO SECOND VISIBILITY MODEL. `discover` holds no write
 * credential, passes the caller's own credentials through to `search_meals`, and
 * lets RLS decide what comes back. Calling it from here rather than from the
 * app changes none of that. A search endpoint of this surface's own would be a
 * second place for the visibility rules to be approximated, and they would
 * drift — ADR-0008 Amendment 1 names that as the largest permanent cost of a
 * JavaScript surface, and this is where it would start.
 *
 * THE PHRASE NEVER TOUCHES KAFOO'S OWN SERVER, AND THAT IS WHY THIS RUNS IN THE
 * BROWSER RATHER THAN IN A SERVER ACTION OR A `?q=` PAGE. Cloudflare logs the
 * request line of everything that reaches the Worker, a browser keeps the URL in
 * history, and a URL rides out in `Referer` to every image host on the page. Any
 * of those is FR-029 and SC-011 broken by a mechanism nobody wrote. So the words
 * go from the Customer's own browser straight to the Edge Function, exactly as
 * they go from the Customer's own phone in the app.
 *
 * The publishable key reaching the browser is what that costs, and ADR-0008
 * settles it: "The publishable key belongs in the bundle; the service-role key
 * never reaches any client." RLS is the authorization story on both surfaces.
 * ────────────────────────────────────────────────────────────────────────────
 */

/** Where the functions live, and the key that is allowed to reach a browser. */
export type Backend = {
  url: string;
  /** The **publishable** key. A service-role key here would be a breach. */
  publishableKey: string;
};

export type DiscoveryDeps = {
  backend: Backend;
  /** The browser's own store. Absent during a server render. */
  storage: Storage | null | undefined;
  /** Injected so a test can watch what leaves rather than read what decides. */
  fetch: typeof globalThis.fetch;
};

/** What came back from a search, and what Kafoo understood of it. */
export type SearchOutcome = {
  /** The Meals, in the order the database ranked them. **Never re-sorted.** */
  results: DiscoveredMeal[];
  /** Which exclusion Kafoo acted on, if any. An id, never the Customer's words. */
  excluded: string | null;
  /**
   * Whether a negation was recognised and the food after it was not.
   *
   * A flag and not the words. Saying nothing here is the failure the whole
   * exclusion design exists to prevent: the results arrive looking exactly like
   * results for a request with no exclusion in it.
   */
  notUnderstood: boolean;
  /**
   * The area the search was narrowed to, in the Customer's own words.
   *
   * Without this, an empty result in a named area is indistinguishable from an
   * empty marketplace, and FR-024 turns on exactly that difference.
   */
  area: string | null;
};

/** An area was named and it has nothing in it — FR-024. */
export function areaIsEmpty(outcome: SearchOutcome): boolean {
  return outcome.area !== null && outcome.results.length === 0;
}

export type SearchResponse =
  /** Results, possibly none. Empty is an ordinary outcome, not an error. */
  | { kind: 'results'; outcome: SearchOutcome }
  /** The Customer has refused, or has not been asked. **Nothing was sent.** */
  | { kind: 'refused' }
  /** Search could not run. Browsing is unaffected — FR-012. */
  | { kind: 'unavailable' };

/**
 * What the AI Assistant made of a set of results.
 *
 * `null` is returned for every failure — a timeout, a non-2xx, a body that is
 * not the shape promised. The Customer loses **a sentence**, never their
 * results (FR-011, SC-007, T161).
 */
export type Judgement =
  | { answers: true }
  | { answers: false; alternatives: MealRow[] };

const KITCHEN_COLUMNS =
  'id,cook_id,display_name,story,area,delivery_terms,photo_path';

/** `search_meals` returns at most 50, so nothing longer is worth sending. */
const MAX_JUDGED_MEALS = 50;

/**
 * The three events this surface records, spelled the way `event-model.md`
 * spells them. **PascalCase, past tense, and never renamed** — historical
 * comparison depends on the string, so a rename here is a break in the record
 * rather than a refactor.
 */
const EVENTS = {
  searchPerformed: 'SearchPerformed',
  searchFailed: 'SearchFailed',
  recommendationAccepted: 'RecommendationAccepted',
} as const;

export class Discovery {
  // Written out rather than declared as a constructor parameter property.
  // `lib/discovery.test.mjs` imports and RUNS this module, and Node's type
  // stripping refuses a parameter property — it is the one TypeScript form that
  // emits code rather than being erased. Spelling the field out costs a line and
  // keeps the tests able to watch what actually leaves.
  private readonly deps: DiscoveryDeps;

  constructor(deps: DiscoveryDeps) {
    this.deps = deps;
  }

  /**
   * Asks for food.
   *
   * `area` is the one a Customer CHOSE after their own area came back empty
   * (FR-024a). It rides on top of the same sentence they said the first time,
   * and `discover` lets it win over any area inside that sentence.
   */
  async search(phrase: string, area: string | null): Promise<SearchResponse> {
    const trimmed = phrase.trim();
    if (trimmed.length === 0) return { kind: 'refused' };

    const body = await this.send('discover', {
      phrase: trimmed,
      ...(area === null ? {} : { area }),
    });
    if (body === 'refused') return { kind: 'refused' };
    if (body === null) return { kind: 'unavailable' };

    const rows = Array.isArray(body.meals) ? (body.meals as MealRow[]) : [];
    const understood = {
      excluded: typeof body.excluded === 'string' ? body.excluded : null,
      notUnderstood: body.notUnderstood === true,
      area: typeof body.area === 'string' ? body.area : null,
    };

    // The kitchens, in one read, the same way browsing does it. `discover`
    // returns Meals alone because `search_meals` returns Meals alone, and a join
    // in the database would be a foreign key added to suit a screen.
    //
    // **This read carries cook ids and no word the Customer said**, so it is
    // deliberately not behind the gate below: the gate exists for phrases
    // leaving, and putting an unrelated read behind it would blur what the gate
    // is for.
    const kitchens = rows.length === 0
      ? new Map<string, KitchenRow>()
      : await this.readKitchens([...new Set(rows.map((row) => row.cook_id))]);
    if (kitchens === null) return { kind: 'unavailable' };

    // A Meal whose kitchen did not come back is dropped rather than shown with
    // nobody behind it. It should be unreachable — the widening policy makes a
    // kitchen readable exactly while it has a Meal on offer — so this is the
    // case where that has stopped being true, and showing a Customer food with
    // no cook is worse than showing less.
    const results = rows.flatMap((meal) => {
      const kitchen = kitchens.get(meal.cook_id);
      return kitchen ? [{ meal, kitchen }] : [];
    });

    // A COUNT AND NOTHING ELSE. FR-029 and SC-011: what a Customer searched for
    // is not recorded, and the most natural shape for this event —
    // `{phrase, result_count}` — is the violation. The attribute type below is
    // numbers only, so the phrase cannot be added here without the type
    // changing, which is a thing a reviewer sees.
    //
    // Emitted from HERE rather than from the screen, because "a search that
    // never ran emits nothing" (event-model.md) is then structural: the gate
    // returns above this line, so a refused Customer produces no event at all
    // rather than one with a count of zero.
    void this.emit(EVENTS.searchPerformed, { result_count: results.length });

    return { kind: 'results', outcome: { results, ...understood } };
  }

  /**
   * Whether the results honestly answer what was asked — FR-013, FR-026.
   *
   * **Called after results are on screen and never awaited before them.** A
   * judgement that fails, hangs, or returns nonsense costs a sentence.
   *
   * **This is a second way for the words to leave, so it passes the same gate**
   * rather than inheriting the one the search passed a moment ago. A Customer
   * who revokes in the round trip between the two had their words sent under a
   * permission they had just withdrawn — narrow today, and not narrow the day
   * somebody adds a retry or a longer timeout.
   */
  async judge(
    phrase: string,
    results: DiscoveredMeal[],
  ): Promise<Judgement | null> {
    if (results.length === 0) return null;

    const byId = new Map(results.map(({ meal }) => [meal.id, meal]));
    const body = await this.send('judge-results', {
      phrase: phrase.trim(),
      mealIds: [...byId.keys()].slice(0, MAX_JUDGED_MEALS),
    });
    if (body === 'refused' || body === null) return null;

    // THE FIELD MUST BE PRESENT AND MUST BE A BOOLEAN, and requiring that is the
    // difference between the server promising and the client checking. Reading
    // "not true" as "nothing answers you" would put that sentence in front of a
    // Customer whose results were fine, on the strength of any body that reached
    // here wearing a 200 — a gateway page, a retry wrapper, a platform error.
    if (typeof body.answers !== 'boolean') return null;
    if (body.answers === true) return { answers: true };

    // MATCHED against the set that was handed over, never looked up. A Meal the
    // AI Assistant invented has no id in this map and simply does not appear —
    // FR-015 says an alternative is a Meal genuinely on offer.
    const named = Array.isArray(body.alternatives) ? body.alternatives : [];
    const alternatives = named.flatMap((id: unknown) => {
      const meal = byId.get(String(id));
      return meal ? [meal] : [];
    });

    // SearchFailed BELONGS HERE AND NOT WHERE THE DATABASE RETURNED NOTHING.
    // Retrieval returning rows is not the same as those rows answering the
    // question — conflating the two is exactly what a score threshold tried and
    // failed to do, and the event would then be measuring the wrong fact.
    //
    // It carries NOTHING. Not the phrase, which FR-029 forbids, and not a count
    // either: the number of results that did not answer is not something anybody
    // can act on.
    void this.emit(EVENTS.searchFailed, {});

    return { answers: false, alternatives };
  }

  /**
   * A Customer opened a Meal the AI Assistant named — FR-030.
   *
   * Answers "did saying 'nothing here answers you, but there is this' actually
   * help", which is the only question that says whether the judgement is worth
   * its cost. It carries the RANK the Meal already had and nothing else — not
   * the phrase, and not the Meal's id, because an id plus a timestamp is a
   * search somebody could reconstruct.
   */
  recommendationAccepted(rank: number): void {
    void this.emit(EVENTS.recommendationAccepted, { rank });
  }

  /**
   * **THE GATE, AND THE ONLY DOOR A PHRASE LEAVES BY.**
   *
   * Every outbound path that carries a Customer's words runs through here, and
   * the consent check is the first statement in it. SC-014 requires that a
   * Customer who refused sends **zero** words anywhere, and the only way to be
   * sure of that is for there to be one door.
   *
   * **The guard belongs on the funnel and not on the entrances, because
   * entrances keep being added.** The app learned this on 2026-08-07: its gate
   * sat on `search`, `chooseArea` called the sender directly, and a Customer
   * could refuse and still have their sentence sent by choosing an area. The
   * screen hid the buttons, so the only thing between a refused Customer and an
   * outbound phrase was a widget branch.
   *
   * Returns `'refused'` when nothing was sent, `null` when something was sent
   * and did not come back usefully, and the parsed body otherwise.
   */
  private async send(
    fn: 'discover' | 'judge-results',
    body: Record<string, unknown>,
  ): Promise<Record<string, unknown> | null | 'refused'> {
    // FIRST STATEMENT. Before anything is put on the wire.
    if (!allowsSearch(readConsent(this.deps.storage))) return 'refused';

    try {
      const response = await this.deps.fetch(
        `${this.deps.backend.url}/functions/v1/${fn}`,
        {
          method: 'POST',
          headers: this.headers(),
          // A POST body. Never a query string — see the note at the top of this
          // file about what a URL is written into.
          body: JSON.stringify(body),
        },
      );
      if (!response.ok) return null;
      const parsed: unknown = await response.json();
      return parsed !== null && typeof parsed === 'object'
        ? (parsed as Record<string, unknown>)
        : null;
    } catch {
      // No `detail`, and nothing logged. A failure quotes the request back often
      // enough that a diagnostic is a way for the phrase to escape — the same
      // defect `discover` shipped as `detail: String(error)` and removed on
      // 2026-08-07. The Customer is told the same thing either way.
      return null;
    }
  }

  /**
   * Records that something happened, and **never what was said**.
   *
   * `Record<string, number>` is the enforcement rather than a convenience. The
   * app carries a runtime guard that drops any string attribute over 100
   * characters, because its emitter takes `Object`; here the phrase cannot be
   * added at a call site without changing this signature, which is a thing a
   * reviewer sees in a diff.
   *
   * Fails silently and is never awaited: a measurement outage must not interrupt
   * a Customer. `keepalive` is what makes the event survive the navigation that
   * `RecommendationAccepted` is emitted during — an ordinary fetch is cancelled
   * when the page unloads, so without it the one event about whether the AI
   * Assistant helped would be the one event that never arrives.
   *
   * `person_id` is deliberately absent. Discovery works signed out, this surface
   * has no session, and the column is nullable for exactly that reason.
   */
  private async emit(
    name: string,
    attributes: Record<string, number>,
  ): Promise<void> {
    try {
      await this.deps.fetch(`${this.deps.backend.url}/rest/v1/analytics_events`, {
        method: 'POST',
        headers: { ...this.headers(), Prefer: 'return=minimal' },
        body: JSON.stringify({ name, attributes }),
        keepalive: true,
      });
    } catch {
      // Silent on purpose.
    }
  }

  /** The kitchens behind a set of Meals. Null when the read failed. */
  private async readKitchens(
    cookIds: string[],
  ): Promise<Map<string, KitchenRow> | null> {
    if (cookIds.length === 0) return new Map();
    const query =
      `select=${KITCHEN_COLUMNS}&cook_id=in.(${cookIds.join(',')})`;
    try {
      const response = await this.deps.fetch(
        `${this.deps.backend.url}/rest/v1/kitchen_profiles?${query}`,
        { headers: this.headers() },
      );
      if (!response.ok) return null;
      const rows = (await response.json()) as KitchenRow[];
      return new Map(rows.map((row) => [row.cook_id, row]));
    } catch {
      return null;
    }
  }

  private headers(): Record<string, string> {
    return {
      'content-type': 'application/json',
      apikey: this.deps.backend.publishableKey,
      Authorization: `Bearer ${this.deps.backend.publishableKey}`,
    };
  }
}
