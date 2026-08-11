/// A price as somebody actually typed it, turned into something the `price`
/// column will accept.
///
/// **WHY THIS EXISTS.** On 2026-08-11 the founder answered the price question
/// with «١٢٠» and was told «مقدرناش نحفظ الأكلة» — we could not save the Meal.
/// Nothing was wrong with the Meal. `price` is `numeric(10,2)`, the answer was
/// sent to Postgres as the text the Cook typed, and Postgres refuses
/// `invalid input syntax for type numeric: "١٢٠"`. Those are the Arabic-Indic
/// digits an Arabic keyboard produces — which is to say the digits an Egyptian
/// Cook types by default, on the one question in this product that is a number.
///
/// The failure was total: every Cook typing in Arabic, every price, every time.
/// It shipped because every test typed `'35'` in Latin digits, so the whole
/// suite was answering the price question the way a developer would rather than
/// the way the person the product is for does.
///
/// **The rule is one function, not a guard at each caller.** The price reaches
/// the database from three places — the conversation, a correction on the
/// summary, and editing a published Meal — and a fourth will arrive. A copy per
/// caller is three chances to leave one out.
library;

/// The digits of the four keyboards this reaches, mapped to what Postgres reads.
///
/// Arabic-Indic (٠-٩) is the Egyptian keyboard. Extended Arabic-Indic (۰-۹) is
/// Persian and Urdu, and costs one line to accept rather than reject.
const int _arabicIndicZero = 0x0660;
const int _extendedArabicIndicZero = 0x06F0;
const int _asciiZero = 0x30;

/// The Arabic decimal separator, ٫ — a decimal point, not punctuation to drop.
const int _arabicDecimalSeparator = 0x066B;

/// Currency, spelled the several ways it gets typed after a number.
///
/// The hint under the question says «سعر الطبق كامل بالجنيه» — the whole dish,
/// in pounds — so a Cook writing «١٢٠ جنيه» is answering it correctly and must
/// not be corrected for doing so.
final RegExp _currency = RegExp(
  r'جنيهات|جنيها|جنيه|جنية|ج\.?\s?م|£|EGP|LE',
  caseSensitive: false,
);

/// Separators and invisible marks that travel with typed or pasted Arabic:
/// spaces, the Arabic thousands separator ٬, commas, and the bidi marks a
/// paste from a browser carries.
///
/// Written as escapes on purpose: three of these characters are invisible, and
/// an invisible character in a character class is a character class nobody can
/// review.
final RegExp _grouping = RegExp(
  '['
  ' \\t' // space, tab
  '\\u00A0' // non-breaking space
  '\\u200E\\u200F' // left-to-right and right-to-left marks
  '\\u066C' // Arabic thousands separator
  '\\u060C' // Arabic comma
  ",'" // Latin thousands separators
  ']',
);

/// Eight digits before the point and two after, which is exactly
/// `numeric(10,2)`. A ninth digit is not a price we should be sending: Postgres
/// answers a numeric overflow with the same opaque failure as bad syntax.
final RegExp _canonical = RegExp(r'^\d{1,8}(\.\d{1,2})?$');

/// The same text with every Arabic digit rewritten as the digit Dart and
/// Postgres recognise. Everything else is left exactly as it was.
///
/// **Separate from [parseMealPrice] because the price is not the only number a
/// Cook types.** Correcting the calorie estimate on the summary ran
/// `int.tryParse` on her answer, and `int.tryParse('٣٥٠')` is null in Dart — so
/// «٣٥٠» was not refused, it was *discarded*: the row closed, the AI Assistant's
/// own estimate came back, and nothing said why. Same cause as the price
/// failure, quieter symptom, and the worse of the two — a Cook could publish a
/// calorie figure she had already corrected.
String normalizeArabicDigits(String input) {
  final digits = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= _arabicIndicZero && rune <= _arabicIndicZero + 9) {
      digits.writeCharCode(_asciiZero + rune - _arabicIndicZero);
    } else if (rune >= _extendedArabicIndicZero &&
        rune <= _extendedArabicIndicZero + 9) {
      digits.writeCharCode(_asciiZero + rune - _extendedArabicIndicZero);
    } else if (rune == _arabicDecimalSeparator) {
      digits.write('.');
    } else {
      digits.writeCharCode(rune);
    }
  }
  return digits.toString();
}

/// The canonical price string, or null when what was typed is not a price.
///
/// Returns the exact text to send to the database — never a number, because
/// `price` is a decimal and Dart's `double` is not. Kafoo stores what the Cook
/// said and reads it back as text (`publicMealPriceValue` passes it straight
/// through), so nothing here may round.
///
/// Null means "tell the Cook, do not attempt the write". A price that cannot be
/// parsed is the one failure in this flow the Cook can actually fix, and
/// «مقدرناش نحفظ الأكلة» tells her nothing she can act on.
String? parseMealPrice(String input) {
  final stripped = normalizeArabicDigits(input)
      .replaceAll(_currency, '')
      .replaceAll(_grouping, '')
      .trim();

  if (!_canonical.hasMatch(stripped)) return null;
  // `CHECK (price > 0)` in `create_meals.sql`. Free food is not a Meal on
  // offer, and the database refuses it — with the same unactionable message.
  if (double.parse(stripped) <= 0) return null;
  return stripped;
}
