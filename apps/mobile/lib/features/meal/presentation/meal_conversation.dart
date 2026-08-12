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
import '../../conversation/presentation/conversation_question.dart';
import '../../conversation/presentation/voice_button.dart';
import '../application/meal_conversation_controller.dart';
import 'meal_error_text.dart';
import 'meal_fallback_question.dart';
import 'meal_summary.dart';

/// The Meal conversation screen.
///
/// A Cook puts a Meal on offer by talking, not by filling in a form.
/// Exactly one unanswered question is on screen at any moment (SC-002).
///
/// The photo step is the only skippable one — declining resolves it without
/// producing an answer. Voice recognition is attempted on start; when
/// unavailable the Cook types instead (research.md §3).
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
  /// **SEEDING HAPPENS HERE, AND MOVING IT HERE IS THE FIX FOR A DEFECT THE
  /// FOUNDER HIT ON 2026-08-11.** He saved a half-finished Meal, came back, and
  /// «كمّل» asked him the first question again — every answer he had given was
  /// still in the database and none of it was on screen.
  ///
  /// `my_meals_screen.dart` called `resume()` through `ref.read` and then pushed
  /// this route. The controller is `@riverpod` without `keepAlive`, so it is
  /// autoDispose: a `read` with nothing watching creates the provider, takes the
  /// mutation, and disposes it before the next frame. The push then built this
  /// screen, which WATCHES the provider, so Riverpod constructed a fresh one —
  /// `build()` returns an empty draft, and the conversation starts over.
  ///
  /// Nothing was broken inside either screen. The seeding happened in a route
  /// that was not listening, which is the same shape as every other defect that
  /// has reached his phone: correct parts, wrong seam. Seeding from `initState`
  /// of the screen that watches the provider is what makes the two the same
  /// instance.
  final CookMeal? resumeFrom;

  @override
  ConsumerState<MealConversationScreen> createState() =>
      _MealConversationScreenState();
}

