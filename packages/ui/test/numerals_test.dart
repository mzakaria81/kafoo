import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

void main() {
  group('KafooNumerals.arabicIndic', () {
    test('rewrites the glyphs and nothing else', () {
      expect(KafooNumerals.arabicIndic('35.00'), '٣٥٫٠٠');
      expect(KafooNumerals.arabicIndic('110.00'), '١١٠٫٠٠');
      expect(KafooNumerals.arabicIndic('1,250.50'), '١٬٢٥٠٫٥٠');
    });

    test('leaves words, spaces and punctuation alone', () {
      expect(KafooNumerals.arabicIndic('35 جنيه'), '٣٥ جنيه');
      expect(KafooNumerals.arabicIndic('لا أرقام هنا'), 'لا أرقام هنا');
    });

    test('never changes the value', () {
      // The whole safety argument for transliterating rather than formatting:
      // the digits round-trip exactly, so no price can be rounded, truncated,
      // or re-ordered on its way to a Customer's eyes.
      for (final price in const [
        '0.00',
        '0.05',
        '35.00',
        '99.99',
        '1000.00',
        '12345.67',
      ]) {
        expect(KafooNumerals.latin(KafooNumerals.arabicIndic(price)), price);
      }
    });

    test('a trailing zero survives, because money has two decimal places', () {
      // "٣٥٫٠" and "٣٥٫٠٠" are different amounts of care. `numeric(10,2)`
      // renders both digits and so must the screen.
      expect(KafooNumerals.arabicIndic('35.00'), endsWith('٠٠'));
    });
  });

  group('KafooNumerals.latin', () {
    test('reads back a dictated Arabic-Indic price', () {
      expect(KafooNumerals.latin('٣٥٫٠٠'), '35.00');
      expect(KafooNumerals.latin('١٢٠'), '120');
    });

    test('is a no-op on a price that is already Latin', () {
      expect(KafooNumerals.latin('35.00'), '35.00');
    });
  });
}
