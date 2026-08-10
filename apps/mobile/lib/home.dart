import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import 'features/identity/presentation/change_phone_screen.dart';
import 'features/identity/presentation/remove_account_screen.dart';
import 'features/kitchen_profile/data/kitchen_profile_repository.dart';
import 'features/kitchen_profile/presentation/conversation.dart';
import 'features/kitchen_profile/presentation/kitchen_profile_screen.dart';
import 'features/meal/presentation/meal_conversation.dart';
import 'features/meal/presentation/meal_publish_entry.dart';
import 'features/meal/presentation/my_meals_screen.dart';
import 'l10n/address_form.dart';
import 'l10n/app_localizations.dart';

/// What a Cook sees after signing in, and every Cook-facing screen reached from
/// it.
///
/// **Until 2026-08-09 it reached none of them.** This was three buttons in
/// `main.dart` under a comment reading "Deliberately thin — browsing and Meals
/// arrive in later epics", which was true when E1 wrote it. E2 shipped Meals
/// and E3 shipped browse, and nobody came back: `my_meals_screen.dart`,
/// `meal_publish_entry.dart`, `meal_edit_screen.dart` and
/// `kitchen_profile_screen.dart` were referenced by no file in this app, so 920
/// lines of merged, tested code could not be opened by anybody holding the
/// phone.
///
/// Every gate passed throughout. A widget test builds a screen directly, which
/// proves it renders and cannot prove that anything reaches it — so
/// `scripts/verify.sh` now asserts reachability, because the identical failure
/// had already happened once (see the `ProviderScope` note in `main.dart`) and
/// the lesson was recorded as a comment rather than as a check.
class SignedInHome extends StatefulWidget {
  const SignedInHome({
    this.kitchenProfileRepository = const SupabaseKitchenProfileRepository(),
    super.key,
  });

  final KitchenProfileRepository kitchenProfileRepository;

  @override
  State<SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<SignedInHome> {
  /// The Cook's kitchen, or null when they have none yet.
  ///
  /// [_loading] is what tells those apart from "not read yet". They put
  /// different destinations behind the same button — creating a kitchen is a
  /// conversation, looking at the one you have is a screen — so acting on null
  /// before the read lands would offer a second kitchen to a Cook who already
  /// has one.
  KitchenProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final result = await widget.kitchenProfileRepository.findMine();
    if (!mounted) return;
    setState(() {
      _loading = false;
      // A failed read leaves the kitchen entry pointing at the conversation,
      // which loads the profile itself and surfaces the real failure there.
      // Blocking this whole screen on it would also hide My Meals and leaving,
      // neither of which needs a Kitchen Profile to work.
      _profile = switch (result) {
        Success(value: final profile) => profile,
        Failure() => null,
      };
    });
  }

  Future<void> _openKitchen() async {
    final profile = _profile;

    if (profile == null) {
      final saved = await Navigator.of(context).push<KitchenProfile>(
        MaterialPageRoute(
          builder: (_) => KitchenConversationScreen(
            repository: widget.kitchenProfileRepository,
          ),
        ),
      );
      if (!mounted || saved == null) return;
      setState(() => _profile = saved);
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => KitchenProfileScreen(
          profile: profile,
          repository: widget.kitchenProfileRepository,
        ),
      ),
    );
    // That screen saves each detail as it is edited, so what is held here is
    // stale the moment it closes. Re-read rather than infer what changed.
    if (mounted) unawaited(_load());
  }

  void _openMyMeals() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Resuming a draft has already seeded the conversation controller by
        // the time this fires; all that is left is to show it.
        builder: (_) => MyMealsScreen(
          onResumeDraft: (_) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const MealConversationScreen(),
            ),
          ),
        ),
      ),
    );
  }

  void _offerAMeal() {
    // MealPublishEntry checks for a Kitchen Profile itself and asks the Cook to
    // create one if there is none (FR-017), so this does not repeat the check.
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MealPublishEntry()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      // SCROLLS, AND MUST. Five entries at 200% text scale overflow a 320x480
      // phone by 192 logical pixels, and a Column that cannot scroll resolves
      // that by pushing its last child off the bottom — which is leaving, the
      // one control SC-011 requires to stay one step away. The three-entry
      // version this replaced had the headroom to hide it.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Entry(
                label: l10n.myMealsTitle,
                onPressed: _openMyMeals,
                filled: true,
              ),
              const SizedBox(height: KafooSpacing.sm),
              _Entry(label: l10n.newMealEntry, onPressed: _offerAMeal),
              const SizedBox(height: KafooSpacing.sm),
              _Entry(
                label: l10n.kitchenViewTitle,
                // Disabled for the moment the read takes, rather than sending a
                // Cook who has a kitchen into the flow that creates one.
                onPressed: _loading ? null : _openKitchen,
              ),
              const SizedBox(height: KafooSpacing.sm),
              // FR-026: a lost or recycled number is recoverable rather than
              // terminal, because a Person is not their phone number.
              _Entry(
                label: l10n.changePhoneEntry(context.addressForm),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangePhoneScreen(),
                  ),
                ),
              ),
              // A fixed gap rather than a Spacer: a Spacer needs bounded height
              // and there is none inside a scroll view. It still separates
              // leaving from the things a Cook came here to do.
              const SizedBox(height: KafooSpacing.xl),
              // SC-011: leaving is reachable in one step from the first screen
              // after signing in — no deeper than joining was. It is not buried
              // under a settings tree, because burying it is the dark pattern
              // this requirement exists to prevent.
              _Entry(
                label: l10n.removeAccountEntry(context.addressForm),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RemoveAccountScreen(),
                  ),
                ),
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One entry on the home screen.
///
/// One widget rather than five near-identical button declarations: the 48dp
/// floor is a non-negotiable and five copies are five places to drop it.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(KafooSpacing.minTapTarget);
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(minimumSize: size),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: size,
        foregroundColor: danger ? KafooColors.danger : null,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
