import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/identity/data/account_repository.dart';
import 'package:kafoo_mobile/features/identity/presentation/email_sign_in_screen.dart';
import 'package:kafoo_mobile/features/identity/presentation/recovery_email_prompt.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_account_repository.dart';

Widget _testApp(Widget child) {
  return ProviderScope(
    overrides: [speechOutputProvider.overrideWithValue(FakeSpeechOutput())],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

/// Pumps a host that calls [RecoveryEmailPrompt.maybeShow], the way the
/// conversation does once a Kitchen Profile is confirmed.
Future<void> pumpPromptHost(
  WidgetTester tester,
  FakeAccountRepository repo,
) async {
  await tester.pumpWidget(_testApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                RecoveryEmailPrompt.maybeShow(context, repository: repo),
            child: const Text('finish'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('finish'));
  await tester.pumpAndSettle();
}

void main() {
  // SC-009: registration asks for an email address zero times. The sign-in
  // screen is the whole of registration, so this is where it is provable.
  testWidgets('registration completes with zero email prompts', (tester) async {
    await tester.pumpWidget(_testApp(const SignInScreen()));
    await tester.pumpAndSettle();

    // One thing asked for: the phone number.
    expect(find.byType(TextField), findsOneWidget);

    final visibleText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');

    // The lost-number route names the situation, never the mechanism, so a
    // person registering never encounters the word at all.
    expect(visibleText, isNot(contains('email')));
    expect(visibleText, isNot(contains('إيميل')));
    expect(visibleText, isNot(contains('بريد')));
  });

  // SC-010: the invitation stops after the cap. Repeating an ask someone has
  // already refused is a dark pattern the constitution forbids outright.
  testWidgets('the invitation stops being offered after the cap',
      (tester) async {
    final repo = FakeAccountRepository(declines: recoveryEmailDeclineCap);
    await pumpPromptHost(tester, repo);

    expect(find.byType(RecoveryEmailPrompt), findsNothing);
    expect(find.text('تحب تضيف إيميل؟'), findsNothing);
  });

  testWidgets('the invitation is offered while under the cap', (tester) async {
    final repo = FakeAccountRepository(declines: recoveryEmailDeclineCap - 1);
    await pumpPromptHost(tester, repo);

    expect(find.byType(RecoveryEmailPrompt), findsOneWidget);
  });

  testWidgets('declining records the decline and withholds nothing',
      (tester) async {
    final repo = FakeAccountRepository();
    await pumpPromptHost(tester, repo);

    await tester.tap(find.text('مش دلوقتي'));
    await tester.pumpAndSettle();

    expect(repo.declineCalls, 1);
    expect(repo.attachCalls, 0);
    // The sheet is gone and the person is back where they were, with nothing
    // taken away.
    expect(find.byType(RecoveryEmailPrompt), findsNothing);
    expect(find.text('finish'), findsOneWidget);
  });

  testWidgets('someone who already has an address is never invited',
      (tester) async {
    final repo = FakeAccountRepository(email: 'someone@example.test');
    await pumpPromptHost(tester, repo);

    expect(find.byType(RecoveryEmailPrompt), findsNothing);
  });

  // FR-007: an address that was never attached from inside an account cannot
  // claim one. The repository refuses; the screen says so plainly.
  testWidgets('an unattached address cannot claim an identity', (tester) async {
    final repo = FakeAccountRepository(addressIsUnknown: true);
    await tester.pumpWidget(_testApp(EmailSignInScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'stranger@example.test');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.emailCodeCalls, 1);
    expect(
      find.text('الإيميل ده مش مربوط بأي حساب. جرب تدخل برقم موبايلك.'),
      findsOneWidget,
    );
    // No code field appeared: there is nothing to verify against.
    expect(find.byType(TextField), findsOneWidget);
  });
}
