/// What Kafoo found, and what the AI Assistant later said about it. No Flutter,
/// no Supabase.
///
/// The shape of this type carries one rule that is easy to lose in an
/// implementation: **results are complete without a judgement.** A
/// [DiscoveryResults] is displayable the moment it exists, and the AI
/// Assistant's opinion arrives afterwards or not at all. Modelling the
/// judgement as a required field would make it impossible to render results
/// without waiting for it, which is the one thing the design forbids.
library;

import 'meal.dart';

/// A Meal that answered a request, and where it ranked.
final class DiscoveryResult {
  /// Creates a ranked result.
  const DiscoveryResult({required this.meal, required this.rank});

  /// The Meal. Only ever one that is on offer — a Meal in any other state is
  /// refused by the database, not filtered here.
  final Meal meal;

  /// Where it placed, from 1. Presentation order, never a score.
  ///
  /// A score is deliberately not carried: it varies more between requests than
  /// between a good answer and a bad one, which is why no threshold on it works
  /// and why the judgement below exists at all.
  final int rank;
}

/// What the AI Assistant concluded about a set of results.
///
/// It may only ever say something *about* results it was given. It cannot
/// reorder them, filter them, add to them, or name a Meal that was not in the
/// set — a Meal it named that is not on offer would be Kafoo advertising food
/// nobody is cooking.
sealed class Judgement {
  /// Creates a judgement.
  const Judgement();
}

/// The results answer the request.
final class ResultsAnswer extends Judgement {
  /// Creates the answering judgement.
  const ResultsAnswer();
}

/// Nothing on offer answers the request.
///
/// [alternatives] are Meals that **are** on offer, drawn from the set the AI
/// Assistant was handed. Naming one is a Recommendation, which the glossary
/// says is owned by nobody and never persisted as truth.
final class NothingAnswers extends Judgement {
  /// Creates the nothing-answers judgement.
  const NothingAnswers({this.alternatives = const <Meal>[]});

  /// Meals genuinely on offer, offered instead.
  final List<Meal> alternatives;
}

/// A set of results, with a judgement that may not have arrived.
final class DiscoveryResults {
  /// Creates a result set.
  const DiscoveryResults({
    required this.results,
    this.judgement,
  });

  /// The ranked Meals, in the order the database returned them.
  ///
  /// Never re-sorted after the fact. A second ordering applied here would be a
  /// second ranking rule living somewhere the first one cannot see.
  final List<DiscoveryResult> results;

  /// What the AI Assistant said, once it has said anything.
  ///
  /// `null` means it has not answered **yet, or at all** — and the two are
  /// deliberately indistinguishable, because they must produce the same screen.
  /// A judgement that fails costs a sentence, never the results.
  final Judgement? judgement;

  /// Whether the database returned anything at all.
  ///
  /// Distinct from [Judgement]: retrieval returning rows is not the same as
  /// those rows answering the question, and conflating the two is what a score
  /// threshold tried and failed to do.
  bool get isEmpty => results.isEmpty;

  /// Whether Kafoo has concluded that nothing answers the request.
  bool get saysNothingAnswers => judgement is NothingAnswers;

  /// The same results with [judgement] attached.
  DiscoveryResults withJudgement(Judgement judgement) =>
      DiscoveryResults(results: results, judgement: judgement);
}
