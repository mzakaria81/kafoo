'use client';

import { useEffect, useRef, useState } from 'react';

import { fill, messages } from '@/lib/messages';
import type { SearchConsent } from '@/lib/consent';
import { readConsent, writeConsent } from '@/lib/consent';
import type { Backend, Judgement, SearchOutcome } from '@/lib/discovery';
import { Discovery, areaIsEmpty } from '@/lib/discovery';
import type { DiscoveredMeal } from '@/lib/supabase';
import { MealCard } from './meal-card';

/**
 * Asking for food, on the surface that needs no install.
 *
 * **ONE INPUT, CARRYING ALL THREE THINGS.** A Customer says
 * `عايز حاجة من غير لحمة في المهندسين` — what they want, what they do not want,
 * and where — in one sentence. Three controls to collect that would be a form at
 * the exact point Principle IV forbids one, so the phrase, the exclusion and the
 * area are read out of the sentence in `discover` and never collected
 * separately. Identical to the app's `SearchScreen`, because it is the same
 * function doing the reading.
 *
 * **THE CONSENT QUESTION AND THIS PANEL ARE ONE PIECE OF WORK, NOT TWO.** A
 * search box that can be submitted before the question has been answered is how
 * "zero words leave the browser" quietly stops being true. The gate lives in
 * `Discovery` — the only path from these words to the network — and this panel
 * renders the question when the answer is still owed. Browsing never asks: the
 * question arrives at the first attempt to search and never on arrival
 * (FR-029a).
 *
 * **The zero state is browse and so is every fallback** — before a search, when
 * nothing matched, and while search is unavailable (FR-012). `children` is the
 * server-rendered browse list, and this panel decides when it shows.
 */
