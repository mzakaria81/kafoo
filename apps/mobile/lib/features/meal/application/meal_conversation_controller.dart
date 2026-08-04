import 'dart:async';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/ai_provider.dart';
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
    this.analysisError,
    this.approvals = const {},
    this.error,
  });

  static const _undefined = Object();

  final MealDraft draft;
  final MealAnalysis? analysis;
  final bool analysisInFlight;

  /// Separate from [error]: a model failure must never look like a save failure.
  final AppError? analysisError;
  final Map<String, bool> approvals;
  final AppError? error;

  MealConversationState copyWith({
    MealDraft? draft,
    MealAnalysis? analysis,
    bool? analysisInFlight,
    Object? analysisError = _undefined,
    Map<String, bool>? approvals,
    Object? error = _undefined,
  }) =>
      MealConversationState(
        draft: draft ?? this.draft,
        analysis: analysis ?? this.analysis,
        analysisInFlight: analysisInFlight ?? this.analysisInFlight,
        analysisError: analysisError == _undefined
            ? this.analysisError
            : analysisError as AppError?,
        approvals: approvals ?? this.approvals,
        error: error == _undefined ? this.error : error as AppError?,
      );
}

/// Riverpod controller for the Meal publishing conversation.
///
/// Out of scope for this controller (later tasks):
/// - The FR-029 photo disclosure behaviour (T036)
/// - The summary screen (T037), publishing (T038), conversation analytics (T039),
///   no-Kitchen-Profile redirect (T040), photo upload UI (T041)
@riverpod
class MealConversationController extends _$MealConversationController {
  MealRepository get _repository => ref.read(mealRepositoryProvider);
  AiProvider get _ai => ref.read(aiProviderProvider);

  /// Monotonic id so a late reply from an earlier analysis is dropped.
  int _analysisRequestId = 0;

  @override
  MealConversationState build() => MealConversationState(
        draft: MealDraft(),
      );

  /// The next unanswered [MealStep], or null when all four are done.
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
  /// First answer creates the draft and emits [EventNames.mealDrafted] once.
  /// Later answers persist only the field that changed. Analysis starts after
  /// description (and again if a photo arrives) without blocking the Cook.
  ///
  /// Returns true when the answer was accepted, false when a write failed.
  /// The caller should clear the text field only on success.
  Future<bool> answer(MealStepId step, String value) async {
    state = state.copyWith(error: null);

    if (state.draft.mealId == null) {
      final result = await _repository.createDraft(title: value);
      if (!ref.mounted) return false;
      switch (result) {
        case Success(value: final id):
          state.draft.mealId = id;
          _recordAnswer(step, value);
          state = state.copyWith();
          unawaited(emitEvent(EventNames.mealDrafted));
          return true;
        case Failure(error: final err):
          state = state.copyWith(error: err);
          return false;
      }
    }

    final mealId = state.draft.mealId!;
    final persist = await _persistAnswer(mealId, step, value);
    if (!ref.mounted) return false;
    switch (persist) {
      case Success():
        _recordAnswer(step, value);
        state = state.copyWith();
        if (step == MealStepId.description) {
          _startAnalysis();
        } else if (step == MealStepId.photo) {
          _startAnalysis(photoPath: value);
        }
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }

  /// Marks the photo step as resolved without a path — the Cook declined.
  void declinePhoto() {
    state.draft.photoResolved = true;
    state = state.copyWith();
  }

  Future<Result<Object?, AppError>> _persistAnswer(
    String mealId,
    MealStepId step,
    String value,
  ) async {
    switch (step) {
      case MealStepId.dish:
        // Reachable only when the Cook CORRECTS the dish from the summary — the
        // first answer creates the draft in the branch above and never arrives
        // here. Returning success without writing would drop that correction
        // silently, which is worse than failing to save it.
        return _repository.updateDraft(mealId: mealId, title: value);
      case MealStepId.description:
        return _repository.updateDraft(mealId: mealId, description: value);
      case MealStepId.photo:
        return _repository.updateDraft(mealId: mealId, photoPath: value);
      case MealStepId.price:
        return _repository.updateDraft(mealId: mealId, price: value);
    }
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

  /// Starts analysis without awaiting it. Safe to call while the Cook answers.
  void _startAnalysis({String? photoPath}) {
    final dish = state.draft.title;
    final description = state.draft.description;
    if (!canBeginAnalysis(dish: dish, description: description)) return;

    final mealId = state.draft.mealId;
    if (mealId == null) return;

    final requestId = ++_analysisRequestId;
    state = state.copyWith(analysisInFlight: true, analysisError: null);

    final request = AiRequest(
      promptId: 'meal-analysis',
      tier: ModelTier.fast,
      variables: {
        'said': '$dish. $description',
        'meal_id': mealId,
        if (photoPath != null) 'photo_path': photoPath,
      },
    );

    unawaited(
        _completeAnalysis(requestId, request, usedPhoto: photoPath != null));
  }

  Future<void> _completeAnalysis(
    int requestId,
    AiRequest request, {
    required bool usedPhoto,
  }) async {
    final result = await _ai.complete(request);

    // The only await in this method, so this is the only place either check can
    // fire. parseMealAnalysis below is synchronous — a second pair after it
    // would be unreachable, and an unreachable guard is one a later cleanup
    // deletes in place of the real one.
    if (!ref.mounted) return;
    if (requestId != _analysisRequestId) return;

    switch (result) {
      case Success(value: final response):
        final parsed = parseMealAnalysis(
          response.text,
          modelId: response.modelId,
          usedPhoto: usedPhoto,
        );
        switch (parsed) {
          case Success(value: final analysis):
            state = state.copyWith(
              analysis: analysis,
              analysisInFlight: false,
              analysisError: null,
            );
          case Failure(error: final err):
            state = state.copyWith(
              analysisInFlight: false,
              analysisError: err,
            );
        }
      case Failure(error: final err):
        state = state.copyWith(
          analysisInFlight: false,
          analysisError: err,
        );
    }
  }
}
