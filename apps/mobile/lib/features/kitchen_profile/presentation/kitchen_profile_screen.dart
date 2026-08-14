import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/address_form.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversation/presentation/spoken_screen.dart';
import '../data/kitchen_profile_repository.dart';

/// The Cook's own Kitchen Profile: what it says, and how to change it.
///
/// Editing is one detail at a time, in keeping with the conversation that
/// created it. Reverting to a five-field form here would undo the thing US2
/// was built to prove.
class KitchenProfileScreen extends StatefulWidget {
  const KitchenProfileScreen({
    required this.profile,
    this.repository = const SupabaseKitchenProfileRepository(),
    super.key,
  });

  final KitchenProfile profile;
  final KitchenProfileRepository repository;

  @override
  State<KitchenProfileScreen> createState() => _KitchenProfileScreenState();
}

class _KitchenProfileScreenState extends State<KitchenProfileScreen> {
  late KitchenProfile _profile = widget.profile;
  String? _error;

  String _valueOf(KitchenFact field) => switch (field) {
        KitchenFact.displayName => _profile.displayName,
        KitchenFact.story => _profile.story,
        KitchenFact.area => _profile.area,
        KitchenFact.deliveryTerms => _profile.deliveryTerms,
        // Not editable here. It is chosen from two values on the Kitchen
        // Profile summary, so it has no free-text value to show in this
        // screen's text editor.
        KitchenFact.addressForm => '',
      };

  String _labelOf(AppLocalizations l10n, KitchenFact field) => switch (field) {
        KitchenFact.displayName => l10n.kitchenConvLabelDisplayName,
        KitchenFact.story => l10n.kitchenConvLabelStory,
        KitchenFact.area => l10n.kitchenConvLabelArea,
        KitchenFact.deliveryTerms => l10n.kitchenConvLabelDeliveryTerms,
        KitchenFact.addressForm => l10n.kitchenConvLabelAddressForm,
      };

  Future<void> _edit(KitchenFact field) async {
    final l10n = AppLocalizations.of(context);
    final replacement = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditOneDetail(
        label: _labelOf(l10n, field),
        // US5 scenario 2: the previous version stays on screen the whole time
        // a change is being made, and remains the truth until it is confirmed.
        currentValue: _valueOf(field),
        currentLabel: l10n.kitchenEditCurrentValue,
        newLabel: l10n.kitchenEditNewValue,
        saveLabel: l10n.kitchenEditSave(context.addressForm),
        cancelLabel: l10n.kitchenEditCancel,
        multiline: field == KitchenFact.story,
      ),
    );

    if (replacement == null || !mounted) return;

    final result = await widget.repository.updateField(
      id: _profile.id,
      field: field,
      value: replacement,
    );
    if (!mounted) return;

    switch (result) {
      case Success(value: final updated):
        setState(() {
          _profile = updated;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.kitchenEditSaved)),
        );
      case Failure():
        // The change did not land, so the previous version is still the truth
        // and is still what the screen shows.
        setState(() => _error = l10n.kitchenConvSaveError(context.addressForm));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SpokenScreen(
      title: l10n.kitchenViewTitle,
      spoken: l10n.publicKitchenSpoken(
        _profile.displayName,
        _profile.area,
        _profile.story,
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
        children: [
          for (final field in KitchenFact.freeText)
            _DetailRow(
              label: _labelOf(l10n, field),
              value: _valueOf(field),
              editLabel: l10n.convEdit(context.addressForm),
              onEdit: () => _edit(field),
            ),
          if (_error != null) ...[
            const SizedBox(height: KafooSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.editLabel,
    required this.onEdit,
  });

  final String label;
  final String value;
  final String editLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: KafooSpacing.xs),
          Row(
            children: [
              Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    KafooSpacing.minTapTarget,
                    KafooSpacing.minTapTarget,
                  ),
                ),
                child: Text(editLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Changes exactly one detail, with the current value visible throughout.
class _EditOneDetail extends StatefulWidget {
  const _EditOneDetail({
    required this.label,
    required this.currentValue,
    required this.currentLabel,
    required this.newLabel,
    required this.saveLabel,
    required this.cancelLabel,
    required this.multiline,
  });

  final String label;
  final String currentValue;
  final String currentLabel;
  final String newLabel;
  final String saveLabel;
  final String cancelLabel;
  final bool multiline;

  @override
  State<_EditOneDetail> createState() => _EditOneDetailState();
}

class _EditOneDetailState extends State<_EditOneDetail> {
  late final _controller = TextEditingController(text: widget.currentValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: KafooSpacing.lg,
        end: KafooSpacing.lg,
        top: KafooSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + KafooSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: KafooSpacing.md),
          Text(widget.currentLabel, style: theme.textTheme.labelSmall),
          Text(widget.currentValue, style: theme.textTheme.bodyMedium),
          const SizedBox(height: KafooSpacing.md),
          Text(widget.newLabel, style: theme.textTheme.labelSmall),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: widget.multiline ? 4 : 1,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: KafooSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(widget.cancelLabel),
                ),
              ),
              const SizedBox(width: KafooSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(KafooSpacing.minTapTarget),
                  ),
                  child: Text(widget.saveLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
