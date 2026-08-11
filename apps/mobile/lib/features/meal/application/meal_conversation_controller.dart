import 'dart:async';
import 'dart:typed_data';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../data/ai_provider.dart';
import '../data/meal_repository.dart';
import 'meal_estimate_fields.dart';

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
    this.corrections = const {},
    this.error,
  });

  static const _undefined = Object();

  final MealDraft draft;
  final MealAnalysis? analysis;
  final bool analysisInFlight;

  /// Separate from [error]: a model failure must never look like a save failure.
  final AppError? analysisError;
  final Map<String, bool> approvals;

  /// Fields the Cook REPLACED rather than approved.
  ///
  /// Separate from [approvals] because correcting a value also approves it, so
  /// one map cannot answer "whose figure is this". The summary needs that
  /// answer: an approved estimate is still the AI Assistant's guess and keeps
  /// its badge, and a corrected one is the Cook's own and loses it. The
  /// database draws the same line in `derive_nutrition_source` by comparing
  /// what arrives against what is stored.
  final Set<String> corrections;

  final AppError? error;

  MealConversationState copyWith({
    MealDraft? draft,
    // Sentinel-guarded, like analysisError and error below, because clearing
    // this is a real operation: resume() must drop the previous Meal's
    // estimates. With `analysis ?? this.analysis` the clear silently did
    // nothing, so a resumed draft carried the last dish's suggested allergens
    // and a Cook approving them would have written another dish's guesses onto
    // this Meal.
    Object? analysis = _undefined,
    bool? analysisInFlight,
    Object? analysisError = _undefined,
    Map<String, bool>? approvals,
    Set<String>? corrections,
    Object? error = _undefined,
  }) =>
      MealConversationState(
        draft: draft ?? this.draft,
        analysis:
            analysis == _undefined ? this.analysis : analysis as MealAnalysis?,
        analysisInFlight: analysisInFlight ?? this.analysisInFlight,
        analysisError: analysisError == _undefined
            ? this.analysisError
            : analysisError as AppError?,
        approvals: approvals ?? this.approvals,
        corrections: corrections ?? this.corrections,
        error: error == _undefined ? this.error : error as AppError?,
      );
}

/// Riverpod controller for the Meal publishing conversation.
///
/// Out of scope for this controller (later tasks):
/// - The FR-029 photo disclosure behaviour (T036)
/// - Conversation analytics (T039), no-Kitchen-Profile redirect (T040),
///   photo upload UI (T041)
@riverpod
class MealConversationController extends _$MealConversationController {
  MealRepository get _repository => ref.read(mealRepositoryProvider);
  AiProvider get _ai => ref.read(aiProviderProvider);

  /// Monotonic id so a late reply from an earlier analysis is dropped.
  int _analysisRequestId = 0;

  /// Guards against a double tap putting the Meal on offer twice.
  bool _publishInFlight = false;

  @override
  MealConversationState build() => MealConversationState(
        draft: MealDraft(),
      );

  /// Every estimate the current analysis produced that still needs a decision.
  List<String> get pendingEstimateFields {
    final analysis = state.analysis;
    if (analysis == null) return const [];
    return MealEstimateFields.presentIn(analysis)
        .where((field) => state.approvals[field] != true)
        .toList(growable: false);
  }

  /// True when every field the analysis produced has been approved or corrected.
  ///
  /// An empty or missing analysis has nothing to approve. Publishing may still
  /// fail at the database if cuisine and category were never set — that is
  /// intentional; inventing defaults is out of scope (FR-014 needs a manual
  /// path that is a separate task).
  bool get allEstimatesApproved {
    if (state.analysisInFlight) return false;
    final analysis = state.analysis;
    if (analysis == null || analysis.isEmpty) return true;
    return MealEstimateFields.presentIn(analysis)
        .every((field) => state.approvals[field] == true);
  }

  /// Whether the Meal may go on offer from the summary.
  ///
  /// Approvals alone are not enough: the draft must carry cuisine and category
  /// (written only when those estimates are approved or corrected), which is
  /// what the database enforces on the way out of `draft`.
  bool get canPublish =>
      allEstimatesApproved && state.draft.isComplete && !_publishInFlight;

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

