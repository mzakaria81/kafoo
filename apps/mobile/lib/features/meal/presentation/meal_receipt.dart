import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/presentation/read_back_gate.dart';
import '../application/meal_conversation_controller.dart';
import '../application/meal_estimate_fields.dart';
import '../data/meal_repository.dart';
import 'meal_enum_labels.dart';
import 'meal_error_text.dart';
import 'meal_estimate_display.dart';
import 'meal_estimate_rows.dart';
import 'meal_summary_rows.dart';

/// The receipt: what the Meal knows about itself so far, and the way to publish
/// it.
///
/// **This was a screen and is now a panel** (ADR-0015, DESIGN.md §11). It used
/// to appear once the four questions ran out; it now sits under the
/// conversation from the first turn and fills in as the Cook talks. Nothing
/// about what it enforces changed — every AI estimate still needs an explicit
/// approval or correction before the Meal can go on offer, and publishing still
/// runs only once every estimate present has been dealt with.
///
/// It is also the tap path ADR-0013 requires: every row here writes exactly what
/// saying the same thing out loud writes.
class MealReceipt extends ConsumerStatefulWidget {
  const MealReceipt({this.onPublished, super.key});

  /// Called after a successful publish. Navigation is the caller's concern.
  final VoidCallback? onPublished;

  @override
  ConsumerState<MealReceipt> createState() => _MealReceiptState();
}

class _MealReceiptState extends ConsumerState<MealReceipt> {
  MealStepId? _editingCookField;
  String? _editingEstimateField;
  final _editController = TextEditingController();
  bool _saving = false;
  bool _publishing = false;
  bool _published = false;
  bool _publishFailed = false;
  Cuisine? _editCuisine;
  MealCategory? _editCategory;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _beginCookEdit(MealStepId field, String value) {
    setState(() {
      _editingCookField = field;
      _editingEstimateField = null;
      _editController.text = value;
    });
  }