export function SearchPanel({
  backend,
  areas,
  browseFailed,
  browseIsEmpty,
  children,
}: {
  backend: Backend;
  /** The areas that have food right now, from what the server already read. */
  areas: string[];
  /** The browse read failed. Not the same fact as the marketplace being empty. */
  browseFailed: boolean;
  browseIsEmpty: boolean;
  children: React.ReactNode;
}) {
  const t = messages();

  const [phrase, setPhrase] = useState('');
  const [consent, setConsent] = useState<SearchConsent | null>(null);
  const [asking, setAsking] = useState(false);
  const [searching, setSearching] = useState(false);
  const [failed, setFailed] = useState(false);
  const [outcome, setOutcome] = useState<SearchOutcome | null>(null);
  const [judgement, setJudgement] = useState<Judgement | null>(null);

  /**
   * What the Customer asked for while the question was on screen.
   *
   * **In memory for the length of one interaction, and never anywhere else.** It
   * exists so that answering "yes" runs the search they already asked for rather
   * than making them type it again, and so that choosing an area can re-ask the
   * same question. FR-029: never recorded.
   */
  const lastPhrase = useRef<string | null>(null);

  /** Which results are on screen, so a late judgement about older ones is dropped. */
  const showing = useRef<SearchOutcome | null>(null);

  const discovery = useRef<Discovery | null>(null);

  /** Focus targets. Unmounting a focused element without moving focus loses the
   *  Customer's place — measured three times in one interaction. */
  const consentRef = useRef<HTMLElement | null>(null);
  const resultsRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    // `localStorage` does not exist while the page is server-rendered, so the
    // answer is read here rather than at module load. Until it arrives the input
    // renders as normal — the same as the app, which reads its own store
    // asynchronously and shows the field meanwhile.
    setConsent(readConsent(window.localStorage));
    discovery.current = new Discovery({
      backend,
      storage: window.localStorage,
      fetch: window.fetch.bind(window),
    });
  }, [backend]);

  // When results replace the browse list, move focus to them. Answering the
  // consent question unmounts the button that was focused, and without this the
  // Customer lands at the top of the document while the results they asked for
  // render silently below.
  useEffect(() => {
    if (outcome !== null && !searching) resultsRef.current?.focus();
  }, [outcome, searching]);

  // SC-015: after ANY answer the question appears zero times. `asking` alone is
  // not enough — the note under the question tells the Customer they can change
  // the answer in Settings, and following that instruction and coming back must
  // not land them on the question they just answered.
  const questionIsOwed = asking && consent === 'unanswered';
  const searchIsOff = consent === 'refused';

  async function submit(chosenArea: string | null) {
    const asked = chosenArea === null ? phrase.trim() : (lastPhrase.current ?? '');
    if (asked.length === 0) return;

    // The question, at the first attempt to search and not before — FR-029a.
    // Everything else is the gate's to refuse.
    if (consent === 'unanswered') {
      lastPhrase.current = asked;
      setAsking(true);
      return;
    }

    await run(asked, chosenArea);
  }

  /**
   * The search itself, with no consent branch in it.
   *
   * **Separate from [submit] because answering the question has to be able to
   * run the search the Customer already asked for**, and at that moment `consent`
   * still reads `unanswered` — a state setter does not change the value this
   * render closed over. Routing the answer back through [submit] set the
   * question flag a second time and quietly did nothing, which is a Customer
   * saying yes and watching nothing happen.
   *
   * Nothing is lost by skipping the branch here: `Discovery` re-reads the
   * browser's own store on every outbound call, and `writeConsent` has already
   * landed. The check that matters is the one in the gate, not this one.
   */
  async function run(asked: string, chosenArea: string | null) {
    lastPhrase.current = asked;
    setSearching(true);
    setFailed(false);
    setJudgement(null);

    const response = await discovery.current!.search(asked, chosenArea);

    setSearching(false);

    if (response.kind === 'refused') return;
    if (response.kind === 'unavailable') {
      // Search failing must not take browsing with it. The list underneath keeps
      // showing what is on offer beneath this message.
      setFailed(true);
      setOutcome(null);
      showing.current = null;
      return;
    }

    setOutcome(response.outcome);
    showing.current = response.outcome;

    // THE JUDGEMENT IS NOT AWAITED, AND THAT IS THE REQUIREMENT RATHER THAN A
    // STYLE. FR-011 and SC-007: the results are on screen by the line above, so
    // a judgement that hangs forever costs a sentence and never a result.
    void (async () => {
      const verdict = await discovery.current!.judge(asked, response.outcome.results);
      // Only if these are still the results on screen. A judgement arriving
      // after the next search would be an opinion about food nobody is looking
      // at.
      if (verdict && showing.current === response.outcome) setJudgement(verdict);
    })();
  }

  function answer(given: SearchConsent) {
    // Written to the browser BEFORE anything else. `Discovery` re-reads the
    // store on every outbound call, so the store is what decides — not this
    // component's idea of the answer.
    writeConsent(window.localStorage, given);
    setConsent(given);
    setAsking(false);

    // Answering yes runs what they already asked for, rather than making them
    // type it again. Answering no sends nothing — the gate would refuse it
    // anyway, and this is simply not asking.
    //
    // Backing out without answering is neither: `asking` is cleared by the
    // question disappearing, nothing is written, and they are asked again next
    // time they try to search. Treating a dismissal as either answer would be
    // deciding for them.
    const pending = lastPhrase.current;
    if (given === 'granted' && pending !== null) void run(pending, null);
  }

  return (
    <>
      {/* Refused. UNAVAILABLE, NOT DEGRADED — FR-029e. There is no reduced
          search here that matches on spelling; a phrase leaves Kafoo in order to
          become searchable at all, so there is no halfway state to fall back
          to. Nothing to type into, and a sentence saying why. */}
      {/* `consent !== null` means the effect above has run, which means
          JavaScript is working. Without it this box could not search, and a box
          that cannot search is worse than no box: browsing is server-rendered
          and keeps working either way (FR-012). */}
      {consent !== null && !searchIsOff && !questionIsOwed ? (
        <form
          className="search"
          onSubmit={(event) => {
            event.preventDefault();
            void submit(null);
          }}
        >
          <label htmlFor="phrase">{t.searchLabel}</label>
          <div className="search-row">
            <input
              id="phrase"
              type="search"
              // NO `name`, DELIBERATELY. A named control in a form with no
              // `action` is serialised into the current URL on a plain submit —
              // and a URL is written to Cloudflare's request log, to the
              // browser's history, and to `Referer` on every image on the page.
              // The phrase leaves in a POST body or it does not leave. FR-029,
              // SC-011, and the note at the top of lib/discovery.ts.
              value={phrase}
              placeholder={t.searchHint}
              autoComplete="off"
              onChange={(event) => setPhrase(event.target.value)}
            />
            <button type="submit">{t.searchAction}</button>
          </div>
        </form>
      ) : null}

      {questionIsOwed ? (
        <ConsentQuestion onAnswer={answer} innerRef={consentRef} />
      ) : null}

      {/* ONE STATUS REGION, ALWAYS IN THE DOM, TEXT SWAPPED IN AND OUT.
          Both halves of that matter and both were wrong. It has to exist before
          its text changes: a live region inserted in the same mutation as its
          content is not reliably announced — Chromium with NVDA usually does,
          VoiceOver and JAWS frequently do not — and all three regions here were
          created already populated.
          And it has to cover every outcome. Six of nine sentences had no live
          region at all, so a Customer using a screen reader pressed Search after
          a failure, an empty result or a refusal and heard nothing whatsoever.
          The result count is here rather than only in the cards because when
          results arrive the browse list is REMOVED from the page, and without a
          number there is no way to tell the food under your cursor is the food
          you asked for. */}
      <div className="note" role="status" aria-live="polite">
        {statusLine(t, { searchIsOff, searching, failed, outcome, judgement })}
      </div>

      {/* FR-024 and FR-024a. An area with nothing in it is its own sentence, and
          widening it is the CUSTOMER'S action — so what is on offer elsewhere is
          deliberately NOT shown underneath. Offering the other areas without
          showing their food is the whole distinction. */}
      {outcome && areaIsEmpty(outcome) ? (
        <EmptyArea
          areas={areas}
          browseFailed={browseFailed}
          browseIsEmpty={browseIsEmpty}
          onChoose={(area) => void submit(area)}
        />
      ) : (
        <div ref={resultsRef} tabIndex={-1}>
        <Results
          outcome={outcome}
          judgement={judgement}
          backend={backend}
          onOpenAlternative={(rank) => discovery.current?.recommendationAccepted(rank)}
        />
        </div>
      )}

      {/* Browse: the zero state and every fallback. Hidden only while results
          are on screen and while an empty area is asking the Customer to
          choose. */}
      {showBrowse({ outcome, searching }) ? children : null}
    </>
  );
}

