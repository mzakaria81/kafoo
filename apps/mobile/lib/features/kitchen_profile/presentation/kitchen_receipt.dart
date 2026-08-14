import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../meal/presentation/meal_summary_rows.dart';
import '../application/kitchen_conversation_controller.dart';

/// The receipt: what the kitchen knows about itself so far, and the tap path
/// for every value she can also say.
///
/// **This was a screen at the end of a wizard and is now a panel** (ADR-0015).
/// It used to appear once the five questions ran out; it now sits under the
/// conversation from the first turn and fills in as she talks.
///
/// Every row here writes exactly what saying the same thing out loud writes —
/// ADR-0013's requirement that tap be a complete alternative rather than a
/// degraded one. Nothing here is an AI estimate, so nothing here needs an
/// approval step: a Kitchen Profile is made entirely of what the Cook said
/// about herself.
class KitchenReceipt extends ConsumerStatefulWidget {
  const KitchenReceipt({super.key});

  @override
  ConsumerState<KitchenReceipt> createState() => _KitchenReceiptState();
}

class _KitchenReceiptState extends ConsumerState<KitchenReceipt> {
  KitchenFact? _editing;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _begin(KitchenFact fact, String value) {
    setState(() {
      _editing = fact;
      _editController.text = value;
    });
  }

  void _commit(KitchenFact fact) {
    final value = _editController.text.trim();
    if (value.isEmpty) {
      setState(() => _editing = null);
      return;
    }
    ref
        .read(kitchenConversationControllerProvider.notifier)
        .correct(fact, value);
    setState(() => _editing = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.addressForm;
    final theme = Theme.of(context);
    final draft = ref.watch(kitchenConversationControllerProvider).draft;

    Widget row(KitchenFact fact, String label, String? value,
            {bool multiline = false}) =>
        SummaryRow(
          label: label,
          value: value ?? l10n.kitchenTalkNotYet,
          editing: _editing == fact,
          controller: _editController,
          editLabel: l10n.convEdit(form),
          multiline: multiline,
          onEdit: () => _begin(fact, value ?? ''),
          onCommit: () => _commit(fact),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The panel names itself. It used to be a screen with this in the app
        // bar, and dropping the heading when it became a panel would leave the
        // Cook a list of values with nothing saying whose they are.
        Text(l10n.kitchenConvSummaryTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: KafooSpacing.md),
        row(KitchenFact.displayName, l10n.kitchenConvLabelDisplayName,
            draft.displayName),
        row(KitchenFact.story, l10n.kitchenConvLabelStory, draft.story,
            multiline: true),
        row(KitchenFact.area, l10n.kitchenConvLabelArea, draft.area),
        row(KitchenFact.deliveryTerms, l10n.kitchenConvLabelDeliveryTerms,
            draft.deliveryTerms,
            multiline: true),
        // THE ONE ROW THAT IS CHOSEN RATHER THAN TYPED, because the answer is
        // one of exactly two values and there is nothing for a Cook to phrase.
        // She can also just say it — «أنا ست» reaches the same field through the
        // conversation — which is why this is a row on the receipt and not a
        // question blocking the screen.
        _AddressFormRow(
          label: l10n.kitchenConvLabelAddressForm,
          selected: draft.addressForm,
          feminineLabel: l10n.kitchenConvAddressFormFeminine,
          masculineLabel: l10n.kitchenConvAddressFormMasculine,
          onChanged: (value) => ref
              .read(kitchenConversationControllerProvider.notifier)
              .correct(KitchenFact.addressForm, value),
        ),
      ],
    );
  }
}

/// How Kafoo addresses this Cook, as two 48dp choices.
///
/// ADR-0010: Kafoo stores a form of address rather than a gender, deliberately,
/// because the narrower field cannot later be repurposed for ranking or
/// advertising. The labels are the two verb endings themselves — «كمّلي» and
/// «كمّل» — so she picks by hearing which one sounds like her rather than by
/// reading a grammatical term.
class _AddressFormRow extends StatelessWidget {
  const _AddressFormRow({
    required this.label,
    required this.selected,
    required this.feminineLabel,
    required this.masculineLabel,
    required this.onChanged,
  });

  final String label;
  final AddressForm? selected;
  final String feminineLabel;
  final String masculineLabel;
  final ValueChanged<AddressForm> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: KafooColors.textMuted),
          ),
          const SizedBox(height: KafooSpacing.xs),
          // Wraps rather than a Row: at 200% text two 48dp chips side by side
          // do not fit a 320px phone, and a Row resolves that by overflowing.
          Wrap(
            spacing: KafooSpacing.targetGap,
            runSpacing: KafooSpacing.targetGap,
            children: [
              for (final (form, text) in [
                (AddressForm.feminine, feminineLabel),
                (AddressForm.masculine, masculineLabel),
              ])
                KafooFilterChip(
                  label: text,
                  selected: selected == form,
                  onSelected: (_) => onChanged(form),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