  /// The next fallback question, or null when none is needed.
  ///
  /// Asked only after the four real questions, never while an estimate might
  /// still arrive, and only for fields the analysis did not supply. Trigger is
  /// the missing value, not [MealConversationState.analysisError] — a successful
  /// analysis with no cuisine leaves the Cook just as stuck.
  MealFallbackStepId? get currentFallbackStep {
    if (currentStep != null) return null;
    if (state.analysisInFlight) return null;

    final analysis = state.analysis;
    final cuisineNeeded =
        state.draft.cuisine == null && analysis?.cuisine == null;
    final categoryNeeded =
        state.draft.category == null && analysis?.category == null;

    return nextUnansweredMealFallbackStep(
      cuisineNeeded: cuisineNeeded,
      categoryNeeded: categoryNeeded,
    );
  }

  /// Seeds the conversation from a stored draft so the Cook can carry on where
  /// they left off.
  ///
  /// Does nothing when [meal] is not a draft — a published, unavailable or
  /// archived Meal is not something this conversation composes, and editing one
  /// that is on offer is a different screen. The state is left untouched.
  void resume(CookMeal meal) {
    if (meal.status != MealStatus.draft) return;

    final draft = state.draft;
    draft.mealId = meal.id;
    draft.title = meal.title;
    draft.description = meal.description;
    draft.price = meal.price;
    draft.cuisine = meal.cuisine;
    draft.category = meal.category;
    draft.ingredients = meal.ingredients;
    draft.calories = meal.calories;
    draft.allergens = meal.allergens;
    draft.photoPath = meal.photoPath;
    // A draft with no photo path is asked the photo question again. Declining
    // a photo is not persisted anywhere, so "declined" and "not asked yet" are
    // indistinguishable in the stored row — and asking once more costs a Cook
    // one tap, where skipping would silently deny a photo to someone who wanted
    // one.
    draft.photoResolved = meal.photoPath != null;

    // Clear conversation-local state that must not carry over. A stale approval
    // would let a Meal be published against estimates nobody approved. Increment
    // the analysis request id so any in-flight reply from the previous Meal is
    // dropped.
    _analysisRequestId++;
    state = state.copyWith(
      approvals: const {},
      corrections: const {},
      analysis: null,
      analysisInFlight: false,
      analysisError: null,
      error: null,
    );

    // Start analysis if the draft already has a description, the same way
    // answering the description step does. Without this a Cook who resumes a
    // draft that has a description but no cuisine or category is stuck: they
    // cannot publish (the database requires both) and nothing would offer them
    // the estimates that supply them.
    if (meal.description != null) {
      _startAnalysis(photoPath: meal.photoPath);
    }
  }

