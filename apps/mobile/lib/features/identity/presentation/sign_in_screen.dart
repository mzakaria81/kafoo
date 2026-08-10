import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kafoo_domain/egyptian_phone.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import 'code_screen.dart';
import 'email_sign_in_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Shows an error and says it out loud.
  ///
  /// `errorText` alone renders the message and announces nothing, so a Customer
  /// using a screen reader taps the button and hears silence. Every error on this
  /// screen goes through here so that cannot be true of one of them. The
  /// direction is RTL because the app is pinned to Arabic — see `main.dart`.
  void _showError(String message) {
    setState(() => _error = message);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.rtl,
    );
  }

  Future<void> _submit() async {
    final typed = _phoneController.text.trim();
    if (typed.isEmpty) return;

    // NOBODY IN EGYPT TYPES `+20`, and until 2026-08-10 nothing here turned what
    // they do type into what the authentication service accepts. `01112513196`
    // went across as-is, came back rejected, and was reported as "no internet".
    final phone = normalizeEgyptianMobile(typed);
    if (phone == null) {
      _showError(
        AppLocalizations.of(context).signInPhoneNotMobile(context.addressForm),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    unawaited(emitEvent(
      EventNames.signInStarted,
      attributes: {'route': 'phone'},
    ));

    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CodeScreen(phone: phone),
        ),
      );
    } on AuthException catch (e) {
      // AN ANSWER FROM THE SERVER IS PROOF THE NETWORK WORKS. This branch used
      // to report every refusal as "no internet connection", which contradicted
      // itself: the only way to be refused is to have been heard. It said so on
      // the first build anybody installed, in front of the founder.
      //
      // The wording does not guess WHY the code was not sent — an unknown
      // number, a number that cannot receive SMS, and a messaging provider that
      // is down are indistinguishable from here, and inventing a reason would be
      // the same failure one layer along.
      final l10n = AppLocalizations.of(context);
      if (e.message.contains('rate') || e.statusCode == '429') {
        _showError(l10n.signInRateLimited(context.addressForm));
      } else {
        _showError(l10n.signInCodeNotSent(context.addressForm));
      }
    } on Exception catch (_) {
      // Nothing came back at all. This is the one case where the network really
      // is the likely cause, so it keeps the network message.
      if (!mounted) return;
      _showError(
        AppLocalizations.of(context).signInNetworkError(context.addressForm),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // SCROLLS. Measured at 360x640 with text at 200%: this Column overflowed
      // by the same shape as its siblings once the design system's type scale landed, and an overflowing
      // Column resolves it by clipping its LAST child — the button that submits.
      // A Cook using large text on a cheap Android handset had no reachable
      // control at all.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: KafooSpacing.xl),
              Text(
                l10n.signInTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: KafooSpacing.lg),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.signInPhoneLabel,
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: KafooSpacing.lg),
              FilledButton(
                onPressed: _loading ? null : _submit,
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
              // The second way in, for someone who has lost their number. It
              // names the problem rather than the mechanism: a person new to
              // Kafoo is asked for an email address zero times (SC-009), and
              // the word only appears once they have said they need it.
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmailSignInScreen(),
                  ),
                ),
                child: Text(l10n.signInLostNumber(context.addressForm)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
