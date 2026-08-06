/// What a Customer asked not to be shown. No Flutter, no Supabase.
///
/// This type exists because of a measurement rather than a preference. On
/// 2026-08-06 the phrase `أكل من غير لحمة خالص` — "food with no meat at all" —
/// was run against a corpus containing both meat and meatless Meals, matched by
/// meaning. It returned **meat dishes**: the first correct answer sat at rank 6
/// and precision@5 was 0.00. See `docs/ops/spike-discovery-embeddings.md`.
///
/// That is a known property of matching by meaning rather than a defect to fix
/// — the representation of "no meat" sits next to the representation of "meat".
/// So an exclusion is never handed to a model. It becomes a database predicate,
/// and this type is the vocabulary that predicate is built from.
///
/// **Why it is a closed list rather than free text.** A Customer excluding a
/// food is usually doing so for dietary, religious or health reasons, and
/// serving them the opposite is a betrayal rather than a poor result. A closed
/// list can be wrong in only one direction: it fails to recognise something,
/// which is visible and says so. Free text fails silently by matching nothing
/// and returning everything.
library;

/// A food a Customer asked not to be shown.
///
/// [surfaceForms] are the ways the thing is actually written, not a definition
/// of it. Matching is by these forms, so a form that is missing means a Customer
/// who used that word is not understood — which [ExclusionVocabulary.lookUp]
/// reports rather than swallowing.
final class Exclusion {
  /// Creates an exclusion.
  const Exclusion({
    required this.id,
    required this.surfaceForms,
  });

  /// The stable name for this exclusion. Never shown to anyone.
  final String id;

  /// The ways a Customer might write it, and the ways a Cook might have written
  /// it in a Meal's ingredients.
  final Set<String> surfaceForms;

  @override
  bool operator ==(Object other) => other is Exclusion && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Exclusion($id)';
}

/// The result of trying to understand what a Customer excluded.
///
/// The two failure cases are deliberately different things, because they must
/// produce different behaviour. Nothing asked for is ordinary. A negation
/// **recognised but not understood** is the dangerous one: it means the Customer
/// said "without X" and Kafoo does not know what X is, and returning results as
/// though no exclusion had been asked for is exactly the failure the measurement
/// above found, arriving by a different route.
sealed class ExclusionLookup {
  /// Creates a lookup outcome.
  const ExclusionLookup();
}

/// The Customer excluded nothing.
final class NoExclusion extends ExclusionLookup {
  /// Creates the no-exclusion outcome.
  const NoExclusion();
}

/// The Customer excluded something Kafoo recognises.
final class ExclusionFound extends ExclusionLookup {
  /// Creates a recognised exclusion.
  const ExclusionFound(this.exclusion);

  /// What was excluded.
  final Exclusion exclusion;
}

/// A negation was recognised and the thing being excluded was not.
///
/// **This must reach the Customer.** Kafoo says it did not understand rather
/// than quietly dropping the exclusion; the [phrase] is what they wrote, so the
/// interface can say which word it failed on.
final class ExclusionNotUnderstood extends ExclusionLookup {
  /// Creates the not-understood outcome around the unrecognised [phrase].
  const ExclusionNotUnderstood(this.phrase);

  /// The words that followed the negation marker.
  final String phrase;
}

/// The controlled list of things a Customer can exclude.
///
/// Deliberately small and deliberately additive. Growing it is how exclusions
/// improve; guessing at it is how a Customer gets served food they asked not to
/// see.
///
/// **The entries themselves land with the exclusion work, not here.** This
/// package ships the type and the lookup so the shape is fixed before anything
/// depends on it; a Meal is not filtered by any of this until that work runs.
abstract final class ExclusionVocabulary {
  /// Egyptian Arabic negation markers, as a closed set.
  ///
  /// Closed because these are the ways the language marks "without", not a
  /// sample of them. Longest first: `من غير ما يكون فيه` contains `من غير`, and
  /// matching the shorter one first would take the rest of the phrase as the
  /// thing excluded.
  static const List<String> negationMarkers = <String>[
    'من غير ما يكون فيه',
    'مش عايز',
    'مش عاوز',
    'من غير',
    'بدون',
  ];

  /// Every exclusion Kafoo understands.
  static const List<Exclusion> all = <Exclusion>[];

  /// Finds the exclusion [term] names, if Kafoo knows it.
  ///
  /// Returns [ExclusionNotUnderstood] rather than null for an unrecognised
  /// term, because the caller must not be able to treat "I do not know this
  /// word" the same as "nothing was excluded". Those produce opposite
  /// behaviour and the type is what stops them being confused.
  static ExclusionLookup lookUp(String term) {
    final needle = term.trim();
    if (needle.isEmpty) return const NoExclusion();

    for (final exclusion in all) {
      if (exclusion.surfaceForms.contains(needle)) {
        return ExclusionFound(exclusion);
      }
    }
    return ExclusionNotUnderstood(needle);
  }
}
