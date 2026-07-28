import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

void main() {
  group('KafooSpacing', () {
    test('the scale ascends', () {
      expect(KafooSpacing.xs, lessThan(KafooSpacing.sm));
      expect(KafooSpacing.sm, lessThan(KafooSpacing.md));
      expect(KafooSpacing.md, lessThan(KafooSpacing.lg));
      expect(KafooSpacing.lg, lessThan(KafooSpacing.xl));
    });

    test('the minimum tap target meets the accessibility floor', () {
      expect(KafooSpacing.minTapTarget, greaterThanOrEqualTo(48));
    });
  });
}
