import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/meal_estimate_fields.dart';
import 'meal_enum_labels.dart';

/// One AI-derived estimate on the Meal summary.
///
/// Shows the value, the basis sentence (FR-013), an estimate badge while
/// unapproved, and approve / edit actions. Editing counts as approving.
class EstimateRow extends StatelessWidget {
  const EstimateRow({
    required this.field,
    required this.label,
    required this.displayValue,
    required this.basis,
    required this.approved,
    required this.editing,
    required this.controller,
    required this.editLabel,
    required this.approveLabel,
    required this.approvedLabel,
    required this.badgeLabel,
    required this.onApprove,
    required this.onEdit,
    required this.onCommit,
    this.cuisineChoices,
    this.categoryChoices,
    this.selectedCuisine,
    this.selectedCategory,
    this.onCuisineChanged,
    this.onCategoryChanged,
    super.key,
  });

  final String field;
  final String label;
  final String displayValue;
  final String basis;
  final bool approved;
  final bool editing;
  final TextEditingController controller;
  final String editLabel;
  final String approveLabel;
  final String approvedLabel;
  final String badgeLabel;
  final VoidCallback? onApprove;
  final VoidCallback onEdit;
  final VoidCallback onCommit;
  final List<Cuisine>? cuisineChoices;
  final List<MealCategory>? categoryChoices;
  final Cuisine? selectedCuisine;
  final MealCategory? selectedCategory;
  final ValueChanged<Cuisine?>? onCuisineChanged;
  final ValueChanged<MealCategory?>? onCategoryChanged;

  bool get _isCuisine => field == MealEstimateFields.cuisine;
  bool get _isCategory => field == MealEstimateFields.category;
  bool get _isCalories => field == MealEstimateFields.calories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              if (!approved)
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: KafooSpacing.sm,
                    vertical: KafooSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(KafooSpacing.xs),
                  ),
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: KafooSpacing.xs),
          if (editing)
            _buildEditor(context, l10n, theme)
          else
            _buildValue(theme),
          const SizedBox(height: KafooSpacing.xs),
          Text(
            basis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          if (!editing) ...[
            const SizedBox(height: KafooSpacing.sm),
            Wrap(
              spacing: KafooSpacing.sm,
              runSpacing: KafooSpacing.xs,
              children: [
                if (approved)
                  Text(
                    approvedLabel,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.primary),
                  )
                else
                  TextButton(
                    onPressed: onApprove,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        KafooSpacing.minTapTarget,
                        KafooSpacing.minTapTarget,
                      ),
                    ),
                    child: Semantics(
                      button: true,
                      label: '$approveLabel: $label',
                      child: Text(approveLabel),
                    ),
                  ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      KafooSpacing.minTapTarget,
                      KafooSpacing.minTapTarget,
                    ),
                  ),
                  child: Semantics(
                    button: true,
                    label: '$editLabel: $label',
                    child: Text(editLabel),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValue(ThemeData theme) {
    return Text(displayValue, style: theme.textTheme.bodyLarge);
  }

  Widget _buildEditor(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Expanded(child: _editControl(l10n)),
        IconButton(
          onPressed: onCommit,
          tooltip: label,
          icon: const Icon(Icons.check),
          constraints: const BoxConstraints(
            minWidth: KafooSpacing.minTapTarget,
            minHeight: KafooSpacing.minTapTarget,
          ),
        ),
      ],
    );
  }

  Widget _editControl(AppLocalizations l10n) {
    if (_isCuisine && cuisineChoices != null) {
      return DropdownButton<Cuisine>(
        isExpanded: true,
        value: selectedCuisine,
        items: [
          for (final cuisine in cuisineChoices!)
            DropdownMenuItem(
              value: cuisine,
              child: Text(cuisineLabel(l10n, cuisine)),
            ),
        ],
        onChanged: onCuisineChanged,
      );
    }
    if (_isCategory && categoryChoices != null) {
      return DropdownButton<MealCategory>(
        isExpanded: true,
        value: selectedCategory,
        items: [
          for (final category in categoryChoices!)
            DropdownMenuItem(
              value: category,
              child: Text(mealCategoryLabel(l10n, category)),
            ),
        ],
        onChanged: onCategoryChanged,
      );
    }
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: _isCalories ? TextInputType.number : TextInputType.text,
      inputFormatters:
          _isCalories ? [FilteringTextInputFormatter.digitsOnly] : null,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onCommit(),
    );
  }
}
