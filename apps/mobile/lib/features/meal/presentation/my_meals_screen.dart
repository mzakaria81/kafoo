import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/money.dart';
import '../../conversation/application/assistant_voice.dart';
import '../application/meal_conversation_controller.dart';
import '../application/my_meals_controller.dart';
import '../data/meal_repository.dart';
import 'meal_edit_screen.dart';
import 'my_meals_row_sheet.dart';
import 'my_meals_states.dart';

/// The Cook's Meal list, voice-first.
///
/// This is the canonical screen in the design handoff, and it is built to that
/// shape rather than to the tap-first version it replaced: the assistant speaks
/// on arrival, the banner underneath the title is the receipt of what it said,
/// the price is the largest thing in every row, and the talk button owns the
/// bottom of the screen.
///
/// **It is also the home** — what a Cook sees the moment she signs in, rather
/// than a menu she picks it off. See `home.dart` for why the menu is gone.
///
/// **The assistant speaks here, and the orb goes somewhere.** The device's own
/// voice reads the summary and any row on request, the mute control is live,
/// and pressing the orb opens the Meal conversation. What it does NOT do is
/// take a spoken command against the list — «شيلي المحشي من المنيو» changing a
/// status — which is the design package's intent for it and needs a model call
/// that does not exist. `docs/design/backend-gaps.md` §2, and row 18 of
/// `docs/mvp-deferred.md`.
class MyMealsScreen extends ConsumerWidget {
  const MyMealsScreen({
    this.onResumeDraft,
    this.onAddByHand,
    this.onTalk,
    this.onAccount,
    super.key,
  });

  /// Called after [MealConversationController.resume] seeds the conversation
  /// from a stored draft. Navigation is the caller's concern.
  final void Function(CookMeal meal)? onResumeDraft;

  /// Opens the Meal-creation flow.
  ///
  /// **Null closes this screen instead, and that is a fallback rather than the
  /// design.** «أضيف بإيدي» promised the creation flow and called `maybePop` —
  /// it shut the list and returned a Cook to Home with nothing started. Tap is
  /// meant to be a complete alternative to speaking, and a button that does not
  /// do what its label says is not one. Home passes the route; only a test
  /// constructing this screen bare gets the fallback.
  final VoidCallback? onAddByHand;

  /// Opens the conversation where a Meal is talked into being.
  ///
  /// **The orb's destination, and it is deliberately the same place
  /// [onAddByHand] goes.** Not because they are the same act — one is speaking
  /// and one is tapping — but because the conversation screen is where both
  /// happen. It opens with the orb ready and the text box hidden until she asks
  /// for it, so arriving by voice and arriving by tap are the same screen with
  /// different first moves.
  final VoidCallback? onTalk;

