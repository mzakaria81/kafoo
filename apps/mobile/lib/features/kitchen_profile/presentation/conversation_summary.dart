import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../analytics/emit_event.dart';
import '../../analytics/event_names.dart';
import '../../conversation/application/photo_picker.dart';
import '../data/kitchen_profile_repository.dart';

/// Everything the conversation gathered, in one place, before anything is kept.
///
/// Nothing on this screen has been written. The Kitchen Profile is created only
/// when the Cook presses confirm (FR-015), and every answer is correctable in a
/// single action (SC-008) — tapping Change turns that one row into a field
/// without replaying the conversation.
class KitchenConversationSummary extends StatefulWidget {
  const KitchenConversationSummary({
    required this.draft,
    required this.repository,
    required this.pickPhoto,
    super.key,
  });

  final KitchenProfileDraft draft;
  final KitchenProfileRepository repository;
  final PickPhoto pickPhoto;

  @override
  State<KitchenConversationSummary> createState() =>
      _KitchenConversationSummaryState();
}

class _KitchenConversationSummaryState
    extends State<KitchenConversationSummary> {
  ConversationStepId? _editing;
  final _editController = TextEditingController();

  Uint8List? _photoBytes;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  String _valueOf(ConversationStepId step) => switch (step) {
        ConversationStepId.displayName => widget.draft.displayName ?? '',
        ConversationStepId.story => widget.draft.story ?? '',
        ConversationStepId.area => widget.draft.area ?? '',
        ConversationStepId.deliveryTerms => widget.draft.deliveryTerms ?? '',
      };

  void _setValue(ConversationStepId step, String value) {
    switch (step) {
      case ConversationStepId.displayName:
        widget.draft.displayName = value;
      case ConversationStepId.story:
        widget.draft.story = value;
      case ConversationStepId.area:
        widget.draft.area = value;
      case ConversationStepId.deliveryTerms:
        widget.draft.deliveryTerms = value;
    }
  }

  String _labelOf(AppLocalizations l10n, ConversationStepId step) =>
      switch (step) {
        ConversationStepId.displayName => l10n.kitchenConvLabelDisplayName,
        ConversationStepId.story => l10n.kitchenConvLabelStory,
        ConversationStepId.area => l10n.kitchenConvLabelArea,
        ConversationStepId.deliveryTerms => l10n.kitchenConvLabelDeliveryTerms,
      };

  void _beginEdit(ConversationStepId step) {
    setState(() {
      _editing = step;
      _editController.text = _valueOf(step);
    });
  }

  void _commitEdit() {
    final step = _editing;
    if (step == null) return;
    final value = _editController.text.trim();
    setState(() {
      if (value.isNotEmpty) _setValue(step, value);
      _editing = null;
    });
  }

  Future<void> _choosePhoto() async {
    try {
      final bytes = await widget.pickPhoto();
      if (bytes != null && mounted) setState(() => _photoBytes = bytes);
    } on Exception catch (_) {
      if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).kitchenConvPhotoError);
      }
    }
  }

  Future<void> _confirm() async {
    final draft = widget.draft;
    if (!draft.isComplete) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // T038: a photo that will not upload must not cost the Cook the whole
    // conversation. Upload first, and carry on without one if it fails.
    String? photoPath;
    if (_photoBytes != null) {
      final upload = await widget.repository.uploadPhoto(_photoBytes!);
      if (upload case Success(value: final path)) {
        photoPath = path;
      } else if (mounted) {
        setState(
            () => _error = AppLocalizations.of(context).kitchenConvPhotoError);
      }
    }

    final result = await widget.repository.create(
      displayName: draft.displayName!,
      story: draft.story!,
      area: draft.area!,
      deliveryTerms: draft.deliveryTerms!,
      photoPath: photoPath,
    );

    if (!mounted) return;

    switch (result) {
      case Success(value: final profile):
        unawaited(emitEvent(EventNames.kitchenProfileCreated));
        unawaited(emitEvent(
          EventNames.conversationCompleted,
          attributes: {
            'kind': kitchenProfileConversationKind,
            'input': 'mixed',
          },
        ));
        Navigator.of(context).pop(profile);
      case Failure():
        setState(() {
          _saving = false;
          _error = AppLocalizations.of(context).kitchenConvSaveError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kitchenConvSummaryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          children: [
            for (final step in ConversationStepId.values)
              _SummaryRow(
                label: _labelOf(l10n, step),
                value: _valueOf(step),
                editing: _editing == step,
                controller: _editController,
                editLabel: l10n.convEdit,
                onEdit: () => _beginEdit(step),
                onCommit: _commitEdit,
              ),
            const Divider(height: KafooSpacing.xl),
            Text(l10n.kitchenConvLabelPhoto,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: KafooSpacing.sm),
            if (_photoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(KafooSpacing.sm),
                child:
                    Image.memory(_photoBytes!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: KafooSpacing.sm),
            OutlinedButton.icon(
              onPressed: _choosePhoto,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.kitchenConvPhotoAdd),
            ),
            if (_error != null) ...[
              const SizedBox(height: KafooSpacing.md),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: KafooSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _confirm,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.kitchenConvSummaryConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    required this.editLabel,
    required this.onEdit,
    required this.onCommit,
  });

  final String label;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final String editLabel;
  final VoidCallback onEdit;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: KafooSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: KafooSpacing.xs),
          if (editing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                IconButton(
                  onPressed: onCommit,
                  icon: const Icon(Icons.check),
                  tooltip: editLabel,
                  constraints: const BoxConstraints(
                    minWidth: KafooSpacing.minTapTarget,
                    minHeight: KafooSpacing.minTapTarget,
                  ),
                ),
              ],
            )
          else
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
