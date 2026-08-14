import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversation/application/assistant_voice.dart';
import '../../conversation/data/hosted_speech_output.dart';
import '../data/search_consent_store.dart';

/// Kafoo's Settings.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **IT WAS ONE SWITCH, AND THE THING IT WAS MISSING WAS THE VOICE.** Kafoo
/// bought two Cairene voices on 2026-08-11 — Ghozlan and Ahmad, chosen by ear
/// from twenty-five — stored the preference, and taught `speak` to take a role.
/// Then no screen ever offered the choice, so every Cook heard whichever one
/// happened to be the default. DESIGN.md §10.11 says each account chooses for
/// itself; the design package draws the chooser (screenshot 06); the machinery
/// was complete and unreachable.
///
/// **The one-switch rule has not been repealed.** A Settings screen is the most
/// natural home in any app for the next toggle nobody can decide about, and
/// every toggle here is a decision handed to a person instead of made. The voice
/// is the exception the design already carried, not a precedent — the next one
/// is still a stop-and-ask.
///
/// **What the design draws and this does not have:** the speech-rate control and
/// the three switches, one of which reads incoming Messages aloud. Messaging is
/// not built and the hosted engine exposes no rate, so drawing either would be a
/// control that does nothing. `docs/mvp-deferred.md`.
/// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Said once, on arrival — not on every rebuild.
  ///
  /// The screen that decides how the assistant sounds is the last screen that
  /// should be silent. Flipping a switch re-rendering the question aloud would
  /// turn it into a nag.
  bool _greeted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final consent = ref.watch(searchConsentControllerProvider);
    final voice = ref.watch(assistantVoiceProvider);

    if (voice.canSpeak && !_greeted) {
      _greeted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(assistantVoiceProvider.notifier)
              .say(l10n.settingsVoiceQuestion),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          // Every screen that speaks carries the mute control, and this one
          // speaks the moment it opens.
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
            Text(
              l10n.settingsVoiceSection,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: KafooSpacing.xs),
            Text(
              l10n.settingsVoiceQuestion,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: KafooColors.textMuted),
            ),
            const SizedBox(height: KafooSpacing.md),
            if (!voice.canChooseVoice)
              Text(
                l10n.settingsVoiceUnavailable,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              for (final (role, name, note) in [
                (
                  AssistantVoiceRole.female,
                  l10n.settingsVoiceFemale,
                  l10n.settingsVoiceFemaleNote,
                ),
                (
                  AssistantVoiceRole.male,
                  l10n.settingsVoiceMale,
                  l10n.settingsVoiceMaleNote,
                ),
              ]) ...[
                _VoiceCard(
                  name: name,
                  note: note,
                  chosen: voice.voice == role,
                  chosenWord: l10n.settingsVoiceChosen,
                  hearLabel: l10n.settingsVoiceHear(form),
                  // PREVIEW AND CHOOSE ARE TWO DIFFERENT ACTIONS, which is the
                  // whole point of the card. Hearing a voice must not commit
                  // her to it: §10.11 says the choice never changes on its own,
                  // and a preview that silently switched would be the app
                  // changing it for her.
                  onHear: voice.canSpeak
                      ? () => unawaited(
                            ref
                                .read(assistantVoiceProvider.notifier)
                                .preview(role, l10n.settingsVoicePreview),
                          )
                      : null,
                  onChoose: () => unawaited(
                    ref.read(assistantVoiceProvider.notifier).setVoice(
                          role,
                          preview: l10n.settingsVoicePreview,
                        ),
                  ),
                ),
                const SizedBox(height: KafooSpacing.row),
              ],
              Text(
                l10n.settingsVoiceStorageNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(height: KafooSpacing.section),
            SwitchListTile(
              title: Text(l10n.settingsSearchTitle),
              subtitle: Text(l10n.settingsSearchExplanation),
              // Unanswered reads as off, because nothing has been sent yet and
              // that is what the switch describes. Turning it on here IS an
              // answer — SC-015 then holds: the question never appears.
              value: switch (consent) {
                AsyncData(value: final answer) => answer.allowsSearch,
                _ => false,
              },
              // Disabled only while the device's own answer is still being
              // read. A switch that could be flipped before the stored value
              // arrived would overwrite it with whatever it happened to show.
              onChanged: consent.isLoading
                  ? null
                  : (on) => unawaited(
                        ref
                            .read(searchConsentControllerProvider.notifier)
                            .answer(
                              on
                                  ? SearchConsent.granted
                                  : SearchConsent.refused,
                            ),
                      ),
            ),
            const SizedBox(height: KafooSpacing.md),
            // Says where the answer is kept, because "we do not store this" is
            // the part a Customer has no way to verify and every reason to want
            // told. FR-029d.
            Text(
              l10n.settingsSearchStorageNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// One voice, with a way to hear it and a way to choose it.
///
/// Selected draws a 2px `primary` border on `primary-tint` with the glance word
/// «مختار» — the design package's card, and the glance word is from the closed
/// set, so it keeps its size, weight, colour and position wherever it appears.
class _VoiceCard extends StatelessWidget {
  const _VoiceCard({
    required this.name,
    required this.note,
    required this.chosen,
    required this.chosenWord,
    required this.hearLabel,
    required this.onHear,
    required this.onChoose,
  });

  final String name;
  final String note;
  final bool chosen;
  final String chosenWord;
  final String hearLabel;
  final VoidCallback? onHear;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: chosen,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
        decoration: BoxDecoration(
          color: chosen ? KafooColors.primaryTint : KafooColors.surfaceRaised,
          borderRadius: BorderRadius.circular(KafooRadius.panel),
          // Structure that carries meaning uses a border, not a shadow.
          // Shadows disappear in sunlight, which is the room this is used in.
          border: Border.all(
            color: chosen ? KafooColors.primary : KafooColors.border,
            width: chosen ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: chosen ? KafooColors.primaryDeep : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (chosen)
                  KafooGlanceWord(
                    word: GlanceWord.published,
                    text: chosenWord,
                  ),
              ],
            ),
            const SizedBox(height: KafooSpacing.xs),
            Text(
              note,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: KafooColors.textMuted),
            ),
            const SizedBox(height: KafooSpacing.row),
            // Wraps rather than a Row: at 200% text the two controls do not fit
            // side by side on a 320px phone, and a Row resolves that by
            // overflowing.
            Wrap(
              spacing: KafooSpacing.targetGap,
              runSpacing: KafooSpacing.targetGap,
              children: [
                OutlinedButton(
                  onPressed: onHear,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      KafooSpacing.minTapTarget,
                      KafooSpacing.minTapTarget,
                    ),
                    foregroundColor: KafooColors.voiceDeep,
                    side: const BorderSide(
                      color: KafooColors.voiceBorder,
                      width: 1.5,
                    ),
                    backgroundColor: KafooColors.voiceTint,
                  ),
                  child: Text(hearLabel),
                ),
                FilledButton(
                  onPressed: chosen ? null : onChoose,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      KafooSpacing.minTapTarget,
                      KafooSpacing.minTapTarget,
                    ),
                  ),
                  child: Text(name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
