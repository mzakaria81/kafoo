import 'dart:async';

import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/meal_repository.dart';

part 'meal_edit_controller.g.dart';

/// The three fields a Cook may correct on a Meal already on offer.
///
/// Explicit enum so a fourth field cannot be added without someone reading
/// the nutrition rule — calories and allergens must never pass through this
/// screen.
enum MealEditField { title, description, price }

class MealEditState {
  const MealEditState({
    required this.meal,
    this.error,
    this.feedback,
  });

  final Meal meal;
  final AppError? error;

  /// Brief feedback after a commit: success or no-change.
  final String? feedback;

  MealEditState copyWith({
    Meal? meal,
    Object? error = _undefined,
    // The same sentinel as [error], and for the same reason. With a plain
    // `feedback ?? this.feedback` a caller cannot clear this field: passing
    // null is indistinguishable from not passing it. That is not cosmetic here
    // — a failed write would leave the previous "changed" line on screen
    // beside the error, telling the Cook their correction both saved and did
    // not.
    Object? feedback = _undefined,
  }) =>
      MealEditState(
        meal: meal ?? this.meal,
        error: error == _undefined ? this.error : error as AppError?,
        feedback: feedback == _undefined ? this.feedback : feedback as String?,
      );

  static const _undefined = Object();
}

@riverpod
class MealEditController extends _$MealEditController {
  MealRepository get _repository => ref.read(mealRepositoryProvider);

  @override
  MealEditState build({required Meal meal}) {
    return MealEditState(meal: meal);
  }

  /// Clears the last commit's feedback.
  ///
  /// Called when the Cook opens a row. Without it, "changed" from an edit
  /// several minutes ago sits under a row being edited now, and feedback that
  /// outlives what it refers to is decoration rather than information.
  void clearFeedback() => state = state.copyWith(feedback: null);

  /// Commits a single-field change.
  ///
  /// Returns true on success, false on no-change or failure.
  /// An empty or unchanged value writes nothing and emits nothing.
  Future<bool> commit(MealEditField field, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(feedback: 'mealEditNoChange');
      return false;
    }

    final currentValue = switch (field) {
      MealEditField.title => state.meal.title,
      MealEditField.description => state.meal.description,
      MealEditField.price => state.meal.price,
    };

    if (trimmed == currentValue) {
      state = state.copyWith(feedback: 'mealEditNoChange');
      return false;
    }

    final result = await _repository.updateDraft(
      mealId: state.meal.id,
      title: field == MealEditField.title ? trimmed : null,
      description: field == MealEditField.description ? trimmed : null,
      price: field == MealEditField.price ? trimmed : null,
    );

    if (!ref.mounted) return false;

    switch (result) {
      case Success(value: final updated):
        state = state.copyWith(
          meal: updated,
          error: null,
          feedback: 'mealEditSaved',
        );
        unawaited(emitEvent(
          EventNames.mealUpdated,
          attributes: {'changed': field.name},
        ));
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err, feedback: null);
        return false;
    }
  }
}
