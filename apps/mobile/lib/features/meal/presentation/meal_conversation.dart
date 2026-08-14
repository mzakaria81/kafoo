import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/application/assistant_voice.dart';
import '../../conversation/application/photo_picker.dart';
import '../../conversation/application/voice_input.dart';
import '../application/meal_conversation_controller.dart';
import 'meal_error_text.dart';
import 'meal_receipt.dart';

/// The Meal conversation — one screen, one open exchange.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THIS WAS SEVEN SURFACES AND IS NOW ONE (ADR-0015, DESIGN.md §11).** Four
/// questions asked one per screen, two fallback questions, and a summary. Each
/// existed because a step had ended.
///
/// What replaces them: the assistant says something, the Cook says something
/// back, and the receipt underneath fills in as she talks. She can ask it
/// questions, ask what to cook, change her mind about the price, and none of
/// that is an error state — it is the conversation.
///
/// **Kafoo still owns what a Meal requires.** `missingFacts` is handed to the
/// model every turn and the model picks what to say; it never decides what a
/// Meal needs and Kafoo never decides the order of the asking.
///
/// **The write boundary did not move.** What the Cook says is written as she
/// says it. Every AI estimate — calories, allergens, inferred cuisine and
/// category — still waits for her approval in the receipt, and publishing is
/// still a read-back that waits for «أيوة».
/// ─────────────────────────────────────────────────────────────────────────────
class MealConversationScreen extends ConsumerStatefulWidget {
  const MealConversationScreen({
    this.voiceInput,
    this.pickPhoto = pickPhotoFromGallery,
    this.resumeFrom,
    super.key,
  });

  final VoiceInput? voiceInput;
  final PickPhoto pickPhoto;

  /// The stored draft to carry on from, or null to start a new Meal.
  ///
  /// **SEEDING HAPPENS HERE, AND MOVING IT HERE WAS THE FIX FOR A DEFECT THE
  /// FOUNDER HIT ON 2026-08-11.** He saved a half-finished Meal, came back, and
  /// «كمّل» asked him the first question again — every answer he had given was
  /// still in the database and none of it was on screen.
  ///
  /// `my_meals_screen.dart` called `resume()` through `ref.read` and then pushed
  /// this route. The controller is `@riverpod` without `keepAlive`, so it is
  /// autoDispose: a `read` with nothing watching creates the provider, takes the
  /// mutation, and disposes it before the next frame. Seeding from `initState`
  /// of the screen that WATCHES the provider is what makes the two the same
  /// instance.
  final CookMeal? resumeFrom;

  @override
  ConsumerState<MealConversationScreen> createState() =>
      _MealConversationScreenState();
}

