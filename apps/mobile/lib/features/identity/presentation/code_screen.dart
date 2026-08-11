import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/account_repository.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({
    required this.phone,
    this.repository = const SupabaseAccountRepository(),
    super.key,
  });

  final String phone;

  /// Injected so this screen can be tested at all. It called
  /// `Supabase.instance.client` directly until 2026-08-10, which both violated
  /// the layering rule in `.claude/rules/dart.md` — presentation never touches
  /// Supabase — and made the screen impossible to build under test without a
  /// live backend. It had no test of any kind as a result, and the bug below
  /// shipped.
  final AccountRepository repository;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await widget.repository.verifyPhoneSignInCode(
      phone: widget.phone,
      token: code,
    );
    if (!mounted) return;

    switch (result) {
      case Success(value: final isNew):
        unawaited(emitEvent(
          EventNames.signInCompleted,
          attributes: {'route': 'phone', 'first_time': isNew},
        ));
        if (isNew) unawaited(emitEvent(EventNames.accountCreated));

        // POP BACK TO THE ROOT, AND THIS LINE IS THE WHOLE BUG FIX.
        //
        // The comment here used to read "navigation is handled by the auth
        // state listener in main.dart", and that was wrong in a way nothing
        // could see. The listener does fire and `_AuthGate` does swap the app's
        // home from sign-in to the Cook's home — but this screen was PUSHED on
        // top of that gate, and changing what a route renders does not remove
        // the routes above it. So the Cook was signed in, correctly, behind a
        // full-screen route that nothing dismissed. She pressed «كمّل» and the
        // app did nothing at all.
        //
        // Found by the founder on a real phone on 2026-08-10, after every
        // check in the gate passed.
        Navigator.of(context).popUntil((route) => route.isFirst);

      case Failure(error: final error):
        final l10n = AppLocalizations.of(context);
        final form = context.addressForm;
        final text = switch (error.messageKey) {
          'codeExpired' => l10n.codeExpired(form),
          'signInNetworkError' => l10n.signInNetworkError(form),
          _ => l10n.codeWrongCode(form),
        };
        unawaited(emitEvent(
          EventNames.signInFailed,
          attributes: {
            'route': 'phone',
            'reason': switch (error.messageKey) {
              'codeExpired' => 'expired',
              'signInNetworkError' => 'network',
              _ => 'wrong_code',
            },
          },
        ));
        setState(() {
          _error = text;
          _loading = false;
        });
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await widget.repository.sendPhoneSignInCode(widget.phone);
    } on Exception catch (_) {
      // Best-effort resend; the field stays editable.
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      // SCROLLS, like every other screen on this path. Caught by this screen's
      // own new test at 360x640 with text at 200% — the four sign-in screens were
      // knowingly left unfixed earlier on 2026-08-10 as a scope call, and writing
      // the missing tests is what turned one of them red.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.codeTitle(context.addressForm),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: KafooSpacing.sm),
              Text(l10n.codeSubtitle(widget.phone)),
              const SizedBox(height: KafooSpacing.lg),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                maxLength: 6,
                decoration: InputDecoration(
                  errorText: _error,
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: KafooSpacing.lg),
              FilledButton(
                onPressed: _loading ? null : _verify,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.signInContinue(context.addressForm)),
              ),
              const SizedBox(height: KafooSpacing.sm),
              TextButton(
                onPressed: _resending ? null : _resend,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: Text(l10n.codeResend(context.addressForm)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
