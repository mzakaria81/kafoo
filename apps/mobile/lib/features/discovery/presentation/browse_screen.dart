import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../application/browse_controller.dart';

/// What a Customer sees having said nothing.
///
/// This is the whole of discovery at its smallest, and it works at twelve Meals
/// — which is where Kafoo actually is. Everything else in the epic falls back
/// to it: it is the zero-state before a Customer searches and the answer when a
/// search finds nothing.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({this.onOpen, this.entry, super.key});

  /// Called when a Customer opens a Meal.
  ///
  /// Carries the kitchen as well as the Meal, because reaching who cooked it is
  /// part of reaching it (FR-003) and the route must not have to look that up
  /// again.
  final void Function(DiscoveredMeal item)? onOpen;

  /// A way in for someone with no account.
  ///
  /// Rendered in the body rather than the bar, and that is measured rather than
  /// preferred: as an `AppBar` action it took its full intrinsic width and
  /// squeezed the title to **zero** at 200% text scale — silently at 360dp, and
  /// with an overflow at 320dp. An `AppBar` clips without throwing, so a test
  /// asserting on exceptions could never see it.
  final Widget? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.browseTitle)),
      body: BrowseBody(onOpen: onOpen, entry: entry),
    );
  }
}

/// What is on offer, without a Scaffold of its own.
///
/// **Split out because the zero state of search IS browse, and so is the
/// fallback when nothing matched — FR-012.** The search screen shows this
/// underneath its input rather than reimplementing a list of Meals, so there is
/// one place where a card is built, one live region, and one pull-to-refresh.
/// Two copies would be two chances for a draft to appear in one of them.
class BrowseBody extends ConsumerWidget {
  /// Creates the body.
  const BrowseBody({this.onOpen, this.entry, super.key});

  /// Called when a Customer opens a Meal.
  final void Function(DiscoveredMeal item)? onOpen;

  /// A way in for someone with no account. See [BrowseScreen.entry].
  final Widget? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(browseControllerProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(browseControllerProvider.notifier).refresh(),
      // A live region, so a screen reader announces the move out of loading
      // and announces what a refresh returned. Without it a blind Customer
      // hears nothing and cannot tell a slow load from a broken app — the
      // failure `browseNothingOnOffer` prevents visually and nothing
      // prevented aloud.
      child: Semantics(
        liveRegion: true,
        child: _body(context, ref, l10n, state),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    BrowseState state,
  ) {
    if (state.loading) {
      // A bare spinner carries an empty semantic label and says nothing at all.
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.browseLoading),
      );
    }

    if (state.error != null) {
      return _message(
        text: l10n.discoveryLoadError,
        color: KafooColors.error,
        onRetry: () => ref.read(browseControllerProvider.notifier).refresh(),
        retryLabel: l10n.browseRetry,
      );
    }

    // FR-006: words, never a blank screen. And never this message for a
    // failure — see [BrowseState.saysNothingOnOffer].
    if (state.saysNothingOnOffer) {
      return _message(
        text: l10n.browseNothingOnOffer,
        color: KafooColors.onSurface,
        onRetry: () => ref.read(browseControllerProvider.notifier).refresh(),
        retryLabel: l10n.browseRetry,
      );
    }

    // A Column in a SingleChildScrollView rather than a lazy ListView. The
    // public kitchen view lost its photo to a lazy list that silently did not
    // build its first child — no error, no ErrorWidget, just an absent subtree
    // — and for a handful of cards the laziness buys nothing while costing a
    // test nobody can write.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entry != null) ...[
            entry!,
            const SizedBox(height: KafooSpacing.md),
          ],
          for (final item in state.onOffer) _card(l10n, item),
        ],
      ),
    );
  }

  Widget _card(AppLocalizations l10n, DiscoveredMeal item) =>
      discoveredMealCard(
        l10n: l10n,
        item: item,
        source: MealOpenSource.browse,
        onOpen: onOpen,
      );

  /// Scrollable so pull-to-refresh still works on a screen with nothing on it —
  /// which is exactly the screen a Customer most wants to retry.
  ///
  /// The button is not a convenience. `RefreshIndicator` exposes **no**
  /// semantics action, so as the only way back it stranded a screen-reader
  /// Customer, and anyone who cannot make a precise vertical drag, on a message
  /// with nothing to press.
  Widget _message({
    required String text,
    required Color color,
    required VoidCallback onRetry,
    required String retryLabel,
  }) =>
      discoveryMessage(
        text: text,
        color: color,
        onRetry: onRetry,
        retryLabel: retryLabel,
      );
}

