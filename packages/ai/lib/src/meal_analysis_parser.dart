import 'dart:convert';

import 'package:kafoo_domain/domain.dart';

/// Turns a model's reply text into a [MealAnalysis].
///
/// The prompt demands strict JSON and nothing else. This parser never repairs a
/// broken reply and never reaches for a regular expression — a mangled response
/// is a [Failure], not a half-invented Meal. Field-level rules are asymmetric
/// on purpose: one bad field is dropped so the good ones still reach the Cook,
/// because a missing cuisine is recoverable and a missing allergen list is not.
Result<MealAnalysis, AppError> parseMealAnalysis(
  String text, {
  String? modelId,
  bool usedPhoto = false,
}) {
  late final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return Failure(
      AppError(messageKey: 'aiMealAnalysisInvalid', cause: e),
    );
  }

  if (decoded is! Map<String, dynamic>) {
    return const Failure(AppError(messageKey: 'aiMealAnalysisInvalid'));
  }

  final root = decoded;
  final basis = _basisMap(root['basis']);

  return Success(
    MealAnalysis(
      ingredients:
          _stringListSuggestion(root['ingredients'], basis['ingredients']),
      calories: _caloriesSuggestion(root['calories'], basis['calories']),
      allergens: _stringListSuggestion(root['allergens'], basis['allergens']),
      cuisine: _cuisineSuggestion(root['cuisine'], basis['cuisine']),
      category: _categorySuggestion(root['category'], basis['category']),
      description: _stringSuggestion(root['description'], basis['description']),
      modelId: modelId,
      usedPhoto: usedPhoto,
    ),
  );
}

/// [basis] is a requirement, not decoration. A value with no sentence explaining
/// it is something the Cook has no reason to believe, so it is dropped rather
/// than shown empty-handed.
Map<String, String> _basisMap(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((key, value) {
    if (key is! String) return;
    if (value is! String) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    out[key] = trimmed;
  });
  return out;
}

MealSuggestion<List<String>>? _stringListSuggestion(
  Object? raw,
  String? basis,
) {
  if (basis == null) return null;
  if (raw is! List) return null;

  final values = <String>[];
  for (final entry in raw) {
    if (entry is! String) continue;
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    values.add(trimmed);
  }
  if (values.isEmpty) return null;
  return MealSuggestion(value: values, basis: basis);
}

/// Out-of-range is dropped, never clamped: a clamped number is a fabricated
/// estimate wearing a plausible value. Doubles and strings are the same class
/// of lie — the model did not give an integer we can stand behind.
MealSuggestion<int>? _caloriesSuggestion(Object? raw, String? basis) {
  if (basis == null) return null;
  if (raw is! int) return null;
  if (raw < 0 || raw > 20000) return null;
  return MealSuggestion(value: raw, basis: basis);
}

/// A value outside the enum drops the field. It never falls back to a default
/// and never guesses a near match: a wrongly-defaulted cuisine is a silent lie
/// about a Cook's food.
MealSuggestion<Cuisine>? _cuisineSuggestion(Object? raw, String? basis) {
  if (basis == null) return null;
  if (raw is! String) return null;
  final cuisine = Cuisine.tryFromWireName(raw);
  if (cuisine == null) return null;
  return MealSuggestion(value: cuisine, basis: basis);
}

MealSuggestion<MealCategory>? _categorySuggestion(Object? raw, String? basis) {
  if (basis == null) return null;
  if (raw is! String) return null;
  final category = MealCategory.tryFromWireName(raw);
  if (category == null) return null;
  return MealSuggestion(value: category, basis: basis);
}

MealSuggestion<String>? _stringSuggestion(Object? raw, String? basis) {
  if (basis == null) return null;
  if (raw is! String) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return MealSuggestion(value: trimmed, basis: basis);
}
