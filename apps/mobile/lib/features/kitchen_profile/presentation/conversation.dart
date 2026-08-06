import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../identity/presentation/recovery_email_prompt.dart';
import '../data/kitchen_profile_repository.dart';
import 'conversation_summary.dart';

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
        'speech_locale':
            available ? (_voice.resolvedLocaleId ?? 'none') : 'none',
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
            child: Text(l10n.convContinue(context.addressForm)),
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
      addressForm: _draft.addressForm,
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
        case ConversationStepId.addressForm:
          // Unreachable: this step has no free-text answer, and _build never
          // shows the text field on it. Handled rather than defaulted so that
          // adding a sixth step is a compile error here.
          return;
      }
      _answerController.clear();
    });

    _recordStepCompleted(step);
  }

  /// The one step that is answered by choosing rather than by speaking or
  /// typing. Kept separate from [_acceptAnswer] because there is no text to
  /// trim, no voice transcript to confirm, and nothing to clear.
  void _acceptAddressForm(AddressForm form) {
    setState(() => _draft.addressForm = form);
    // 'chosen' rather than 'typed' or 'voice': the funnel measures how an
    // answer arrived, and calling a tap a typed answer would misreport the one
    // step where typing was never offered. The chosen form itself is not an
    // attribute — that is the Cook's data, not a measurement (FR-037).
    _inputMode = 'chosen';
    _recordStepCompleted(ConversationStepId.addressForm);
  }

  void _recordStepCompleted(ConversationStepId step) {
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

  // The Cook's own form is not known until the last step, so every question
  // before it is asked in the unset form. That is the sequence's cost and it is
  // the reason the question is asked at all rather than inferred later.
  String _promptFor(
    AppLocalizations l10n,
    ConversationStepId step,
    String form,
  ) =>
      switch (step) {
        // Two of these four carry no gendered word, so they take no form. That
        // asymmetry is the ARB's to decide, not this screen's.
        ConversationStepId.displayName => l10n.kitchenConvPromptDisplayName,
        ConversationStepId.story => l10n.kitchenConvPromptStory(form),
        ConversationStepId.area => l10n.kitchenConvPromptArea(form),
        ConversationStepId.deliveryTerms => l10n.kitchenConvPromptDeliveryTerms,
        // No placeholder, on purpose: a question asked in order to learn the
        // Cook's form cannot itself be gendered, so it is built from
        // first-person verbs.
        ConversationStepId.addressForm => l10n.kitchenConvPromptAddressForm,
      };

  String? _hintFor(AppLocalizations l10n, ConversationStepId step) =>
      switch (step) {
        ConversationStepId.displayName => l10n.kitchenConvHintDisplayName,
        ConversationStepId.story => l10n.kitchenConvHintStory,
        ConversationStepId.area => l10n.kitchenConvHintArea,
        ConversationStepId.deliveryTerms => l10n.kitchenConvHintDeliveryTerms,
        ConversationStepId.addressForm => null,
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
                prompt: _promptFor(l10n, step, context.addressForm),
                hint: _hintFor(l10n, step),
              ),
              const SizedBox(height: KafooSpacing.lg),
              if (step == ConversationStepId.addressForm)
                ..._addressFormChoices(l10n)
              else
                ..._freeTextAnswer(l10n, step),
            ],
          ),
        ),
      ),
    );
  }

  /// Two buttons, no text field and no microphone.
  ///
  /// The answer is one of exactly two values, so there is nothing for a Cook to
  /// phrase and offering a text box would only invite an answer the app then
  /// has to reject. Each button is labelled with the word it would produce —
  /// كمّل or كمّلي — so the choice is shown rather than described.
  List<Widget> _addressFormChoices(AppLocalizations l10n) => [
        FilledButton(
          onPressed: () => _acceptAddressForm(AddressForm.masculine),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
          ),
          child: Text(l10n.kitchenConvAddressFormMasculine),
        ),
        const SizedBox(height: KafooSpacing.md),
        FilledButton(
          onPressed: () => _acceptAddressForm(AddressForm.feminine),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
          ),
          child: Text(l10n.kitchenConvAddressFormFeminine),
        ),
      ];

  List<Widget> _freeTextAnswer(
    AppLocalizations l10n,
    ConversationStepId step,
  ) =>
      [
        TextField(
          controller: _answerController,
          maxLines: step == ConversationStepId.story ? 4 : 1,
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
          // research.md §3: recognition missing is the likeliest
          // real-world outcome. Say so plainly and keep the flow whole.
          Text(
            l10n.convVoiceUnavailable(context.addressForm),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const Spacer(),
        FilledButton(
          onPressed: _acceptAnswer,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
          ),
          child: Text(l10n.convContinue(context.addressForm)),
        ),
      ];
}
