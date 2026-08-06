/// Kitchen Profile entity. No Flutter, no Supabase.
///
/// Business rules enforced here:
/// - All text fields must be non-empty after trimming.
/// - A Kitchen Profile belongs to exactly one Cook and cannot be transferred.
/// - photo_path is optional — a Cook can publish without a photo.
library;

/// Which grammatical form Kafoo uses when it addresses a Cook.
///
/// Arabic conjugates the second person and has no neutral form, so the app
/// either asks or guesses. These name the **verb ending**, not the person:
/// ADR-0010 chose to store a form of address rather than a gender precisely
/// because the narrower field cannot later be repurposed for ranking or
/// advertising.
///
/// Null means the Cook has not been asked. Every Cook-facing string must
/// still render — the Cook is asked during Kitchen Profile creation from
/// T090, and until then, and for anyone who predates that question, the
/// unset form is what shows.
enum AddressForm { masculine, feminine }

final class KitchenProfile {
  const KitchenProfile({
    required this.id,
    required this.cookId,
    required this.displayName,
    required this.story,
    required this.area,
    required this.deliveryTerms,
    this.photoPath,
    this.addressForm,
  });

  final String id;
  final String cookId;
  final String displayName;
  final String story;
  final String area;
  final String deliveryTerms;
  final String? photoPath;
  final AddressForm? addressForm;
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
  AddressForm? addressForm;

  /// [photoPath] is absent here because a Cook can publish without a
  /// photograph. [addressForm] is present because from T090 the Cook is asked
  /// during Kitchen Profile creation, so a draft that has not been answered is
  /// an unfinished conversation rather than a complete profile with a blank.
  bool get isComplete =>
      displayName != null &&
      story != null &&
      area != null &&
      deliveryTerms != null &&
      addressForm != null;
}
