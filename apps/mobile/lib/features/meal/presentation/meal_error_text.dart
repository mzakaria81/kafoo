import 'package:flutter/widgets.dart';
import 'package:kafoo_domain/domain.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';

/// The Cook-facing sentence for an [AppError] from any Meal screen.
///
/// **ONE FUNCTION, BECAUSE FIVE SCREENS HAD FIVE ANSWERS AND THREE OF THEM WERE
/// WRONG.** Until 2026-08-11 `meal_summary.dart`, `meal_edit_screen.dart` and
/// `meal_fallback_question.dart` each rendered `mealSaveError` for *any* error
/// their controller produced, ignoring [AppError.messageKey] entirely. The
/// message was hardcoded, so a controller could report anything it liked and the
/// Cook would still read «مقدرناش نحفظ الأكلة».
///
/// That is not a cosmetic problem. It is the reason a price the database could
/// not read looked identical to a network failure — one the Cook can fix in five
/// seconds, one she cannot do anything about, rendered as the same sentence.
///
/// The fallback is deliberately the save error and not the raw key: a Cook must
/// never be shown `mealPriceInvalid`. A key with no case here is a bug, and
/// `meal_error_text_test.dart` is what fails when one is added without a
/// sentence.
/// [fromAnalysis] picks the sentence for a key with no case below.
///
/// **The default fallback claims the Meal was not saved, and for an AI failure
/// that is a lie.** Her answers ARE saved — the assistant is what did not
/// answer — so a Cook told "we could not save the Meal" would go and retype
/// work that is already in the database. Found by writing the test for the
/// finding above: the stub provider fails with a key this switch does not know,
/// which is exactly what a new provider error code will do in production.
String mealErrorText(
  BuildContext context,
  AppError error, {
  bool fromAnalysis = false,
}) {
  final l10n = AppLocalizations.of(context);
  final form = context.addressForm;
  return switch (error.messageKey) {
    // THE ANALYSIS KEYS EXISTED AND REACHED NOBODY. `_completeAnalysis` sets a
    // localized `analysisError` for every way the AI Assistant can fail, and
    // until 2026-08-11 no widget in the app read that field — grep returned zero
    // consumers outside the controller. The infinite-spinner fix earlier the same
    // day therefore traded a hang for a SILENT failure: the fallback questions
    // simply appeared, with nothing saying why. Raised by accessibility-reviewer
    // on PR #455 and confirmed by grep before it was believed.
    'analyzeMealUnauthorized' => l10n.analyzeMealUnauthorized(form),
    'analyzeMealNotOwned' => l10n.analyzeMealNotOwned,
    'analyzeMealRateLimited' => l10n.analyzeMealRateLimited(form),
    'analyzeMealTimeout' => l10n.analyzeMealTimeout(form),
    'analyzeMealInvalidResponse' => l10n.analyzeMealInvalidResponse(form),
    'analyzeMealProviderError' => l10n.analyzeMealProviderError(form),
    'analyzeMealServerError' => l10n.analyzeMealServerError(form),
    'analyzeMealUnknownError' => l10n.analyzeMealUnknownError(form),
    'mealPriceInvalid' => l10n.mealPriceInvalid(form),
    'mealPhotoError' => l10n.mealPhotoError(form),
    'mealPublishError' => l10n.mealPublishError(form),
    'mealLoadError' => l10n.mealLoadError(form),
    'mealAvailabilityError' => l10n.mealAvailabilityError(form),
    'mealDeleteError' => l10n.mealDeleteError(form),
    'mealKitchenCheckError' => l10n.mealKitchenCheckError(form),
    _ => fromAnalysis
        ? l10n.analyzeMealUnknownError(form)
        : l10n.mealSaveError(form),
  };
}
