import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../data/account_repository.dart';

/// Leaving Kafoo.
///
/// One confirmation and nothing else. FR-034: no reason field, no retention
/// offer, no second "are you sure?", no guilt. FR-035: abandonable part-way —
/// the back button and Cancel both leave with nothing changed.
///
/// This screen deliberately contains no persuasion. If a future change adds a
/// "before you go..." step, an offer, or a survey, that change is a dark
/// pattern in a cancellation flow and is product-fatal per the trust rules.
class RemoveAccountScreen extends StatefulWidget {
  const RemoveAccountScreen({
    this.repository = const SupabaseAccountRepository(),
    super.key,
  });

  final AccountRepository repository;

  @override
  State<RemoveAccountScreen> createState() => _RemoveAccountScreenState();
}

class _RemoveAccountScreenState extends State<RemoveAccountScreen> {
  bool _removing = false;
  String? _error;

  Future<void> _remove() async {
    setState(() {
      _removing = true;
      _error = null;
    });

    final result = await widget.repository.removeAccount();
    if (!mounted) return;

    switch (result) {
      case Success():
        // The auth state listener in main.dart takes it from here: with no
        // session, the app returns to sign-in on its own.
        Navigator.of(context).popUntil((route) => route.isFirst);
      case Failure():
        setState(() {
          _removing = false;
          _error = AppLocalizations.of(context)
              .removeAccountError(context.addressForm);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.removeAccountTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.removeAccountBody, style: theme.textTheme.bodyLarge),
              if (_error != null) ...[
                const SizedBox(height: KafooSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _removing ? null : _remove,
                style: FilledButton.styleFrom(
                  backgroundColor: KafooColors.danger,
                  foregroundColor: KafooColors.onPrimary,
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: _removing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.removeAccountConfirm(context.addressForm)),
              ),
              const SizedBox(height: KafooSpacing.sm),
              TextButton(
                onPressed: _removing ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: Text(l10n.removeAccountCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
