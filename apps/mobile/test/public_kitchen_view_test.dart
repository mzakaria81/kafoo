import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/public_kitchen_view.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';

const _profile = KitchenProfile(
  id: 'b7c1d2e3-0000-4000-8000-000000000001',
  cookId: 'a1b2c3d4-0000-4000-8000-000000000002',
  displayName: 'مطبخ أم علي',
  story: 'بنطبخ أكل بيتي زي زمان',
  area: 'المعادي',
  deliveryTerms: 'توصيل في نص ساعة',
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
  // FR-019: the public face is exactly five details.
  testWidgets('renders the five public details', (tester) async {
    await tester
        .pumpWidget(_testApp(const PublicKitchenView(profile: _profile)));
    await tester.pumpAndSettle();

    // Display name appears in the title and as the heading.
    expect(find.text('مطبخ أم علي'), findsWidgets);
    expect(find.text('بنطبخ أكل بيتي زي زمان'), findsOneWidget);
    expect(find.text('المعادي'), findsOneWidget);
    expect(find.text('توصيل في نص ساعة'), findsOneWidget);
    // The photo is the fifth: absent here, and the view still renders.
    expect(find.byType(KitchenPhoto), findsNothing);
  });

  // FR-019 / FR-020: nothing else about the Cook is reachable through it. The
  // identifiers that would let someone look the Cook up must never be rendered.
  testWidgets('exposes no identifier and no phone number by any route',
      (tester) async {
    await tester
        .pumpWidget(_testApp(const PublicKitchenView(profile: _profile)));
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');

    expect(rendered, isNot(contains(_profile.cookId)));
    expect(rendered, isNot(contains(_profile.id)));
    // No digit sequence long enough to be a phone number.
    expect(RegExp(r'\d{7,}').hasMatch(rendered), isFalse);
  });

  // Asserting on the KitchenPhoto widget rather than a decoded image keeps
  // this a test of the branch, not of the network — Image.network cannot
  // resolve under the test binding.
  testWidgets('shows the photo only when the Cook has one', (tester) async {
    await tester
        .pumpWidget(_testApp(const PublicKitchenView(profile: _profile)));
    await tester.pumpAndSettle();
    expect(find.byType(KitchenPhoto), findsNothing);

    await tester.pumpWidget(_testApp(
      const PublicKitchenView(
        profile: _profile,
        photoUrl: 'https://example.test/kitchen.jpg',
      ),
    ));
    await tester.pump();
    expect(find.byType(KitchenPhoto), findsOneWidget);
  });
}
