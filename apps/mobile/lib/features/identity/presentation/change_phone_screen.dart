import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/account_repository.dart';

/// Moving an identity to a new phone number (FR-026).
///
/// This is the flow that makes a lost or recycled number recoverable rather
/// than terminal. A Person is not their phone number — the number is a
/// credential attached to them — so changing it keeps the Kitchen Profile and
/// everything else, and the old number stops reaching the identity the moment
/// the new one is confirmed.
class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({
    this.repository = const SupabaseAccountRepository(),
    super.key,
  });

  final AccountRepository repository;

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestChange() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.repository.changePhoneNumber(phone);
    if (!mounted) return;

    switch (result) {
      case Success():
        setState(() {
          _busy = false;
          _codeSent = true;
        });
      case Failure():
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).changePhoneError;
        });
    }
  }

  Future<void> _confirmChange() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.repository.verifyPhoneChange(
      phone: _phoneController.text.trim(),
      token: code,
    );
    if (!mounted) return;

    switch (result) {
      case Success():
        // Also a takeover signal: a number moving is worth being able to see
        // in aggregate, without recording whose or to what.
        unawaited(emitEvent(EventNames.phoneNumberChanged));
        final message = AppLocalizations.of(context).changePhoneDone;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      case Failure():
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).changePhoneError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePhoneTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.changePhoneBody),
              const SizedBox(height: KafooSpacing.lg),
              TextField(
                controller: _phoneController,
                enabled: !_codeSent,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.changePhoneLabel,
                  errorText: _codeSent ? null : _error,
                ),
                onSubmitted: (_) => _requestChange(),
              ),
              if (_codeSent) ...[
                const SizedBox(height: KafooSpacing.lg),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: l10n.codeTitle,
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _confirmChange(),
                ),
              ],
              const SizedBox(height: KafooSpacing.lg),
              FilledButton(
                onPressed: _busy
                    ? null
                    : (_codeSent ? _confirmChange : _requestChange),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.signInContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
