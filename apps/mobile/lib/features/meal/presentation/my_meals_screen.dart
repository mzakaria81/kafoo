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
/// **The assistant speaks here; it does not listen here yet.** The device's own
/// voice reads the summary and any row on request, and the mute control is
/// live. The talk button is still drawn and inert, because *recognition* on
/// this screen is separate work — speaking and listening are two gaps and only
/// one is closed. `docs/design/backend-gaps.md` is the list.
class MyMealsScreen extends ConsumerWidget {
  const MyMealsScreen({this.onResumeDraft, super.key});

  /// Called after [MealConversationController.resume] seeds the conversation
  /// from a stored draft. Navigation is the caller's concern.
  final void Function(CookMeal meal)? onResumeDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myMealsControllerProvider);

    return Scaffold(
      body: SafeArea(
        // Loading is checked FIRST and before emptiness. "No Meals yet" and
        // "not answered yet" look identical in the data and mean opposite
        // things to the Cook reading them.
        //
        // The spinner is not from the design: DESIGN.md lists the loading state
        // as undefined and tells an implementer to stop and ask rather than
        // invent one. This is the pre-existing treatment, kept unchanged.
        child: switch (state) {
          MyMealsState(loading: true) =>
            const Center(child: CircularProgressIndicator()),
          MyMealsState(error: final error?) when state.meals.isEmpty =>
            MyMealsFailed(error: error),
          MyMealsState(meals: []) => const MyMealsEmpty(),
          _ => _Full(state: state, onResumeDraft: onResumeDraft),
        },
      ),
    );
  }
}

class _Full extends ConsumerStatefulWidget {
  const _Full({required this.state, this.onResumeDraft});

  final MyMealsState state;
  final void Function(CookMeal meal)? onResumeDraft;

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

    if (voice.canSpeak) {
      // After this frame, not during it: speaking from inside build would fire
      // while the tree is still being laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _greet(summary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KafooSpacing.lg,
            KafooSpacing.md,
            KafooSpacing.lg,
            KafooSpacing.row,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.myMealsTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              // Every screen carries the mute control, top inline-end, and it
              // persists until reversed.
              KafooMuteButton(
                muted: voice.muted,
                label:
                    voice.muted ? l10n.voiceMuteRestore : l10n.voiceMuteSilence,
                onChanged: (muted) => ref
                    .read(assistantVoiceProvider.notifier)
                    .setMuted(muted: muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: KafooSpacing.lg,
          ),
          // The receipt of the spoken greeting, and the most important element
          // on the screen.
          child: KafooSpokenBanner(
            line: summary,
            hearAgainLabel: l10n.myMealsHearAgain,
            // Inert while muted, and on a handset with no Arabic speech data.
            // A control that silently does nothing is worse than one that
            // visibly cannot.
            onHearAgain: voice.canSpeak
                ? () => ref.read(assistantVoiceProvider.notifier).say(summary)
                : null,
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KafooSpacing.lg,
              KafooSpacing.row,
              KafooSpacing.lg,
              0,
            ),
            child: Text(
              myMealsErrorMessage(l10n, form, state.error!),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: KafooColors.error),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
            itemCount: state.meals.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: KafooSpacing.row),
            itemBuilder: (context, index) => MyMealRow(
              meal: state.meals[index],
              onResumeDraft: onResumeDraft,
            ),
          ),
        ),
        const _TalkDock(),
      ],
    );
  }
}

/// The bottom of every voice screen: the orb, and the way to do it by hand.
class _TalkDock extends StatelessWidget {
  const _TalkDock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          // Drawn as designed and inert: there is no speech engine. The label
          // carries the reason, the way every disabled control in Kafoo does.
          KafooTalkButton(
            state: TalkOrbState.idle,
            amplitude: 0,
            enabled: false,
            label: l10n.voiceNotReadyYet,
            onPressStart: () {},
            onPressEnd: () {},
          ),
          // Tap is a complete alternative, not a degraded one — and today it is
          // the only one that works.
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
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
  const MyMealRow({required this.meal, this.onResumeDraft, super.key});

  final CookMeal meal;
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

    return KafooMealRow(
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
      placeholderLabel: l10n.photoPlaceholder,
      hearLabel: l10n.myMealsHearRow,
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
/// The closed set, not the descriptive sentences in `myMealsStatus*` — those
/// are body text ("مش متاحة دلوقتي"), and a glance word is recognised by its
/// silhouette, so it has to be the same shape every time.
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
