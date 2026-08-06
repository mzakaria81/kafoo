import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('kitchenProfileSteps', () {
    // SC-006: at any point in the conversation exactly one question is asked.
    // We verify this by asserting that every step BEFORE nextUnansweredStep
    // is marked answered, and that nextUnansweredStep is unique.
    test(
        'SC-006: exactly one unanswered question presented at a time — no answers',
        () {
      final steps = kitchenProfileSteps(
        displayName: null,
        story: null,
        area: null,
        deliveryTerms: null,
        addressForm: null,
      );
      final next = nextUnansweredStep(steps);
      expect(next, isNotNull);
      expect(next!.id, ConversationStepId.displayName);
      // All steps before the current question are answered.
      final beforeNext = steps.takeWhile((s) => s.id != next.id).toList();
      expect(beforeNext.every((s) => s.answered), isTrue);
    });

    test('SC-006: after first answer, second step is the sole current question',
        () {
      final steps = kitchenProfileSteps(
        displayName: 'مطبخ أم علي',
        story: null,
        area: null,
        deliveryTerms: null,
        addressForm: null,
      );
      final next = nextUnansweredStep(steps);
      expect(next?.id, ConversationStepId.story);
      final beforeNext = steps.takeWhile((s) => s.id != next!.id).toList();
      expect(beforeNext.every((s) => s.answered), isTrue);
    });

    test('SC-006: all answered — no current question', () {
      final steps = kitchenProfileSteps(
        displayName: 'مطبخ أم علي',
        story: 'بنطبخ أكل بيتي زي ما أمهاتنا كانت بتعمل',
        area: 'المعادي',
        deliveryTerms: 'توصيل في نص ساعة',
        addressForm: AddressForm.feminine,
      );
      expect(nextUnansweredStep(steps), isNull);
    });

    // T090: the form of address is a question, not a setting with a default.
    // Leaving it unanswered must leave the conversation unfinished — otherwise
    // the Cook is never asked and every one of them is addressed as a man,
    // which is the whole failure ADR-0010 exists to end.
    test('the four kitchen details alone do not finish the conversation', () {
      final steps = kitchenProfileSteps(
        displayName: 'مطبخ أم علي',
        story: 'بنطبخ أكل بيتي زي ما أمهاتنا كانت بتعمل',
        area: 'المعادي',
        deliveryTerms: 'توصيل في نص ساعة',
        addressForm: null,
      );
      expect(nextUnansweredStep(steps)?.id, ConversationStepId.addressForm);
    });

    test('sequence is always the same five steps in order', () {
      final steps = kitchenProfileSteps(
        displayName: null,
        story: null,
        area: null,
        deliveryTerms: null,
        addressForm: null,
      );
      expect(steps.map((s) => s.id), [
        ConversationStepId.displayName,
        ConversationStepId.story,
        ConversationStepId.area,
        ConversationStepId.deliveryTerms,
        // Last: it is about the conversation rather than about the kitchen.
        ConversationStepId.addressForm,
      ]);
    });

    test('nextUnansweredStep returns third step when first two answered', () {
      final steps = kitchenProfileSteps(
        displayName: 'مطبخ أم علي',
        story: 'بنطبخ أكل بيتي',
        area: null,
        deliveryTerms: null,
        addressForm: null,
      );
      expect(nextUnansweredStep(steps)?.id, ConversationStepId.area);
    });
  });
}
