import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/kitchen_profile_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

import 'support/fake_kitchen_profile_repository.dart';

const _profile = KitchenProfile(
  id: 'test-id',
  cookId: 'test-cook',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي',
  area: 'المعادي',
  deliveryTerms: 'توصيل في ساعة',
);

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
  // T044 / US5 scenario 2: the previous version is still the truth, and still
  // on screen, until a change is confirmed.
  testWidgets('previous value stays visible while a change is being made',
      (tester) async {
    final repo = FakeKitchenProfileRepository(existing: _profile);
    await tester.pumpWidget(
      _testApp(KitchenProfileScreen(profile: _profile, repository: repo)),
    );
    await tester.pumpAndSettle();

    expect(find.text('مطبخ أم علي'), findsOneWidget);

    // Open the editor for the kitchen name.
    await tester.tap(find.text('غيّر').first);
    await tester.pumpAndSettle();

    // The current value is shown inside the editor, unchanged.
    expect(find.text('الحالي'), findsOneWidget);
    expect(find.text('مطبخ أم علي'), findsWidgets);

    // Type a replacement but do not confirm it.
    await tester.enterText(find.byType(TextField), 'مطبخ الشام');
    await tester.pump();

    // Nothing has been written.
    expect(repo.updateCalls, 0);

    // Back out — the previous version survives untouched.
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 0);
    expect(find.text('مطبخ أم علي'), findsOneWidget);
    expect(find.text('مطبخ الشام'), findsNothing);
  });

  testWidgets('confirming a change updates only that detail', (tester) async {
    final repo = FakeKitchenProfileRepository(existing: _profile);
    await tester.pumpWidget(
      _testApp(KitchenProfileScreen(profile: _profile, repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('غيّر').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'مطبخ الشام');
    await tester.tap(find.text('احفظ التغيير'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(find.text('مطبخ الشام'), findsOneWidget);
    // Nothing else moved.
    expect(find.text('المعادي'), findsOneWidget);
    expect(find.text('توصيل في ساعة'), findsOneWidget);
  });

  testWidgets('a failed change leaves the previous version on screen',
      (tester) async {
    final repo =
        FakeKitchenProfileRepository(existing: _profile, failUpdates: true);
    await tester.pumpWidget(
      _testApp(KitchenProfileScreen(profile: _profile, repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('غيّر').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'مطبخ الشام');
    await tester.tap(find.text('احفظ التغيير'));
    await tester.pumpAndSettle();

    expect(repo.updateCalls, 1);
    expect(find.text('مطبخ أم علي'), findsOneWidget);
    expect(find.text('مطبخ الشام'), findsNothing);
  });
}
