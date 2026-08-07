/// What a Customer asked for. No Flutter, no Supabase.
///
/// One sentence in a Customer's own words carries three things at once — what
/// they want, what they do not want, and where. They are held here as separate
/// fields because the database needs them separately, **not** because the
/// interface collects them separately. Three input controls would be a form at
/// the exact point Kafoo's rules forbid one.
///
/// **Nothing here is ever stored.** A request lives for the length of one
/// interaction. Kafoo records that a search happened and how many results came
/// back, never what was said — so [phrase] must not reach an analytics event, a
/// log line, or an error carrying the request that produced it.
library;

import 'exclusion.dart';

/// A Customer's request, parsed from one sentence.
final class DiscoveryRequest {
  /// Creates a request.
  const DiscoveryRequest({
    required this.phrase,
    this.exclusions = const <Exclusion>[],
    this.notUnderstood,
    this.area,
  });

  /// A request that excludes nothing and names no area.
  const DiscoveryRequest.plain(this.phrase)
      : exclusions = const <Exclusion>[],
        notUnderstood = null,
        area = null;

  /// What the Customer said, as they said it.
  ///
  /// Never recorded, never cached against, never logged.
  final String phrase;

  /// What they asked not to be shown.
  final List<Exclusion> exclusions;

  /// Set when a negation was recognised and what followed it was not.
  ///
  /// **A request carrying this must not be served as though nothing was
  /// excluded.** Kafoo says it did not understand. Dropping it silently is the
  /// failure the exclusion measurement found, arriving by a different route —
  /// see [Exclusion].
  final ExclusionNotUnderstood? notUnderstood;

  /// An area the Customer named, in their own words.
  ///
  /// Matched against what Cooks wrote about their own kitchens. Kafoo holds no
  /// location for a Customer and no notion of where an area is, so this can
  /// narrow a search and can never order one by distance.
  final String? area;

  /// Whether Kafoo failed to understand something the Customer excluded.
  bool get hasNotUnderstoodExclusion => notUnderstood != null;

  /// Whether this request narrows anything beyond the phrase itself.
  bool get isNarrowed => exclusions.isNotEmpty || area != null;

  /// Deliberately omits [phrase], and this is not an oversight to tidy up.
  ///
  /// `toString` is what ends up in a crash report, a debug log and an error
  /// message, which is exactly where a Customer's own words must never appear.
  /// Adding the phrase here would defeat the rule everywhere at once, quietly.
  @override
  String toString() =>
      'DiscoveryRequest(exclusions: ${exclusions.length}, area: ${area != null},'
      ' notUnderstood: $hasNotUnderstoodExclusion)';
}
