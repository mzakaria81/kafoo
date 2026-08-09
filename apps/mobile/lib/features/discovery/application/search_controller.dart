import 'dart:async';

import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../settings/data/search_consent_store.dart';
import '../data/discovery_repository.dart';

part 'search_controller.g.dart';

/// What the search half of the discovery screen is showing.
///
/// **The zero state is browse and so is every fallback**, which is why there is
/// no `results: []` default here: [outcome] being null means nothing has been
/// asked, and the screen shows what is on offer. FR-012.
class SearchState {
  /// Creates a state.
  const SearchState({
    this.outcome,
    this.error,
    this.searching = false,
    this.asking = false,
    this.searchIsOff = false,
    this.pendingPhrase,
    this.lastPhrase,
  });

  /// What came back, or null if nothing has been asked yet.
  final SearchOutcome? outcome;

  /// Set when search could not run. Browsing is unaffected.
  final AppError? error;

  /// True while `discover` is answering.
  final bool searching;

  /// True when the Customer must be told their words will leave Kafoo, and
  /// asked — FR-029a.
  ///
  /// **Reachable only from an attempt to search, never from arrival.** Browsing
  /// must not require an answer, so nothing sets this on build.
  final bool asking;

  /// True when the Customer has refused and search is therefore unavailable.
  ///
  /// Unavailable, not degraded — FR-029e. There is no reduced search here that
  /// matches on spelling, because a phrase leaves Kafoo in order to become
  /// searchable at all.
  final bool searchIsOff;

  /// What the Customer asked for while the question was on screen.
  ///
  /// **In memory for the length of one interaction, and never anywhere else.**
  /// It exists so that answering "yes" runs the search they already asked for
  /// rather than making them type it again. FR-029: never recorded.
  final String? pendingPhrase;

  /// The last phrase that was sent, so choosing an area can re-ask the same
  /// question. Memory only, for the same reason as [pendingPhrase].
  final String? lastPhrase;

  /// Whether a search has answered and returned nothing at all.
  ///
  /// Distinct from [SearchOutcome.areaIsEmpty]: an empty result in a named area
  /// is a different sentence from an empty result across the marketplace, and
  /// FR-024 exists because a Customer cannot tell them apart unless Kafoo does.
  bool get foundNothing =>
      !searching && outcome != null && outcome!.results.isEmpty;

  /// Whether to show results rather than what is on offer.
  bool get showsResults =>
      outcome != null && outcome!.results.results.isNotEmpty;

  /// Creates a copy. `_undefined` distinguishes "leave it" from "set it to
  /// null", which matters for every nullable field here.
  SearchState copyWith({
    Object? outcome = _undefined,
    Object? error = _undefined,
    bool? searching,
    bool? asking,
    bool? searchIsOff,
    Object? pendingPhrase = _undefined,
    Object? lastPhrase = _undefined,
  }) =>
      SearchState(
        outcome:
            outcome == _undefined ? this.outcome : outcome as SearchOutcome?,
        error: error == _undefined ? this.error : error as AppError?,
        searching: searching ?? this.searching,
        asking: asking ?? this.asking,
        searchIsOff: searchIsOff ?? this.searchIsOff,
        pendingPhrase: pendingPhrase == _undefined
            ? this.pendingPhrase
            : pendingPhrase as String?,
        lastPhrase:
            lastPhrase == _undefined ? this.lastPhrase : lastPhrase as String?,
      );

  static const _undefined = Object();
}

/// Searching, and the one gate a phrase has to pass to leave the device.
///
/// **[_send] is the only path from a Customer's words to the network, and the
/// consent check is the first thing in it.** SC-014 requires that a Customer
/// who refused sends zero words anywhere, and the only way to be sure of that
/// is for there to be one door.
///
/// **The gate was on [search] until trust-reviewer walked round it on
/// 2026-08-07**, and the way it did so is the reason this comment is worth
/// reading. [chooseArea] is a second entry point — the one FR-024a requires —
/// and it called `_send` directly. A Customer could search, turn the switch
/// off, and still have their sentence sent by choosing an area. The screen hid
/// the buttons, so the only thing standing between a refused Customer and an
/// outbound phrase was a widget branch: exactly the arrangement SC-014 was
/// written to forbid.
///
/// The guard belongs on the FUNNEL and not on the entrances, because entrances
/// keep being added. This class doc named that failure mode and the code did
/// not follow it.
@riverpod
class SearchController extends _$SearchController {
  DiscoveryRepository get _repository => ref.read(discoveryRepositoryProvider);

