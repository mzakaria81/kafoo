import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/application/photo_picker.dart';
import '../../conversation/application/voice_input.dart';
import '../../conversation/presentation/conversation_question.dart';
import '../../conversation/presentation/voice_button.dart';
import '../application/meal_conversation_controller.dart';
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
    super.key,
  });

  final VoiceInput? voiceInput;
  final PickPhoto pickPhoto;

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
  bool _uploading = false;

  /// Set once the person speaks or types on the current step, so the funnel
  /// records how the answer arrived without recording what was said (FR-037).
  String _inputMode = 'typed';

  @override
  void initState() {
    super.initState();
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
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
    final step = _currentStep;

    if (step == null) {
      final fallback = ref
          .read(mealConversationControllerProvider.notifier)
          .currentFallbackStep;
      if (fallback != null) {
        return MealFallbackQuestion(
          step: fallback,
          error: state.error,
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

    return Scaffold(
      appBar: AppBar(),
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
              const SizedBox(height: KafooSpacing.lg),
              if (!isPhoto) ...[
                TextField(
                  controller: _answerController,
                  maxLines: step.id == MealStepId.description ? 4 : 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _acceptAnswer(),
                ),
                const SizedBox(height: KafooSpacing.md),
                if (_voiceAvailable)
                  VoiceButton(
                    listening: _listening,
                    label: l10n.convVoiceHint(context.addressForm),
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
                  _errorText(l10n, state.error!),
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

  /// Both keys already existed for the repository (T033); this screen adds no
  /// error vocabulary of its own. The default is the save error rather than a
  /// generic one, because every failure this screen can currently reach is a
  /// failure to write the draft.
  String _errorText(AppLocalizations l10n, AppError error) =>
      switch (error.messageKey) {
        'mealPhotoError' => l10n.mealPhotoError(context.addressForm),
        _ => l10n.mealSaveError(context.addressForm),
      };
}
