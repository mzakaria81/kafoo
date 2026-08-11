import 'dart:async';

// `SearchController` is a Material type as well as ours. Hidden rather than prefixed: nothing on
// this screen uses Material's, and an alias would put a prefix on every reference to our own.
import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/application/voice_input.dart';
import '../../conversation/presentation/voice_button.dart';
import '../../settings/data/search_consent_store.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/browse_controller.dart';
import '../application/search_controller.dart';
import '../data/discovery_repository.dart';
import 'browse_screen.dart';

/// Asking for food, and everything that happens when a Customer does.
///
/// **ONE INPUT, CARRYING ALL THREE THINGS.** A Customer says
/// `عايز حاجة من غير لحمة في المهندسين` — what they want, what they do not want,
/// and where — in one sentence. Three controls to collect that would be a form
/// at the exact point Principle IV forbids one, so the phrase, the exclusion and
/// the area are read out of the sentence in `discover` and never collected
/// separately here.
///
/// **THE CONSENT QUESTION AND THIS SCREEN ARE ONE PIECE OF WORK, NOT TWO.** A
/// search box that can be submitted before the question has been answered is how
/// "zero words leave the device" quietly stops being true, so the gate lives in
/// [SearchController.search] — the only path from these words to the network —
/// and this screen renders the question when the controller says it is time.
/// Browsing never asks: the question arrives at the first attempt to search and
/// never on arrival (FR-029a).
///
/// **The zero state is browse and so is every fallback** — before a search, when
/// nothing matched, and while search is unavailable (FR-012).
class SearchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SearchScreen({this.onOpen, this.entry, this.voiceInput, super.key});

  /// Called when a Customer opens a Meal.
  final void Function(DiscoveredMeal item)? onOpen;

  /// A way in for someone with no account, shown over what is on offer.
  final Widget? entry;

  /// Injected in tests. Speech is unavailable in a widget test otherwise, which
  /// is also the likeliest real-world outcome — research.md §3.
  final VoiceInput? voiceInput;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _phrase = TextEditingController();
  late final VoiceInput _voice = widget.voiceInput ?? VoiceInput();
  bool _voiceAvailable = false;
  bool _voiceNeedsArabic = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initVoice());
  }

  @override
  void dispose() {
    unawaited(_voice.cancel());
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _initVoice() async {
    final available = await _voice.initialize();
    if (!mounted) return;
    setState(() {
      _voiceAvailable = available;
      // A working recogniser with no Arabic is the one unavailable case a person
      // can fix themselves, so it gets its own sentence rather than being folded
      // into "voice does not work on this phone" — which is true, unactionable,
      // and what the founder was shown after granting the microphone permission.
      _voiceNeedsArabic = !available && _voice.engineAvailable;
    });
  }

  Future<void> _submit() async {
    // The text is read here and handed straight to the controller. It is never
    // put anywhere else — not a field, not a log, not an event. FR-029.
    await ref.read(searchControllerProvider.notifier).search(_phrase.text);
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    // The same gate as typing. The microphone is a second way for words to
    // leave, so it does not get a looser one.
    final allowed =
        await ref.read(searchControllerProvider.notifier).requestVoice();
    if (!mounted || !allowed) return;

    setState(() => _listening = true);
    // The transcript lands in the field a Customer would have typed into, so
    // they see it before it is sent — the same rule the Cook's conversation
    // follows.
    await _voice.listen(
      onTranscript: (transcript, isFinal) {
        if (!mounted) return;
        setState(() {
          _phrase.text = transcript;
          if (isFinal) _listening = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(searchControllerProvider);

    // Read from the device rather than waiting for an attempt to search. A
    // Customer who has already refused arrives to a screen with NOTHING TO TYPE
    // INTO and a sentence saying why — FR-029e says Kafoo states plainly that
    // searching is off and browsing still works, and stating it only after they
    // have tried and failed is stating it late.
    final answer = switch (ref.watch(searchConsentControllerProvider)) {
      AsyncData(value: final consent) => consent,
      _ => null,
    };
    final searchIsOff = state.searchIsOff || answer == SearchConsent.refused;

    // SC-015: after ANY answer the question appears zero times. `state.asking`
    // alone was not enough — `searchConsentNote` tells the Customer they can
    // change the answer in Settings, the Settings icon is in this screen's own
    // bar, and following that instruction brought them back to the question
    // they had just answered, with a live "No" button sitting on top of a
    // granted answer. Found by trust-reviewer on 2026-08-07 by doing exactly
    // what the copy says to do.
    final asking = state.asking && (answer == null || answer.needsAsking);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseTitle),
        actions: [
          // An icon rather than a text button, deliberately. A text action in an
          // `AppBar` takes its full intrinsic width and squeezed this title to
          // zero at 200% text scale — see the note on `BrowseScreen.entry`.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!searchIsOff) _input(l10n),
            Expanded(
              child: _content(
                l10n,
                state,
                searchIsOff: searchIsOff,
                asking: asking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(AppLocalizations l10n) => Padding(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phrase,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: l10n.searchLabel,
                hintText: l10n.searchHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.searchAction,
                  onPressed: () => unawaited(_submit()),
                ),
              ),
            ),
            const SizedBox(height: KafooSpacing.sm),
            if (_voiceAvailable)
              VoiceButton(
                listening: _listening,
                label: l10n.searchVoiceHint,
                onPressed: () => unawaited(_toggleListening()),
              )
            else
              // FR-008: typing is never the degraded path. Recognition missing
              // is the likeliest real outcome on an Egyptian handset, so it is
              // said plainly rather than left as a dead microphone.
              // Announced, not merely rendered. A message written to be more
              // actionable than the one it replaced reaches nobody who cannot
              // see it unless it is a live region — the same treatment every
              // other status sentence on this screen already gets.
              Semantics(
                liveRegion: true,
                child: Text(
                  _voiceNeedsArabic
                      ? l10n.searchVoiceNeedsArabic
                      : l10n.searchVoiceUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      );

  Widget _content(
    AppLocalizations l10n,
    SearchState state, {
    required bool searchIsOff,
    required bool asking,
  }) {
    // The question. Reached only from an attempt to search — FR-029a.
    if (asking) return _consentQuestion(l10n);

    // Refused. UNAVAILABLE, NOT DEGRADED — FR-029e. There is no reduced search
    // here that matches on spelling; a phrase leaves Kafoo in order to become
    // searchable at all, so there is no halfway state to fall back to.
    if (searchIsOff) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _note(l10n.searchIsOff, KafooColors.onSurface),
          Expanded(child: _browse()),
        ],
      );
    }

    if (state.searching) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.searchRunning),
      );
    }

    if (state.error != null) {
      // Search failing must not take browsing with it.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _note(l10n.searchUnavailable, KafooColors.danger),
          Expanded(child: _browse()),
        ],
      );
    }

    final outcome = state.outcome;
    if (outcome == null) return _browse();

    // FR-024 and FR-024a. An area with nothing in it is its own sentence, and
    // widening it is the CUSTOMER'S action — so what is on offer elsewhere is
    // deliberately NOT shown underneath. Offering the other areas without
    // showing their food is the whole distinction.
    if (outcome.areaIsEmpty) return _emptyArea(l10n, outcome.area!);

    if (outcome.results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _note(l10n.searchFoundNothing, KafooColors.onSurface),
          if (outcome.notUnderstood)
            _note(l10n.searchExclusionNotUnderstood, KafooColors.danger),
          Expanded(child: _browse()),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WHAT WAS FILTERED ON, AND NEVER THAT A MEAL IS SAFE. `meals.allergens`
          // is frequently an AI estimate carrying `nutrition_source`, so the
          // strongest true statement is what Kafoo removed and where that
          // information came from. "This Meal is safe" is a claim Kafoo cannot
          // make about food it did not cook, and a Customer with an allergy is
          // exactly the person who would act on it.
          if (outcome.excludedId case final excluded?) ...[
            _note(
              l10n.searchFilteredOn(l10n.exclusionName(excluded)),
              KafooColors.onSurface,
            ),
            const SizedBox(height: KafooSpacing.sm),
          ],
          // A negation Kafoo recognised without recognising the food. Saying
          // nothing here is the failure the whole exclusion design exists to
          // prevent: the results look exactly like results for a request with no
          // exclusion in it.
          if (outcome.notUnderstood) ...[
            _note(l10n.searchExclusionNotUnderstood, KafooColors.danger),
            const SizedBox(height: KafooSpacing.sm),
          ],
          if (outcome.area case final area?) ...[
            _note(l10n.searchNarrowedToArea(area), KafooColors.onSurface),
            const SizedBox(height: KafooSpacing.sm),
          ],
          // NOTHING HERE ANSWERS — SAID ABOVE RESULTS THAT DO NOT MOVE.
          //
          // The list underneath is exactly what the database returned, in the
          // order it returned it. That is not a rendering convenience: the
          // judgement may not reorder, filter, add to or remove a Meal, and a
          // screen that showed only the named alternatives would be filtering
          // wearing a layout. It says something ABOUT a set the Customer can
          // still see all of.
          //
          // THE GUARANTEE THAT A NAMED MEAL IS ON OFFER LIVES IN THE
          // REPOSITORY, NOT HERE. This comment used to say the screen looks up
          // each Meal by id; it does not — it renders the titles it is handed.
          // `SupabaseDiscoveryRepository.judge` is what matches the ids the
          // function returned against the Meals that were actually on screen
          // and drops anything else, so a Meal the AI Assistant invented never
          // becomes a `NothingAnswers` in the first place. Trust-reviewer proved
          // the difference by handing this screen a judgement naming a Meal that
          // was not in the results: the title rendered, with no card beneath it.
          //
          // Naming the wrong layer for a product-fatal invariant is how the next
          // change deletes it, which is why this says where the guard is instead
          // of implying there are two.
          //
          // The AI Assistant still supplies no word of this sentence: the titles
          // are the Cook's and the rest is Kafoo's own copy.
          if (outcome.results.judgement
              case final NothingAnswers judgement) ...[
            _note(
              judgement.alternatives.isEmpty
                  ? l10n.searchJudgementNothingAnswers
                  : _namedAlternatives(l10n, judgement.alternatives),
              KafooColors.onSurface,
            ),
            const SizedBox(height: KafooSpacing.sm),
          ],
          for (final result in outcome.results.results)
            discoveredMealCard(
              l10n: l10n,
              item: result.item,
              source: MealOpenSource.search,
              onOpen: _openFrom(outcome, result),
            ),
        ],
      ),
    );
  }

  /// The sentence naming Meals, with the grammar of the list left to the ARB.
  ///
  /// **The separator used to be `، ` hardcoded here, and it shipped an Arabic
  /// comma to English readers** — measured by localization-reviewer against the
  /// real screen under `Locale('en')`: "Koshari، Molokhia، Fattah", and no "and"
  /// anywhere. Joining is grammar, and grammar belongs where a translator can
  /// reach it: Arabic repeats و before every item, English uses one `and` before
  /// the last, and no single separator can serve both.
  ///
  /// **Each title is isolated between U+2068 and U+2069.** Two Latin-script
  /// titles side by side fuse into one left-to-right island inside a
  /// right-to-left sentence, and the island's internal order runs against the
  /// sentence — measured, "Pizza، Burger" put Burger to the RIGHT of Pizza, so
  /// the Meal named first was read second. Isolation fixes it and changes
  /// nothing for Arabic titles.
  String _namedAlternatives(AppLocalizations l10n, List<Meal> alternatives) {
    // At most three arrive — `judge-results` caps them — and the ARB carries a
    // plural arm per count rather than a joined string.
    String isolated(int index) => index < alternatives.length
        ? '\u2068${alternatives[index].title}\u2069'
        : '';
    return l10n.searchJudgementAlternatives(
      alternatives.length,
      isolated(0),
      isolated(1),
      isolated(2),
    );
  }

  /// Opening a Meal, and noticing when it is one the AI Assistant named.
  ///
  /// RecommendationAccepted answers "did saying 'nothing here answers you, but
  /// there is this' actually help", which is the only question that tells us
  /// whether the judgement is worth its cost. It carries the RANK the Meal
  /// already had and nothing else — not the phrase, and not the Meal's id,
  /// because an id plus a timestamp is a search somebody could reconstruct.
  void Function(DiscoveredMeal)? _openFrom(
    SearchOutcome outcome,
    DiscoveryResult result,
  ) {
    final open = widget.onOpen;
    if (open == null) return null;
    return (item) {
      if (outcome.results.judgement case final NothingAnswers judgement) {
        if (judgement.alternatives.any((m) => m.id == item.meal.id)) {
          unawaited(
            emitEvent(
              EventNames.recommendationAccepted,
              attributes: {'rank': result.rank},
            ),
          );
        }
      }
      open(item);
    };
  }

  /// FR-029a. Said before anything is sent, in plain terms, with refusing as an
  /// answer of equal weight rather than a way out of a dialog.
  Widget _consentQuestion(AppLocalizations l10n) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.searchConsentQuestion, textAlign: TextAlign.center),
              const SizedBox(height: KafooSpacing.md),
              // BOTH OUTLINED, AND THAT IS THE FINDING RATHER THAN THE STYLE.
              // Agreeing was a `FilledButton` and refusing an `OutlinedButton`,
              // which are Material's high- and medium-emphasis widgets — that
              // is the whole reason both exist. Three places in this repository
              // asserted "the same size and the same prominence"; the sizes
              // matched and the prominence did not. On a consent choice that is
              // the dark pattern the trust rules name as product-fatal.
              // Neither answer is the one Kafoo wants.
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                onPressed: () => unawaited(
                  ref
                      .read(searchControllerProvider.notifier)
                      .answerConsent(SearchConsent.granted),
                ),
                child: Text(l10n.searchConsentAgree),
              ),
              const SizedBox(height: KafooSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                onPressed: () => unawaited(
                  ref
                      .read(searchControllerProvider.notifier)
                      .answerConsent(SearchConsent.refused),
                ),
                child: Text(l10n.searchConsentRefuse),
              ),
              const SizedBox(height: KafooSpacing.sm),
              Text(
                l10n.searchConsentNote,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  /// FR-024, FR-024a, FR-024b, FR-024c.
  ///
  /// Names the areas that do have food, in the Cooks' own words, and makes the
  /// Customer choose. **No distance, no ordering by proximity, and no suggestion
  /// that anyone there delivers** — Kafoo holds no location for any Customer, no
  /// notion of where an area is, and a Cook's delivery terms are words rather
  /// than a radius.
  Widget _emptyArea(AppLocalizations l10n, String area) {
    final browse = ref.watch(browseControllerProvider);
    // The areas come from what is on offer right now, so an area named here
    // always has food in it. They are in the order the Cooks' Meals came back —
    // newest first — because any other order would be Kafoo ranking places.
    final areas = <String>{
      for (final item in browse.onOffer)
        if (item.kitchen.area.trim().isNotEmpty) item.kitchen.area.trim(),
    }.toList();

    // WHY THIS BRANCHES ON THE BROWSE STATE AND NOT ON `areas.isEmpty`.
    // `onOffer` is empty while the first load runs and empty when it failed,
    // and neither of those means the marketplace is empty. Saying
    // `browseNothingOnOffer` there tells a Customer that no Cook anywhere has
    // anything — a thing Kafoo does not know — right after telling them their
    // own area is empty. `BrowseState.saysNothingOnOffer` exists precisely to
    // stop that and was not being asked. Found by trust-reviewer 2026-08-07;
    // the ordinary case is search answering in 300 ms while browse has not.
    final String? insteadOfAreas = browse.loading
        ? l10n.browseLoading
        : browse.error != null
            ? l10n.searchAreasUnknown
            : browse.saysNothingOnOffer
                ? l10n.browseNothingOnOffer
                // Food on offer, and not one Cook wrote an area. Kafoo cannot
                // name the areas that have food, and saying the marketplace is
                // empty would be the same lie by a different route.
                : areas.isEmpty
                    ? l10n.searchAreasUnknown
                    : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.searchAreaEmpty(area), textAlign: TextAlign.center),
            const SizedBox(height: KafooSpacing.md),
            if (insteadOfAreas != null)
              Text(insteadOfAreas, textAlign: TextAlign.center)
            else ...[
              Text(l10n.searchAreaChoose, textAlign: TextAlign.center),
              const SizedBox(height: KafooSpacing.sm),
              for (final other in areas)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: KafooSpacing.sm,
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(KafooSpacing.minTapTarget),
                    ),
                    onPressed: () => unawaited(
                      ref
                          .read(searchControllerProvider.notifier)
                          .chooseArea(other),
                    ),
                    child: Text(other),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _browse() => BrowseBody(onOpen: widget.onOpen, entry: widget.entry);

  /// A sentence Kafoo says about the results.
  ///
  /// **THE `Builder` IS LOAD-BEARING AND WAS NOT HERE.** `DefaultTextStyle.of`
  /// resolves from whatever context it is handed, and `this.context` inside a
  /// `State` sits ABOVE the `Scaffold` — above the `Material` that installs the
  /// theme's body style. What it picked up instead was `MaterialApp`'s
  /// `_errorTextStyle`: 48-point black monospace under a double yellow
  /// underline, the style Flutter installs at the root precisely so that stray
  /// text is impossible to miss.
  ///
  /// Measured by localization-reviewer on 2026-08-07: at 360dp and ordinary
  /// text scale, `searchIsOff` rendered 966 pixels tall and overflowed; with
  /// the `Builder` it is 80. Six Customer-facing sentences went through here,
  /// including the allergy sentence and the one about an exclusion Kafoo did
  /// not understand.
  ///
  /// **Twenty-five widget tests passed over it.** `find.text` does not look at
  /// style, and the test harness renders 800x600 — a viewport no phone has.
  /// `browse_screen.dart` carries the identical line and is CORRECT, because
  /// its context comes from a `LayoutBuilder` at the insertion point. The same
  /// line is right in one file and wrong in the other, and only where the
  /// context comes from tells them apart.
  Widget _note(String text, Color color) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KafooSpacing.md,
          vertical: KafooSpacing.sm,
        ),
        child: Semantics(
          liveRegion: true,
          child: Builder(
            builder: (inner) => Text(
              text,
              textAlign: TextAlign.center,
              // Copied from the ambient style so it keeps inheriting text
              // scaling — from `inner`, which is below the Scaffold.
              style: DefaultTextStyle.of(inner).style.copyWith(color: color),
            ),
          ),
        ),
      );
}
