import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/money.dart';
import '../application/meal_edit_controller.dart';
import 'meal_summary_rows.dart';

class MealEditScreen extends ConsumerStatefulWidget {
  const MealEditScreen({required this.meal, super.key});

  final Meal meal;

  @override
  ConsumerState<MealEditScreen> createState() => _MealEditScreenState();
}

class _MealEditScreenState extends ConsumerState<MealEditScreen> {
  MealEditField? _editingField;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _beginEdit(MealEditField field, String value) {
    ref
        .read(mealEditControllerProvider(meal: widget.meal).notifier)
        .clearFeedback();
    setState(() {
      _editingField = field;
      _editController.text = value;
    });
  }

  Future<void> _commitEdit(MealEditField field) async {
    final value = _editController.text;
    await ref
        .read(mealEditControllerProvider(meal: widget.meal).notifier)
        .commit(field, value);
    if (!mounted) return;
    setState(() {
      _editingField = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editState = ref.watch(mealEditControllerProvider(meal: widget.meal));
    final currentMeal = editState.meal;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mealEditTitle(context.addressForm))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
            SummaryRow(
              label: l10n.mealSummaryLabelDish,
              value: currentMeal.title,
              editing: _editingField == MealEditField.title,
              controller: _editController,
              editLabel: l10n.convEdit(context.addressForm),
              onEdit: () => _beginEdit(MealEditField.title, currentMeal.title),
              onCommit: () => _commitEdit(MealEditField.title),
            ),
            SummaryRow(
              label: l10n.mealSummaryLabelDescription,
              value: currentMeal.description,
              multiline: true,
              editing: _editingField == MealEditField.description,
              controller: _editController,
              editLabel: l10n.convEdit(context.addressForm),
              onEdit: () => _beginEdit(
                  MealEditField.description, currentMeal.description),
              onCommit: () => _commitEdit(MealEditField.description),
            ),
            SummaryRow(
              label: l10n.mealSummaryLabelPrice,
              value: mealPriceLabel(l10n, currentMeal.price),
              editing: _editingField == MealEditField.price,
              controller: _editController,
              editLabel: l10n.convEdit(context.addressForm),
              onEdit: () => _beginEdit(MealEditField.price, currentMeal.price),
              onCommit: () => _commitEdit(MealEditField.price),
            ),
            if (editState.feedback != null) ...[
              const SizedBox(height: KafooSpacing.md),
              Text(
                editState.feedback == 'mealEditSaved'
                    ? l10n.mealEditSaved
                    : l10n.mealEditNoChange,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            if (editState.error != null) ...[
              const SizedBox(height: KafooSpacing.md),
              Text(
                l10n.mealSaveError(context.addressForm),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
