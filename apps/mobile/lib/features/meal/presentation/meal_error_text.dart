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
String mealErrorText(BuildContext context, AppError error) {
  final l10n = AppLocalizations.of(context);
  final form = context.addressForm;
  return switch (error.messageKey) {
    'mealPriceInvalid' => l10n.mealPriceInvalid(form),
    'mealPhotoError' => l10n.mealPhotoError(form),
    'mealPublishError' => l10n.mealPublishError(form),
    'mealLoadError' => l10n.mealLoadError(form),
    'mealAvailabilityError' => l10n.mealAvailabilityError(form),
    'mealDeleteError' => l10n.mealDeleteError(form),
    'mealKitchenCheckError' => l10n.mealKitchenCheckError(form),
    _ => l10n.mealSaveError(form),
  };
}
