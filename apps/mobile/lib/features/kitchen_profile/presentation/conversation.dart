import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../identity/presentation/recovery_email_prompt.dart';
import '../application/photo_picker.dart';
import '../application/voice_input.dart';
import '../data/kitchen_profile_repository.dart';
import 'conversation_summary.dart';

/// One question, rendered alone.
///
/// A distinct type so a test can assert that exactly one unanswered question
/// is on screen at any moment (SC-006, T040) — an invariant that is otherwise
/// only visible by reading the layout.
class ConversationQuestion extends StatelessWidget {
  const ConversationQuestion({
    required this.prompt,
    required this.hint,
    super.key,
  });

  final String prompt;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: theme.textTheme.headlineSmall),
        const SizedBox(height: KafooSpacing.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

/// The Kitchen Profile conversation.
///
/// Answers are held **in memory only** (FR-013, FR-015): the draft lives in
/// this State object and nothing reaches the database until the Cook confirms
/// the summary. An abandoned conversation therefore leaves nothing behind by
/// construction, not by a cleanup step that could be forgotten.
class KitchenConversationScreen extends StatefulWidget {
  const KitchenConversationScreen({
    this.repository = const SupabaseKitchenProfileRepository(),
    this.pickPhoto = pickPhotoFromGallery,
    this.voiceInput,
    super.key,
  });

  final KitchenProfileRepository repository;
  final PickPhoto pickPhoto;
  final VoiceInput? voiceInput;

  @override
  State<KitchenConversationScreen> createState() =>
      _KitchenConversationScreenState();
}

class _KitchenConversationScreenState extends State<KitchenConversationScreen> {
  final _draft = KitchenProfileDraft();
  final _answerController = TextEditingController();
  late final VoiceInput _voice = widget.voiceInput ?? VoiceInput();

  bool _checkingExisting = true;
  bool _voiceAvailable = false;
  bool _listening = false;

  /// Set once the person speaks or types on the current step, so the funnel
  /// records how the answer arrived without recording what was said (FR-037).
  String _inputMode = 'typed';

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _answerController.dispose();
    unawaited(_voice.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    // FR-009: a person has at most one Kitchen Profile. Send an existing Cook
    // to theirs rather than starting a second conversation. The unique
    // constraint on cook_id is the real guard; this is the courtesy.
    final existing = await widget.repository.findMine();
    if (!mounted) return;
    if (existing case Success(value: final profile?)) {
      await _showAlreadyOwns(profile);
      return;
    }

    final available = await _voice.initialize();
    if (!mounted) return;
    setState(() {
      _checkingExisting = false;
      _voiceAvailable = available;
    });

    unawaited(emitEvent(
      EventNames.conversationStarted,
      attributes: {
        'kind': kitchenProfileConversationKind,
        'input': available ? 'voice' : 'typed',
      },
    ));
  }

  Future<void> _showAlreadyOwns(KitchenProfile profile) async {
    setState(() => _checkingExisting = false);
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.kitchenExistsTitle),
        content: Text(l10n.kitchenExistsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.kitchenConvContinue),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(profile);
  }

  ConversationStepId? get _currentStep {
    final steps = kitchenProfileSteps(
      displayName: _draft.displayName,
      story: _draft.story,
      area: _draft.area,
      deliveryTerms: _draft.deliveryTerms,
    );
    return nextUnansweredStep(steps)?.id;
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    // The transcript lands in the same field the Cook would type into, so it
    // is shown back for confirmation before it is ever accepted (FR-012).
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

  void _acceptAnswer() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    final step = _currentStep;
    if (step == null) return;

    setState(() {
      switch (step) {
        case ConversationStepId.displayName:
          _draft.displayName = answer;
        case ConversationStepId.story:
          _draft.story = answer;
        case ConversationStepId.area:
          _draft.area = answer;
        case ConversationStepId.deliveryTerms:
          _draft.deliveryTerms = answer;
      }
      _answerController.clear();
    });

    // The drop-off signal the whole funnel exists for. Records which step was
    // answered and how — never the answer itself (FR-037).
    unawaited(emitEvent(
      EventNames.conversationStepCompleted,
      attributes: {
        'kind': kitchenProfileConversationKind,
        'step': step.wireName,
        'input': _inputMode,
      },
    ));
    _inputMode = 'typed';

    if (_currentStep == null) unawaited(_openSummary());
  }

  Future<void> _openSummary() async {
    await _voice.cancel();
    if (!mounted) return;
    final saved = await Navigator.of(context).push<KitchenProfile>(
      MaterialPageRoute(
        builder: (_) => KitchenConversationSummary(
          draft: _draft,
          repository: widget.repository,
          pickPhoto: widget.pickPhoto,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      // FR-028: the invitation belongs here, after a Kitchen Profile exists,
      // and never during registration.
      await RecoveryEmailPrompt.maybeShow(context);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } else {
      // They came back to change something — re-render the last question.
      setState(() {});
    }
  }

  String _promptFor(AppLocalizations l10n, ConversationStepId step) =>
      switch (step) {
        ConversationStepId.displayName => l10n.kitchenConvPromptDisplayName,
        ConversationStepId.story => l10n.kitchenConvPromptStory,
        ConversationStepId.area => l10n.kitchenConvPromptArea,
        ConversationStepId.deliveryTerms => l10n.kitchenConvPromptDeliveryTerms,
      };

  String _hintFor(AppLocalizations l10n, ConversationStepId step) =>
      switch (step) {
        ConversationStepId.displayName => l10n.kitchenConvHintDisplayName,
        ConversationStepId.story => l10n.kitchenConvHintStory,
        ConversationStepId.area => l10n.kitchenConvHintArea,
        ConversationStepId.deliveryTerms => l10n.kitchenConvHintDeliveryTerms,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = _currentStep;

    if (_checkingExisting || step == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Exactly one question is built, ever. There is no list of
              // questions to accidentally render two of.
              ConversationQuestion(
                prompt: _promptFor(l10n, step),
                hint: _hintFor(l10n, step),
              ),
              const SizedBox(height: KafooSpacing.lg),
              TextField(
                controller: _answerController,
                maxLines: step == ConversationStepId.story ? 4 : 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _acceptAnswer(),
              ),
              const SizedBox(height: KafooSpacing.md),
              if (_voiceAvailable)
                _VoiceButton(
                  listening: _listening,
                  label: l10n.kitchenConvVoiceHint,
                  onPressed: _toggleListening,
                )
              else
                // research.md §3: recognition missing is the likeliest
                // real-world outcome. Say so plainly and keep the flow whole.
                Text(
                  l10n.kitchenConvVoiceUnavailable,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const Spacer(),
              FilledButton(
                onPressed: _acceptAnswer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: Text(l10n.kitchenConvContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.listening,
    required this.label,
    required this.onPressed,
  });

  final bool listening;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        icon: Icon(listening ? Icons.stop : Icons.mic),
        label: Text(label),
      ),
    );
  }
}