/**
 * What the status region says, for every outcome, in one place.
 *
 * Returning `''` rather than rendering nothing is deliberate: the element stays
 * in the DOM so a screen reader has already registered it as live before the
 * text arrives.
 */
function statusLine(
  t: ReturnType<typeof messages>,
  state: {
    searchIsOff: boolean;
    searching: boolean;
    failed: boolean;
    outcome: SearchOutcome | null;
    judgement: Judgement | null;
  },
): string {
  if (state.searchIsOff) return t.searchIsOff;
  if (state.searching) return t.searchRunning;
  if (state.failed) return t.searchUnavailable;
  const outcome = state.outcome;
  if (outcome === null) return '';
  if (areaIsEmpty(outcome)) return fill(t.searchAreaEmpty, { area: outcome.area! });
  if (outcome.results.length === 0) return t.searchFoundNothing;
  // The judgement arrives a round trip after the count, and replacing the count
  // with it is the right announcement: "nothing here answers you" is what the
  // Customer needs to hear about the list they are already looking at.
  const judgement = state.judgement;
  if (judgement !== null && judgement.answers === false) {
    return judgement.alternatives.length === 0
      ? t.searchJudgementNothingAnswers
      : namedAlternatives(judgement.alternatives.map((meal) => meal.title));
  }
  return fill(t.searchResultCount, { count: String(outcome.results.length) });
}

function showBrowse({
  outcome,
  searching,
}: {
  outcome: SearchOutcome | null;
  searching: boolean;
}): boolean {
  // **THE QUESTION IS NOT ON THIS LIST, AND THAT IS FR-029a.** Browsing must not
  // require an answer, so the food stays on the page underneath the question. On
  // a full screen in the app the question replaces the content and a Customer
  // backs out of it; here there is nothing to back out of, so hiding the list
  // would make the question a wall between a Customer and food they were already
  // looking at — an answer extracted by holding something.
  if (searching) return false;
  if (outcome === null) return true;
  // An empty area shows the areas that are not empty and nothing from them.
  // Widening is the Customer's action — FR-024a — and showing other areas' food
  // underneath would be Kafoo doing it for them.
  if (areaIsEmpty(outcome)) return false;
  // Nothing matched: back to what is on offer, which is search's zero state
  // and every one of its fallbacks (FR-012).
  return outcome.results.length === 0;
}

/**
 * FR-029a. Said before anything is sent, in plain terms, with refusing as an
 * answer of equal weight rather than a way out of a dialog.
 */
