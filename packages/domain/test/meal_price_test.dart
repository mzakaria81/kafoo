import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

/// THE PRICE AS AN EGYPTIAN COOK TYPES IT.
///
/// Every case below «١٢٠» is a case that reached the founder's phone on
/// 2026-08-11 as «مقدرناش نحفظ الأكلة» — we could not save the Meal — for a Meal
/// that was fine. An Arabic keyboard produces Arabic-Indic digits, `price` is
/// `numeric(10,2)`, and Postgres answers `invalid input syntax for type
/// numeric: "١٢٠"`.
void main() {
  group('the digits an Arabic keyboard produces', () {
    test('Arabic-Indic digits become a price', () {
      // The defect, in one assertion. This returned null — no, worse: the raw
      // string went to Postgres and came back as an unactionable save failure.
      expect(parseMealPrice('١٢٠'), '120');
    });

    test('Extended Arabic-Indic digits become a price', () {
      // Persian and Urdu keyboards. Not the target market, and no reason to
      // refuse someone who has one.
      expect(parseMealPrice('۱۲۰'), '120');
    });

    test('Latin digits are unchanged', () {
      expect(parseMealPrice('120'), '120');
    });

    test('mixed digits are accepted rather than half-read', () {
      // A Cook who switches keyboards mid-number. Reading only the Latin half
      // would send `12` to the database and charge a fifth of the price.
      expect(parseMealPrice('١٢0'), '120');
    });
  });

  group('the price as it is written rather than as a number', () {
    test('the currency the hint asked for is not an error', () {
      // «سعر الطبق كامل بالجنيه» invites this. Refusing it would be Kafoo
      // rejecting a correct answer to its own question.
      expect(parseMealPrice('١٢٠ جنيه'), '120');
      expect(parseMealPrice('120 EGP'), '120');
      expect(parseMealPrice('120 ج.م'), '120');
    });

    test('the Arabic decimal separator is a decimal point', () {
      expect(parseMealPrice('١٢٠٫٥٠'), '120.50');
    });

    test('thousands separators are dropped', () {
      expect(parseMealPrice('1,200'), '1200');
      expect(parseMealPrice('١٢٠٠'), '1200');
    });

    test('surrounding space and bidi marks are dropped', () {
      // A paste from a browser carries a right-to-left mark, invisibly.
      expect(parseMealPrice('  ‏120‎ '), '120');
    });

    test('two decimal places are kept exactly, never rounded', () {
      // `numeric(10,2)` and `publicMealPriceValue` both pass the stored text
      // through. A price that arrives as 99.99 must reach a Customer as 99.99.
      expect(parseMealPrice('99.99'), '99.99');
    });
  });

  group('what is not a price', () {
    test('words are not a price', () {
      expect(parseMealPrice('كام'), isNull);
      expect(parseMealPrice('مية وعشرين'), isNull);
    });

    test('empty is not a price', () {
      expect(parseMealPrice(''), isNull);
      expect(parseMealPrice('   '), isNull);
    });

    test('zero and below are not a price', () {
      // `CHECK (price > 0)`. Rejecting it here is what turns the database's
      // opaque refusal into a sentence the Cook can act on.
      expect(parseMealPrice('0'), isNull);
      expect(parseMealPrice('٠'), isNull);
      expect(parseMealPrice('-5'), isNull);
      expect(parseMealPrice('0.00'), isNull);
    });

    test('more precision than the column holds is refused, not rounded', () {
      // Postgres would round 120.567 to 120.57 silently. Silently changing a
      // Cook's price is worse than asking her to write it again.
      expect(parseMealPrice('120.567'), isNull);
    });

    test('a number too large for the column is refused here', () {
      // `numeric(10,2)` holds eight digits before the point. A ninth is a
      // numeric overflow, which surfaces as the same opaque failure.
      expect(parseMealPrice('999999999'), isNull);
      expect(parseMealPrice('99999999'), '99999999');
    });

    test('two decimal points are not a price', () {
      expect(parseMealPrice('12.3.4'), isNull);
    });
  });

  group('digits on their own, for the numbers that are not the price', () {
    // Correcting the calorie estimate on the summary runs `int.tryParse`, and
    // `int.tryParse('٣٥٠')` is null — so «٣٥٠» was silently discarded and the AI
    // Assistant's own estimate came back. Same cause as the price, quieter.
    test('Arabic digits become digits Dart can parse', () {
      expect(int.tryParse(normalizeArabicDigits('٣٥٠')), 350);
      expect(int.tryParse(normalizeArabicDigits('۳۵۰')), 350);
      expect(int.tryParse(normalizeArabicDigits('350')), 350);
    });

    test('everything that is not a digit is left alone', () {
      // Deliberately not a sanitiser. It rewrites digits and nothing else, so
      // it is safe to run over any answer without changing what she said.
      expect(normalizeArabicDigits('كشري ٢ نفر'), 'كشري 2 نفر');
      expect(normalizeArabicDigits('عدس ورز'), 'عدس ورز');
    });

    test('words stay unparseable rather than becoming a number', () {
      expect(int.tryParse(normalizeArabicDigits('كتير')), isNull);
    });
  });
}
