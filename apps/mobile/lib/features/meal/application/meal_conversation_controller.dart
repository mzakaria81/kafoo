import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/meal_repository.dart';

part 'meal_conversation_controller.g.dart';

/// Immutable snapshot of the Meal conversation's runtime state.
///
/// The [draft] inside is mutable and is shared by every state this class
/// produces: the controller mutates it in place and reassigns state so Riverpod
/// notifies listeners, which works only because this class has no `==` override
/// and every copy is a new identity.
///
/// This is the first Riverpod controller in Kafoo, so it is a pattern being set
/// rather than one being followed. The mutable draft is deliberate — it is the
/// shape `mealSteps()` already reads — but it means a previous state cannot be
/// compared against the current one. If a later task needs that (undo, or a
/// diff of what the Cook changed), make MealDraft immutable then rather than
/// bolting a second source of truth alongside it.
class MealConversationState {
  const MealConversationState({
    required this.draft,
    this.analysis,
    this.analysisInFlight = false,
    this.approvals = const {},
    this.error,
  });

  static const _undefined = Object();

  final MealDraft draft;
  final MealAnalysis? analysis;
  final bool analysisInFlight;
  final Map<String, bool> approvals;
  final AppError? error;

  MealConversationState copyWith({
    MealDraft? draft,
    MealAnalysis? analysis,
    bool? analysisInFlight,
    Map<String, bool>? approvals,
    Object? error = _undefined,
  }) =>
      MealConversationState(
        draft: draft ?? this.draft,
        analysis: analysis ?? this.analysis,
        analysisInFlight: analysisInFlight ?? this.analysisInFlight,
        approvals: approvals ?? this.approvals,
        error: error == _undefined ? this.error : error as AppError?,
      );
}

/// Riverpod controller for the Meal publishing conversation.
///
/// This is the first Riverpod controller in Kafoo. The rest of E2 copies this
/// pattern: @riverpod annotation, part directive, immutable state class,
/// repository obtained from a provider so tests drive it with a fake.
///
/// Out of scope for this controller (later tasks):
/// - Persisting answers 2..4 to the database (T034)
/// - Starting the AI analysis (T035) — the [analysis] slot exists, nothing fills it
/// - The FR-029 photo disclosure behaviour (T036)
/// - The summary screen (T037), publishing (T038), analytics (T039),
///   no-Kitchen-Profile redirect (T040), photo upload (T041)
@riverpod
class MealConversationController extends _$MealConversationController {
  MealRepository get _repository => ref.read(mealRepositoryProvider);

  @override
  MealConversationState build() => MealConversationState(
        draft: MealDraft(),
      );

  /// The next unanswered [MealStep], or null when all four are done.
  ///
  /// Delegates to the domain functions in meal_step.dart — the sequence logic
  /// lives there, not here.
  MealStep? get currentStep {
    final steps = mealSteps(
      dish: state.draft.title,
      description: state.draft.description,
      photoResolved: state.draft.photoResolved,
      price: state.draft.price,
    );
    return nextUnansweredMealStep(steps);
  }

  /// Records an answer for the given step.
  ///
  /// On the very first answer (when no draft exists yet), calls
  /// [repository.createDraft] with the answer as the Meal's title and stores
  /// the returned id. On later answers the answer is recorded locally only —
  /// persisting them is T034.
  ///
  /// Returns true when the answer was accepted, false when createDraft failed.
  /// The caller should clear the text field only on success.
  Future<bool> answer(MealStepId step, String value) async {
    state = state.copyWith(error: null);

    // First answer — persist the draft before recording anything else.
    if (state.draft.mealId == null) {
      final result = await _repository.createDraft(title: value);
      switch (result) {
        case Success(value: final id):
          state.draft.mealId = id;
          _recordAnswer(step, value);
        case Failure(error: final err):
          state = state.copyWith(error: err);
          return false;
      }
    } else {
      _recordAnswer(step, value);
    }

    state = state.copyWith();
    return true;
  }

  void _recordAnswer(MealStepId step, String value) {
    switch (step) {
      case MealStepId.dish:
        state.draft.title = value;
      case MealStepId.description:
        state.draft.description = value;
      case MealStepId.photo:
        // Both, always. photoResolved is what mealSteps() reads; setting only
        // the path leaves the step unanswered and loops the Cook back onto the
        // question they just answered — the trap meal_step.dart documents.
        state.draft.photoPath = value;
        state.draft.photoResolved = true;
      case MealStepId.price:
        state.draft.price = value;
    }
  }

  /// Marks the photo step as resolved without a path — the Cook declined.
  void declinePhoto() {
    state.draft.photoResolved = true;
    state = state.copyWith();
  }
}
