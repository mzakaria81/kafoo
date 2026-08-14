import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversation/presentation/read_back_gate.dart';
import '../data/account_repository.dart';

/// Leaving Kafoo.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THE SCREEN IS THE GATE, AND THAT IS THE ONLY SHAPE THAT SATISFIES BOTH
/// RULES.** FR-034 allows exactly one confirmation — no reason field, no
/// retention offer, no second «متأكد؟», no guilt. `business-rules.md` says an
/// irreversible action is read back aloud in full and waits for «أيوة».
///
/// A warning screen with a confirm button that then pushed a gate would be two
/// confirmations. A warning screen with a silent button would be the most
/// irreversible thing in the product going through without a word, on an app
/// that talks to a Cook who may not read comfortably. So the read-back IS the
/// screen: it says the whole warning aloud, repeats it once after eight seconds,
/// and then waits indefinitely. Silence never confirms.
///
/// **There is no persuasion here and there must never be.** If a later change
/// adds a "before you go…" step, an offer, or a survey, that change is a dark
/// pattern in a cancellation flow and is product-fatal per the trust rules.
/// FR-035: the back gesture and «رجوع» both leave with nothing changed.
/// ─────────────────────────────────────────────────────────────────────────────
class RemoveAccountScreen extends ConsumerStatefulWidget {
  const RemoveAccountScreen({
    this.repository = const SupabaseAccountRepository(),
    super.key,
  });

  final AccountRepository repository;

  @override
  ConsumerState<RemoveAccountScreen> createState() =>
      _RemoveAccountScreenState();
}

class _RemoveAccountScreenState extends ConsumerState<RemoveAccountScreen> {
  bool _removing = false;
  String? _error;

  void _answer({required bool confirmed}) =>
      unawaited(_remove(confirmed: confirmed));

  Future<void> _remove({required bool confirmed}) async {
    if (!confirmed) {
      Navigator.of(context).pop();
      return;
    }
    if (_removing) return;

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
        // THE GATE STAYS UP. Nothing was deleted, so she is still deciding, and
        // a gate that closed on a failure would look exactly like one that
        // succeeded — on the single action where that confusion is worst.
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
    final form = context.addressForm;

    return ReadBackGateScreen(
      // The whole warning, in full, as the sentence she is agreeing to. Not a
      // summary: «هيتمسح حسابك وكل حاجة فيه» is the thing that cannot be undone.
      readback: l10n.removeAccountBody,
      question: l10n.removeAccountQuestion,
      confirmLabel: l10n.removeAccountConfirm(form),
      rejectLabel: l10n.removeAccountCancel,
      onAnswered: _answer,
      error: _error,
      busy: _removing,
    );
  }
}
