import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/account_repository.dart';

/// Signing in by email — the second way in, for someone who has lost their
/// number.
///
/// Reached only from the lost-number route on the sign-in screen, never from
/// registration: a person new to Kafoo is asked for an email address zero
/// times (SC-009).
///
/// This route reaches the identity the address was attached to, and can create
/// nothing. An address that was never attached from inside an account cannot
/// claim one here (FR-007).
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({
    this.repository = const SupabaseAccountRepository(),
    super.key,
  });

  final AccountRepository repository;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    unawaited(emitEvent(
      EventNames.signInStarted,
      attributes: {'route': 'email'},
    ));

    final result = await widget.repository.sendEmailSignInCode(email);
    if (!mounted) return;

    switch (result) {
      case Success():
        setState(() {
          _busy = false;
          _codeSent = true;
        });
      case Failure(error: final error):
        unawaited(emitEvent(
          EventNames.signInFailed,
          attributes: {'route': 'email', 'reason': 'unknown_address'},
        ));
        setState(() {
          _busy = false;
          _error = error.messageKey == 'emailSignInUnknown'
              ? AppLocalizations.of(context)
                  .emailSignInUnknown(context.addressForm)
              : AppLocalizations.of(context)
                  .signInNetworkError(context.addressForm);
        });
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.repository.verifyEmailSignInCode(
      email: _emailController.text.trim(),
      token: code,
    );
    if (!mounted) return;

    switch (result) {
      case Success():
        // The auth state listener in main.dart takes it from here, landing on
        // the same identity — including any Kitchen Profile — rather than a
        // second, empty one.
        unawaited(emitEvent(
          EventNames.signInCompleted,
          attributes: {'route': 'email', 'first_time': false},
        ));
      case Failure():
        unawaited(emitEvent(
          EventNames.signInFailed,
          attributes: {'route': 'email', 'reason': 'wrong_code'},
        ));
        setState(() {
          _busy = false;
          _error =
              AppLocalizations.of(context).codeWrongCode(context.addressForm);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.emailSignInTitle(context.addressForm))),
      // SCROLLS. Measured at 360x640 with text at 200%: this Column overflowed
      // by more than a screen once the design system's type scale landed, and an overflowing
      // Column resolves it by clipping its LAST child — the button that submits.
      // A Cook using large text on a cheap Android handset had no reachable
      // control at all.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.emailSignInBody(context.addressForm)),
              const SizedBox(height: KafooSpacing.lg),
              TextField(
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.emailSignInLabel,
                  errorText: _codeSent ? null : _error,
                ),
                onSubmitted: (_) => _sendCode(),
              ),
              if (_codeSent) ...[
                const SizedBox(height: KafooSpacing.lg),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: l10n.codeTitle(context.addressForm),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _verify(),
                ),
              ],
              const SizedBox(height: KafooSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.signInContinue(context.addressForm)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