function ConsentQuestion({
  onAnswer,
  innerRef,
}: {
  onAnswer: (given: SearchConsent) => void;
  innerRef: React.RefObject<HTMLElement | null>;
}) {
  const t = messages();
  // A BLOCKING DECISION TAKES FOCUS; A LIVE REGION IS THE WRONG TOOL FOR IT.
  // Pressing Search unmounts the form that held the focused button, so focus
  // fell to the top of the document — measured `activeElement === BODY` — and
  // the Customer had to Tab past the header to reach the question they had just
  // triggered.
  useEffect(() => innerRef.current?.focus(), [innerRef]);
  return (
    <section className="consent" ref={innerRef} tabIndex={-1}>
      <p>{t.searchConsentQuestion}</p>
      {/* BOTH THE SAME BUTTON, AND THAT IS THE RULE RATHER THAN THE STYLE. The
          app shipped agreeing as a high-emphasis widget and refusing as a
          medium-emphasis one; on a consent choice that is the dark pattern the
          trust rules name as product-fatal. Neither answer is the one Kafoo
          wants. */}
      <button type="button" className="choice" onClick={() => onAnswer('granted')}>
        {t.searchConsentAgree}
      </button>
      <button type="button" className="choice" onClick={() => onAnswer('refused')}>
        {t.searchConsentRefuse}
      </button>
      <p className="fine">{t.searchConsentNote}</p>
    </section>
  );
}

function Results({
  outcome,
  judgement,
  backend,
  onOpenAlternative,
}: {
  outcome: SearchOutcome | null;
  judgement: Judgement | null;
  backend: Backend;
  onOpenAlternative: (rank: number) => void;
}) {
  const t = messages();
  if (outcome === null) return null;

  // `searchFoundNothing` is not repeated here — the status region above says it,
  // visibly and out loud. Printing it twice would show it twice.
  if (outcome.results.length === 0) {
    return outcome.notUnderstood ? (
      <p className="note danger" role="alert">
        {t.searchExclusionNotUnderstood}
      </p>
    ) : null;
  }

  const nothingAnswers = judgement !== null && judgement.answers === false;
  const alternatives = nothingAnswers ? judgement.alternatives : [];

  return (
    <>
      {/* WHAT WAS FILTERED ON, AND NEVER THAT A MEAL IS SAFE. A Meal's allergens
          are frequently an AI estimate, so the strongest true statement is what
          Kafoo removed and where that information came from. "This Meal is safe"
          is a claim Kafoo cannot make about food it did not cook, and a Customer
          with an allergy is exactly the person who would act on it. */}
      {outcome.excluded !== null ? (
        <p className="note">
          {fill(t.searchFilteredOn, { food: exclusionName(outcome.excluded) })}
        </p>
      ) : null}

      {/* A negation Kafoo recognised without recognising the food. Saying
          nothing here is the failure the whole exclusion design exists to
          prevent: the results look exactly like results for a request with no
          exclusion in it. */}
      {/* `role="alert"` and not the polite region above, deliberately: this one
          should interrupt. It is the sentence saying Kafoo could not identify
          what a Customer asked to leave out, and it rendered as a plain <p> — so
          a Customer who asked for food without peanuts got a list that sounded
          exactly like a list which had honoured the exclusion.
          The red stays, and it is not the only carrier: the words say the whole
          thing, so nothing here depends on seeing a colour. */}
      {outcome.notUnderstood ? (
        <p className="note danger" role="alert">
          {t.searchExclusionNotUnderstood}
        </p>
      ) : null}

      {outcome.area !== null ? (
        <p className="note">{fill(t.searchNarrowedToArea, { area: outcome.area })}</p>
      ) : null}

      {/* NOTHING HERE ANSWERS — SAID ABOVE RESULTS THAT DO NOT MOVE.
          The list underneath is exactly what the database returned, in the order
          it returned it. The judgement may not reorder, filter, add to or remove
          a Meal; a panel that showed only the named alternatives would be
          filtering wearing a layout. It says something ABOUT a set the Customer
          can still see all of.

          The guarantee that a named Meal is genuinely on offer lives in
          `Discovery.judge`, which matches the ids the function returned against
          the Meals that were actually on screen and drops anything else. The AI
          Assistant supplies no word of this sentence: the titles are the Cook's
          and the rest is Kafoo's own copy. */}
      {/* The sentence itself is in the status region above — one place, said
          once. What stays here is the rule it enforces: the list below is
          exactly what the database returned, in the order it returned it, and
          the judgement may not reorder, filter, add to or remove a Meal. */}

      {outcome.results.map((item, index) => (
        <MealCard
          key={item.meal.id}
          item={item}
          backend={backend}
          source="search"
          // `MealOpened` fires from inside the card for every open.
          // `RecommendationAccepted` is the narrower question — did the sentence
          // "nothing here answers you, but there is this" actually help — and
          // only a Meal the AI Assistant named answers it.
          onOpen={
            alternatives.some((meal) => meal.id === item.meal.id)
              ? () => onOpenAlternative(index + 1)
              : undefined
          }
        />
      ))}
    </>
  );
}

