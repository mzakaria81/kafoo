/// Kitchen Profile entity. No Flutter, no Supabase.
///
/// Business rules enforced here:
/// - All text fields must be non-empty after trimming.
/// - A Kitchen Profile belongs to exactly one Cook and cannot be transferred.
/// - photo_path is optional — a Cook can publish without a photo.
library;

final class KitchenProfile {
  const KitchenProfile({
    required this.id,
    required this.cookId,
    required this.displayName,
    required this.story,
    required this.area,
    required this.deliveryTerms,
    this.photoPath,
  });

  final String id;
  final String cookId;
  final String displayName;
  final String story;
  final String area;
  final String deliveryTerms;
  final String? photoPath;
}

/// Mutable draft of a [KitchenProfile] held in memory during the conversation.
/// Nothing here is written to the database until [isComplete] is true and the
/// Cook explicitly confirms.
final class KitchenProfileDraft {
  KitchenProfileDraft();

  String? displayName;
  String? story;
  String? area;
  String? deliveryTerms;
  String? photoPath;

  bool get isComplete =>
      displayName != null &&
      story != null &&
      area != null &&
      deliveryTerms != null;
}
