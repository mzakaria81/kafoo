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

  final analysis = MealAnalysis(
    ingredients:
        _stringListSuggestion(root['ingredients'], basis['ingredients']),
    calories: _caloriesSuggestion(root['calories'], basis['calories']),
    allergens: _stringListSuggestion(root['allergens'], basis['allergens']),
    cuisine: _cuisineSuggestion(root['cuisine'], basis['cuisine']),
    category: _categorySuggestion(root['category'], basis['category']),
    description: _stringSuggestion(root['description'], basis['description']),
    modelId: modelId,
    usedPhoto: usedPhoto,
  );

  // A REPLY FULL OF VALUES AND EMPTY OF REASONS IS A BROKEN REPLY, NOT AN
  // OPINIONLESS ONE.
  //
  // On 2026-08-11 the founder analysed «محشي صغير / ورق عنب وأرز», the model
  // answered in 2.5 seconds with a 785-byte reply, and the summary said «المساعد
  // مقدرش يقدّر حاجة» — the assistant could not estimate anything. Those are two
  // very different events wearing one sentence, and the app could not tell them
  // apart because both arrive here as `Success` carrying an empty analysis.
  //
  // Every field is dropped when it has no basis sentence, and that rule is
  // right: a calorie count with no reason behind it is a number a Cook has no
  // grounds to believe (FR-013). Dropping SILENTLY is what was wrong. If the
  // model filled fields and explained none of them, it did not decline to
  // answer — it answered in a shape this product cannot use, which is a provider
  // contract failure and belongs in the error channel where somebody will see
  // it.
  //
  // NARROWED TO "FILLED FIELDS, NO REASONS AT ALL", and the narrowing was the
  // tests' doing rather than mine. The first version fired whenever an empty
  // analysis came from a reply with any value in it, which turned red two
  // deliberate tests pinning a different rule — `calories: 850.5` and
  // `calories: -10` are each dropped for being an invalid VALUE, with a perfectly
  // good basis sentence beside them, and one bad field poisoning the whole reply
  // is the opposite of what those tests exist to protect.
  //
  // So the condition is the shape that actually reached the founder: values, and
  // an empty `basis` map. A reply with some reasons is a reply this product can
  // work with, and a value dropped for being invalid is the field-level rule
  // doing its job.
  //
  // The narrower rule leaves one ambiguous case unreported — values, one basis
  // sentence, and every field dropped anyway. `analyze_meal_shape` in the Edge
  // Function logs it, which is the right place for a case too rare to have
  // earned a sentence in Egyptian Arabic.
  if (analysis.isEmpty && basis.isEmpty && _hasAnyValue(root)) {
    return const Failure(AppError(messageKey: 'analyzeMealInvalidResponse'));
  }

  return Success(analysis);
}

/// Whether the reply offered a value for any field this parser reads.
///
/// The question is deliberately "did the model say anything", not "was it
/// valid" — an invalid value that was dropped for being invalid is also a reply
/// worth reporting rather than reading as silence.
bool _hasAnyValue(Map<String, dynamic> root) => const [
      'ingredients',
      'calories',
      'allergens',
      'cuisine',
      'category',
      'description',
    ].any((field) {
      final value = root[field];
      if (value == null) return false;
      if (value is Iterable) return value.isNotEmpty;
      if (value is String) return value.trim().isNotEmpty;
      return true;
    });

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
