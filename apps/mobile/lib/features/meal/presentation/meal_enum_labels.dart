import 'package:kafoo_domain/domain.dart';

import '../../../l10n/app_localizations.dart';

/// Localized display names for Meal enums.
///
/// Wire identifiers (`egyptian`, `main`) must never reach a Cook. Mapping lives
/// here — presentation — because `packages/domain` has zero Flutter imports.
String cuisineLabel(AppLocalizations l10n, Cuisine cuisine) =>
    switch (cuisine) {
      Cuisine.egyptian => l10n.cuisineEgyptian,
      Cuisine.levantine => l10n.cuisineLevantine,
      Cuisine.gulf => l10n.cuisineGulf,
      Cuisine.sudanese => l10n.cuisineSudanese,
      Cuisine.moroccan => l10n.cuisineMoroccan,
      Cuisine.turkish => l10n.cuisineTurkish,
      Cuisine.italian => l10n.cuisineItalian,
      Cuisine.asian => l10n.cuisineAsian,
      Cuisine.american => l10n.cuisineAmerican,
      Cuisine.other => l10n.cuisineOther,
    };

String mealCategoryLabel(AppLocalizations l10n, MealCategory category) =>
    switch (category) {
      MealCategory.main => l10n.categoryMain,
      MealCategory.appetizer => l10n.categoryAppetizer,
      MealCategory.soup => l10n.categorySoup,
      MealCategory.salad => l10n.categorySalad,
      MealCategory.side => l10n.categorySide,
      MealCategory.dessert => l10n.categoryDessert,
      MealCategory.bakery => l10n.categoryBakery,
      MealCategory.drink => l10n.categoryDrink,
      MealCategory.other => l10n.categoryOther,
    };

String mealStatusLabel(AppLocalizations l10n, MealStatus status) =>
    switch (status) {
      MealStatus.draft => l10n.myMealsStatusDraft,
      MealStatus.published => l10n.glancePublished,
      MealStatus.unavailable => l10n.myMealsStatusUnavailable,
      MealStatus.archived => l10n.myMealsStatusArchived,
    };