  /// Opens the account sheet from the top bar.
  ///
  /// Everything the old home menu carried that is not a Meal. Null on a screen
  /// pushed as a route rather than shown as the home, where the platform's own
  /// back is the way out.
  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myMealsControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ABOVE THE SWITCH, AND THAT IS THE POINT. The bar used to live
            // inside the loaded state only, so muting the assistant and
            // reaching the account were both impossible on the three states a
            // Cook is most likely to be stuck in — loading, empty, and failed.
            // The persistent mute control is a §10 requirement, and a control
            // that persists except when something goes wrong does not persist.
            _TopBar(onAccount: onAccount),
            Expanded(
              // Loading is checked FIRST and before emptiness. "No Meals yet"
              // and "not answered yet" look identical in the data and mean
              // opposite things to the Cook reading them.
              child: switch (state) {
                MyMealsState(loading: true) => KafooSkeletonList(
                    semanticsLabel: AppLocalizations.of(context).myMealsLoading,
                  ),
                MyMealsState(error: final error?) when state.meals.isEmpty =>
                  MyMealsFailed(error: error),
                MyMealsState(meals: []) => MyMealsEmpty(
                    onAddByHand: onAddByHand,
                    onTalk: onTalk,
                  ),
                _ => _Full(
                    state: state,
                    onResumeDraft: onResumeDraft,
                    onAddByHand: onAddByHand,
                    onTalk: onTalk,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The Meal list's top bar: the title, and the two controls that must never
/// disappear.
///
/// «أكلاتي» at 20/600 on the inline-start, then the 48dp account control and the
/// 48dp mute control on the inline-end — the design package's bar, with the
/// account entry added because the menu that used to hold it is gone.
class _TopBar extends ConsumerWidget {
  const _TopBar({this.onAccount});

  final VoidCallback? onAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final voice = ref.watch(assistantVoiceProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KafooSpacing.lg,
        KafooSpacing.md,
        KafooSpacing.lg,
        KafooSpacing.row,
      ),
      child: Row(
        spacing: KafooSpacing.targetGap,
        children: [
          Expanded(
            child: Text(
              l10n.myMealsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (onAccount != null)
            IconButton(
              onPressed: onAccount,
              tooltip: l10n.accountEntry,
              icon: const Icon(Icons.person_outline),
              iconSize: KafooSpacing.lg,
              constraints: const BoxConstraints(
                minWidth: KafooSpacing.minTapTarget,
                minHeight: KafooSpacing.minTapTarget,
              ),
              color: KafooColors.primaryDeep,
            ),
          KafooMuteButton(
            muted: voice.muted,
            label: voice.muted
                ? l10n.voiceMuteRestore(form)
                : l10n.voiceMuteSilence(form),
            onChanged: (muted) => ref
                .read(assistantVoiceProvider.notifier)
                .setMuted(muted: muted),
          ),
        ],
      ),
    );
  }
}

class _Full extends ConsumerStatefulWidget {
  const _Full({
    required this.state,
    this.onResumeDraft,
    this.onAddByHand,
    this.onTalk,
  });

  final MyMealsState state;
  final void Function(CookMeal meal)? onResumeDraft;
  final VoidCallback? onAddByHand;
  final VoidCallback? onTalk;

  @override
  ConsumerState<_Full> createState() => _FullState();
}

class _FullState extends ConsumerState<_Full> {
  /// Said once, on arrival — not on every rebuild.
  ///
  /// The greeting is an event. A screen that re-reads its own summary every
  /// time a Meal changes status turns the assistant into a nag; re-saying it on
  /// request is what «اسمعها تاني» is for.
  bool _greeted = false;

  void _greet(String line) {
    if (_greeted || !mounted) return;
    _greeted = true;
    ref.read(assistantVoiceProvider.notifier).say(line);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final onResumeDraft = widget.onResumeDraft;
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final voice = ref.watch(assistantVoiceProvider);
    final published =
        state.meals.where((m) => m.status == MealStatus.published).length;
    final summary =
        l10n.myMealsSpokenSummary(form, state.meals.length, published);
    // **THE SAME SENTENCE IN TWO SCRIPTS, ON PURPOSE.** An Arabic keyboard
    // writes «٢٠» and every other numeral on this screen is Arabic-Indic
    // already — the price two widgets down goes through this same call. The
    // greeting was the one number still in Latin digits, which is the script a
    // Cook does not use.
    //
    // **Only the written half is converted.** The provider reads «20» as
    // «عشرين» correctly — heard on a handset, 2026-08-12 — and whether it reads
    // «٢٠» as well is an open listening question in
    // `docs/ops/measuring-spoken-arabic.md`. Converting what is spoken would
    // trade a proven pronunciation for an unproven one to fix something nobody
    // hears. Raised by localization-reviewer on #462.
    // `separators: false` because this is a sentence, not a price. The default
    // rewrites a full stop into the Arabic decimal mark — right for «35.00»,
    // and it turned «على المنيو. عايزة تعملي إيه؟» into «على المنيو٫ عايزة» on
    // every visit to this screen.
    final writtenSummary =
        KafooNumerals.arabicIndic(summary, separators: false);

    if (voice.canSpeak) {
      // After this frame, not during it: speaking from inside build would fire
      // while the tree is still being laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _greet(summary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // THE BANNER AND THE ERROR SCROLL WITH THE LIST, they do not sit
        // above it. At 200% text scale the greeting runs to several lines, and
        // as fixed height above a fixed talk dock it squeezed the list to a
        // negative size — the Column overflowed and dropped its last child,
        // which is the talk button. Inside the scroll view everything simply
        // moves up.
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
            itemCount: state.meals.length + 1,
            separatorBuilder: (_, __) =>
                const SizedBox(height: KafooSpacing.row),
            itemBuilder: (context, index) {
              if (index > 0) {
                return MyMealRow(
                  meal: state.meals[index - 1],
                  addressForm: form,
                  onResumeDraft: onResumeDraft,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: KafooSpacing.row,
                children: [
                  // The receipt of the spoken greeting, and the most important
                  // element on the screen.
                  KafooSpokenBanner(
                    line: writtenSummary,
                    hearAgainLabel: l10n.myMealsHearAgain(form),
                    // Inert while muted, and on a handset with no Arabic speech
                    // data. A control that silently does nothing is worse than
                    // one that visibly cannot.
                    onHearAgain: voice.canSpeak
                        ? () => ref
                            .read(assistantVoiceProvider.notifier)
                            .say(summary)
                        : null,
                  ),
                  if (state.error != null)
                    Text(
                      myMealsErrorMessage(l10n, form, state.error!),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: KafooColors.error),
                    ),
                ],
              );
            },
          ),
        ),
        _TalkDock(onAddByHand: widget.onAddByHand, onTalk: widget.onTalk),
      ],
    );
  }
}

/// The bottom of every voice screen: the orb, and the way to do it by hand.
///
/// **Capped at half the screen, and it scrolls inside that cap.** At 200% text
/// on a 320px phone the orb plus its wrapped label runs to 388 logical pixels —
/// taller than the list it sits under — and a Column that cannot fit its
/// children drops the LAST one, which here is the button that does the task by
/// hand. Truncating the label instead is not an option: on a disabled control
/// the label is the only thing carrying the reason, and a disabled control with
/// no explanation is a dead end.
class _TalkDock extends StatelessWidget {
  const _TalkDock({this.onAddByHand, this.onTalk});

