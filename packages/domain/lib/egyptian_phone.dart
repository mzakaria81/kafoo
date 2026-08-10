/// Turns a phone number as an Egyptian writes it into the form Supabase needs.
///
/// NOBODY IN EGYPT TYPES `+20`. They type `01112513196`, and until 2026-08-10 the
/// sign-in screen sent whatever was typed straight to the authentication service,
/// which requires E.164 — the international form with a country code. So the only
/// format a Customer would naturally use was the one format that could not work,
/// and the screen reported the rejection as "no internet connection". The founder
/// hit it on the first real build.
///
/// Returns null when the input is not an Egyptian mobile number. Null is a
/// decision, not an absence: the caller must say "that is not a mobile number"
/// rather than send it and let a server answer for us. A number that cannot
/// receive an SMS cannot receive a sign-in code, and finding that out locally is
/// both faster and clearer than a round trip.
String? normalizeEgyptianMobile(String input) {
  final digits = _toAsciiDigits(input);
  if (digits.isEmpty) return null;

  // Strip whichever way the country code was written, leaving the national
  // number. `00` is how a phone dials internationally; `+` is how one is written.
  var national = digits;
  if (national.startsWith('0020')) {
    national = national.substring(4);
  } else if (national.startsWith('20') && national.length == 12) {
    national = national.substring(2);
  }

  // The national form is ten digits after an optional trunk zero: 0 10 1234567.
  if (national.startsWith('0')) national = national.substring(1);
  if (national.length != 10) return null;

  // Egypt has four mobile operators and therefore four prefixes. A landline
  // (02 for Cairo, 03 for Alexandria) reaches a person but not an SMS, so it is
  // refused here rather than accepted and left to fail silently later.
  const mobilePrefixes = {'10', '11', '12', '15'};
  if (!mobilePrefixes.contains(national.substring(0, 2))) return null;

  return '+20$national';
}

/// Folds Arabic-Indic and Extended Arabic-Indic digits to ASCII and drops
/// everything that is punctuation rather than a number.
///
/// An Arabic keyboard produces `٠١١` rather than `011`, and a number typed that
/// way is not a malformed number — it is the same number written in the script
/// the rest of this app is written in. A leading `+` is dropped with the other
/// punctuation because the country code is re-derived below either way.
String _toAsciiDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.writeCharCode(rune);
    } else if (rune >= 0x0660 && rune <= 0x0669) {
      // Arabic-Indic ٠..٩
      buffer.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      // Extended Arabic-Indic ۰..۹, which some keyboards send instead.
      buffer.writeCharCode(rune - 0x06F0 + 0x30);
    }
  }
  return buffer.toString();
}