class _MealConversationScreenState
    extends ConsumerState<MealConversationScreen> {
  final _saidController = TextEditingController();
  final _scrollController = ScrollController();
  late final VoiceInput _voice = widget.voiceInput ?? VoiceInput();
  bool _voiceAvailable = false;
  bool _listening = false;
  bool _preparing = false;
  bool _uploading = false;

  /// How the current turn arrived, so the funnel records the channel without
  /// recording what was said (FR-037).
  String _inputMode = 'typed';

  /// Whether the Cook asked for the text box.
  ///
  /// Starts false and is never set by a failure. §10.7 rung 3 falls back to
  /// tapping, never to typing — "typing is the hardest thing this product could
  /// ask of a Cook", so it is hers to choose and nothing else may choose it for
  /// her.
  bool _typing = false;

  /// The live microphone level, 0 to 1.
  ///
  /// **Zero until the recogniser reports a real one, and the zero is honest.**
  /// `VoiceInput` exposes no amplitude today, so the bars stay still while
  /// listening rather than animating from a timer. §10.2: a fake animation that
  /// moves while the microphone is muted or broken destroys trust in every other
  /// state, and a still bar is a smaller lie than a moving one.
  double get _amplitude => 0;

  TalkOrbState _orbState(MealConversationState state) {
    if (_listening) return TalkOrbState.listening;
    if (state.turnInFlight || _preparing) return TalkOrbState.thinking;
    return TalkOrbState.idle;
  }

  /// True until the stored draft has been read into the controller.
  ///
  /// Riverpod forbids modifying a provider during a widget life-cycle, so
  /// seeding is deferred by one microtask. Without this flag the first frame
  /// would render an empty receipt for a Meal that is half written.
  late bool _seeding = widget.resumeFrom != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.resumeFrom;
    if (draft != null) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(mealConversationControllerProvider.notifier).resume(draft);
        setState(() => _seeding = false);
      });
    }
    unawaited(_initVoice());
  }

  @override
  void dispose() {
    _saidController.dispose();
    _scrollController.dispose();
    unawaited(_voice.cancel());
    super.dispose();
  }

  Future<void> _initVoice() async {
    final available = await _voice.initialize();
    if (!mounted) return;
    setState(() => _voiceAvailable = available);

    unawaited(emitEvent(
      EventNames.conversationStarted,
      attributes: {
        'kind': mealConversationKind,
        'input': available ? 'voice' : 'typed',
        'speech_locale':
            available ? (_voice.resolvedLocaleId ?? 'none') : 'none',
      },
    ));
  }

  Future<void> _send() async {
    final said = _saidController.text.trim();
    if (said.isEmpty) return;

    // CLOSE THE MICROPHONE BEFORE THE ASSISTANT ANSWERS.
    //
    // She can tap send while still mid-sentence, with a partial transcript in
    // the box. Without this the recogniser is still listening when the reply is
    // spoken aloud, so the assistant talks into a live microphone and she hears
    // herself being spoken over. Worse in a kitchen, which is the room this
    // product is for.
    if (_listening) {
      await _voice.stop();
      if (!mounted) return;
      setState(() => _listening = false);
    }

    final mode = _inputMode;
    final controller = ref.read(mealConversationControllerProvider.notifier);
    final ok = await controller.hear(said);
    if (!mounted) return;

    if (ok) {
      setState(_saidController.clear);
      _inputMode = 'typed';
      unawaited(emitEvent(
        EventNames.conversationStepCompleted,
        attributes: {
          'kind': mealConversationKind,
          // A turn, not a step. The event keeps its name because analytics
          // names are never renamed (`docs/product/event-model.md`), and the
          // attribute records what is now true: there are no steps left to name.
          'step': 'turn',
          'input': mode,
        },
      ));
    }
    // On failure the words STAY IN THE BOX. Making her say it again because the
    // network dropped is the cost this product can least afford.
  }

  Future<void> _declinePhoto() async {
    ref.read(mealConversationControllerProvider.notifier).declinePhoto();
  }

  Future<void> _addPhoto() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    final bytes = await widget.pickPhoto();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _uploading = false);
      return;
    }

    await ref
        .read(mealConversationControllerProvider.notifier)
        .attachPhoto(bytes);
    if (!mounted) return;
    setState(() => _uploading = false);
  }

  /// How many assistant lines have already been said out loud.
  ///
  /// Without it every rebuild would re-speak. A Cook typing a long sentence
  /// rebuilds this screen on each keystroke, and an assistant that repeats
  /// itself over her while she answers is worse than one that never spoke.
  int _spokenLines = 0;

  /// Says the assistant's newest line — the same sentence, not a summary.
  ///
  /// Deferred by a microtask because `build` must stay pure. `_spokenLines` is
  /// advanced BEFORE the microtask, so two builds in the same frame cannot both
  /// queue the same sentence.
  void _speakNewLines(List<String> lines) {
    if (lines.length <= _spokenLines) return;
    final line = lines.last;
    _spokenLines = lines.length;
    Future.microtask(() {
      if (!mounted) return;
      unawaited(ref.read(assistantVoiceProvider.notifier).say(line));
      if (_scrollController.hasClients) {
        unawaited(_scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    // THE ASSISTANT STOPS TALKING BEFORE THE MICROPHONE OPENS, and the runtime
    // guard is this call rather than any test over the state enum.
    //
    // The button says so while it waits, because that wait is unbounded and on a
    // slow handset it is long enough to read as a button that did nothing —
    // §10.3, the failure where she taps again and cuts off her own first words.
    //
    // `finally`, because the acknowledgement disables the button: a state that
    // can only be cleared on the happy path is a trap waiting for a future edit.
    // And the microphone stays shut when the hush fails — a hush that threw is
    // not a promise of silence.
    setState(() => _preparing = true);
    try {
      await ref.read(assistantVoiceProvider.notifier).hush();
    } on Object catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'kafoo',
        context: ErrorDescription('silencing the assistant before listening'),
      ));
      return;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _voice.listen(
      onTranscript: (transcript, isFinal) {
        if (!mounted) return;
        setState(() {
          _saidController.text = transcript;
          _inputMode = 'voice';
          if (isFinal) _listening = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // WATCHED BEFORE THE EARLY RETURN, AND THE ORDER IS THE WHOLE POINT.
    //
    // The controller is autoDispose. While `_seeding` is true this method
    // returns a spinner, and if the watch sat below that return then the
    // seeding microtask's `ref.read` would create the provider, take the
    // mutation, and dispose it again with nothing listening — so the resumed
    // draft would vanish before the first real frame. That is the 2026-08-11
    // defect, reintroduced by moving two lines.
    final state = ref.watch(mealConversationControllerProvider);
    final voice = ref.watch(assistantVoiceProvider);

    if (_seeding) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.mealConvResuming(context.addressForm),
          ),
        ),
      );
    }

    // The opening line, seeded once. Deferred for the same reason resume() is:
    // a provider must not be written during a build.
    if (state.lines.isEmpty && !state.turnInFlight) {
      final opening = l10n.mealTalkOpening(context.addressForm);
      Future.microtask(() {
        if (!mounted) return;
        ref.read(mealConversationControllerProvider.notifier).open(opening);
      });
    }
    _speakNewLines(state.lines);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mealTalkTitle),
        actions: [
          // Every screen that speaks carries the mute control, top inline-end,
          // and it persists until reversed.
          KafooMuteButton(
            muted: voice.muted,
            label: voice.muted
                ? l10n.voiceMuteRestore(context.addressForm)
                : l10n.voiceMuteSilence(context.addressForm),
            onChanged: (muted) => ref
                .read(assistantVoiceProvider.notifier)
                .setMuted(muted: muted),
          ),
        ],
      ),
      // SCROLLS, AND HAS TO. Measured at 360x640 with text at 200%, a Column
      // here overflows and resolves it by clipping its LAST child — which is the
      // control that sends what she just said.
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WHAT THE ASSISTANT SAID, AND ONLY THAT. The Cook's own words are
              // deliberately absent: ADR-0013 rule 2 — the assistant paraphrases
              // what it understood, and a transcript hides a misunderstanding
              // from exactly the person who cannot read it.
              // `take` on an empty list with a negative count throws, and an
              // empty list is the first frame of every conversation.
              for (final line in state.lines
                  .take(state.lines.isEmpty ? 0 : state.lines.length - 1))
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: KafooSpacing.sm,
                  ),
                  child: Text(
                    line,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: KafooColors.voiceDeep),
                  ),
                ),
              if (state.lines.isNotEmpty)
                KafooSpokenBanner(
                  line: state.lines.last,
                  hearAgainLabel: l10n.mealTalkHearAgain,
                  onHearAgain: () => unawaited(ref
                      .read(assistantVoiceProvider.notifier)
                      .say(state.lines.last)),
                ),
              if (state.turnInFlight) ...[
                const SizedBox(height: KafooSpacing.sm),
                Text(
                  l10n.mealTalkThinking,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: KafooColors.textMuted),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: KafooSpacing.sm),
                Text(
                  mealErrorText(context, state.error!),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: KafooSpacing.lg),

              // The receipt. Present from the first turn, filling in as she
              // talks, and the tap path for every value she can also say.
              const MealReceipt(),

              const SizedBox(height: KafooSpacing.lg),
              Text(
                l10n.mealConvPhotoDisclosure,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: KafooSpacing.sm),
              if (_uploading)
                const SizedBox(
                  height: KafooSpacing.minTapTarget,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                OutlinedButton(
                  onPressed: _addPhoto,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.mealConvPhotoAdd(context.addressForm)),
                ),
                if (!state.draft.photoResolved) ...[
                  const SizedBox(height: KafooSpacing.sm),
                  TextButton(
                    onPressed: _declinePhoto,
                    child: Text(l10n.mealConvPhotoSkip(context.addressForm)),
                  ),
                ],
              ],

              const SizedBox(height: KafooSpacing.xl),

              // THE TALK BUTTON, 88dp, CENTRED, WITH NOTHING ELSE INSIDE ITS
              // RADIUS. §10.3, and drawn the way the design package draws it —
              // the orb is the screen's one unmissable control, found by thumb
              // without looking, sometimes with wet hands.
              if (_voiceAvailable)
                Center(
                  child: KafooTalkButton(
                    state: _orbState(state),
                    amplitude: _amplitude,
                    label: _preparing
                        ? l10n.voicePreparing
                        : l10n.mealTalkPress(context.addressForm),
                    enabled: !state.turnInFlight,
                    onPressStart: () => unawaited(_toggleListening()),
                    onPressEnd: () {},
                  ),
                )
              else
                Text(
                  l10n.convVoiceUnavailable(context.addressForm),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),

              const SizedBox(height: KafooSpacing.lg),

              // TYPING IS A CHOICE AND IS DRAWN AS ONE. Secondary, below the
              // orb, with the rule written under it — the box only appears when
              // she asks for it, so typing is never what the screen offers her
              // after failing to understand (§10.7 rung 3).
              if (!_typing)
                Column(
                  children: [
                    OutlinedButton(
                      key: const ValueKey('meal-talk-type'),
                      onPressed: () => setState(() => _typing = true),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(KafooSpacing.minTapTarget),
                      ),
                      child: Text(l10n.mealTalkType(context.addressForm)),
                    ),
                    const SizedBox(height: KafooSpacing.xs),
                    Text(
                      l10n.mealTalkTypeNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: KafooColors.textMuted),
                    ),
                  ],
                )
              else ...[
                TextField(
                  key: const ValueKey('meal-talk-box'),
                  controller: _saidController,
                  maxLines: 3,
                  minLines: 1,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: l10n.mealTalkHint(context.addressForm),
                  ),
                  onSubmitted: (_) => _send(),
                ),
                const SizedBox(height: KafooSpacing.md),
                FilledButton(
                  onPressed: state.turnInFlight ? null : _send,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.convContinue(context.addressForm)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
