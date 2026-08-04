import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../conversation/application/voice_input.dart';
import '../../conversation/presentation/conversation_question.dart';
import '../../conversation/presentation/voice_button.dart';
import '../application/meal_conversation_controller.dart';

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
    super.key,
  });

  final VoiceInput? voiceInput;

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
    }
  }

  Future<void> _declinePhoto() async {
    ref.read(mealConversationControllerProvider.notifier).declinePhoto();
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
          if (isFinal) _listening = false;
        });
      },
    );
  }

  String _promptFor(AppLocalizations l10n, MealStepId step) => switch (step) {
        MealStepId.dish => l10n.mealConvPromptDish,
        MealStepId.description => l10n.mealConvPromptDescription,
        MealStepId.photo => l10n.mealConvPromptPhoto,
        MealStepId.price => l10n.mealConvPromptPrice,
      };

  String _hintFor(AppLocalizations l10n, MealStepId step) => switch (step) {
        MealStepId.dish => l10n.mealConvHintDish,
        MealStepId.description => l10n.mealConvHintDescription,
        MealStepId.photo => l10n.mealConvHintPhoto,
        MealStepId.price => l10n.mealConvHintPrice,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealConversationControllerProvider);
    final l10n = AppLocalizations.of(context);
    final step = _currentStep;

    if (step == null) {
      // PLACEHOLDER, and it must not ship as one. All four answers are in and
      // the next thing a Cook should see is the summary where every AI
      // suggestion is approved or corrected — that is T037, and until it exists
      // there is nothing to push. A spinner with no exit is a dead end, so T037
      // replaces this rather than adding to it.
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPhoto = step.id == MealStepId.photo;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
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
                    label: l10n.convVoiceHint,
                    onPressed: _toggleListening,
                  )
                else
                  Text(
                    l10n.convVoiceUnavailable,
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
              const Spacer(),
              if (isPhoto)
                OutlinedButton(
                  onPressed: _declinePhoto,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.mealConvPhotoSkip),
                )
              else
                FilledButton(
                  onPressed: _acceptAnswer,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.convContinue),
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
        'mealPhotoError' => l10n.mealPhotoError,
        _ => l10n.mealSaveError,
      };
}
