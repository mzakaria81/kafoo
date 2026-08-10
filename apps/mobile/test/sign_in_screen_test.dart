// THE SCREEN MUST NOT SEND A NUMBER IT CAN ALREADY SEE IS WRONG.
//
// This covers the half of sign-in that needs no server: a number typed the way
// an Egyptian types one is accepted, and a number that could never receive an
// SMS is refused here with a sentence about the number. Neither path reaches
// Supabase, which is why they can be tested at all — everything past
// `signInWithOtp` needs a live client this screen reaches through a singleton.
//
// The bug being locked down: `01112513196` — the only form anybody in Egypt
// writes — used to go across unchanged, be rejected, and be reported as "no
// internet connection", on a phone whose internet was working.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

Widget _app() => const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar'), Locale('en')],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SignInScreen(),
    );

void main() {
  testWidgets('a number that cannot receive an SMS is refused on the spot',
      (tester) async {
    await tester.pumpWidget(_app());
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    // A Cairo landline. It reaches a person and it cannot reach a code.
    await tester.enterText(find.byType(TextField), '0223456789');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text(l10n.signInPhoneNotMobile('other')), findsOneWidget);

    // The message must be about the number. Saying the internet is down in
    // front of somebody whose internet is working is the whole defect.
    expect(find.text(l10n.signInNetworkError('other')), findsNothing);
  });

  // NO TEST HERE FOR `01112513196` BEING ACCEPTED, and the reason is worth
  // stating rather than leaving as a gap. Accepting it means calling
  // `signInWithOtp`, which this screen reaches through `Supabase.instance` — a
  // singleton with no live client in a widget test. It throws an `Error` rather
  // than an `Exception`, so it escapes both catch clauses and fails the test for
  // a reason that has nothing to do with the number.
  //
  // `packages/domain/test/egyptian_phone_test.dart` covers every form an
  // Egyptian writes, against the same function this screen calls. Testing the
  // rule where the rule lives beats faking a singleton to observe it here.

  testWidgets('an empty field does nothing at all', (tester) async {
    await tester.pumpWidget(_app());
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text(l10n.signInPhoneNotMobile('other')), findsNothing);
  });
}
