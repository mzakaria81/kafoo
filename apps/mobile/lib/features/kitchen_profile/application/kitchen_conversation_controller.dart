import 'dart:async';
import 'dart:typed_data';

import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../meal/data/ai_provider.dart';
import '../data/kitchen_profile_repository.dart';

part 'kitchen_conversation_controller.g.dart';

/// The repository, as a provider so a test can replace it.
///
/// It used to be passed down the widget tree from `home.dart` instead. That
/// works for a screen and stops working for a controller, which has no parent
/// to be handed anything by.
@riverpod
KitchenProfileRepository kitchenProfileRepository(Ref ref) =>
    const SupabaseKitchenProfileRepository();

/// Immutable snapshot of the Kitchen Profile conversation.
class KitchenConversationState {
  const KitchenConversationState({
    required this.draft,
    this.lines = const [],
    this.turnInFlight = false,
    this.saved,
    this.error,
  });

  static const _undefined = Object();

  final KitchenProfileDraft draft;

  /// What the assistant has said so far, oldest first.
  ///
  /// **Only the assistant's side, and that is ADR-0013 rule 2 rather than an
  /// omission.** The screen shows what the assistant understood, never a
  /// transcript of the Cook — a paraphrase exposes a misunderstanding, and small
  /// verbatim text hides it from exactly the person who cannot read it.
  final List<String> lines;

  final bool turnInFlight;

  /// The Kitchen Profile once it exists. Null until she says «أيوة» at the gate.
  final KitchenProfile? saved;

  final AppError? error;

  KitchenConversationState copyWith({
    KitchenProfileDraft? draft,
    List<String>? lines,
    bool? turnInFlight,
    Object? saved = _undefined,
    Object? error = _undefined,
  }) =>
      KitchenConversationState(
        draft: draft ?? this.draft,
        lines: lines ?? this.lines,
        turnInFlight: turnInFlight ?? this.turnInFlight,
        saved: saved == _undefined ? this.saved : saved as KitchenProfile?,
        error: error == _undefined ? this.error : error as AppError?,
      );
}

/// The Kitchen Profile conversation — one open exchange, no questions.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THIS REPLACES A FIVE-QUESTION WIZARD, AND THE WIZARD WAS THE SECOND THING A
/// NEW COOK EVER MET.** Name, then story, then area, then delivery terms, then
/// how to address her — one per screen, in that order, with a summary at the
/// end. She signed in, was told the product talks to her, and was handed a form.
///
/// What replaces it is the same shape the Meal conversation already has: the
/// assistant says something, the Cook says something back, and the receipt
/// underneath fills in as she talks. She can ask questions, be advised, and
/// change her mind, and none of that is an error state.
///
/// **Kafoo still owns what a kitchen requires.** [missingFacts] is handed to the
/// model every turn and the model picks what to say; it never decides what a
/// kitchen needs and Kafoo never decides the order of the asking.
///
/// **NOTHING IS WRITTEN UNTIL SHE SAYS «أيوة».** This is the one real difference
/// from the Meal conversation, and it comes from the database rather than from a
/// preference: a Meal has a `draft` status and can be saved half-finished, and
/// `kitchen_profiles` requires every text column non-empty in a single insert.
/// So facts accumulate in memory and [create] runs once, behind the read-back
/// gate. A Cook who walks away has written nothing, which is also the right
/// privacy answer — she has told a stranger about herself and Kafoo kept none
/// of it.
/// ─────────────────────────────────────────────────────────────────────────────
@riverpod
class KitchenConversationController extends _$KitchenConversationController {
  KitchenProfileRepository get _repository =>
      ref.read(kitchenProfileRepositoryProvider);
  AiProvider get _ai => ref.read(aiProviderProvider);

  /// How long a turn gets before the Cook is told nothing came back.
  ///
  /// Not the 2-second budget — it is the point at which waiting stops being
  /// useful. Same number the Meal conversation uses, because it is the same
  /// person standing in the same kitchen wondering whether the app heard her.
  static const Duration _turnTimeout = Duration(seconds: 15);

  bool _createInFlight = false;

  @override
  KitchenConversationState build() =>
      KitchenConversationState(draft: KitchenProfileDraft());

  /// What the kitchen still does not know about itself. Unordered, by design.
  Set<KitchenFact> get missingFacts => kitchenFactsMissing(
        displayName: state.draft.displayName,
        story: state.draft.story,
        area: state.draft.area,
        deliveryTerms: state.draft.deliveryTerms,
        addressForm: state.draft.addressForm,
      );

  /// Whether the kitchen can be created.
  bool get canCreate =>
      state.draft.isComplete && state.saved == null && !_createInFlight;

  /// Seeds the assistant's opening line, once.
  ///
  /// The line is localized, so it comes from the screen rather than from here —
  /// this controller has no `BuildContext` and must not grow one. Idempotent,
  /// because a rebuild must not make the assistant greet the same Cook twice.
  void open(String line) {
    if (state.lines.isNotEmpty) return;
    state = state.copyWith(lines: [line]);
  }