  Future<void> _commitCookEdit(MealStepId field) async {
    final value = _editController.text.trim();
    if (value.isEmpty) {
      setState(() => _editingCookField = null);
      return;
    }
    setState(() => _saving = true);
    final ok = await ref
        .read(mealConversationControllerProvider.notifier)
        .correct(field, value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editingCookField = null;
    });
  }

  void _beginEstimateEdit(String field, String textValue) {
    final state = ref.read(mealConversationControllerProvider);
    setState(() {
      _editingEstimateField = field;
      _editingCookField = null;
      _editController.text = textValue;
      _editCuisine = state.draft.cuisine ?? state.analysis?.cuisine?.value;
      _editCategory = state.draft.category ?? state.analysis?.category?.value;
    });
  }

  Future<void> _commitEstimateEdit(String field) async {
    final controller = ref.read(mealConversationControllerProvider.notifier);
    final raw = _editController.text.trim();
    final Object? value = switch (field) {
      MealEstimateFields.cuisine => _editCuisine,
      MealEstimateFields.category => _editCategory,
      // `int.tryParse('٣٥٠')` is null. An Arabic keyboard produces those digits,
      // so a Cook correcting the calorie estimate the way she types numbers had
      // her correction thrown away — see `normalizeArabicDigits`.
      MealEstimateFields.calories => int.tryParse(normalizeArabicDigits(raw)),
      MealEstimateFields.ingredients => _parseList(_editController.text),
      MealEstimateFields.allergens => _parseList(_editController.text),
      _ => null,
    };
    if (value == null || (value is List<String> && value.isEmpty)) {
      setState(() => _editingEstimateField = null);
      return;
    }
    setState(() => _saving = true);
    final ok = await controller.correctEstimate(field, value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editingEstimateField = null;
    });
  }

  List<String> _parseList(String raw) => raw
      .split(RegExp(r'[,،]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  Future<void> _approve(String field) async {
    setState(() => _saving = true);
    await ref
        .read(mealConversationControllerProvider.notifier)
        .approveEstimate(field);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  /// Publishing, through the read-back gate the design has always specified.
  ///
  /// **IT WAS A PLAIN BUTTON UNTIL 2026-08-14, AND IT IS THE MOST IRREVERSIBLE
  /// THING A COOK DOES HERE.** DESIGN.md §10.6 and `business-rules.md` both say
  /// an irreversible action is read back aloud in full and waits for «أيوة».
  /// `KafooConfirmationGate` was built for exactly this screen, wired to
  /// retiring a Meal, and never wired to publishing one — so the smaller
  /// destructive case got the gate and the Meal going live to every Customer in
  /// the area got a `FilledButton`.
  Future<void> _publish() async {
    if (_publishing || _published) return;

    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final draft = ref.read(mealConversationControllerProvider).draft;
    final price = draft.price;
    final confirmed = await askReadBackGate(
      context: context,
      readback: l10n.publishGateReadback(
        draft.title ?? l10n.myMealsUntitledDraft,
        price == null ? '' : KafooNumerals.arabicIndic(price),
      ),
      question: l10n.publishGateQuestion,
      confirmLabel: l10n.publishGateYes(form),
      rejectLabel: l10n.gateAnswerNo,
      // The numeral is the largest thing on the gate. She is agreeing to a
      // price as much as to a Meal.
      amount: price == null ? null : KafooNumerals.arabicIndic(price),
      amountUnit: price == null ? null : l10n.publicMealPriceUnit,
      glanceWord: GlanceWord.published,
      glanceText: l10n.glancePublished,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _publishing = true;
      _publishFailed = false;
    });
    final ok =
        await ref.read(mealConversationControllerProvider.notifier).publish();
    if (!mounted) return;
    setState(() {
      _publishing = false;
      if (ok) {
        _published = true;
      } else {
        _publishFailed = true;
      }
    });
    if (ok) {
      unawaited(emitEvent(
        EventNames.conversationCompleted,
        attributes: {
          'kind': mealConversationKind,
          'input': 'mixed',
        },
      ));
      widget.onPublished?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mealConversationControllerProvider);
    final draft = state.draft;
    final notifier = ref.read(mealConversationControllerProvider.notifier);
    final analysis = state.analysis;
    final estimateFields = analysis == null
        ? const <String>[]
        : MealEstimateFields.presentIn(analysis);
    final canPublish = notifier.canPublish && !_publishing && !_published;
    final needsApproval =
        !notifier.allEstimatesApproved && estimateFields.isNotEmpty;
    final theme = Theme.of(context);
    // The bucket is public, so this is string construction rather than a
    // request — safe to derive in build().
    final storedPhoto = draft.photoPath;
    final photoUrl = storedPhoto == null
        ? null
        : ref.read(mealRepositoryProvider).photoUrl(storedPhoto);

    // A COLUMN AND NOT A LIST VIEW, because this is no longer the whole screen.
    // The conversation above it scrolls, and a scrolling panel inside a
    // scrolling screen is two scroll positions competing for one thumb.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The panel names itself. It used to be a screen with this in the app
        // bar, and dropping the heading when it became a panel would leave the
        // Cook a list of values with nothing saying whose they are.
        Text(l10n.mealSummaryTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: KafooSpacing.md),
        SummaryRow(
          label: l10n.mealSummaryLabelDish,
          value: draft.title ?? '',
          editing: _editingCookField == MealStepId.dish,
          controller: _editController,
          editLabel: l10n.convEdit(context.addressForm),
          onEdit: () => _beginCookEdit(MealStepId.dish, draft.title ?? ''),
          onCommit: () => _commitCookEdit(MealStepId.dish),
        ),
        SummaryRow(
          label: l10n.mealSummaryLabelDescription,
          value: draft.description ?? '',
          multiline: true,
          editing: _editingCookField == MealStepId.description,
          controller: _editController,
          editLabel: l10n.convEdit(context.addressForm),
          onEdit: () => _beginCookEdit(
            MealStepId.description,
            draft.description ?? '',
          ),
          onCommit: () => _commitCookEdit(MealStepId.description),
        ),
        PhotoRow(
          label: l10n.mealSummaryLabelPhoto,
          photoUrl: photoUrl,
          noPhotoLabel: l10n.mealSummaryNoPhoto,
          photoSemanticsLabel:
              l10n.mealSummaryPhotoAttached(context.addressForm),
        ),
        SummaryRow(
          label: l10n.mealSummaryLabelPrice,
          value: draft.price ?? '',
          editing: _editingCookField == MealStepId.price,
          controller: _editController,
          editLabel: l10n.convEdit(context.addressForm),
          onEdit: () => _beginCookEdit(MealStepId.price, draft.price ?? ''),
          onCommit: () => _commitCookEdit(MealStepId.price),
        ),
        // Cook-owned cuisine/category from the fallback path only — shown
        // when the draft has the value and the analysis offered no estimate.
        // No estimate badge: these are what the Cook stated, not guesses.
        if (draft.cuisine != null && analysis?.cuisine == null)
          SummaryRow(
            label: l10n.mealSummaryLabelCuisine,
            value: cuisineLabel(l10n, draft.cuisine!),
          ),
        if (draft.category != null && analysis?.category == null)
          SummaryRow(
            label: l10n.mealSummaryLabelCategory,
            value: mealCategoryLabel(l10n, draft.category!),
          ),
        const SizedBox(height: KafooSpacing.lg),
        Text(l10n.mealSummaryEstimatesTitle,
            style: theme.textTheme.titleMedium),
        const SizedBox(height: KafooSpacing.sm),
        Text(
          l10n.mealSummaryEstimatesNotice(context.addressForm),
          style:
              theme.textTheme.bodySmall?.copyWith(color: KafooColors.textMuted),
        ),
        const SizedBox(height: KafooSpacing.md),
        if (state.analysisInFlight)
          const Center(
            child: Padding(
              padding: EdgeInsetsDirectional.all(KafooSpacing.md),
              child: CircularProgressIndicator(),
            ),
          )
        else if (estimateFields.isEmpty)
          Text(l10n.mealSummaryNoEstimates(context.addressForm),
              style: theme.textTheme.bodyMedium)
        else
          for (final field in estimateFields)
            EstimateRow(
              field: field,
              label: estimateLabel(l10n, field),
              displayValue: estimateDisplay(l10n, state, field),
              basis: estimateBasis(analysis!, field),
              approved: state.approvals[field] == true,
              isCookOwn: state.corrections.contains(field),
              editing: _editingEstimateField == field,
              controller: _editController,
              editLabel: l10n.convEdit(context.addressForm),
              approveLabel: l10n.mealSummaryApprove,
              approvedLabel: l10n.mealSummaryApproved,
              badgeLabel: l10n.mealSummaryEstimateBadge,
              onApprove: _saving ? null : () => _approve(field),
              onEdit: () => _beginEstimateEdit(
                field,
                estimateEditText(l10n, state, field),
              ),
              onCommit: () => _commitEstimateEdit(field),
              cuisineChoices:
                  field == MealEstimateFields.cuisine ? Cuisine.values : null,
              categoryChoices: field == MealEstimateFields.category
                  ? MealCategory.values
                  : null,
              selectedCuisine: _editCuisine,
              selectedCategory: _editCategory,
              onCuisineChanged: (value) => setState(() => _editCuisine = value),
              onCategoryChanged: (value) =>
                  setState(() => _editCategory = value),
            ),
        // The AI Assistant's own failure, kept separate from a save failure
        // above it: one means her answers did not reach the database, the
        // other means the estimates did not arrive. Reading them as the same
        // sentence would send her looking for the wrong problem.
        if (state.analysisError case final failure?) ...[
          const SizedBox(height: KafooSpacing.md),
          Text(
            mealErrorText(context, failure, fromAnalysis: true),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (state.error != null && !_publishFailed) ...[
          const SizedBox(height: KafooSpacing.md),
          Text(
            mealErrorText(context, state.error!),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (_publishFailed) ...[
          const SizedBox(height: KafooSpacing.md),
          Text(
            l10n.mealPublishError(context.addressForm),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        if (_published) ...[
          const SizedBox(height: KafooSpacing.xl),
          Text(
            l10n.mealPublishedConfirmation,
            style: theme.textTheme.titleMedium,
          ),
        ] else ...[
          if (needsApproval) ...[
            const SizedBox(height: KafooSpacing.md),
            Text(
              l10n.mealSummaryNeedsApproval,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: KafooColors.textMuted),
            ),
          ],
          const SizedBox(height: KafooSpacing.xl),
          FilledButton(
            onPressed: canPublish && !_saving ? _publish : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
            ),
            child: _publishing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.mealSummaryConfirm(context.addressForm)),
          ),
        ],
      ],
    );
  }
}
