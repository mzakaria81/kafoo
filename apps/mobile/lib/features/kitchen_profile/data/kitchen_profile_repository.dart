import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the Kitchen Profile conversation needs from storage.
///
/// An interface rather than a concrete class so the conversation can be driven
/// in a test without a live Supabase — which is what makes "an abandoned
/// conversation writes nothing" provable rather than asserted.
abstract interface class KitchenProfileRepository {
  /// Returns the signed-in person's Kitchen Profile, or null if they own none.
  ///
  /// A person has at most one (FR-009), enforced by a unique constraint on
  /// `cook_id`. This read is how the UI sends an existing Cook to their own
  /// kitchen rather than starting a second conversation.
  Future<Result<KitchenProfile?, AppError>> findMine();

  /// Writes a confirmed Kitchen Profile. Called only after the Cook confirms
  /// the summary — nothing in the conversation reaches here before that.
  Future<Result<KitchenProfile, AppError>> create({
    required String displayName,
    required String story,
    required String area,
    required String deliveryTerms,
    String? photoPath,
  });

  /// Uploads a kitchen photo and returns its storage path.
  Future<Result<String, AppError>> uploadPhoto(Uint8List bytes);
}

/// The only layer that touches Supabase for Kitchen Profiles.
///
/// RLS is the real guard on every call here — these queries are scoped by
/// `auth.uid()` in the database, not by the filters written below.
class SupabaseKitchenProfileRepository implements KitchenProfileRepository {
  const SupabaseKitchenProfileRepository();

  static const String _table = 'kitchen_profiles';
  static const String _bucket = 'kitchen-photos';

  SupabaseClient get _client => Supabase.instance.client;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  Future<Result<KitchenProfile?, AppError>> findMine() async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'kitchenConvSaveError'));
      }
      final row =
          await _client.from(_table).select().eq('cook_id', uid).maybeSingle();
      if (row == null) return const Success(null);
      return Success(_fromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'kitchenConvSaveError', cause: e));
    }
  }

  @override
  Future<Result<KitchenProfile, AppError>> create({
    required String displayName,
    required String story,
    required String area,
    required String deliveryTerms,
    String? photoPath,
  }) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'kitchenConvSaveError'));
      }
      final row = await _client
          .from(_table)
          .insert({
            'cook_id': uid,
            'display_name': displayName,
            'story': story,
            'area': area,
            'delivery_terms': deliveryTerms,
            if (photoPath != null) 'photo_path': photoPath,
          })
          .select()
          .single();
      return Success(_fromRow(row));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'kitchenConvSaveError', cause: e));
    }
  }

  /// Uploads to `kitchen-photos/{uid}/kitchen.jpg`.
  ///
  /// The owner prefix is what the storage policy matches on, so the path is
  /// derived here and never supplied by a caller.
  @override
  Future<Result<String, AppError>> uploadPhoto(Uint8List bytes) async {
    try {
      final uid = _uid;
      if (uid == null) {
        return const Failure(AppError(messageKey: 'kitchenConvPhotoError'));
      }
      final path = '$uid/kitchen.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return Success(path);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'kitchenConvPhotoError', cause: e));
    }
  }

  KitchenProfile _fromRow(Map<String, dynamic> row) {
    return KitchenProfile(
      id: row['id'] as String,
      cookId: row['cook_id'] as String,
      displayName: row['display_name'] as String,
      story: row['story'] as String,
      area: row['area'] as String,
      deliveryTerms: row['delivery_terms'] as String,
      photoPath: row['photo_path'] as String?,
    );
  }
}
