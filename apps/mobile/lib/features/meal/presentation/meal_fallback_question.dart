import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/presentation/conversation_question.dart';
import '../application/meal_conversation_controller.dart';
import 'meal_enum_labels.dart';
import 'meal_error_text.dart';

/// One fallback question — cuisine or category — when the AI Assistant could
/// not supply that value. Exactly one at a time (SC-002); choices are a
/// scrollable list of buttons, never a dropdown.
class MealFallbackQuestion extends ConsumerWidget {
  const MealFallbackQuestion({
    required this.step,
    this.error,
    this.analysisError,
    super.key,
  });

  final MealFallbackStepId step;
  final AppError? error;

  /// Why the AI Assistant did not supply this answer, when it failed rather
  /// than simply returning nothing.
  ///
  /// **THIS SCREEN IS WHERE A FAILED ANALYSIS LANDS HER**, so it is where the
  /// reason belongs. The question itself already says Kafoo is asking because it
  /// could not work the answer out; without this she cannot tell "the model had
  /// no opinion about my food" from "the assistant is down". Separate from
  /// [error], which is a failure to SAVE her answer — a different problem with a
  /// different fix.
  final AppError? analysisError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final prompt = switch (step) {
      MealFallbackStepId.cuisine => l10n.mealConvPromptCuisine,
      MealFallbackStepId.category => l10n.mealConvPromptCategory,
    };
    final hint = switch (step) {
      MealFallbackStepId.cuisine =>
        l10n.mealConvHintCuisine(context.addressForm),
      MealFallbackStepId.category =>
        l10n.mealConvHintCategory(context.addressForm),
    };

    final choices = switch (step) {
      MealFallbackStepId.cuisine => Cuisine.values
          .map(
            (c) => (
              label: cuisineLabel(l10n, c),
              value: c as Object,
            ),
          )
          .toList(growable: false),
      MealFallbackStepId.category => MealCategory.values
          .map(
            (c) => (
              label: mealCategoryLabel(l10n, c),
              value: c as Object,
            ),
          )
          .toList(growable: false),
    };

    // ONE SCROLLABLE LIST, HEADER AND CHOICES TOGETHER.
    //
    // **This was a fixed Column above an Expanded list, and adding the analysis
    // error to it reintroduced the exact defect this branch fixed one screen
    // over.** `Expanded` takes what is left after the header, so at 200% text
    // scale with both the notice and an error showing, what was left could
    // approach nothing — and the choices squeezed to nothing are the two answers
    // (cuisine and category) the database REQUIRES before a Meal may leave
    // draft. A Cook using large text who hit an AI failure would have been
    // locked out of publishing again, by the very feature added to tell her what
    // went wrong.
    //
    // A `SingleChildScrollView` around the header would have been the smaller
    // patch and would have left the same `Expanded` underneath it. Making the
    // whole screen one list removes the constraint instead of dividing it: there
    // is no height left to run out of.
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
            Text(
              l10n.mealConvFallbackNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KafooColors.textMuted,
              ),
            ),
            if (analysisError case final failure?) ...[
              const SizedBox(height: KafooSpacing.xs),
              Text(
                mealErrorText(context, failure, fromAnalysis: true),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: KafooSpacing.md),
            ConversationQuestion(prompt: prompt, hint: hint),
            const SizedBox(height: KafooSpacing.lg),
            if (error != null) ...[
              Text(
                mealErrorText(context, error!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: KafooSpacing.sm),
            ],
            for (final choice in choices) ...[
              Semantics(
                button: true,
                label: choice.label,
                child: OutlinedButton(
                  onPressed: () => _pick(ref, choice.value),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      KafooSpacing.minTapTarget,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: KafooSpacing.md,
                    ),
                  ),
                  child: Text(choice.label),
                ),
              ),
              const SizedBox(height: KafooSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pick(WidgetRef ref, Object value) async {
    final controller = ref.read(mealConversationControllerProvider.notifier);
    final ok = await controller.answerFallback(step, value);
    if (!ok) return;

    unawaited(emitEvent(
      EventNames.conversationStepCompleted,
      attributes: {
        'kind': mealConversationKind,
        'step': step.wireName,
        'input': 'typed',
      },
    ));
  }
}
