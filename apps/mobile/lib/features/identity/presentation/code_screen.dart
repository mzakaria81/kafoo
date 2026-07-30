import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({required this.phone, super.key});

  final String phone;

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

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: widget.phone,
        token: code,
        type: OtpType.sms,
      );

      final isNew = response.user?.createdAt != null &&
          response.user!.createdAt == response.user!.updatedAt;

      unawaited(emitEvent(
        EventNames.signInCompleted,
        attributes: {'first_time': isNew},
      ));

      if (isNew) {
        unawaited(emitEvent(EventNames.accountCreated));
      }
      // Navigation is handled by the auth state listener in main.dart.
    } on AuthException catch (e) {
      final l10n = AppLocalizations.of(context);
      final msg = e.message.toLowerCase();
      String errorText;
      if (msg.contains('expired') ||
          msg.contains('otp') && msg.contains('invalid')) {
        errorText = l10n.codeExpired;
      } else {
        errorText = l10n.codeWrongCode;
      }
      unawaited(emitEvent(
        EventNames.signInFailed,
        attributes: {
          'reason': msg.contains('expired') ? 'expired' : 'wrong_code'
        },
      ));
      if (mounted) setState(() => _error = errorText);
    } on Exception catch (_) {
      if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).signInNetworkError);
      }
      unawaited(emitEvent(
        EventNames.signInFailed,
        attributes: {'reason': 'network'},
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: widget.phone);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.codeTitle,
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
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.signInContinue),
              ),
              const SizedBox(height: KafooSpacing.sm),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(l10n.codeResend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
