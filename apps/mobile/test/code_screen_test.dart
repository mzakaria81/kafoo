import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/identity/presentation/code_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';

import 'support/fake_account_repository.dart';

/// THE SCREEN THAT HAD NO TEST, AND THE BUG THAT SHIPPED BECAUSE OF IT.
///
/// On 2026-08-10 the founder signed in on a real phone with a correct code and
/// the app did nothing visible. He was signed in — the session existed — behind
/// a full-screen route that nothing dismissed. `code_screen.dart` had a comment
/// saying "navigation is handled by the auth state listener in main.dart", which
/// was wrong: the listener changes what the ROOT route renders and cannot remove
/// routes pushed above it.
///
/// This file had no equivalent before. The release-engineer review that morning
/// said so in terms — real conditional states, zero coverage — and it was right.
///
/// The first test below is the regression test for that bug, and it fails if the
/// pop is removed.
const _phone = '+201000000002';

Widget _app(Widget child) => MaterialApp(
      theme: kafooTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // A recognisable root, so "did it pop back to the start" is an assertion
      // about the navigator rather than about a screen's contents.
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => child),
              ),
              child: const Text('ROOT'),
            ),
          ),
        ),
      ),
    );

/// Pushes the code screen from the root, so popping has somewhere to land.
Future<void> _open(WidgetTester tester, FakeAccountRepository repo) async {
  await tester.pumpWidget(_app(CodeScreen(phone: _phone, repository: repo)));
  await tester.tap(find.text('ROOT'));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  testWidgets('a correct code leaves the sign-in screens behind',
      (tester) async {
    // THE REGRESSION TEST. Delete the popUntil in code_screen.dart and this
    // fails: the Cook stays on the code screen forever, signed in and unable to
    // tell. Verified red against the unfixed code.
    final repo = FakeAccountRepository();
    await _open(tester, repo);

    await tester.enterText(find.byType(TextField), '000002');
    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(repo.verified, ['000002']);
    expect(
      find.byType(CodeScreen),
      findsNothing,
      reason: 'The code was accepted and the screen is still on top. That is '
          'the bug the founder hit: signed in, behind a route nothing removed.',
    );
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('a wrong code says so and stays put', (tester) async {
    final repo = FakeAccountRepository()
      ..failVerifyWith = const AppError(messageKey: 'codeWrongCode');
    await _open(tester, repo);

    await tester.enterText(find.byType(TextField), '111111');
    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.codeWrongCode('other')), findsOneWidget);
    expect(
      find.byType(CodeScreen),
      findsOneWidget,
      reason: 'A rejected code must not navigate anywhere.',
    );
  });

  testWidgets('an expired code says expired, not wrong', (tester) async {
    // Different words on purpose: "the code is wrong" tells a Cook to look at
    // her fingers, "the code expired" tells her to ask for another one.
    final repo = FakeAccountRepository()
      ..failVerifyWith = const AppError(messageKey: 'codeExpired');
    await _open(tester, repo);

    await tester.enterText(find.byType(TextField), '000002');
    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.codeExpired('other')), findsOneWidget);
    expect(find.text(l10n.codeWrongCode('other')), findsNothing);
  });

  testWidgets('a network failure blames the network, not the code',
      (tester) async {
    final repo = FakeAccountRepository()
      ..failVerifyWith = const AppError(messageKey: 'signInNetworkError');
    await _open(tester, repo);

    await tester.enterText(find.byType(TextField), '000002');
    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.signInNetworkError('other')), findsOneWidget);
  });

  testWidgets('the button is disabled while verifying', (tester) async {
    // The gate is the test. Without it the call resolves in the same microtask,
    // the in-flight frame never renders, and this passes while asserting
    // nothing.
    final gate = Completer<void>();
    final repo = FakeAccountRepository()..gate = gate;
    await _open(tester, repo);

    await tester.enterText(find.byType(TextField), '000002');
    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.onPressed,
      isNull,
      reason: 'A second tap while the first is in flight asks the server to '
          'verify the same code twice, and the second answer is a failure.',
    );

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('asking for a new code sends to the same number', (tester) async {
    final repo = FakeAccountRepository();
    await _open(tester, repo);

    await tester.tap(find.text(l10n.codeResend('other')));
    await tester.pumpAndSettle();

    expect(repo.sentTo, [_phone]);
  });

  testWidgets('an empty code asks the server nothing', (tester) async {
    final repo = FakeAccountRepository();
    await _open(tester, repo);

    await tester.tap(find.text(l10n.signInContinue('other')));
    await tester.pumpAndSettle();

    expect(repo.verified, isEmpty);
    expect(find.byType(CodeScreen), findsOneWidget);
  });

  testWidgets('it does not clip at 200% text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child:
          _app(CodeScreen(phone: _phone, repository: FakeAccountRepository())),
    ));
    await tester.tap(find.text('ROOT'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
