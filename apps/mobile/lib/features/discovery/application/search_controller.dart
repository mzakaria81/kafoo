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
/// **[search] is the only path from a Customer's words to the network, and the
/// consent check is the first thing in it.** That is deliberate and structural:
/// SC-014 requires that a Customer who refused sends zero words anywhere, and
/// the only way to be sure of that is for there to be one door. A check placed
/// in the screen instead would be one branch among several, and the second
/// entry point somebody adds later — a suggestion chip, a deep link, a retry —
/// would walk straight past it.
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

    final consent = await ref.read(searchConsentControllerProvider.future);
    if (!ref.mounted) return;

    switch (consent) {
      case SearchConsent.unanswered:
        // The question, at the first attempt to search and not before — FR-029a.
        state = state.copyWith(asking: true, pendingPhrase: trimmed);
      case SearchConsent.refused:
        state = state.copyWith(
          searchIsOff: true,
          outcome: null,
          error: null,
          searching: false,
        );
      case SearchConsent.granted:
        await _send(trimmed, null);
    }
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

  /// Clears the search and returns to what is on offer.
  void clear() => state = const SearchState();

  Future<void> _send(String phrase, String? area) async {
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

        // SearchPerformed carries a COUNT AND NOTHING ELSE. FR-029 and SC-011:
        // what a Customer searched for is not recorded, and the most natural
        // shape for this event — `{phrase: ..., result_count: ...}` — is the
        // violation. `search_performed_test` asserts the attribute set rather
        // than the count, because a phrase added later would still pass a test
        // that only checked the number.
        unawaited(
          emitEvent(
            EventNames.searchPerformed,
            attributes: {'result_count': outcome.results.results.length},
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

  Future<void> _judge(String phrase, SearchOutcome outcome) async {
    if (outcome.results.results.isEmpty) return;
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
  }
}
