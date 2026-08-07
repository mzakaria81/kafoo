import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../meal/presentation/public_meal_view.dart';
import '../data/discovery_repository.dart';

/// A Meal a Customer opened from discovery, checked for still being on offer.
///
/// **FR-005 and the one freshness case a Customer actually meets.** Discovery
/// reflects what is on offer at the moment it is asked; opening a Meal is a
/// later moment, and a Cook takes food off the menu while somebody is reading
/// about it. The results were true when they were ranked and the Meal may not
/// be now.
///
/// **The Meal renders immediately and the check runs behind it.** Holding a
/// spinner over food a Customer just tapped, on an Egyptian mobile connection,
/// to answer a question that is almost always "yes" would cost every Customer
/// a wait to spare one of them a wasted message. The sentence arrives on top
/// when it arrives, and the Meal is never replaced by it — losing what they
/// were reading is a worse answer than telling them late.
class OpenedMeal extends ConsumerStatefulWidget {
  /// Creates the view.
  const OpenedMeal({required this.item, this.onOpenKitchen, super.key});

  /// The Meal and the kitchen behind it, as they were when ranked.
  final DiscoveredMeal item;

  /// Opens the Kitchen Profile behind it — FR-003.
  final VoidCallback? onOpenKitchen;

  @override
  ConsumerState<OpenedMeal> createState() => _OpenedMealState();
}

class _OpenedMealState extends ConsumerState<OpenedMeal> {
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final stillOnOffer = await ref
        .read(discoveryRepositoryProvider)
        .isStillOnOffer(widget.item.meal.id);
    if (!mounted || stillOnOffer) return;
    setState(() => _gone = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PublicMealView(
      meal: widget.item.meal,
      // The Cook's OWN stored form, never the reader's — ADR-0010.
      cookAddressForm: widget.item.kitchen.addressForm,
      onOpenKitchen: widget.onOpenKitchen,
      notice: _gone
          ? Semantics(
              liveRegion: true,
              child: Text(
                l10n.mealNoLongerOnOffer,
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(color: KafooColors.danger),
              ),
            )
          : null,
    );
  }
}
