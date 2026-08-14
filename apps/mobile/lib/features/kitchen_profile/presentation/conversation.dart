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
import '../../conversation/data/agent_conversation.dart';
import '../../conversation/data/pcm_player.dart';
import '../../conversation/presentation/read_back_gate.dart';
import '../../meal/presentation/meal_error_text.dart';
import '../application/kitchen_conversation_controller.dart';
import 'kitchen_receipt.dart';

/// The Kitchen Profile conversation — one screen, one open exchange.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THIS WAS FIVE QUESTIONS AND IS NOW ONE CONVERSATION (ADR-0015).** Name,
/// then story, then area, then delivery terms, then how to address her — one per
/// screen, in that order, with a summary at the end. It was the second thing a
/// new Cook ever met: she signed in, was told the product talks to her, and was
/// handed a form.
///
/// What replaces them: the assistant says something, the Cook says something
/// back, and the receipt underneath fills in as she talks. She can ask it
/// questions, ask what to call her kitchen, change her mind, and none of that is
/// an error state — it is the conversation.
///
/// **Kafoo still owns what a kitchen requires.** `missingFacts` is handed to the
/// model every turn and the model picks what to say; it never decides what a
/// kitchen needs and Kafoo never decides the order of the asking.
///
/// **Nothing is written until she hears it back and says «أيوة».** Unlike a
/// Meal, a Kitchen Profile has no draft state in the database — every text
/// column is required in one insert — so the whole thing is created at the gate
/// or not at all. A Cook who walks away has told a stranger about herself and
/// Kafoo kept none of it.
/// ─────────────────────────────────────────────────────────────────────────────
class KitchenConversationScreen extends ConsumerStatefulWidget {
  const KitchenConversationScreen({
    this.pickPhoto = pickPhotoFromGallery,
    this.voiceInput,
    super.key,
  });

  /// Kept for ONE reason: the `speech_locale` attribute on
  /// `ConversationStarted`, which is how `docs/ops/measuring-transcription.md`
  /// counts handsets with no Egyptian Arabic language pack. Nothing on this
  /// screen listens through it — the orb opens a hosted conversation that brings
  /// its own recognition — so it must never decide what gets drawn. That
  /// mistake was made once already, on the Meal conversation, and it hid the orb
  /// from every phone without the language pack.
  final VoiceInput? voiceInput;

  /// **NO REPOSITORY PARAMETER, AND THAT IS THE CHANGE.** The wizard took one
  /// from its parent and handed it down; a controller has no parent to be
  /// handed anything by. Whatever needs to replace it — a test, a preview —
  /// overrides `kitchenProfileRepositoryProvider` instead.
  final PickPhoto pickPhoto;

  @override
  ConsumerState<KitchenConversationScreen> createState() =>
      _KitchenConversationScreenState();
}

