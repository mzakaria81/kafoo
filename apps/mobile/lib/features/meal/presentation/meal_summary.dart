import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../application/meal_conversation_controller.dart';
import '../application/meal_estimate_fields.dart';
import 'meal_enum_labels.dart';
import 'meal_estimate_display.dart';
import 'meal_estimate_rows.dart';
import 'meal_summary_rows.dart';

/// The summary a Cook sees after answering all four Meal questions.
///
/// Cook answers first, then AI estimates that each need explicit approval or
/// edit before the Meal can go on offer. Approving writes that value to the
/// draft; publishing only runs once every estimate present has been dealt with.
class MealSummaryScreen extends ConsumerStatefulWidget {
  const MealSummaryScreen({this.onPublished, super.key});

  /// Called after a successful publish. Navigation is the caller's concern.
  final VoidCallback? onPublished;

  @override
  ConsumerState<MealSummaryScreen> createState() => _MealSummaryScreenState();
}

class _MealSummaryScreenState extends ConsumerState<MealSummaryScreen> {
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
        .answer(field, value);
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
    final Object? value = switch (field) {
      MealEstimateFields.cuisine => _editCuisine,
      MealEstimateFields.category => _editCategory,
      MealEstimateFields.calories => int.tryParse(_editController.text.trim()),
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

  Future<void> _publish() async {
    if (_publishing || _published) return;
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mealSummaryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
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
              photoPath: draft.photoPath,
              noPhotoLabel: l10n.mealSummaryNoPhoto,
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
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
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
                  cuisineChoices: field == MealEstimateFields.cuisine
                      ? Cuisine.values
                      : null,
                  categoryChoices: field == MealEstimateFields.category
                      ? MealCategory.values
                      : null,
                  selectedCuisine: _editCuisine,
                  selectedCategory: _editCategory,
                  onCuisineChanged: (value) =>
                      setState(() => _editCuisine = value),
                  onCategoryChanged: (value) =>
                      setState(() => _editCategory = value),
                ),
            if (state.error != null && !_publishFailed) ...[
              const SizedBox(height: KafooSpacing.md),
              Text(
                l10n.mealSaveError(context.addressForm),
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
                      ?.copyWith(color: theme.colorScheme.outline),
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
        ),
      ),
    );
  }
}
