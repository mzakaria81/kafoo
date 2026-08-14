import 'dart:convert';

import 'package:kafoo_domain/domain.dart';

/// One turn of the assistant, as it came back from the model.
///
/// [say] is what is spoken aloud. [captured] holds only the facts the Cook
/// stated herself this turn — never an inference, because an inference is an
/// estimate and estimates go through the approval step instead.
final class ConversationReply {
  const ConversationReply({required this.say, this.captured = const {}});

  final String say;
  final Map<MealFact, Object> captured;
}

/// Turns a model reply into a [ConversationReply].
///
/// **`say` is the only required field, and a reply without one is a failure.**
/// Everything else can be absent — an empty `captured` is the common case, not
/// an error, because most turns are a question being answered or a piece of
/// advice being given rather than a fact being stated.
///
/// Same posture as `parseMealAnalysis`: strict JSON, no repair, no regular
/// expression. A field whose value is the wrong shape is dropped rather than
/// failing the whole turn — losing one captured value costs the Cook one
/// sentence, and losing the turn costs her the thread of the conversation.
Result<ConversationReply, AppError> parseConversationReply(String text) {
  late final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return Failure(AppError(messageKey: 'aiConversationInvalid', cause: e));
  }

  if (decoded is! Map<String, dynamic>) {
    return const Failure(AppError(messageKey: 'aiConversationInvalid'));
  }

  final say = decoded['say'];
  if (say is! String || say.trim().isEmpty) {
    // THE ONE FAILURE. A turn with nothing to say is a silent assistant, and
    // ADR-0013 calls a silent, still moment a defect at any latency. Better a
    // «معلش، مافهمتش» from the caller than a screen that shows nothing and a
    // Cook who cannot tell whether the app heard her.
    return const Failure(AppError(messageKey: 'aiConversationInvalid'));
  }

  return Success(
    ConversationReply(
        say: say.trim(), captured: _captured(decoded['captured'])),
  );
}

Map<MealFact, Object> _captured(Object? raw) {
  if (raw is! Map<String, dynamic>) return const {};

  final out = <MealFact, Object>{};
  for (final fact in MealFact.values) {
    final Object? value = raw[fact.wireName];
    if (value == null) continue;
    final parsed = _value(fact, value);
    if (parsed != null) out[fact] = parsed;
  }
  return Map.unmodifiable(out);
}

Object? _value(MealFact fact, Object value) {
  switch (fact) {
    case MealFact.dish:
    case MealFact.description:
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;

    case MealFact.price:
      // THE MODEL'S DIGITS GO THROUGH THE SAME PARSER A COOK'S KEYBOARD DOES.
      // On 2026-08-11 «١٢٠» reached a numeric column as that exact text and
      // every Cook was told her Meal could not be saved. A model asked to write
      // Egyptian Arabic will hand back Arabic-Indic digits sooner or later, so
      // this path cannot be the one that trusts them.
      if (value is num) return parseMealPrice(value.toString());
      if (value is! String) return null;
      return parseMealPrice(value);

    case MealFact.cuisine:
      if (value is! String) return null;
      final name = value.trim().toLowerCase();
      for (final c in Cuisine.values) {
        if (c.name == name) return c;
      }
      return null;

    case MealFact.category:
      if (value is! String) return null;
      final name = value.trim().toLowerCase();
      for (final c in MealCategory.values) {
        if (c.name == name) return c;
      }
      return null;
  }
}
