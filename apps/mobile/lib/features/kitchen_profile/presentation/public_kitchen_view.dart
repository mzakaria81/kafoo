import 'package:flutter/material.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_ui/ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../conversation/presentation/spoken_screen.dart';

/// The deliberately public face of a Kitchen Profile.
///
/// FR-019 fixes this to **exactly** five details: display name, story, area,
/// delivery terms, and photo. Nothing else about the Cook is reachable through
/// it, signed in or not — in particular there is no phone number here and no
/// route to one, because Kafoo never copies a phone number out of `auth.users`.
///
/// Adding a sixth detail to this widget is a change to FR-019, not a layout
/// tweak. If one is wanted, the requirement changes first.
///
/// **Nothing is discoverable in E1.** No Cook has a published Meal, so no
/// Customer can reach this view by browsing or searching. That is FR-030
/// working, not a gap: this widget is the rule made concrete, ready for the
/// first genuinely findable kitchen in E2.
class PublicKitchenView extends StatelessWidget {
  const PublicKitchenView({
    required this.profile,
    this.photoUrl,
    super.key,
  });

  final KitchenProfile profile;

  /// Resolved public URL for [KitchenProfile.photoPath], or null when the Cook
  /// has not added a photo. A kitchen without one renders correctly.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SpokenScreen(
      title: profile.displayName,
      // The kitchen, in the Cook's own words. This is how a Customer decides
      // whether to trust a stranger cooking at home, so it is the last thing
      // that should only be readable.
      spoken: l10n.publicKitchenSpoken(
        profile.displayName,
        profile.area,
        profile.story,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KafooSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Photo.
            if (photoUrl != null) KitchenPhoto(url: photoUrl!),
            const SizedBox(height: KafooSpacing.lg),

            // 2. Display name.
            Text(profile.displayName, style: theme.textTheme.headlineMedium),
            const SizedBox(height: KafooSpacing.lg),

            // 3. Story.
            _PublicDetail(
              label: l10n.kitchenConvLabelStory,
              value: profile.story,
            ),

            // 4. Area.
            _PublicDetail(
              label: l10n.kitchenConvLabelArea,
              value: profile.area,
            ),

            // 5. Delivery terms.
            _PublicDetail(
              label: l10n.kitchenConvLabelDeliveryTerms,
              value: profile.deliveryTerms,
            ),
          ],
        ),
      ),
    );
  }
}

/// The kitchen photo, named as its own widget so the "has a photo" branch can
/// be asserted in a test. [Image.network] cannot resolve under the test
/// binding, so a test that looked for the decoded image would be testing the
/// network rather than the layout.
class KitchenPhoto extends StatelessWidget {
  const KitchenPhoto({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KafooSpacing.sm),
      child: Image.network(
        url,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        // A photo that will not load must not leave a broken box on a Cook's
        // shopfront.
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _PublicDetail extends StatelessWidget {
  const _PublicDetail({required this.label, required this.value});

  final String label;
  final String value;

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
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
