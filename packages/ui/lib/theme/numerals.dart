/// Which digits a number is drawn with.
///
/// Egyptian Arabic reads prices, counts and distances in Arabic-Indic numerals
/// — ٣٥ rather than 35 — and numerals carry more of Kafoo's meaning than words
/// do, because numbers are read by nearly everyone and words are not. Drawing
/// them in Latin digits makes the one element a Cook is most likely to read the
/// one element in a foreign script.
///
/// **This changes glyphs, never value.** It does not parse, round, reformat or
/// re-order anything: "35.00" becomes "٣٥٫٠٠", digit for digit. A Meal's price
/// is stored as the exact string the Cook typed and must stay that way; a
/// transliteration is the only kind of price formatting that cannot lose a
/// piastre.
///
/// **Three things stay in Latin digits, and that is deliberate:** phone
/// numbers, one-time codes, and identifiers. They are typed on a Latin numeric
/// keypad, read back to a call-centre, and copy-pasted between apps, so
/// converting them would make them harder to use rather than easier to read.
/// That is why this is applied at the call site rather than globally.
abstract final class KafooNumerals {
  static const String _latinDigits = '0123456789';
  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// U+066B ARABIC DECIMAL SEPARATOR. A full stop between Arabic-Indic digits
  /// reads as a full stop rather than as a decimal point.
  static const String arabicDecimalSeparator = '٫';

  /// U+066C ARABIC THOUSANDS SEPARATOR.
  static const String arabicThousandsSeparator = '٬';

  /// Rewrites Latin digits and separators in [source] as Arabic-Indic.
  ///
  /// Anything that is not a digit or a separator — a currency word, a space, a
  /// range dash — is left exactly as it was.
  static String arabicIndic(String source) {
    final out = StringBuffer();
    for (final unit in source.runes) {
      final character = String.fromCharCode(unit);
      final digit = _latinDigits.indexOf(character);
      out.write(switch (character) {
        '.' => arabicDecimalSeparator,
        ',' => arabicThousandsSeparator,
        _ => digit >= 0 ? _arabicIndicDigits[digit] : character,
      });
    }
    return out.toString();
  }

  /// Rewrites Arabic-Indic digits back as Latin.
  ///
  /// Needed on the way *in*, not on the way out: a Cook dictating a price may
  /// have it transcribed in either script, and what reaches the database has to
  /// be one of them.
  static String latin(String source) {
    final out = StringBuffer();
    for (final unit in source.runes) {
      final character = String.fromCharCode(unit);
      final digit = _arabicIndicDigits.indexOf(character);
      out.write(switch (character) {
        arabicDecimalSeparator => '.',
        arabicThousandsSeparator => ',',
        _ => digit >= 0 ? _latinDigits[digit] : character,
      });
    }
    return out.toString();
  }
}
