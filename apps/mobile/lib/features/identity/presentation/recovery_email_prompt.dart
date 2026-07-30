import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/account_repository.dart';

/// Invites a person to attach an email address, once they have something a
/// lost number would cost them.
///
/// Shown **after** a Kitchen Profile is confirmed, never during registration
/// (FR-028) — taxing the flow that is meant to be immediate is the whole
/// mistake this timing avoids. Declining withholds nothing (FR-029), and after
/// [recoveryEmailDeclineCap] declines it is not offered again (SC-010).
///
/// Call [maybeShow] rather than pushing this directly: the decision about
/// whether to ask at all belongs with the asking.
class RecoveryEmailPrompt extends StatefulWidget {
  const RecoveryEmailPrompt({required this.repository, super.key});

  final AccountRepository repository;

  /// Shows the invitation if it is still allowed to be shown. Returns without
  /// doing anything otherwise — silently, because someone who has declined
  /// should see no trace of the thing they refused.
  static Future<void> maybeShow(
    BuildContext context, {
    AccountRepository repository = const SupabaseAccountRepository(),
  }) async {
    if (!repository.mayOfferRecoveryEmail()) return;

    unawaited(emitEvent(EventNames.recoveryEmailOffered));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Dismissing by tapping away is a decline like any other, so the sheet
      // must not trap anyone.
      builder: (_) => RecoveryEmailPrompt(repository: repository),
    );
  }

  @override
  State<RecoveryEmailPrompt> createState() => _RecoveryEmailPromptState();
}

class _RecoveryEmailPromptState extends State<RecoveryEmailPrompt> {
  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.repository.attachRecoveryEmail(email);
    if (!mounted) return;

    switch (result) {
      case Success():
        unawaited(emitEvent(EventNames.recoveryEmailAttached));
        final message = AppLocalizations.of(context).recoveryEmailAttached;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      case Failure():
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).recoveryEmailError;
        });
    }
  }

  Future<void> _decline() async {
    final result = await widget.repository.declineRecoveryEmail();
    final times = switch (result) {
      Success(value: final count) => count,
      Failure() => widget.repository.declineCount() + 1,
    };
    unawaited(emitEvent(
      EventNames.recoveryEmailDeclined,
      attributes: {'times_declined': times},
    ));
    // Declining never fails from the person's point of view. If recording it
    // did not stick, they are asked once more — which is a smaller harm than
    // an error message for having said no.
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: KafooSpacing.lg,
        end: KafooSpacing.lg,
        top: KafooSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + KafooSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.recoveryEmailTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: KafooSpacing.sm),
          Text(l10n.recoveryEmailBody, style: theme.textTheme.bodyMedium),
          const SizedBox(height: KafooSpacing.lg),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.recoveryEmailLabel,
              errorText: _error,
            ),
            onSubmitted: (_) => _attach(),
          ),
          const SizedBox(height: KafooSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _attach,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
            ),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.recoveryEmailAttach),
          ),
          const SizedBox(height: KafooSpacing.sm),
          // Declining is a first-class choice, not a greyed-out afterthought.
          TextButton(
            onPressed: _busy ? null : _decline,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
            ),
            child: Text(l10n.recoveryEmailDecline),
          ),
        ],
      ),
    );
  }
}