class _KitchenConversationScreenState
    extends ConsumerState<KitchenConversationScreen> {
  final _saidController = TextEditingController();
  final _scrollController = ScrollController();

  /// The live conversation, when one is open (ADR-0017).
  AgentConversation? _agent;
  PcmPlayer? _speaker;
  StreamSubscription<AgentEvent>? _agentEvents;
  bool _live = false;
  bool _preparing = false;
  bool _uploading = false;
  bool _creating = false;

  /// Whether the Cook asked for the text box.
  ///
  /// Starts false and is never set by a failure to UNDERSTAND. §10.7 rung 3
  /// falls back to tapping, never to typing — so it is hers to choose, and only
  /// a failure to CONNECT may reveal it, which she is told about plainly.
  bool _typing = false;

  late final VoiceInput _voice = widget.voiceInput ?? VoiceInput();

  /// The live microphone level, 0 to 1.
  ///
  /// Zero until the recogniser reports a real one, and the zero is honest: a
  /// fake animation that moves while the microphone is broken destroys trust in
  /// every other state.
  double get _amplitude => 0;

  TalkOrbState _orbState(KitchenConversationState state) {
    if (_live) return TalkOrbState.listening;
    if (state.turnInFlight || _preparing) return TalkOrbState.thinking;
    return TalkOrbState.idle;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_reportSpeechLocale());
  }

  /// Opens the funnel, and records which handset this Cook is holding.
  ///
  /// `ConversationStarted` is what `ConversationCompleted` closes, so a
  /// conversation that never reports starting makes the completion rate look
  /// like a divide by zero. The locale is measurement only — see
  /// [KitchenConversationScreen.voiceInput].
  Future<void> _reportSpeechLocale() async {
    final available = await _voice.initialize();
    if (!mounted) return;
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

  @override
  void dispose() {
    unawaited(_voice.cancel());
    _saidController.dispose();
    _scrollController.dispose();
    unawaited(_agentEvents?.cancel());
    unawaited(_agent?.dispose());
    unawaited(_speaker?.dispose());
    super.dispose();
  }

  KitchenConversationController get _controller =>
      ref.read(kitchenConversationControllerProvider.notifier);

  /// Opens or closes the live conversation.
  ///
  /// **The fallback is tap, never a dead button.** Every way this can fail — no
  /// microphone permission, no signed URL, no network — ends the same way: the
  /// assistant says it cannot hear right now and the typing control is
  /// revealed. That is a failure to CONNECT, which she has to be told about
  /// plainly, and it is a different thing from failing to understand her.
  Future<void> _toggleLive() async {
    if (_live) {
      await _agent?.stop();
      return;
    }

    await ref.read(assistantVoiceProvider.notifier).hush();
    if (!mounted) return;

    final agent = _agent ??= AgentConversation(
      // THE KITCHEN AGENT, NOT THE MEAL ONE. Both opened the Meal agent until
      // 2026-08-14, so a Cook setting up her kitchen was greeted with «قوليلي
      // عملتي إيه النهاردة؟» and asked about a dish.
      kind: AgentConversationKind.kitchen,
      voice: ref.read(assistantVoiceProvider).voice.wireName,
    );
    final speaker = _speaker ??= PcmPlayer();

    _agentEvents ??= agent.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case AgentAudio(:final pcm):
          speaker.add(pcm);
        case AgentSaid(:final text):
          // SHOWN, NOT SAID AGAIN. The agent has already spoken these words in
          // its own voice; `_spokenLines` is advanced past them so the screen
          // is the receipt rather than a second voice repeating it.
          _announceWithoutRepeating(text);
        case AgentHeard(:final text):
          // HER WORDS NEVER REACH THE SCREEN. They are fed to the controller so
          // the facts inside them can be kept — the same path typing takes.
          //
          // `speaking: false` because the agent is the one talking. Without it
          // Kafoo composes its own answer to the same sentence and says that
          // too: two assistants on the screen and two voices in the room.
          unawaited(_controller.hear(text, speaking: false));
        case AgentInterrupted():
          unawaited(speaker.clear());
        case AgentEnded():
          if (mounted) setState(() => _live = false);
      }
    });

    setState(() => _preparing = true);
    final started = await agent.start();
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _live = started;
      if (!started) _typing = true;
    });

    if (!started && mounted) {
      _controller.announce(
        AppLocalizations.of(context).convVoiceUnavailable(context.addressForm),
      );
    }
  }

  Future<void> _send() async {
    final said = _saidController.text.trim();
    if (said.isEmpty) return;

    final ok = await _controller.hear(said);
    if (!mounted) return;
    if (ok) {
      setState(_saidController.clear);
      unawaited(emitEvent(
        EventNames.conversationStepCompleted,
        attributes: {
          'kind': kitchenProfileConversationKind,
          // A turn, not a step. The event keeps its name because analytics
          // names are never renamed; the attribute records what is now true —
          // there are no steps left to name.
          'step': 'turn',
          'input': 'typed',
        },
      ));
    }
    // On failure the words STAY IN THE BOX. Making her say it again because the
    // network dropped is the cost this product can least afford.
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
    await _controller.attachPhoto(bytes);
    if (!mounted) return;
    setState(() => _uploading = false);
  }

  /// Creates the kitchen, through the read-back gate.
  ///
  /// Everything she said is spoken back in her own words first, because what is
  /// on this screen becomes the page a Customer reads to decide whether to trust
  /// a stranger cooking at home. She hears it before anybody else does.
  Future<void> _create() async {
    if (_creating) return;
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final draft = ref.read(kitchenConversationControllerProvider).draft;

    final confirmed = await askReadBackGate(
      context: context,
      readback: l10n.kitchenGateReadback(
        draft.displayName ?? '',
        draft.area ?? '',
        draft.story ?? '',
        draft.deliveryTerms ?? '',
      ),
      question: l10n.kitchenGateQuestion,
      confirmLabel: l10n.kitchenGateYes(form),
      rejectLabel: l10n.gateAnswerNo,
    );
    if (!confirmed || !mounted) return;

    setState(() => _creating = true);
    final ok = await _controller.create();
    if (!mounted) return;
    setState(() => _creating = false);
    if (!ok) return;

    unawaited(emitEvent(
      EventNames.conversationCompleted,
      attributes: {
        'kind': kitchenProfileConversationKind,
        'input': 'mixed',
      },
    ));
    await ref
        .read(assistantVoiceProvider.notifier)
        .say(l10n.kitchenTalkCreated);
    if (!mounted) return;
    Navigator.of(context).pop(
      ref.read(kitchenConversationControllerProvider).saved,
    );
  }

  /// How many assistant lines have already been said out loud.
  ///
  /// Without it every rebuild would re-speak. A Cook typing a long sentence
  /// rebuilds this screen on each keystroke, and an assistant that repeats
  /// itself over her while she answers is worse than one that never spoke.
  int _spokenLines = 0;

  /// Puts an agent line on the screen without queueing it to be spoken.
  void _announceWithoutRepeating(String text) {
    _controller.announce(text);
    _spokenLines = ref.read(kitchenConversationControllerProvider).lines.length;
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final form = context.addressForm;
    final state = ref.watch(kitchenConversationControllerProvider);
    final voice = ref.watch(assistantVoiceProvider);

    // The opening line, seeded once. Deferred because a provider must not be
    // written during a build.
    if (state.lines.isEmpty && !state.turnInFlight) {
      final opening = l10n.kitchenTalkOpening(form);
      Future.microtask(() {
        if (!mounted) return;
        _controller.open(opening);
      });
    }
    _speakNewLines(state.lines);

    final canCreate =
        ref.read(kitchenConversationControllerProvider.notifier).canCreate;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kitchenTalkTitle),
        actions: [
          // Every screen that speaks carries the mute control, top inline-end,
          // and it persists until reversed.
          KafooMuteButton(
            muted: voice.muted,
            label: voice.muted
                ? l10n.voiceMuteRestore(form)
                : l10n.voiceMuteSilence(form),
            onChanged: (muted) => ref
                .read(assistantVoiceProvider.notifier)
                .setMuted(muted: muted),
          ),
        ],
      ),
      // SCROLLS, AND HAS TO. At 200% text a Column here overflows and resolves
      // it by clipping its LAST child — which is the control that sends what she
      // just said.
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // WHAT THE ASSISTANT SAID, AND ONLY THAT. Her own words are
              // deliberately absent: ADR-0013 rule 2 — the assistant paraphrases
              // what it understood, and a transcript hides a misunderstanding
              // from exactly the person who cannot read it.
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
              const KitchenReceipt(),

              const SizedBox(height: KafooSpacing.lg),
              if (_uploading)
                const SizedBox(
                  height: KafooSpacing.minTapTarget,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                OutlinedButton(
                  onPressed: _addPhoto,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(l10n.kitchenConvPhotoAdd(form)),
                ),

              const SizedBox(height: KafooSpacing.lg),
              if (!canCreate)
                Text(
                  l10n.kitchenTalkMissingNote(form),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: KafooColors.textMuted),
                ),
              const SizedBox(height: KafooSpacing.sm),
              FilledButton(
                key: const ValueKey('kitchen-create'),
                onPressed: canCreate && !_creating ? _create : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: _creating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.kitchenConvSummaryConfirm(form)),
              ),

              const SizedBox(height: KafooSpacing.xl),

              // THE TALK BUTTON, 88dp, CENTRED, WITH NOTHING ELSE INSIDE ITS
              // RADIUS. §10.3, and drawn unconditionally — it opens a hosted
              // conversation that brings its own recognition, so no handset
              // language pack decides whether it exists.
              Center(
                child: KafooTalkButton(
                  state: _orbState(state),
                  amplitude: _amplitude,
                  label: _preparing
                      ? l10n.voicePreparing
                      : l10n.kitchenTalkPress(form),
                  enabled: !state.turnInFlight,
                  onPressStart: () => unawaited(_toggleLive()),
                  onPressEnd: () {},
                ),
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
                      key: const ValueKey('kitchen-talk-type'),
                      onPressed: () => setState(() => _typing = true),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(KafooSpacing.minTapTarget),
                      ),
                      child: Text(l10n.mealTalkType(form)),
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
                  key: const ValueKey('kitchen-talk-box'),
                  controller: _saidController,
                  maxLines: 3,
                  minLines: 1,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: l10n.kitchenTalkHint(form),
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
                  child: Text(l10n.kitchenTalkSend),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
