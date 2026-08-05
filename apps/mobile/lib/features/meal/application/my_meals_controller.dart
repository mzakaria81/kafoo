import 'dart:async';

import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/meal_repository.dart';

part 'my_meals_controller.g.dart';

class MyMealsState {
  const MyMealsState({
    this.meals = const [],
    this.error,
    this.loading = true,
  });

  final List<Meal> meals;
  final AppError? error;

  /// True until the first load answers.
  ///
  /// Separate from `meals.isEmpty` because the two mean opposite things to a
  /// Cook. Without it the screen renders "no Meals yet, start one" for the
  /// whole of the first load — telling a Cook with a full menu that their work
  /// is gone, every time they open the screen.
  final bool loading;

  MyMealsState copyWith({
    List<Meal>? meals,
    Object? error = _undefined,
    bool? loading,
  }) =>
      MyMealsState(
        meals: meals ?? this.meals,
        error: error == _undefined ? this.error : error as AppError?,
        loading: loading ?? this.loading,
      );

  static const _undefined = Object();
}

@riverpod
class MyMealsController extends _$MyMealsController {
  MealRepository get _repository => ref.read(mealRepositoryProvider);

  @override
  MyMealsState build() {
    _load();
    return const MyMealsState();
  }

  Future<void> _load() async {
    final result = await _repository.myMeals();
    if (!ref.mounted) return;
    switch (result) {
      case Success(value: final list):
        state = state.copyWith(meals: list, error: null, loading: false);
      case Failure(error: final err):
        state = state.copyWith(error: err, loading: false);
    }
  }

  Future<bool> setStatus(Meal meal, MealStatus next) async {
    if (!meal.canTransitionTo(next)) return false;

    final result = await _repository.setStatus(
      mealId: meal.id,
      next: next,
    );
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        await _load();
        if (next == MealStatus.unavailable || next == MealStatus.published) {
          unawaited(emitEvent(
            EventNames.mealUpdated,
            attributes: {'changed': 'availability'},
          ));
        } else if (next == MealStatus.archived) {
          unawaited(emitEvent(EventNames.mealArchived));
        }
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }

  Future<bool> deleteDraft(Meal meal) async {
    if (!meal.status.isDeletable) return false;

    final result = await _repository.deleteDraft(meal.id);
    if (!ref.mounted) return false;
    switch (result) {
      case Success():
        await _load();
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }

  /// Whether taking [meal] off the menu would leave the Cook's kitchen
  /// unfindable. Named for the consequence rather than the count, because the
  /// consequence is what the Cook has to be told.
  bool wouldCloseKitchen(Meal meal) => isLastMealOnOffer(state.meals, meal);
}
