import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/discovery/application/browse_controller.dart';

/// Why this file exists, and it is worth reading before adding to it.
///
/// `browse_screen_test.dart` covers the same rule from the outside and **cannot
/// see it break**. The screen checks `error != null` before it asks
/// `saysNothingOnOffer`, so removing the `error == null` guard from the state
/// leaves every widget test green: the screen's ordering masks the state's
/// guard, and the state's guard would mask a reordered screen.
///
/// That was measured, not guessed — the guard was deleted on purpose and all six
/// widget tests still passed. It is the same shape as the two Meal policies that
/// each hide the other in the database, and the answer is the same one: give
/// each layer its own assertion, so a single mutation has somewhere to go red.
void main() {
  const error = AppError(messageKey: 'discoveryLoadError');

  group('BrowseState.saysNothingOnOffer', () {
    test('is false while the first load is still running', () {
      // Otherwise a Customer is told the marketplace is empty every time they
      // open the app, for as long as the network takes.
      expect(const BrowseState().saysNothingOnOffer, isFalse);
    });

    test('is false when the load failed', () {
      // A failure is Kafoo's fault; an empty marketplace is not. Reporting one
      // as the other is a small lie, and it is the assertion the widget test
      // cannot make because the screen never asks.
      expect(
        const BrowseState(loading: false, error: error).saysNothingOnOffer,
        isFalse,
      );
    });

    test('is true only when a finished load genuinely found nothing', () {
      expect(
        const BrowseState(loading: false).saysNothingOnOffer,
        isTrue,
      );
    });

    test('is false when there is food, however the load went', () {
      const state = BrowseState(
        loading: false,
        onOffer: [
          DiscoveredMeal(
            meal: Meal(
              id: 'm1',
              cookId: 'c1',
              title: 'كشري',
              description: 'عدس ورز',
              price: '35',
              cuisine: Cuisine.egyptian,
              category: MealCategory.main,
              status: MealStatus.published,
              nutritionSource: NutritionSource.ai,
            ),
            kitchen: KitchenProfile(
              id: 'k1',
              cookId: 'c1',
              displayName: 'مطبخ فاطمة',
              story: 'بطبخ من زمان',
              area: 'المهندسين',
              deliveryTerms: 'توصيل',
            ),
          ),
        ],
      );
      expect(state.saysNothingOnOffer, isFalse);
    });
  });
}
