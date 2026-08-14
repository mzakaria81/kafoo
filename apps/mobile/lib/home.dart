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

/// What a Cook sees after signing in.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THIS WAS A MENU AND THE MENU WAS THE BUG.** Five stacked text buttons —
/// أكلاتي، أكلة جديدة، مطبخك، غيّر رقم الموبايل، امسح حسابي — and the founder
/// photographed it on 2026-08-14 asking why it looked nothing like the design
/// package. The answer was that it looked like nothing in the design package:
/// the package draws no home screen, because a voice-first product has no menu
/// to draw. A list of destinations is a form with one field.
///
/// **The design package's canonical screen IS the home.** The Cook's Meal list
/// opens speaking — «عندك خمس أكلات، اتنين منشورين. عايزة تعملي إيه؟» — with the
/// spoken banner underneath as the receipt of that sentence, her Meals as rows,
/// and the 88dp orb owning the bottom of the screen. Arriving on it, she is
/// already in the conversation rather than choosing which conversation to have.
///
/// So this file no longer draws anything. It owns **where the routes go**, which
/// is the one job a home has left, and hands them to `MyMealsScreen`.
///
/// **Everything the menu carried still exists and is one step away**, in the
/// account sheet behind the 48dp control in the top bar: the Kitchen Profile,
/// changing the phone number, and leaving. SC-011 asks that leaving take no more
/// steps than joining took — joining is a phone number and a code, so one tap to
/// a sheet that shows «امسح حسابي» without scrolling is well inside it. It is
/// not buried under a settings tree, which is the dark pattern the requirement
/// exists to prevent.
/// ─────────────────────────────────────────────────────────────────────────────
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
  /// Null means two opposite things until [_loaded] completes — "no kitchen" and
  /// "not read yet" — and they put different destinations behind the same entry:
  /// creating a kitchen is a conversation, looking at the one you have is a
  /// screen. Acting on null early offers a second kitchen to a Cook who already
  /// has one.
  KitchenProfile? _profile;

  /// **AWAITED RATHER THAN RENDERED, AND THAT REPLACED A DISABLED BUTTON.** The
  /// entry used to grey out while the read was in flight. That worked while the
  /// entry lived on a screen that rebuilt; it does not work inside a modal
  /// sheet, which is built once and never hears that the read landed — so a Cook
  /// who opened the sheet quickly got an entry that stayed dead forever.
  ///
  /// Waiting is also the better answer. A control that does nothing for a moment
  /// and then works is invisible to her; a control that is visibly dead is
  /// something she has to understand.
  late final Future<void> _loaded = _load();

  @override
  void initState() {
    super.initState();
    unawaited(_loaded);
  }

  Future<void> _load() async {
    final result = await widget.kitchenProfileRepository.findMine();
    if (!mounted) return;
    setState(() {
      // A failed read leaves the kitchen entry pointing at the conversation,
      // which loads the profile itself and surfaces the real failure there.
      // Blocking the whole screen on it would also hide the Meal list and
      // leaving, neither of which needs a Kitchen Profile to work.
      _profile = switch (result) {
        Success(value: final profile) => profile,
        Failure() => null,
      };
    });
  }

  Future<void> _openKitchen() async {
    await _loaded;
    if (!mounted) return;
    final profile = _profile;

    if (profile == null) {
      final saved = await Navigator.of(context).push<KitchenProfile>(
        MaterialPageRoute(
          builder: (_) => const KitchenConversationScreen(),
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

  void _resumeDraft(CookMeal draft) {
    // THE DRAFT IS HANDED TO THE SCREEN, not seeded before it.
    //
    // This used to discard the argument on the stated grounds that the list had
    // already seeded the controller. It had, into an autoDispose provider
    // nothing was watching, which threw the seeding away before this route was
    // built. A Cook returning to a half-finished Meal was asked the first
    // question again with all her answers still in the database. See
    // `MealConversationScreen.resumeFrom`.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealConversationScreen(resumeFrom: draft),
      ),
    );
  }

  void _offerAMeal() {
    // MealPublishEntry checks for a Kitchen Profile itself and asks the Cook to
    // create one if there is none (FR-017), so this does not repeat the check.
    //
    // It is handed the repository this screen already holds. Constructed
    // `const` it built its own `SupabaseAccountRepository` — which works on a
    // phone and makes the whole route untestable, because a test reaches an
    // uninitialised Supabase before it can assert anything.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealPublishEntry(
          kitchenProfileRepository: widget.kitchenProfileRepository,
        ),
      ),
    );
  }

  /// Pushes [screen] from THIS screen's Navigator, not the sheet's.
  ///
  /// **The sheet's own context is dead by the time it is needed.** The entry
  /// pops the sheet and then navigates, and `Navigator.of(sheetContext)` after
  /// that pop is looking up a defunct element — the push silently does nothing
  /// and a Cook taps «امسح حسابي» and stays where she is. Every destination is
  /// therefore built here, where the context outlives the sheet.
  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openAccount() async {
    await KafooSheet.show<void>(
      context: context,
      builder: (_) => _AccountSheet(
        onKitchen: _openKitchen,
        // FR-026: a lost or recycled number is recoverable rather than
        // terminal, because a Person is not their phone number.
        onChangePhone: () => _push(const ChangePhoneScreen()),
        onLeave: () => _push(const RemoveAccountScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MyMealsScreen(
      onResumeDraft: _resumeDraft,
      onAddByHand: _offerAMeal,
      onTalk: _offerAMeal,
      onAccount: _openAccount,
    );
  }
}

/// The account sheet, opened from the Meal list top bar.
///
/// Everything the old home menu carried that is not a Meal. Three entries and a
/// way out — the sheet's own retreat, which is plain text under them, because
/// retreat must be easy and must never compete with the actions above it.
class _AccountSheet extends StatelessWidget {
  const _AccountSheet({
    required this.onKitchen,
    required this.onChangePhone,
    required this.onLeave,
  });

  final VoidCallback onKitchen;
  final VoidCallback onChangePhone;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;

    /// Closes the sheet FIRST, then navigates.
    ///
    /// The other order leaves a modal sheet sitting above the screen it pushed,
    /// so the Cook comes back from the Kitchen Profile to a sheet she has no
    /// memory of opening.
    void go(VoidCallback destination) {
      Navigator.of(context).pop();
      destination();
    }

    return KafooSheet(
      title: l10n.accountSheetTitle,
      cancel: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        ),
        child: Text(l10n.accountSheetClose(form)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // 8dp minimum between adjacent targets, and these are all 48dp.
        spacing: KafooSpacing.targetGap,
        children: [
          _Entry(
            label: l10n.kitchenViewTitle,
            onPressed: () => go(onKitchen),
          ),
          _Entry(
            label: l10n.changePhoneEntry(form),
            onPressed: () => go(onChangePhone),
          ),
          // SC-011: leaving takes no more steps than joining did, and it is
          // visible here without scrolling.
          _Entry(
            label: l10n.removeAccountEntry(form),
            danger: true,
            onPressed: () => go(onLeave),
          ),
        ],
      ),
    );
  }
}

/// One entry in the account sheet.
///
/// One widget rather than three near-identical declarations: the 48dp floor is
/// a non-negotiable and three copies are three places to drop it.
class _Entry extends StatelessWidget {
  const _Entry(
      {required this.label, required this.onPressed, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
        foregroundColor: danger ? KafooColors.error : null,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
