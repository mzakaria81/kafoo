import 'dart:convert';

import 'package:kafoo_domain/domain.dart';

/// One turn of the Kitchen Profile conversation, as it came back from the model.
///
/// [say] is what is spoken aloud. [captured] holds only the facts the Cook
/// stated herself this turn — never an inference, and in this conversation that
/// rule has one place it really bites: the form of address. A model that reads
/// «أم علي» and writes `feminine` has guessed at something ADR-0010 says may
/// only be answered, so the prompt forbids it and this parser cannot tell the
/// difference. The defence is the prompt plus the read-back before anything is
/// created.
final class KitchenConversationReply {
  const KitchenConversationReply({required this.say, this.captured = const {}});

  final String say;
  final Map<KitchenFact, Object> captured;
}

/// Turns a model reply into a [KitchenConversationReply].
///
/// Same posture as `parseConversationReply`, deliberately: strict JSON, no
/// repair, no regular expression. A field whose value is the wrong shape is
/// dropped rather than failing the whole turn — losing one captured value costs
/// the Cook one sentence, and losing the turn costs her the thread.
///
/// **`say` is the only required field**, and a reply without one is a failure.
/// A turn with nothing to say is a silent assistant, and ADR-0013 calls a
/// silent, still moment a defect at any latency.
Result<KitchenConversationReply, AppError> parseKitchenConversationReply(
  String text,
) {
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
    return const Failure(AppError(messageKey: 'aiConversationInvalid'));
  }

  return Success(
    KitchenConversationReply(
      say: say.trim(),
      captured: _captured(decoded['captured']),
    ),
  );
}

Map<KitchenFact, Object> _captured(Object? raw) {
  if (raw is! Map<String, dynamic>) return const {};

  final out = <KitchenFact, Object>{};
  for (final fact in KitchenFact.values) {
    final Object? value = raw[fact.wireName];
    if (value == null) continue;
    final parsed = _value(fact, value);
    if (parsed != null) out[fact] = parsed;
  }
  return Map.unmodifiable(out);
}

Object? _value(KitchenFact fact, Object value) {
  switch (fact) {
    case KitchenFact.displayName:
    case KitchenFact.story:
    case KitchenFact.area:
    case KitchenFact.deliveryTerms:
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;

    case KitchenFact.addressForm:
      // ONLY THE TWO WORDS, AND ANYTHING ELSE IS DROPPED RATHER THAN GUESSED.
      // The column has a CHECK constraint and the wrong ending follows a Cook
      // for the life of her account, so an unrecognised value must leave the
      // fact missing — which makes the assistant ask, which is the correct
      // outcome.
      if (value is! String) return null;
      return switch (value.trim().toLowerCase()) {
        'feminine' => AddressForm.feminine,
        'masculine' => AddressForm.masculine,
        _ => null,
      };
  }
}