  /// Records a Cook answer to a fallback question (cuisine or category).
  ///
  /// These are the Cook's own values, not AI estimates — so they are written
  /// with [markApproved] false and never enter [MealConversationState.approvals].
  Future<bool> answerFallback(MealFallbackStepId step, Object value) {
    final field = switch (step) {
      MealFallbackStepId.cuisine => MealEstimateFields.cuisine,
      MealFallbackStepId.category => MealEstimateFields.category,
    };
    return _writeEstimate(field, value, markApproved: false);
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

  /// Uploads a photo and records it as the answer to the photo step.
  ///
  /// Returns true when the photo was stored and the step advanced. On a
  /// failed upload the state carries the error and the Cook stays on the
  /// photo question — a photo that would not upload must not cost them the
  /// conversation.
  Future<bool> attachPhoto(Uint8List bytes) async {
    final mealId = state.draft.mealId;
    if (mealId == null) return false;

    state = state.copyWith(error: null);
    final result = await _repository.uploadPhoto(mealId: mealId, bytes: bytes);
    if (!ref.mounted) return false;

    switch (result) {
      case Success(value: final path):
        return answer(MealStepId.photo, path);
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
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
            // A new analysis replaces the old one; prior approvals were for
            // different values and must not silently carry over.
            state = state.copyWith(
              analysis: analysis,
              analysisInFlight: false,
              analysisError: null,
              approvals: const {},
              corrections: const {},
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

  /// Writes one AI-derived value to the draft and marks it approved.
  ///
  /// This is the human approval step: before it, nothing AI-derived reaches the
  /// database; after it, the Cook has said yes to that specific value.
  Future<bool> approveEstimate(String field) async {
    final analysis = state.analysis;
    if (analysis == null) return false;
    final value = _suggestedValue(analysis, field);
    if (value == null) return false;
    return _writeEstimate(field, value, markApproved: true);
  }

  /// Persists a Cook correction and marks that field approved.
  ///
  /// Editing counts as approving: a Cook who corrected a value has engaged
  /// with it more than one who tapped approve.
  Future<bool> correctEstimate(String field, Object value) async {
    return _writeEstimate(field, value,
        markApproved: true, markCorrected: true);
  }

  /// Puts the Meal on offer. Emits [EventNames.mealPublished] once on success.
  ///
  /// Does not set `published_at` — a database trigger owns that moment.
  Future<bool> publish() async {
    if (_publishInFlight) return false;
    if (!canPublish) return false;

    final mealId = state.draft.mealId;
    if (mealId == null) return false;

    _publishInFlight = true;
    state = state.copyWith(error: null);

    final result = await _repository.publish(mealId);
    if (!ref.mounted) {
      _publishInFlight = false;
      return false;
    }

    switch (result) {
      case Success():
        // Leave _publishInFlight true so a second tap cannot re-publish.
        unawaited(emitEvent(EventNames.mealPublished));
        state = state.copyWith(error: null);
        return true;
      case Failure(error: final err):
        _publishInFlight = false;
        state = state.copyWith(error: err);
        return false;
    }
  }

  Object? _suggestedValue(MealAnalysis analysis, String field) {
    return switch (field) {
      MealEstimateFields.cuisine => analysis.cuisine?.value,
      MealEstimateFields.category => analysis.category?.value,
      MealEstimateFields.ingredients => analysis.ingredients?.value,
      MealEstimateFields.calories => analysis.calories?.value,
      MealEstimateFields.allergens => analysis.allergens?.value,
      _ => null,
    };
  }

  Future<bool> _writeEstimate(
    String field,
    Object value, {
    required bool markApproved,
    bool markCorrected = false,
  }) async {
    final mealId = state.draft.mealId;
    if (mealId == null) return false;

    state = state.copyWith(error: null);

    // CookMeal, not Meal: every write here lands on a draft, and a draft has no
    // cuisine or category until one of these very calls puts it there.
    final Result<CookMeal, AppError> result;
    switch (field) {
      case MealEstimateFields.cuisine:
        if (value is! Cuisine) return false;
        result = await _repository.updateDraft(mealId: mealId, cuisine: value);
      case MealEstimateFields.category:
        if (value is! MealCategory) return false;
        result = await _repository.updateDraft(mealId: mealId, category: value);
      case MealEstimateFields.ingredients:
        if (value is! List<String>) return false;
        result =
            await _repository.updateDraft(mealId: mealId, ingredients: value);
      case MealEstimateFields.calories:
        if (value is! int) return false;
        result = await _repository.updateDraft(mealId: mealId, calories: value);
      case MealEstimateFields.allergens:
        if (value is! List<String>) return false;
        result =
            await _repository.updateDraft(mealId: mealId, allergens: value);
      default:
        return false;
    }

    if (!ref.mounted) return false;

    switch (result) {
      case Success():
        _applyToDraft(field, value);
        state = state.copyWith(
          approvals: markApproved
              ? (Map<String, bool>.from(state.approvals)..[field] = true)
              : null,
          corrections: markCorrected
              ? (Set<String>.from(state.corrections)..add(field))
              : null,
        );
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }

  void _applyToDraft(String field, Object value) {
    switch (field) {
      case MealEstimateFields.cuisine:
        state.draft.cuisine = value as Cuisine;
      case MealEstimateFields.category:
        state.draft.category = value as MealCategory;
      case MealEstimateFields.ingredients:
        state.draft.ingredients = value as List<String>;
      case MealEstimateFields.calories:
        state.draft.calories = value as int;
      case MealEstimateFields.allergens:
        state.draft.allergens = value as List<String>;
    }
  }
}
