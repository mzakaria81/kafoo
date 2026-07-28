import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/main.dart';

void main() {
  testWidgets('defaults to Arabic and RTL', (tester) async {
    await tester.pumpWidget(const KafooApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));

    expect(Localizations.localeOf(context).languageCode, 'ar');
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