/**
 * FR-024, FR-024a, FR-024b, FR-024c.
 *
 * Names the areas that do have food, in the Cooks' own words, and makes the
 * Customer choose. **No distance, no ordering by proximity, and no suggestion
 * that anyone there delivers** — Kafoo holds no location for any Customer, no
 * notion of where an area is, and a Cook's delivery terms are words rather than
 * a radius.
 */
function EmptyArea({
  areas,
  browseFailed,
  browseIsEmpty,
  onChoose,
}: {
  areas: string[];
  browseFailed: boolean;
  browseIsEmpty: boolean;
  onChoose: (area: string) => void;
}) {
  const t = messages();

  // WHY THIS BRANCHES ON HOW THE BROWSE READ WENT AND NOT ON `areas.length`.
  // A failed read produces no areas and an empty marketplace produces no areas,
  // and only one of them means "no Cook anywhere has anything" — a thing Kafoo
  // would otherwise be saying without knowing it, immediately after telling the
  // Customer their own area is empty.
  const insteadOfAreas = browseFailed
    ? t.searchAreasUnknown
    : browseIsEmpty
      ? t.browseNothingOnOffer
      : // Food on offer, and not one Cook wrote an area. Kafoo cannot name the
        // areas that have food, and saying the marketplace is empty would be the
        // same untruth by a different route.
        areas.length === 0
        ? t.searchAreasUnknown
        : null;

  return (
    <section className="empty-area">
      {/* `searchAreaEmpty` is in the status region above, said once. */}
      {insteadOfAreas !== null ? (
        <p>{insteadOfAreas}</p>
      ) : (
        <>
          <p>{t.searchAreaChoose}</p>
          {areas.map((other) => (
            <button
              key={other}
              type="button"
              className="choice"
              onClick={() => onChoose(other)}
            >
              {other}
            </button>
          ))}
        </>
      )}
    </section>
  );
}

/** The display name for an exclusion id, from the messages file. */
function exclusionName(id: string): string {
  const t = messages();
  const key = `exclusion${id.charAt(0).toUpperCase()}${id.slice(1)}`;
  // An id this surface has no word for falls back to "that", exactly as the
  // app's `other` arm does. A missing word must not print a bare identifier at a
  // Customer who may be asking about an allergy.
  return (t as Record<string, string>)[key] ?? t.exclusionOther;
}

/**
 * The sentence naming Meals, with the grammar of the list left to the messages
 * file.
 *
 * **A separator hardcoded here would ship an Arabic comma to English readers** —
 * the app measured exactly that: "Koshari، Molokhia، Fattah", with no "and"
 * anywhere. Joining is grammar, and grammar belongs where a translator can reach
 * it: Arabic repeats و before every item, English uses one `and` before the
 * last, and no single separator serves both. So there is a key per count.
 *
 * **Each title is isolated between U+2068 and U+2069.** Two Latin-script titles
 * side by side fuse into one left-to-right island inside a right-to-left
 * sentence, and the island's internal order runs against the sentence — measured
 * in the app, "Pizza، Burger" put Burger to the RIGHT of Pizza, so the Meal named
 * first was read second. Isolation fixes it and changes nothing for Arabic
 * titles.
 */
function namedAlternatives(titles: string[]): string {
  const t = messages();
  // At most three arrive — `judge-results` caps them.
  const [first, second, third] = titles
    .slice(0, 3)
    .map((title) => `⁨${title}⁩`);
  if (titles.length === 1) return fill(t.searchJudgementAlternativesOne, { first });
  if (titles.length === 2) {
    return fill(t.searchJudgementAlternativesTwo, { first, second });
  }
  return fill(t.searchJudgementAlternativesThree, { first, second, third });
}
