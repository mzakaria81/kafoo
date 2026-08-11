import 'package:kafoo_ui/ui.dart';

import 'app_localizations.dart';

/// The one place a Meal's price becomes something a person reads.
///
/// It exists as a funnel rather than as four call sites because the digits are
/// a locale decision and the currency word is an ARB entry, and those two have
/// to be made together. Four screens each remembering to convert would be four
/// chances to forget — and a price shown in the wrong script on one screen and
/// the right one on the next reads as two different prices.
///
/// The value is never touched. See [KafooNumerals] for why a transliteration is
/// the only price formatting that cannot lose a piastre.
String mealPriceLabel(AppLocalizations l10n, String price) =>
    l10n.publicMealPriceValue(
      // Arabic reads ٣٥; English reads 35. Keyed on the active locale rather
      // than on a constant, because `en` is a real supported locale and
      // Arabic-Indic digits in an English sentence help nobody.
      l10n.localeName == 'ar' ? KafooNumerals.arabicIndic(price) : price,
    );