  final VoidCallback? onAddByHand;
  final VoidCallback? onTalk;

  /// Chosen so nothing changes at ordinary text sizes — the dock is about 180
  /// logical pixels on a normal phone, well under the cap — and the whole thing
  /// stays reachable at 200%.
  static const double _shareOfScreen = 0.5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _shareOfScreen,
      ),
      child: SingleChildScrollView(
        child: _dock(context, l10n),
      ),
    );
  }

  Widget _dock(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KafooSpacing.lg,
        KafooSpacing.row,
        KafooSpacing.lg,
        KafooSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: KafooSpacing.sm,
        children: [
          // LIVE, AND IT WAS DEAD UNTIL 2026-08-14. It was drawn disabled with
          // «الكلام لسه مش شغال» because nothing could listen — true when it
          // was written, and false since the hosted conversation landed
          // (ADR-0017). The screen's one unmissable control read as broken to
          // the founder, which is the worst thing an unmissable control can do.
          //
          // **What it opens is narrower than the design draws, and that is
          // recorded.** The package has this orb answering «عايزة تعملي إيه؟»
          // out loud — "شيلي المحشي من المنيو" changing a status. That needs an
          // intent step through `packages/ai/` which does not exist. Until it
          // does, the orb opens the Meal conversation: the one voice journey
          // MVP mode asks for at full fidelity. `docs/mvp-deferred.md`.
          KafooTalkButton(
            state: TalkOrbState.idle,
            amplitude: 0,
            enabled: onTalk != null,
            label: onTalk == null
                ? l10n.voiceNotReadyYet(context.addressForm)
                : l10n.myMealsTalkInvitation(context.addressForm),
            onPressStart: onTalk ?? () {},
            onPressEnd: () {},
          ),
          // Tap is a complete alternative, not a degraded one — and today it is
          // the only one that works.
          TextButton(
            onPressed: onAddByHand ?? () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
            ),
            child: Text(l10n.myMealsAddByHand(context.addressForm)),
          ),
        ],
      ),
    );
  }
}

