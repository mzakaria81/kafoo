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
    this.lines = const [],
    this.turnInFlight = false,
    this.analysis,
    this.analysisInFlight = false,
    this.analysisError,
    this.approvals = const {},
    this.corrections = const {},
    this.error,
  });

  static const _undefined = Object();

  final MealDraft draft;

  /// What the assistant has said so far, oldest first.
  ///
  /// **Only the assistant's side is here, and that is ADR-0013 rule 2 rather
  /// than an omission.** The screen shows what the assistant understood, never a
  /// transcript of the Cook — a paraphrase exposes a misunderstanding, and small
  /// verbatim text hides it from exactly the person who cannot read it.
  final List<String> lines;

  /// True while the assistant is working out what to say.
  ///
  /// Separate from [analysisInFlight]: one is the conversation, the other is the
  /// estimates being made in the background. A Cook waiting for a reply and a
  /// Cook waiting for a calorie count are in different situations and must not
  /// be shown the same spinner.
  final bool turnInFlight;
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
    List<String>? lines,
    bool? turnInFlight,
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
        lines: lines ?? this.lines,
        turnInFlight: turnInFlight ?? this.turnInFlight,
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

  /// How long the AI Assistant gets before the Cook is told it did not answer.
  ///
  /// Far outside the <2s budget on purpose: this is not a target, it is the
  /// point at which waiting stops being useful. The budget governs how fast a
  /// good reply arrives; this governs how long a Cook stares at a spinner when
  /// no reply is coming.
  static const Duration _analysisTimeout = Duration(seconds: 30);

  /// How long a conversational turn gets before the Cook is told nothing came
  /// back.
  ///
  /// Shorter than [_analysisTimeout] because the situations are different: an
  /// estimate arriving late is a background inconvenience, and a reply arriving
  /// late is a person standing in a kitchen wondering whether the app heard her.
  /// This is not the 2-second budget — it is the point at which waiting stops
  /// being useful.
  static const Duration _turnTimeout = Duration(seconds: 15);

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

  /// What the Meal still does not know about itself. Unordered, by design.
  ///
  /// Handed to the model each turn so it can decide what to say. **Kafoo owns
  /// this list and the model owns the sentence** — ADR-0015. Nothing here picks
  /// a next question, and if something ever does, the wizard is growing back.
  Set<MealFact> get missingFacts => mealFactsMissing(
        dish: state.draft.title,
        description: state.draft.description,
        price: state.draft.price,
        cuisine: state.draft.cuisine,
        category: state.draft.category,
      );

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

  /// Seeds the assistant's opening line, once.
  ///
  /// The line is localized, so it comes from the screen rather than from here —
  /// `packages/domain` and this controller have no `BuildContext` and must not
  /// grow one. Idempotent, because a rebuild must not make the assistant greet
  /// the same Cook twice.
  void open(String line) {
    if (state.lines.isNotEmpty) return;
    state = state.copyWith(lines: [line]);
  }

  /// Records a line the assistant already spoke for itself.
  ///
  /// The live conversation (ADR-0017) speaks through the provider's own voice, so
  /// by the time the words reach Kafoo they have been said. This puts them on
  /// the screen — the receipt of what was spoken — without saying them twice.
  void announce(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(lines: [...state.lines, trimmed]);
  }

  /// One turn of the conversation: the Cook said something, the assistant
  /// answers, and anything she stated is written to the draft.
  ///
  /// **This is the whole of ADR-0015 in one method.** There is no step, no
  /// order, and no question the screen was waiting to have answered. What
  /// Kafoo supplies is the state — what is known, what is missing — and the
  /// model supplies the sentence.
  ///
  /// **Only what she said is written.** The prompt returns `captured` for
  /// values she stated herself; an inferred cuisine is deliberately absent from
  /// it and reaches the draft through the estimate approval path instead. That
  /// is the AI write boundary, and it is the reason this method persists
  /// `captured` without a gate and could not persist an estimate the same way.
  ///
  /// Returns false when the assistant could not answer or a write failed; the
  /// caller keeps what the Cook typed so she does not have to say it twice.
  Future<bool> hear(String said) async {
    final heard = said.trim();
    if (heard.isEmpty) return false;
    if (state.turnInFlight) return false;

    state = state.copyWith(turnInFlight: true, error: null);

    final request = AiRequest(
      promptId: 'conversation',
      tier: ModelTier.fast,
      variables: {
        'said': heard,
        // KAFOO'S STATE AND THE COOK'S WORDS ARRIVE AS SEPARATE VARIABLES, and
        // the separation is the injection boundary rather than tidiness. What
        // is missing is Kafoo talking; `said` is a person talking. A prompt that
        // concatenated them would let a Cook write her own "still missing" list.
        'missing': missingFacts.map((f) => f.wireName).join(','),
        'known': _known(),
      },
    );

    final Result<AiResponse, AppError> result;
    try {
      result = await _ai.complete(request).timeout(
            _turnTimeout,
            onTimeout: () =>
                const Failure(AppError(messageKey: 'analyzeMealTimeout')),
          );
    } on Object catch (e) {
      // `_ai.complete` is declared to return a Result and the transport under it
      // throws on any non-2xx — the same trap that left `analysisInFlight` stuck
      // true for the life of a screen on 2026-08-11. A conversation that stops
      // answering with no message is the worst version of that bug, because
      // silence is what a Cook reads as "it did not hear me".
      if (!ref.mounted) return false;
      state = state.copyWith(
        turnInFlight: false,
        error: AppError(messageKey: 'analyzeMealUnknownError', cause: e),
      );
      return false;
    }

    if (!ref.mounted) return false;

    switch (result) {
      case Failure(error: final err):
        state = state.copyWith(turnInFlight: false, error: err);
        return false;
      case Success(value: final response):
        final parsed = parseConversationReply(response.text);
        switch (parsed) {
          case Failure(error: final err):
            state = state.copyWith(turnInFlight: false, error: err);
            return false;
          case Success(value: final reply):
            final written = await _persistCaptured(reply.captured);
            if (!ref.mounted) return false;
            state = state.copyWith(
              lines: [...state.lines, reply.say],
              turnInFlight: false,
            );
            if (canBeginAnalysis(
              dish: state.draft.title,
              description: state.draft.description,
            )) {
              _startAnalysis(photoPath: state.draft.photoPath);
            }
            return written;
        }
    }
  }

  /// What is already known, as a short line the model can read.
  ///
  /// Deliberately values rather than a schema: the model is being told what not
  /// to ask for, and «الأكلة: محشي ورق عنب» answers that better than a key list.
  String _known() {
    final draft = state.draft;
    final parts = <String>[
      if (draft.title != null) 'dish=${draft.title}',
      if (draft.description != null) 'description=${draft.description}',
      if (draft.price != null) 'price=${draft.price}',
      if (draft.cuisine != null) 'cuisine=${draft.cuisine!.name}',
      if (draft.category != null) 'category=${draft.category!.name}',
    ];
    return parts.join('\n');
  }

  /// Writes the facts the Cook stated this turn, creating the draft if this is
  /// the first one.
  ///
  /// Returns false if any write failed. A partial failure leaves the successful
  /// writes in place — losing a price because a description would not save is
  /// worse than a draft that is half-written and can be finished.
  Future<bool> _persistCaptured(Map<MealFact, Object> captured) async {
    if (captured.isEmpty) return true;

    var ok = true;

    if (state.draft.mealId == null) {
      final title = captured[MealFact.dish];
      // A DRAFT NEEDS A TITLE AND THE COOK MAY NOT HAVE GIVEN ONE YET. She can
      // open with a price, or a question. Nothing is written until she names the
      // food, which is also the first thing the database requires.
      if (title is! String) return true;
      final created = await _repository.createDraft(title: title);
      if (!ref.mounted) return false;
      switch (created) {
        case Success(value: final id):
          state.draft.mealId = id;
          state.draft.title = title;
          state = state.copyWith();
          unawaited(emitEvent(EventNames.mealDrafted));
        case Failure(error: final err):
          state = state.copyWith(error: err);
          return false;
      }
    }

    final mealId = state.draft.mealId!;
    for (final entry in captured.entries) {
      if (entry.key == MealFact.dish && state.draft.title == entry.value) {
        continue;
      }
      final result = await _writeFact(mealId, entry.key, entry.value);
      if (!ref.mounted) return false;
      switch (result) {
        case Success():
          _applyFact(entry.key, entry.value);
        case Failure(error: final err):
          state = state.copyWith(error: err);
          ok = false;
      }
    }
    state = state.copyWith();
    return ok;
  }

  Future<Result<Object?, AppError>> _writeFact(
    String mealId,
    MealFact fact,
    Object value,
  ) =>
      switch (fact) {
        MealFact.dish =>
          _repository.updateDraft(mealId: mealId, title: value as String),
        MealFact.description =>
          _repository.updateDraft(mealId: mealId, description: value as String),
        MealFact.price =>
          _repository.updateDraft(mealId: mealId, price: value as String),
        MealFact.cuisine =>
          _repository.updateDraft(mealId: mealId, cuisine: value as Cuisine),
        MealFact.category => _repository.updateDraft(
            mealId: mealId,
            category: value as MealCategory,
          ),
      };

  void _applyFact(MealFact fact, Object value) {
    switch (fact) {
      case MealFact.dish:
        state.draft.title = value as String;
      case MealFact.description:
        state.draft.description = value as String;
      case MealFact.price:
        state.draft.price = value as String;
      case MealFact.cuisine:
        state.draft.cuisine = value as Cuisine;
      case MealFact.category:
        state.draft.category = value as MealCategory;
    }
  }

  /// Records a Cook's correction of a value she gave, from the receipt.
  ///
  /// **Correcting by tap is the complete alternative ADR-0013 requires**, not a
  /// lesser path: it writes exactly what saying «لأ، السعر مية وخمسين» writes.
  ///
  /// Returns true when the answer was accepted, false when a write failed.
  /// The caller should clear the text field only on success.
  Future<bool> correct(MealStepId step, String raw) async {
    state = state.copyWith(error: null);

    // THE PRICE IS NORMALISED BEFORE ANYTHING ELSE SEES IT, and that is the fix
    // for the second defect to reach the founder's phone on 2026-08-11. He typed
    // «١٢٠» — the digits an Arabic keyboard produces — and the answer went to a
    // `numeric(10,2)` column as that exact text. Postgres refuses it, and the
    // refusal surfaced as «مقدرناش نحفظ الأكلة»: every Cook, every price.
    //
    // Here rather than in `_persistAnswer`, so the value written to the database
    // and the value `_recordAnswer` keeps in memory are the same string. Two
    // representations of one price is how a summary comes to disagree with the
    // row it is summarising.
    final String value;
    if (step == MealStepId.price) {
      final price = parseMealPrice(raw);
      if (price == null) {
        // Not a save failure — a question the Cook can answer again, and the
        // only failure in this flow she can actually do anything about.
        state = state.copyWith(
          error: const AppError(messageKey: 'mealPriceInvalid'),
        );
        return false;
      }
      value = price;
    } else {
      value = raw;
    }

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
        return correct(MealStepId.photo, path);
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
    // WRAPPED, AND THE WRAPPER IS THE FIX FOR A DEAD END THE FOUNDER HIT ON
    // 2026-08-11: «تقديرات المساعد» spun forever and the conversation could not
    // be finished at all.
    //
    // `_ai.complete` is declared to return a `Result`, and the transport under
    // it does not honour that — `client.functions.invoke` THROWS on any non-2xx
    // reply. `_startAnalysis` calls this method inside `unawaited(...)`, so the
    // throw went nowhere: no error, no log, and `analysisInFlight` left true for
    // the life of the screen.
    //
    // A stuck flag is worse than a visible failure. `currentFallbackStep`
    // returns null while it is set, so the questions that ASK for cuisine and
    // category — the two answers the database requires before a Meal may leave
    // draft — were never offered. The Cook was not waiting for an estimate. She
    // was locked out of publishing, with a spinner as the only explanation.
    //
    // Anything thrown from here therefore has to land as an error the Cook can
    // read, and the flag has to come down whatever happens.
    try {
      await _analyse(requestId, request, usedPhoto: usedPhoto);
    } on Object catch (e) {
      if (!ref.mounted) return;
      if (requestId != _analysisRequestId) return;
      state = state.copyWith(
        analysisInFlight: false,
        analysisError:
            AppError(messageKey: 'analyzeMealUnknownError', cause: e),
      );
    }
  }

  Future<void> _analyse(
    int requestId,
    AiRequest request, {
    required bool usedPhoto,
  }) async {
    final result = await _ai.complete(request).timeout(
          _analysisTimeout,
          // A reply that never arrives is the same dead end as a throw. The
          // Edge Function has its own deadline; nothing was enforcing one on a
          // connection that simply stops answering, which on an Egyptian mobile
          // network is not a rare case.
          onTimeout: () =>
              const Failure(AppError(messageKey: 'analyzeMealTimeout')),
        );

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