  /// Records a line the assistant already spoke for itself.
  ///
  /// The live conversation (ADR-0017) speaks through the provider's own voice,
  /// so by the time the words reach Kafoo they have been said. This puts them
  /// on the screen without saying them twice.
  void announce(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(lines: [...state.lines, trimmed]);
  }

  /// One turn: the Cook said something, the assistant answers, and anything she
  /// stated is kept.
  ///
  /// Returns false when the assistant could not answer; the caller keeps what
  /// the Cook typed so she does not have to say it twice.
  Future<bool> hear(String said) async {
    final heard = said.trim();
    if (heard.isEmpty) return false;
    if (state.turnInFlight) return false;

    state = state.copyWith(turnInFlight: true, error: null);

    final request = AiRequest(
      promptId: 'kitchen-conversation',
      tier: ModelTier.fast,
      variables: {
        'said': heard,
        // KAFOO'S STATE AND THE COOK'S WORDS ARRIVE AS SEPARATE VARIABLES, and
        // the separation is the injection boundary rather than tidiness. What is
        // missing is Kafoo talking; `said` is a person talking. A prompt that
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
      // throws on any non-2xx. A conversation that stops answering with no
      // message is the worst version of that bug, because silence is what a Cook
      // reads as "it did not hear me".
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
        final parsed = parseKitchenConversationReply(response.text);
        switch (parsed) {
          case Failure(error: final err):
            state = state.copyWith(turnInFlight: false, error: err);
            return false;
          case Success(value: final reply):
            _apply(reply.captured);
            state = state.copyWith(
              lines: [...state.lines, reply.say],
              turnInFlight: false,
            );
            return true;
        }
    }
  }

  /// What is already known, as a short line the model can read.
  ///
  /// Values rather than a schema: the model is being told what not to ask for,
  /// and «المطبخ: مطبخ أم علي» answers that better than a key list.
  String _known() {
    final draft = state.draft;
    return [
      if (draft.displayName != null) 'display_name=${draft.displayName}',
      if (draft.story != null) 'story=${draft.story}',
      if (draft.area != null) 'area=${draft.area}',
      if (draft.deliveryTerms != null) 'delivery_terms=${draft.deliveryTerms}',
      if (draft.addressForm != null) 'address_form=${draft.addressForm!.name}',
    ].join('\n');
  }

  /// Writes a fact the Cook stated, whether she spoke it or tapped it.
  ///
  /// Public because the receipt's «غيّر» rows write exactly what saying the same
  /// thing out loud writes — ADR-0013's requirement that tap be a complete
  /// alternative rather than a degraded one.
  void correct(KitchenFact fact, Object value) {
    _apply({fact: value});
    state = state.copyWith(error: null);
  }

  void _apply(Map<KitchenFact, Object> captured) {
    if (captured.isEmpty) return;
    final draft = state.draft;
    for (final entry in captured.entries) {
      switch (entry.key) {
        case KitchenFact.displayName:
          if (entry.value is String) draft.displayName = entry.value as String;
        case KitchenFact.story:
          if (entry.value is String) draft.story = entry.value as String;
        case KitchenFact.area:
          if (entry.value is String) draft.area = entry.value as String;
        case KitchenFact.deliveryTerms:
          if (entry.value is String) {
            draft.deliveryTerms = entry.value as String;
          }
        case KitchenFact.addressForm:
          if (entry.value is AddressForm) {
            draft.addressForm = entry.value as AddressForm;
          }
      }
    }
    // The draft is mutated in place, so a new state identity is what tells
    // Riverpod anything happened.
    state = state.copyWith();
  }

  /// Attaches an uploaded photo. Optional, and never blocks the kitchen.
  Future<bool> attachPhoto(Uint8List bytes) async {
    final result = await _repository.uploadPhoto(bytes);
    if (!ref.mounted) return false;
    switch (result) {
      case Success(value: final path):
        state.draft.photoPath = path;
        state = state.copyWith();
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }

  /// Creates the Kitchen Profile. Called only after the read-back gate.
  ///
  /// Guarded against a double answer putting two kitchens on one account — a
  /// unique constraint on `cook_id` would refuse the second, but the Cook would
  /// be shown a database error for pressing a button twice.
  Future<bool> create() async {
    if (!canCreate) return false;
    _createInFlight = true;
    state = state.copyWith(error: null);

    final draft = state.draft;
    final result = await _repository.create(
      displayName: draft.displayName!,
      story: draft.story!,
      area: draft.area!,
      deliveryTerms: draft.deliveryTerms!,
      addressForm: draft.addressForm,
      photoPath: draft.photoPath,
    );
    _createInFlight = false;
    if (!ref.mounted) return false;

    switch (result) {
      case Success(value: final profile):
        state = state.copyWith(saved: profile);
        return true;
      case Failure(error: final err):
        state = state.copyWith(error: err);
        return false;
    }
  }
}
