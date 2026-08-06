import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ExclusionVocabulary.lookUp', () {
    test('nothing asked for is not the same as not understood', () {
      // These two outcomes must stay distinguishable by TYPE, not by a null
      // check, because they produce opposite behaviour: one serves the request
      // normally, the other must tell the Customer Kafoo did not understand.
      // Collapsing them is how a Customer who said "without meat" gets meat.
      expect(ExclusionVocabulary.lookUp(''), isA<NoExclusion>());
      expect(ExclusionVocabulary.lookUp('   '), isA<NoExclusion>());
      expect(ExclusionVocabulary.lookUp('كافيار'), isA<ExclusionNotUnderstood>());
    });

    test('an unrecognised term reports what it failed on', () {
      final outcome = ExclusionVocabulary.lookUp('  كافيار  ');
      expect(outcome, isA<ExclusionNotUnderstood>());
      expect((outcome as ExclusionNotUnderstood).phrase, 'كافيار');
    });

    test('longer negation markers sort before the markers they contain', () {
      // 'من غير ما يكون فيه' contains 'من غير'. Matching the shorter one first
      // would take "ما يكون فيه لحمة" as the thing being excluded, which is not
      // a food and would report not-understood on a phrase Kafoo does handle.
      final markers = ExclusionVocabulary.negationMarkers;
      for (var i = 0; i < markers.length; i++) {
        for (var j = i + 1; j < markers.length; j++) {
          expect(
            markers[i].contains(markers[j]) && markers[i].length < markers[j].length,
            isFalse,
            reason: '${markers[j]} must come before ${markers[i]}',
          );
        }
      }
    });
  });

  group('DiscoveryRequest', () {
    test('toString never leaks what the Customer said', () {
      // toString is what reaches a crash report and a log line. A phrase there
      // defeats the no-recording rule everywhere at once.
      const request = DiscoveryRequest(phrase: 'نفسي في حاجة خفيفة', area: 'المهندسين');
      expect(request.toString(), isNot(contains('نفسي')));
      expect(request.toString(), isNot(contains('المهندسين')));
    });

    test('a plain request narrows nothing', () {
      expect(const DiscoveryRequest.plain('كشري').isNarrowed, isFalse);
      expect(
        const DiscoveryRequest(phrase: 'كشري', area: 'الدقي').isNarrowed,
        isTrue,
      );
    });
  });

  group('DiscoveryResults', () {
    const results = DiscoveryResults(results: <DiscoveryResult>[]);

    test('results are complete without a judgement', () {
      // The whole ordering rule in one assertion: a result set must be
      // displayable before anything has judged it.
      expect(results.judgement, isNull);
      expect(results.isEmpty, isTrue);
    });

    test('empty retrieval is not the same as nothing answering', () {
      // Rows coming back is not the same as those rows answering the question.
      // Conflating them is what a score threshold tried and failed to do.
      expect(results.saysNothingAnswers, isFalse);
      expect(
        results.withJudgement(const NothingAnswers()).saysNothingAnswers,
        isTrue,
      );
    });

    test('attaching a judgement leaves the results untouched', () {
      final judged = results.withJudgement(const ResultsAnswer());
      expect(judged.results, same(results.results));
    });
  });
}
