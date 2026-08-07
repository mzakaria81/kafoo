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

  /// Builds a [KitchenProfile] from a database row.
  ///
  /// Here rather than in a repository for the same reason [CookMeal.fromRow]
  /// is: the column mapping is a rule, and it is now read by both the Cook's
  /// own view of their kitchen and by what a Customer discovers. Takes a plain
  /// map, so this file still imports neither Flutter nor Supabase.
  factory KitchenProfile.fromRow(Map<String, dynamic> row) => KitchenProfile(
        id: row['id'] as String,
        cookId: row['cook_id'] as String,
        displayName: row['display_name'] as String,
        story: row['story'] as String,
        area: row['area'] as String,
        deliveryTerms: row['delivery_terms'] as String,
        photoPath: row['photo_path'] as String?,
        // An unrecognised value reads as null rather than throwing. A CHECK
        // constraint already limits what can be stored, so this only fires if a
        // later migration adds a form this build predates — and a Cook seeing
        // the unset wording is a smaller failure than a crash on their own
        // kitchen.
        addressForm: switch (row['address_form'] as String?) {
          'masculine' => AddressForm.masculine,
          'feminine' => AddressForm.feminine,
          _ => null,
        },
      );

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
