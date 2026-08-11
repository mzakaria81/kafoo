/**
 * Which digits a number is drawn with.
 *
 * Mirrors `packages/ui/lib/theme/numerals.dart`. Two surfaces, one design — and
 * a price that reads `٣٥ جنيه` in the app and `35 جنيه` on the web is the same
 * Meal claiming two prices.
 *
 * Egyptian Arabic reads prices, counts and distances in Arabic-Indic numerals.
 * Numerals carry more of Kafoo's meaning than words do, because numbers are
 * read by nearly everyone and words are not — so drawing them in Latin digits
 * makes the one element a Customer is most likely to read the one element in a
 * foreign script.
 *
 * **This changes glyphs, never value.** It does not parse, round or reformat:
 * `35.00` becomes `٣٥٫٠٠`, digit for digit. A Meal's price is stored as the
 * exact string the Cook typed and must stay that way; a transliteration is the
 * only kind of price formatting that cannot lose a piastre.
 *
 * **Phone numbers, one-time codes and identifiers stay in Latin digits.** They
 * are typed on a Latin numeric keypad, read aloud to a call-centre and
 * copy-pasted between apps, so converting them makes them harder to use rather
 * than easier to read. That is why this is applied where a price is rendered
 * rather than globally.
 */
const LATIN_DIGITS = '0123456789';
const ARABIC_INDIC_DIGITS = '٠١٢٣٤٥٦٧٨٩';

/** U+066B ARABIC DECIMAL SEPARATOR. */
export const ARABIC_DECIMAL_SEPARATOR = '٫';

/** U+066C ARABIC THOUSANDS SEPARATOR. */
export const ARABIC_THOUSANDS_SEPARATOR = '٬';

/** Rewrites Latin digits and separators as Arabic-Indic, leaving all else. */
export function arabicIndic(source: string): string {
  let out = '';
  for (const character of source) {
    if (character === '.') {
      out += ARABIC_DECIMAL_SEPARATOR;
    } else if (character === ',') {
      out += ARABIC_THOUSANDS_SEPARATOR;
    } else {
      const digit = LATIN_DIGITS.indexOf(character);
      out += digit >= 0 ? ARABIC_INDIC_DIGITS[digit] : character;
    }
  }
  return out;
}
