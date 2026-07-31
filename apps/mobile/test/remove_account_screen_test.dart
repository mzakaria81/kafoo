import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/identity/presentation/remove_account_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_account_repository.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  // FR-034: one confirmation, no bargaining. A reason field, a retention
  // offer, or a second "are you sure?" would each be a dark pattern in a
  // cancellation flow — product-fatal under the trust rules, not a UX nit.
  testWidgets('asks once, with no reason field and no retention offer',
      (tester) async {
    final repo = FakeAccountRepository();
    await tester.pumpWidget(_testApp(RemoveAccountScreen(repository: repo)));
    await tester.pumpAndSettle();

    // Nothing to fill in on the way out.
    expect(find.byType(TextField), findsNothing);

    // Exactly two choices: leave, or go back.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });

  // FR-035: abandonable part-way, with nothing changed.
  testWidgets('backing out removes nothing', (tester) async {
    final repo = FakeAccountRepository();
    await tester.pumpWidget(_testApp(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RemoveAccountScreen(repository: repo),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();

    expect(repo.removeCalls, 0);
    expect(find.text('open'), findsOneWidget);
  });

  // A failure must never leave someone unsure whether they are half-erased.
  testWidgets('a failed removal says the account is unchanged', (tester) async {
    final repo = FakeAccountRepository(fails: true);
    await tester.pumpWidget(_testApp(RemoveAccountScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('امسح حسابي'));
    await tester.pumpAndSettle();

    expect(repo.removeCalls, 1);
    expect(
      find.text('مقدرناش نمسح الحساب. حسابك زي ما هو، جرب تاني.'),
      findsOneWidget,
    );
  });
}
