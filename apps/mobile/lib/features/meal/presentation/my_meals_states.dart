import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../application/my_meals_controller.dart';

/// The Cook-facing text for an [AppError] the Meal list can produce.
///
/// One function rather than a copy in each widget that renders an error: a
/// second switch is a second place to forget a key, and the fallback shows the
/// raw key to the Cook, which is the failure this must not have.
String myMealsErrorMessage(
  AppLocalizations l10n,
  String addressForm,
  AppError error,
) =>
    switch (error.messageKey) {
      'mealOfflineError' => l10n.mealOfflineError(addressForm),
      'mealLoadError' => l10n.mealLoadError(addressForm),
      'mealAvailabilityError' => l10n.mealAvailabilityError(addressForm),
      'mealDeleteError' => l10n.mealDeleteError(addressForm),
      _ => l10n.mealLoadError(addressForm),
    };

/// A Cook with no Meals yet.
///
/// **An invitation to speak, not a form.** The dark panel and the 120dp orb are
/// the design's way of making the first Meal a conversation — the screen has
/// one sentence, one big button, and one quiet way to do it by hand.
class MyMealsEmpty extends StatelessWidget {
  const MyMealsEmpty({this.onAddByHand, this.onTalk, super.key});

  /// Opens the Meal-creation flow. See `MyMealsScreen.onAddByHand` — on this
  /// screen it matters more, because a Cook with no Meals has nothing else to
  /// do here.
  final VoidCallback? onAddByHand;

  /// The orb's destination — the conversation where a Meal is talked into
  /// being. Null draws the orb inert, which is what a test constructing this
  /// widget bare gets.
  final VoidCallback? onTalk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;

    return ColoredBox(
      color: KafooColors.darkSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: KafooSpacing.lg,
          children: [
            const SizedBox(height: KafooSpacing.xl),
            Text(
              l10n.myMealsEmptyInvitation,
              textAlign: TextAlign.center,
              style: KafooType.screenTitle(arabic: true)
                  .copyWith(color: KafooColors.surface),
            ),
            Container(
              padding: const EdgeInsetsDirectional.all(KafooSpacing.md),
              decoration: BoxDecoration(
                color: KafooColors.voiceDeep,
                borderRadius: BorderRadius.circular(KafooRadius.panel),
              ),
              child: Text(
                l10n.myMealsEmptySpoken(form),
                textAlign: TextAlign.center,
                style: KafooType.bodyLarge(arabic: true)
                    .copyWith(color: KafooColors.quotedText),
              ),
            ),
            Center(
              // 120dp here rather than 88: on a screen whose only purpose is to
              // invite one, the invitation is the screen.
              child: KafooTalkButton(
                state: TalkOrbState.idle,
                amplitude: 0,
                enabled: onTalk != null,
                size: KafooSpacing.talkButtonInvitation,
                // The invitation, not an apology. This orb was drawn disabled
                // reading «الكلام لسه مش شغال» on the one screen whose entire
                // purpose is to invite a Cook to speak — so the first thing a
                // Cook with no Meals ever saw was the product telling her its
                // main idea did not work.
                label: onTalk == null
                    ? l10n.voiceNotReadyYet(form)
                    : l10n.myMealsTalkInvitation(form),
                onPressStart: onTalk ?? () {},
                onPressEnd: () {},
              ),
            ),
            OutlinedButton(
              onPressed: onAddByHand ?? () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: KafooColors.surface,
                side: const BorderSide(color: KafooColors.surface, width: 1.5),
                minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
              ),
              child: Text(l10n.myMealsEmptyByHand(form)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Meal list could not be loaded.
///
/// **Reassurance first, then the failure.** A Cook on a dropped connection
/// needs to know her work survived before she is told anything went wrong —
/// so «محفوظ» sits above the retry, not below it. Where a cached list exists it
/// is shown underneath at reduced opacity, because the last good answer beats
/// no answer.
class MyMealsFailed extends ConsumerWidget {
  const MyMealsFailed(
      {required this.error, this.cached, this.cachedAt, super.key});

  final AppError error;

  /// The last list that loaded, if any is held. Nothing caches yet — see
  /// `docs/design/backend-gaps.md`.
  final Widget? cached;
  final String? cachedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;

    // «مفيش نت» is a claim about her connection, and it was made whatever went
    // wrong. It is now made only when that is what happened.
    final offline = error.messageKey == 'mealOfflineError';

    return KafooEmptyState(
      failure: true,
      title: offline ? l10n.glanceOffline : l10n.myMealsFailedTitle,
      body: myMealsErrorMessage(l10n, form, error),
      // Both are true whatever failed — the read broke, not her Meals. Only the
      // offline one also names the cause.
      reassurance: offline
          ? l10n.myMealsOfflineReassurance
          : l10n.myMealsFailedReassurance,
      cachedLabel: cachedAt == null ? null : l10n.myMealsCachedAt(cachedAt!),
      cachedContent: cached,
      primaryAction: KafooButton(
        label: l10n.myMealsRetry(form),
        fullWidth: true,
        onPressed: () => ref.invalidate(myMealsControllerProvider),
      ),
    );
  }
}