/// Where a Customer was when they opened a Meal. The `source` of `MealOpened`.
///
/// Two values and no third without a decision: this is an analytics vocabulary,
/// and a vocabulary that grows quietly is a funnel that stops adding up.
abstract final class MealOpenSource {
  /// From what is on offer.
  static const String browse = 'browse';

  /// From the results of a search.
  static const String search = 'search';
}

/// One Meal card, built the same way wherever it is shown.
///
/// Browse and search render the same thing: a result is a Meal on offer with the
/// kitchen behind it, and a second card would be a second place for the price to
/// lose its currency — which it did once already.
///
/// **It is also the one place a Meal is opened from**, which is why `MealOpened`
/// is emitted here rather than at the call sites.
Widget discoveredMealCard({
  required AppLocalizations l10n,
  required DiscoveredMeal item,
  required String source,
  void Function(DiscoveredMeal item)? onOpen,
}) {
  final kitchenLabel = l10n.browseKitchenLabel(item.kitchen.displayName);
  // The price carries its currency. `Meal.price` is the exact string the Cook
  // typed — `numeric(10,2)`, never a double — and this card was rendering it
  // bare as "35" while the Meal one tap deeper said "٣٥ جنيه". Money a
  // Customer reads is never a naked number.
  final price = l10n.publicMealPriceValue(item.meal.price);

  return MealCard(
    title: item.meal.title,
    price: price,
    kitchenLabel: kitchenLabel,
    // Composed here from an ARB entry so the separator follows the locale.
    // Built inside the card it meant a hardcoded Arabic comma reaching every
    // English voice.
    semanticsLabel: l10n.mealCardSemanticLabel(
      item.meal.title,
      kitchenLabel,
      price,
    ),
    // MealOpened IS EMITTED HERE AND NOT AT THE CALL SITES, for the same reason
    // the consent gate sits on the funnel rather than on the entrances: call
    // sites keep being added, and the one that forgets is invisible — a number
    // that is quietly low rather than a screen that is quietly broken.
    //
    // `source` is required above so a new caller has to say where it is, rather
    // than defaulting to whichever value happened to be written first.
    onTap: onOpen == null
        ? null
        : () {
            unawaited(
              emitEvent(
                EventNames.mealOpened,
                attributes: {
                  'source': source,
                  // The domain enums, never the Cook's own words. The title and
                  // the description are what a Cook typed; these are chosen
                  // from a list and are keys rather than copy.
                  'cuisine': item.meal.cuisine.wireName,
                  'category': item.meal.category.wireName,
                },
              ),
            );
            onOpen(item);
          },
  );
}

/// A sentence with something to press.
///
/// Scrollable so pull-to-refresh still works on a screen with nothing on it —
/// which is exactly the screen a Customer most wants to retry.
///
/// The button is not a convenience. `RefreshIndicator` exposes **no** semantics
/// action, so as the only way back it stranded a screen-reader Customer, and
/// anyone who cannot make a precise vertical drag, on a message with nothing to
/// press.
Widget discoveryMessage({
  required String text,
  required Color color,
  required VoidCallback onRetry,
  required String retryLabel,
}) =>
    LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    // Copied from the ambient style rather than built fresh,
                    // so it keeps inheriting text scaling.
                    style: DefaultTextStyle.of(context)
                        .style
                        .copyWith(color: color),
                  ),
                  const SizedBox(height: KafooSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(KafooSpacing.minTapTarget),
                    ),
                    onPressed: onRetry,
                    child: Text(retryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
