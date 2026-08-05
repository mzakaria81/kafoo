import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../conversation/application/voice_input.dart';
import '../../kitchen_profile/data/kitchen_profile_repository.dart';
import '../../kitchen_profile/presentation/conversation.dart';
import 'meal_conversation.dart';

/// Entry point to offering a Meal.
///
/// FR-017: a Meal may only be offered by a Cook who has a Kitchen Profile.
/// Checks first, then renders the conversation — or asks the Cook to create
/// a kitchen if none exists.
class MealPublishEntry extends StatefulWidget {
  const MealPublishEntry({
    this.kitchenProfileRepository = const SupabaseKitchenProfileRepository(),
    this.voiceInput,
    super.key,
  });

  final KitchenProfileRepository kitchenProfileRepository;
  final VoiceInput? voiceInput;

  @override
  State<MealPublishEntry> createState() => _MealPublishEntryState();
}

class _MealPublishEntryState extends State<MealPublishEntry> {
  bool _checking = true;
  KitchenProfile? _profile;
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final result = await widget.kitchenProfileRepository.findMine();
    if (!mounted) return;
    switch (result) {
      case Success(value: final profile?):
        setState(() {
          _checking = false;
          _profile = profile;
          _checkFailed = false;
        });
      case Success(value: null):
        setState(() {
          _checking = false;
          _profile = null;
          _checkFailed = false;
        });
      case Failure():
        setState(() {
          _checking = false;
          _checkFailed = true;
        });
    }
  }

  /// The one branch here with no widget test, and deliberately so.
  ///
  /// Driving it end to end means confirming a Kitchen Profile, and the
  /// Kitchen Profile conversation offers a recovery email straight afterwards
  /// through a default `SupabaseAccountRepository` it does not take as an
  /// argument — so the test hits an uninitialised Supabase before it can
  /// assert anything. Making that injectable is a change to the identity
  /// feature, not to this gate. Until then the gate's other four states are
  /// covered and this one is read rather than run.
  Future<void> _createKitchen() async {
    final saved = await Navigator.of(context).push<KitchenProfile>(
      MaterialPageRoute(
        builder: (_) => KitchenConversationScreen(
          repository: widget.kitchenProfileRepository,
        ),
      ),
    );
    if (!mounted) return;
    if (saved != null) {
      // A kitchen now exists — go straight to the Meal conversation.
      setState(() => _profile = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_checkFailed) {
      return _CheckFailedScreen(onRetry: _check);
    }

    if (_profile == null) {
      return _NeedsKitchenScreen(onCreate: _createKitchen);
    }

    return MealConversationScreen(voiceInput: widget.voiceInput);
  }
}

class _NeedsKitchenScreen extends StatelessWidget {
  const _NeedsKitchenScreen({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.mealNeedsKitchenTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: KafooSpacing.md),
              Text(
                l10n.mealNeedsKitchenBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: KafooSpacing.xl),
              FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: Text(l10n.mealNeedsKitchenAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckFailedScreen extends StatelessWidget {
  const _CheckFailedScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.mealKitchenCheckError,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: KafooSpacing.xl),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(KafooSpacing.minTapTarget),
                ),
                child: Text(l10n.mealKitchenCheckRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