/// One Meal in the Cook's list.
class MyMealRow extends ConsumerWidget {
  const MyMealRow({
    required this.meal,
    required this.addressForm,
    this.onResumeDraft,
    super.key,
  });

  final CookMeal meal;

  /// Passed down rather than read here.
  ///
  /// The Cook's form of address arrives asynchronously and can land after the
  /// list is already on screen. Read inside the row, every visible row would
  /// rebuild the moment it did — and a Cook using a screen reader, halfway
  /// through hearing one, would have it torn down and started again. Read once
  /// at the screen and handed down, only the screen rebuilds.
  final String addressForm;

  final void Function(CookMeal meal)? onResumeDraft;

  /// The dish name, or what to call a draft that has none.
  ///
  /// The schema permits a title-less row, so the list names one rather than
  /// rendering a blank that reads as something broken.
  String _title(AppLocalizations l10n) =>
      meal.title ?? l10n.myMealsUntitledDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final price = meal.price;
    final statusText = glanceWordText(l10n, meal.status);
    // HER OWN PHOTOGRAPH, WHICH THIS ROW NEVER SHOWED. The row was built with
    // no photo at all, so a Cook who took one and uploaded it opened her list
    // and saw «مفيش صورة للأكلة دي لسه» over every Meal. `meal_summary.dart`
    // resolved it correctly one file over; this row simply never asked.
    final storedPhoto = meal.photoPath;
    final photoUrl = storedPhoto == null
        ? null
        : ref.read(mealRepositoryProvider).photoUrl(storedPhoto);

    return KafooMealRow(
      photoUrl: photoUrl,
      name: _title(l10n),
      // The numeral alone; the currency is one step smaller beside it.
      price: price == null
          ? l10n.myMealsNoPriceYet
          : KafooNumerals.arabicIndic(price),
      priceUnit: price == null ? null : l10n.publicMealPriceUnit,
      status: glanceWordFor(meal.status),
      statusText: statusText,
      semanticsLabel: l10n.mealRowSemanticLabel(
        _title(l10n),
        statusText,
        price == null ? l10n.myMealsNoPriceYet : mealPriceLabel(l10n, price),
      ),
      placeholderLabel: l10n.mealNoPhotoYet,
      hearLabel: l10n.myMealsHearRow(addressForm),
      // Read aloud, quietly: the row carries a price, homes are shared, and
      // income is private.
      onHear: ref.watch(assistantVoiceProvider).canSpeak
          ? () => ref.read(assistantVoiceProvider.notifier).say(
                l10n.mealRowSemanticLabel(
                  _title(l10n),
                  statusText,
                  price == null
                      ? l10n.myMealsNoPriceYet
                      : mealPriceLabel(l10n, price),
                ),
                quiet: true,
              )
          : null,
      moreLabel: l10n.myMealsRowActions,
      // A retired Meal offers nothing. Drawn inert rather than opening an empty
      // sheet — and inert rather than absent, so the row keeps its shape.
      onMore: meal.status == MealStatus.archived
          ? null
          : () => showMyMealRowSheet(
                context: context,
                ref: ref,
                meal: meal,
                title: _title(l10n),
                onResumeDraft: onResumeDraft,
                onEdit: (editable) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MealEditScreen(meal: editable),
                  ),
                ),
              ),
    );
  }
}

/// The glance word for a Meal's status.
///
/// The closed set. A glance word is recognised by its silhouette, so it has to
/// be the same shape every time — which is also why «على المنيو» is now the
/// only name for a published Meal anywhere in the app rather than one of two.
GlanceWord glanceWordFor(MealStatus status) => switch (status) {
      MealStatus.published => GlanceWord.published,
      MealStatus.draft => GlanceWord.draft,
      MealStatus.unavailable => GlanceWord.unavailable,
      MealStatus.archived => GlanceWord.archived,
    };

String glanceWordText(AppLocalizations l10n, MealStatus status) =>
    switch (status) {
      MealStatus.published => l10n.glancePublished,
      MealStatus.draft => l10n.glanceDraft,
      MealStatus.unavailable => l10n.glanceUnavailable,
      MealStatus.archived => l10n.glanceArchived,
    };
