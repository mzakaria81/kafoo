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
  ///
  /// **Small on purpose, and additive on purpose.** These are the things a
  /// Customer most often needs excluded for a reason that matters — the major
  /// allergens, the meats a religious or dietary rule turns on, and two
  /// aromatics people genuinely cannot eat. Growing it is how exclusions
  /// improve; guessing at it is how somebody gets served food they asked not to
  /// see.
  ///
  /// **The forms are how the word is WRITTEN, not what it means.** They are
  /// matched as substrings against what a Cook typed into a Meal's ingredients
  /// and allergens, so `لحمة` reaches `لحمة مفرومة` without either party having
  /// agreed on a vocabulary. That direction of looseness is deliberate: a
  /// substring match over-excludes rather than under-excludes, and
  /// over-excluding shows a Customer less food while under-excluding hands them
  /// the thing they asked to avoid.
  ///
  /// **A form is never shared between two entries.** `exclusion_vocabulary_test`
  /// asserts it, because a form claimed twice would let list order decide which
  /// exclusion a Customer gets, and the order of a list is not a decision
  /// anybody made.
  static const List<Exclusion> all = <Exclusion>[
    Exclusion(id: 'meat', surfaceForms: {'لحمة', 'لحمه', 'لحم'}),
    Exclusion(id: 'chicken', surfaceForms: {'فراخ', 'فرخة', 'فرخه', 'دجاج'}),
    Exclusion(id: 'fish', surfaceForms: {'سمك', 'سمكة', 'سمكه'}),
    Exclusion(
      id: 'shellfish',
      surfaceForms: {'جمبري', 'جمبرى', 'استاكوزا', 'كابوريا'},
    ),
    Exclusion(id: 'egg', surfaceForms: {'بيض', 'بيضة', 'بيضه'}),
    Exclusion(
      id: 'dairy',
      surfaceForms: {'لبن', 'حليب', 'جبنة', 'جبنه', 'زبادي', 'قشطة'},
    ),
    // Peanut is its own entry rather than part of `nuts`, because it is not a
    // nut and because someone allergic to one is frequently not allergic to the
    // other. Merging them would exclude food nobody needed excluded.
    Exclusion(id: 'peanut', surfaceForms: {'فول سوداني', 'سوداني'}),
    Exclusion(
      id: 'nuts',
      surfaceForms: {'مكسرات', 'لوز', 'عين جمل', 'بندق', 'فستق', 'كاجو'},
    ),
    Exclusion(id: 'sesame', surfaceForms: {'سمسم', 'طحينة', 'طحينه'}),
    Exclusion(id: 'gluten', surfaceForms: {'قمح', 'دقيق', 'جلوتين'}),
    Exclusion(id: 'onion', surfaceForms: {'بصل'}),
    Exclusion(id: 'garlic', surfaceForms: {'توم', 'ثوم'}),
  ];

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

  /// Reads what a Customer asked to avoid out of what they said.
  ///
  /// **Returning [NoExclusion] for a phrase that contained a negation would be
  /// the whole defect**, so it happens in exactly one case: no negation marker
  /// is present at all. A marker with a food nobody recognises — or with
  /// nothing after it, which is what a cut-off recording produces — is
  /// [ExclusionNotUnderstood], and the interface must say so rather than
  /// answering as though the Customer had asked for nothing.
  ///
  /// Only the first marker is read. A Customer excluding two things in one
  /// breath gets the first honoured and is told about it; that is a smaller
  /// wrong than guessing at the second.
  static ExclusionLookup parse(String phrase) {
    final text = phrase.trim();
    if (text.isEmpty) return const NoExclusion();

    // `negationMarkers` is longest-first, and a test holds it that way:
    // 'من غير ما يكون فيه' contains 'من غير', and matching the shorter one
    // first takes "ما يكون فيه لحمة" as the food — which is not a food, so a
    // phrase Kafoo handles would report not-understood.
    for (final marker in negationMarkers) {
      final at = text.indexOf(marker);
      if (at < 0) continue;

      final remainder = text.substring(at + marker.length).trim();
      if (remainder.isEmpty) return ExclusionNotUnderstood(remainder);

      // Longest run of words first, so a two-word food beats its first word.
      // Shorter runs then catch the ordinary case where the food is followed by
      // something that is not part of it — `من غير لحمة خالص`, the phrase the
      // 2026-08-06 measurement used, where `خالص` is an intensifier.
      final words = remainder.split(RegExp(r'\s+'));
      for (var take = words.length; take >= 1; take--) {
        final candidate = words.take(take).join(' ');
        final outcome = lookUp(candidate);
        if (outcome is ExclusionFound) return outcome;
      }
      return ExclusionNotUnderstood(remainder);
    }
    return const NoExclusion();
  }
}