class _MealConversationScreenState
    extends ConsumerState<MealConversationScreen> {
  final _answerController = TextEditingController();
  late final VoiceInput _voice = widget.voiceInput ?? VoiceInput();
  bool _voiceAvailable = false;
  bool _listening = false;
  bool _preparing = false;
  bool _uploading = false;

  /// Set once the person speaks or types on the current step, so the funnel
  /// records how the answer arrived without recording what was said (FR-037).
  String _inputMode = 'typed';

  /// True until the stored draft has been read into the controller.
  ///
  /// **A LOADING FRAME RATHER THAN THE WRONG QUESTION.** Riverpod forbids
  /// modifying a provider during a widget life-cycle, so the seeding cannot
  /// happen in `initState` itself — it is deferred by one microtask. Without
  /// this flag the first frame would render `currentStep`, which for an unseeded
  /// controller is the dish question: the exact thing the Cook complained about,
  /// on screen for one frame instead of forever.
  ///
  /// A test using `pumpAndSettle` would never see that frame, which is why the
  /// flag is here rather than a comment saying it does not matter.
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
    _answerController.dispose();
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

  /// Asks the controller, which asks the domain. Deriving the sequence here as
  /// well would be a second copy of a rule that already has one home.
  MealStep? get _currentStep =>
      ref.read(mealConversationControllerProvider.notifier).currentStep;

  Future<void> _acceptAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    final step = _currentStep;
    if (step == null) return;

    // CLOSE THE MICROPHONE BEFORE THE NEXT QUESTION IS SPOKEN.
    //
    // A Cook can tap «كمّل» while still mid-sentence, with a partial transcript
    // already in the box — she has said enough and wants to move on. Without
    // this the recogniser is still listening when the next question is said
    // aloud, so the assistant talks into a live microphone and she hears herself
    // being spoken over. Worse in a kitchen, which is the room this product is
    // for.
    if (_listening) {
      await _voice.stop();
      if (!mounted) return;
      setState(() => _listening = false);
    }

    final controller = ref.read(mealConversationControllerProvider.notifier);
    final success = await controller.answer(step.id, answer);

    if (mounted && success) {
      setState(_answerController.clear);

      unawaited(emitEvent(
        EventNames.conversationStepCompleted,
        attributes: {
          'kind': mealConversationKind,
          'step': step.id.wireName,
          'input': _inputMode,
        },
      ));
      _inputMode = 'typed';
    }
  }

  Future<void> _declinePhoto() async {
    ref.read(mealConversationControllerProvider.notifier).declinePhoto();

    unawaited(emitEvent(
      EventNames.conversationStepCompleted,
      attributes: {
        'kind': mealConversationKind,
        'step': MealStepId.photo.wireName,
        'input': 'typed',
      },
    ));
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

    final controller = ref.read(mealConversationControllerProvider.notifier);
    final ok = await controller.attachPhoto(bytes);

    if (!mounted) return;
    setState(() => _uploading = false);

    if (ok) {
      unawaited(emitEvent(
        EventNames.conversationStepCompleted,
        attributes: {
          'kind': mealConversationKind,
          'step': MealStepId.photo.wireName,
          'input': 'typed',
        },
      ));
    }
  }

  /// The step whose question has already been said out loud.
  ///
  /// Without it, every rebuild would re-ask. A Cook typing a long description
  /// rebuilds this screen on each keystroke, and an assistant that repeats the
  /// question over her while she answers is worse than one that never spoke.
  MealStepId? _spokenStep;

  /// Says the question the screen is showing — the same sentence, not a summary.
  ///
  /// **This is the half that was missing.** The conversation has listened since
  /// E2 and has never once talked back, so a Cook who cannot read comfortably
  /// met a screen of text with a microphone attached. ADR-0013 is the other
  /// direction: the assistant speaks, she speaks back, and the screen is the
  /// receipt.
  ///
  /// Deferred by a microtask because `build` must stay pure — speaking is a side
  /// effect, and calling it during a build is how a rebuild loop starts.
  /// `_spokenStep` is set BEFORE the microtask, so two builds in the same frame
  /// cannot both queue the same sentence.
  void _speakQuestion(MealStepId id, String prompt) {
    if (_spokenStep == id || prompt.isEmpty) return;
    _spokenStep = id;
    Future.microtask(() {
      if (!mounted) return;
      unawaited(ref.read(assistantVoiceProvider.notifier).say(prompt));
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    // THE ASSISTANT STOPS TALKING BEFORE THE MICROPHONE OPENS.
    //
    // `voice.dart` states this as a property of the nine states and
    // `voice_test.dart` asserts it there — but that is a check over an enum, not
    // a guard over a running speaker and a running microphone. **The runtime
    // guard is this call and the generation counter behind it**, and an earlier
    // version of this comment claimed the enum test enforced it. It does not.
    // A false claim of safety is worse than no comment, because it stops the
    // next person looking.
    //
    // **AND THE BUTTON SAYS SO WHILE IT WAITS.** That wait is unbounded on
    // purpose, so on a slow handset it is long enough to read as a button that
    // did nothing — §10.3, the failure where she taps again and cuts off her own
    // first words. The state is set before the await, never after it.
    //
    // **`finally`, because the acknowledgement disables the button.** Every
    // engine behind `hush()` swallows its own errors today, so nothing here
    // throws — but the day one does, a Cook's microphone goes dead with no
    // message and no way back except leaving the screen. A state that can only
    // be cleared on the happy path is a trap waiting for a future edit. Raised
    // by accessibility-reviewer on #461, round eight.
    setState(() => _preparing = true);
    try {
      await ref.read(assistantVoiceProvider.notifier).hush();
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _voice.listen(
      onTranscript: (transcript, isFinal) {
        if (!mounted) return;
        setState(() {
          _answerController.text = transcript;
          _inputMode = 'voice';
          if (isFinal) _listening = false;
        });
      },
    );
  }

  String _promptFor(AppLocalizations l10n, MealStepId step) => switch (step) {
        MealStepId.dish => l10n.mealConvPromptDish,
        MealStepId.description =>
          l10n.mealConvPromptDescription(context.addressForm),
        MealStepId.photo => l10n.mealConvPromptPhoto,
        MealStepId.price => l10n.mealConvPromptPrice(context.addressForm),
      };

  String _hintFor(AppLocalizations l10n, MealStepId step) => switch (step) {
        MealStepId.dish => l10n.mealConvHintDish,
        MealStepId.description => l10n.mealConvHintDescription,
        MealStepId.photo => l10n.mealConvHintPhoto(context.addressForm),
        MealStepId.price => l10n.mealConvHintPrice,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealConversationControllerProvider);
    final l10n = AppLocalizations.of(context);

    if (_seeding) {
      return Scaffold(
        body: Center(
          // Announced, though it lasts one microtask. A state only the screen
          // reports is invisible to the person this product exists for, and
          // «كمّل الأكلة دي» is the path a returning Cook takes.
          child: CircularProgressIndicator(
            semanticsLabel: l10n.mealConvResuming(context.addressForm),
          ),
        ),
      );
    }

    final step = _currentStep;

    if (step == null) {
      final fallback = ref
          .read(mealConversationControllerProvider.notifier)
          .currentFallbackStep;
      if (fallback != null) {
        return MealFallbackQuestion(
          step: fallback,
          error: state.error,
          analysisError: state.analysisError,
        );
      }
      // Rendered in place rather than pushed as a route.
      //
      // The first version pushed the summary from build() behind a one-shot
      // flag, which trapped a Cook who came back: the flag stayed set, so the
      // conversation rendered a spinner and never pushed again. Rendering in
      // place removes the whole class of bug — there is no navigation to get
      // out of step with, and correcting a value simply rebuilds this.
      //
      // Nothing is written by arriving here. The draft already exists (T034)
      // and stays `draft` until the Cook approves estimates and publishes
      // from the summary.
      return const MealSummaryScreen();
    }

    final isPhoto = step.id == MealStepId.photo;

    final voice = ref.watch(assistantVoiceProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          // Every screen that speaks carries the mute control, top inline-end,
          // and it persists until reversed. This screen started speaking and did
          // not get one — so a Cook beside a sleeping baby could only silence it
          // by leaving the screen, which loses the question she was answering.
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
      // SCROLLS. Measured at 360x640 with text at 200%: this Column overflowed
      // by 182 logical pixels, up from 4 before the theme once the design system's type scale landed, and an overflowing
      // Column resolves it by clipping its LAST child — the button that submits.
      // A Cook using large text on a cheap Android handset had no reachable
      // control at all.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isPhoto)
                Text(
                  l10n.mealConvPhotoDisclosure,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              if (isPhoto) const SizedBox(height: KafooSpacing.sm),
              ConversationQuestion(
                prompt: _promptFor(l10n, step.id),
                hint: _hintFor(l10n, step.id),
              ),
              // Said aloud as well as shown. The screen is the receipt of what
              // was spoken, not the place it first appears.
              Builder(builder: (_) {
                _speakQuestion(step.id, _promptFor(l10n, step.id));
                return const SizedBox.shrink();
              }),
              const SizedBox(height: KafooSpacing.lg),
              if (!isPhoto) ...[
                TextField(
                  controller: _answerController,
                  maxLines: step.id == MealStepId.description ? 4 : 1,
                  // A number pad for the one question that is a number. It
                  // reduces how often the price arrives as Arabic-Indic digits;
                  // it does not remove the need to handle them, because on many
                  // Egyptian handsets the number pad IS Arabic-Indic. The
                  // parsing in `parseMealPrice` is the fix — this is a courtesy.
                  keyboardType: step.id == MealStepId.price
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _acceptAnswer(),
                ),
                const SizedBox(height: KafooSpacing.md),
                if (_voiceAvailable)
                  VoiceButton(
                    listening: _listening,
                    preparing: _preparing,
                    label: _preparing
                        ? l10n.voicePreparing
                        : l10n.convVoiceHint(context.addressForm),
                    onPressed: _toggleListening,
                  )
                else
                  Text(
                    l10n.convVoiceUnavailable(context.addressForm),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: KafooSpacing.sm),
                Text(
                  mealErrorText(context, state.error!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
              // A fixed gap: a Spacer needs bounded height and a scroll view
              // gives it none.
              const SizedBox(height: KafooSpacing.xl),
              if (isPhoto) ...[
                if (_uploading)
                  const SizedBox(
                    height: KafooSpacing.minTapTarget,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  FilledButton(
                    onPressed: _addPhoto,
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(KafooSpacing.minTapTarget),
                    ),
                    child: Text(l10n.mealConvPhotoAdd(context.addressForm)),
                  ),
                const SizedBox(height: KafooSpacing.sm),
                OutlinedButton(
                  onPressed: _uploading ? null : _declinePhoto,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.mealConvPhotoSkip(context.addressForm)),
                ),
              ] else
                FilledButton(
                  onPressed: _acceptAnswer,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.convContinue(context.addressForm)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
