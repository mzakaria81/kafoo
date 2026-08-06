import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/browse_controller.dart';

/// What a Customer sees having said nothing.
///
/// This is the whole of discovery at its smallest, and it works at twelve Meals
/// — which is where Kafoo actually is. Everything else in the epic falls back
/// to it: it is the zero-state before a Customer searches and the answer when a
/// search finds nothing.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({this.onOpen, this.trailing, super.key});

  /// Called when a Customer opens a Meal.
  ///
  /// Carries the kitchen as well as the Meal, because reaching who cooked it is
  /// part of reaching it (FR-003) and the route must not have to look that up
  /// again.
  final void Function(DiscoveredMeal item)? onOpen;

  /// An action in the bar. Signed out this is the way in for a Cook; signed in
  /// there is nothing to put here.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(browseControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseTitle),
        actions: [if (trailing != null) trailing!],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(browseControllerProvider.notifier).refresh(),
        child: _body(context, l10n, state),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    BrowseState state,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _message(l10n.discoveryLoadError, KafooColors.danger);
    }

    // FR-006: words, never a blank screen. And never this message for a
    // failure — see [BrowseState.saysNothingOnOffer].
    if (state.saysNothingOnOffer) {
      return _message(l10n.browseNothingOnOffer, KafooColors.onSurface);
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
          for (final item in state.onOffer)
            MealCard(
              title: item.meal.title,
              price: item.meal.price,
              kitchenLabel: l10n.browseKitchenLabel(item.kitchen.displayName),
              onTap: onOpen == null ? null : () => onOpen!(item),
            ),
        ],
      ),
    );
  }

  /// Scrollable so the pull-to-refresh gesture still works on a screen with
  /// nothing on it — which is exactly the screen a Customer most wants to
  /// retry.
  Widget _message(String text, Color color) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color),
                ),
              ),
            ),
          ),
        ),
      );
}
