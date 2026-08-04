import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/meal_conversation_controller.dart';
import 'meal_summary_rows.dart';

/// The summary a Cook sees after answering all four Meal questions.
///
/// Nothing is written on arriving here — the draft already exists in the
/// database (T034) and stays `draft`. Putting it on offer is T038, and until
/// that lands [onConfirm] is where the Meal would be published.
///
/// Every detail is correctable in a single action (SC-004): Change turns that
/// one row into a field, without replaying the conversation.
///
/// **The draft lives in the controller, not here.** An earlier version of this
/// screen took the values as constructor arguments and wrote corrections
/// straight to the repository, which left the controller holding the values the
/// Cook had just replaced. Nothing was visibly wrong — until T038 publishes from
/// the controller and quietly ships the uncorrected Meal. One owner, read
/// through the provider.
///
/// AI-derived values — cuisine, category, ingredients, calories, allergens —
/// are deliberately absent. They belong to User Story 2 (T045 onward), which
/// adds the strings that label them as estimates and say what each was based on.
/// There is no string in this repository yet that labels a value as an estimate,
/// so rendering one here would necessarily present it as fact.
class MealSummaryScreen extends ConsumerStatefulWidget {
  const MealSummaryScreen({required this.onConfirm, super.key});

  final VoidCallback onConfirm;

  @override
  ConsumerState<MealSummaryScreen> createState() => _MealSummaryScreenState();
}

class _MealSummaryScreenState extends ConsumerState<MealSummaryScreen> {
  /// Which row is open for editing, and the text in it. This is the only state
  /// the screen owns — everything else is read from the controller.
  MealStepId? _editing;
  final _editController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _beginEdit(MealStepId field, String value) {
    setState(() {
      _editing = field;
      _editController.text = value;
    });
  }

  Future<void> _commitEdit(MealStepId field) async {
    final value = _editController.text.trim();
    if (value.isEmpty) {
      // FR-005 makes every value correctable, not erasable. An empty correction
      // is a slip, so it closes the row and keeps what was there.
      setState(() => _editing = null);
      return;
    }

    setState(() => _saving = true);

    // Through the controller, which persists it and owns the draft. Correcting
    // the description also restarts the analysis, because an estimate made from
    // the words the Cook just replaced is an estimate of a different Meal.
    final ok = await ref
        .read(mealConversationControllerProvider.notifier)
        .answer(field, value);

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(mealConversationControllerProvider);
    final draft = state.draft;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mealSummaryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
            SummaryRow(
              label: l10n.mealSummaryLabelDish,
              value: draft.title ?? '',
              editing: _editing == MealStepId.dish,
              controller: _editController,
              editLabel: l10n.convEdit,
              onEdit: () => _beginEdit(MealStepId.dish, draft.title ?? ''),
              onCommit: () => _commitEdit(MealStepId.dish),
            ),
            SummaryRow(
              label: l10n.mealSummaryLabelDescription,
              value: draft.description ?? '',
              multiline: true,
              editing: _editing == MealStepId.description,
              controller: _editController,
              editLabel: l10n.convEdit,
              onEdit: () =>
                  _beginEdit(MealStepId.description, draft.description ?? ''),
              onCommit: () => _commitEdit(MealStepId.description),
            ),
            PhotoRow(
              label: l10n.mealSummaryLabelPhoto,
              photoPath: draft.photoPath,
              noPhotoLabel: l10n.mealSummaryNoPhoto,
            ),
            SummaryRow(
              label: l10n.mealSummaryLabelPrice,
              value: draft.price ?? '',
              editing: _editing == MealStepId.price,
              controller: _editController,
              editLabel: l10n.convEdit,
              onEdit: () => _beginEdit(MealStepId.price, draft.price ?? ''),
              onCommit: () => _commitEdit(MealStepId.price),
            ),
            if (state.error != null) ...[
              const SizedBox(height: KafooSpacing.md),
              Text(
                l10n.mealSaveError,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: KafooSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : widget.onConfirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
              ),
              child: Text(l10n.mealSummaryConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
