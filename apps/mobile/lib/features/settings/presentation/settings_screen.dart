import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../data/search_consent_store.dart';

/// Kafoo's Settings, which is one switch.
///
/// **Adding a screen and adding a settings toggle are both stop-and-ask
/// triggers, and the founder asked for both explicitly on 2026-08-06.** It
/// exists because FR-029c requires a Customer to be able to change their answer
/// at any time, in one place, in both directions — and a question asked once at
/// the first search has nowhere else to live.
///
/// **Keep it to the one switch.** A Settings screen is the most natural home in
/// any app for the next toggle somebody cannot decide about, and every toggle
/// added here is a decision handed to a Customer instead of made. The next one
/// is another stop-and-ask, not a follow-on.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(searchConsentControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
          children: [
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
