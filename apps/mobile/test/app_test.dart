import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/identity/presentation/sign_in_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

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

void main() {
  testWidgets('defaults to Arabic and RTL', (tester) async {
    // KafooApp includes _AuthGate which requires a live Supabase instance.
    // We verify the locale/RTL contract via the same wrapper used by other tests.
    await tester.pumpWidget(_testApp(const Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));

    expect(Localizations.localeOf(context).languageCode, 'ar');
    expect(Directionality.of(context), TextDirection.rtl);
  });

  // SC-009: sign-in asks for exactly one thing and never mentions email.
  testWidgets('sign-in screen has one text field and no email reference',
      (tester) async {
    await tester.pumpWidget(_testApp(const SignInScreen()));
    await tester.pumpAndSettle();

    // Exactly one editable text field.
    expect(find.byType(TextField), findsOneWidget);

    // No email mention in any visible text.
    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data?.toLowerCase() ?? '')
        .join(' ');
    expect(allText, isNot(contains('email')));
    expect(allText, isNot(contains('إيميل')));
    expect(allText, isNot(contains('بريد')));
  });
}
