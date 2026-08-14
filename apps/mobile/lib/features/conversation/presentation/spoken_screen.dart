import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../application/assistant_voice.dart';

/// A screen that says what it is for, once, on arrival.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **KAFOO IS VOICE-FIRST AND MOST OF ITS SCREENS WERE SILENT.** The Meal list
/// greeted, the conversations talked, and everything else — signing in, the
/// code, changing a phone number, a Customer reading a Meal — rendered text and
/// said nothing. For a Cook who does not read comfortably, a silent screen is a
/// blank one. §10.2: the assistant speaks first and the screen is the receipt.
///
/// Three rules are enforced here so no screen has to remember them:
///
/// - **Said once, on arrival, not on every rebuild.** A screen that re-reads
///   itself on each keystroke is an assistant talking over the person using it.
/// - **The mute control is always in the bar**, inline-end, 48dp, and persists
///   until reversed. A control the design calls persistent that some screens
///   lack does not persist.
/// - **Nothing is said while muted or on a handset with no Arabic voice**, and
///   the screen still works. Speech is the first way in, never the only one.
/// ─────────────────────────────────────────────────────────────────────────────
class SpokenScreen extends ConsumerStatefulWidget {
  const SpokenScreen({
    required this.title,
    required this.spoken,
    required this.body,
    this.actions = const [],
    this.quiet = false,
    super.key,
  });

  /// The app bar title, already localized.
  final String title;

  /// What the assistant says on arrival, already localized.
  ///
  /// Null says nothing — for a screen whose spoken line depends on data that
  /// has not loaded yet and which speaks for itself once it has.
  final String? spoken;

  /// [quiet] for money and addresses: homes are shared and income is private.
  final bool quiet;

  final Widget body;

  /// Extra bar actions, inline-start of the mute control.
  final List<Widget> actions;

  @override
  ConsumerState<SpokenScreen> createState() => _SpokenScreenState();
}

class _SpokenScreenState extends ConsumerState<SpokenScreen> {
  String? _said;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final voice = ref.watch(assistantVoiceProvider);
    final line = widget.spoken;

    // KEYED ON THE SENTENCE, NOT ON A BOOLEAN. A screen whose line changes when
    // its data arrives — "your kitchen in Maadi" once the profile loads — must
    // say the new one, and must not say the old one twice on the way there.
    if (line != null && line != _said && voice.canSpeak) {
      _said = line;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(assistantVoiceProvider.notifier)
              .say(line, quiet: widget.quiet),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ...widget.actions,
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
      body: SafeArea(child: widget.body),
    );
  }
}
