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

/// One fallback question — cuisine or category — when the AI Assistant could
/// not supply that value. Exactly one at a time (SC-002); choices are a
/// scrollable list of buttons, never a dropdown.
class MealFallbackQuestion extends ConsumerWidget {
  const MealFallbackQuestion({
    required this.step,
    this.error,
    super.key,
  });

  final MealFallbackStepId step;
  final AppError? error;

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

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.mealConvFallbackNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: KafooSpacing.md),
              ConversationQuestion(prompt: prompt, hint: hint),
              const SizedBox(height: KafooSpacing.lg),
              if (error != null) ...[
                Text(
                  l10n.mealSaveError(context.addressForm),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: KafooSpacing.sm),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: choices.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: KafooSpacing.sm),
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    return Semantics(
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
                    );
                  },
                ),
              ),
            ],
          ),
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