  @override
  SearchState build() => const SearchState();

  /// Asks for food.
  ///
  /// Nothing leaves the device until [SearchConsent.granted] has been read back
  /// from the device's own storage.
  Future<void> search(String phrase) async {
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) return;

    // The question, at the first attempt to search and not before — FR-029a.
    // Everything else is `_send`'s to refuse.
    final consent = await ref.read(searchConsentControllerProvider.future);
    if (!ref.mounted) return;
    if (consent.needsAsking) {
      state = state.copyWith(asking: true, pendingPhrase: trimmed);
      return;
    }

    await _send(trimmed, null);
  }

  /// Records the Customer's answer and, if they agreed, runs what they asked
  /// for.
  ///
  /// Asked once. [SearchConsentController.answer] writes it to the device, so
  /// the next launch neither asks nor needs to — SC-015.
  Future<void> answerConsent(SearchConsent consent) async {
    if (consent == SearchConsent.unanswered) return;
    await ref.read(searchConsentControllerProvider.notifier).answer(consent);
    if (!ref.mounted) return;

    final pending = state.pendingPhrase;
    state = state.copyWith(
      asking: false,
      pendingPhrase: null,
      searchIsOff: !consent.allowsSearch,
    );
    if (consent.allowsSearch && pending != null) await _send(pending, null);
  }

  /// Whether the device may listen, asking the question if it has not been
  /// asked.
  ///
  /// **The microphone is a second way for words to leave**, so it passes the
  /// same gate as typing rather than a looser one. Tapping it before the
  /// question has been answered IS an attempt to search, so it asks — which is
  /// still once, and still not on arrival.
  Future<bool> requestVoice() async {
    final consent = await ref.read(searchConsentControllerProvider.future);
    if (!ref.mounted) return false;
    if (consent.allowsSearch) return true;
    if (consent.needsAsking) state = state.copyWith(asking: true);
    return false;
  }

  /// Dismisses the question without answering it.
  ///
  /// **Not an answer, and deliberately so.** A Customer who backs out of the
  /// question has not agreed, so nothing is sent and nothing is written — they
  /// will be asked again next time they try to search. Treating a dismissal as
  /// either answer would be deciding for them.
  void dismissConsent() =>
      state = state.copyWith(asking: false, pendingPhrase: null);

  /// Narrows to an area the Customer chose from the ones Kafoo offered.
  ///
  /// FR-024a: widening is the Customer's action, never Kafoo's. This exists so
  /// that the offer made when their own area was empty is something they can act
  /// on — without it, naming the other areas would be decoration.
  Future<void> chooseArea(String area) async {
    final phrase = state.lastPhrase;
    if (phrase == null) return;
    await _send(phrase, area);
  }

  /// Whether the phrase may leave, and the only place that question is asked.
  ///
  /// Every outbound path runs through [_send], and [_send] runs through this.
  Future<bool> _mayLeave() async {
    final consent = await ref.read(searchConsentControllerProvider.future);
    if (!ref.mounted) return false;
    if (consent.allowsSearch) return true;
    state = state.copyWith(
      searchIsOff: !consent.needsAsking,
      searching: false,
    );
    return false;
  }

  /// Clears the search and returns to what is on offer.
  void clear() => state = const SearchState();

  Future<void> _send(String phrase, String? area) async {
    // THE GATE. First statement, before anything is put on the wire and before
    // the state says a search is running.
    if (!await _mayLeave()) return;

    state = state.copyWith(
      searching: true,
      error: null,
      searchIsOff: false,
      lastPhrase: phrase,
    );

    final result = await _repository.search(phrase: phrase, area: area);
    if (!ref.mounted) return;

    switch (result) {
      case Success(value: final outcome):
        state = state.copyWith(outcome: outcome, error: null, searching: false);

        // SearchPerformed carries WHAT KAFOO CHOSE, NEVER WHAT THE CUSTOMER
        // SAID. FR-029 and SC-011: the most natural shape for this event —
        // `{phrase: ..., result_count: ...}` — is the violation.
        // `search_performed_test` asserts the attribute SET rather than the
        // count, because a phrase added later would still pass a test that only
        // checked the number.
        //
        // Every value below comes from a fixed vocabulary or is a boolean. The
        // cuisine and category are the domain enums, off the first result —
        // what Kafoo SERVED, which is not the same as what was asked for, and
        // is honest only when read beside SearchFailed. `none` when nothing came
        // back, so the attribute set is the same shape on every search.
        //
        // `area_narrowed` is a BOOLEAN AND NEVER THE AREA. The area is a phrase
        // the Customer said, pulled out of their own sentence.
        unawaited(
          emitEvent(
            EventNames.searchPerformed,
            attributes: {
              'result_count': outcome.results.results.length,
              'top_cuisine': _topCuisine(outcome),
              'top_category': _topCategory(outcome),
              'area_narrowed': outcome.area != null,
            },
          ),
        );

        // THE JUDGEMENT IS NOT AWAITED, AND THE `unawaited` IS THE REQUIREMENT
        // RATHER THAN A LINT FIX. FR-011 and SC-007: results are already in
        // `state` on the line above, so a judgement that hangs forever costs a
        // sentence and never a result. `search_controller_test` proves it by
        // handing over a judgement that never completes.
        unawaited(_judge(phrase, outcome));

      case Failure(error: final err):
        // Search failing must not take browsing with it. The screen keeps
        // showing what is on offer underneath this message.
        state = state.copyWith(error: err, searching: false, outcome: null);
    }
  }

  /// The vocabulary word for a search with nothing in it.
  ///
  /// A literal rather than an omitted key, so every `SearchPerformed` carries
  /// the same four attributes and a query never has to ask whether a field is
  /// missing or absent. It cannot collide with a real value — the enums have an
  /// `other`, and neither has a `none`.
  static const String _nothingServed = 'none';

  static String _topCuisine(SearchOutcome outcome) =>
      outcome.results.results.isEmpty
          ? _nothingServed
          : outcome.results.results.first.item.meal.cuisine.wireName;

  static String _topCategory(SearchOutcome outcome) =>
      outcome.results.results.isEmpty
          ? _nothingServed
          : outcome.results.results.first.item.meal.category.wireName;

  Future<void> _judge(String phrase, SearchOutcome outcome) async {
    if (outcome.results.results.isEmpty) return;

    // THE JUDGEMENT IS A SECOND WAY FOR THE WORDS TO LEAVE, so it passes the
    // same gate rather than inheriting the one `_send` passed a moment ago.
    //
    // Consent was checked before the search; this call goes out afterwards,
    // one network round-trip later, carrying the same phrase again. A Customer
    // who reaches Settings and revokes in that window had their words sent a
    // second time under a permission they had just withdrawn. The window is
    // narrow today — trust-reviewer called it too narrow to be a finding — and
    // it stops being narrow the day somebody adds a retry, a queue, or a
    // longer timeout. `_send` re-reads consent and this did not, and an
    // asymmetry between two outbound paths is how the second one gets
    // forgotten.
    final consent = await ref.read(searchConsentControllerProvider.future);
    if (!ref.mounted || !consent.allowsSearch) return;
    final judgement =
        await _repository.judge(phrase: phrase, results: outcome.results);
    if (!ref.mounted || judgement == null) return;
    // Only if these are still the results on screen. A judgement arriving after
    // the next search would be an opinion about food nobody is looking at.
    if (!identical(state.outcome, outcome)) return;
    state = state.copyWith(
      outcome: SearchOutcome(
        results: outcome.results.withJudgement(judgement),
        excludedId: outcome.excludedId,
        notUnderstood: outcome.notUnderstood,
        area: outcome.area,
      ),
    );

    // SearchFailed BELONGS HERE AND NOT WHERE THE DATABASE RETURNED NOTHING.
    // Retrieval returning rows is not the same as those rows answering the
    // question — conflating the two is exactly what a score threshold tried
    // and failed to do, and the event would then be measuring the wrong fact.
    //
    // It carries NOTHING. Not the phrase, which FR-029 forbids, and not a
    // count either: the number of results that did not answer is not something
    // anybody can act on. `search_failed_test` asserts the attribute set is
    // EMPTY rather than asserting a size, because a test that checks only a
    // count stays green the day somebody adds a phrase beside it.
    if (judgement is NothingAnswers) {
      unawaited(emitEvent(EventNames.searchFailed));
    }
  }
}
