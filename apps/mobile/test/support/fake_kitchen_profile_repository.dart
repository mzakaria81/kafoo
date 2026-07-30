import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/kitchen_profile/data/kitchen_profile_repository.dart';

/// Records every write it is asked to make, so a test can assert which writes
/// happened — and, more usefully, that none did.
class FakeKitchenProfileRepository implements KitchenProfileRepository {
  FakeKitchenProfileRepository({this.existing, this.failUpdates = false});

  /// What [findMine] returns. Null means this person owns no kitchen yet.
  KitchenProfile? existing;

  /// When true, [updateField] fails — the case where the previous version must
  /// remain what the Cook sees.
  bool failUpdates;

  int createCalls = 0;
  int uploadCalls = 0;
  int updateCalls = 0;

  @override
  Future<Result<KitchenProfile?, AppError>> findMine() async =>
      Success(existing);

  @override
  Future<Result<KitchenProfile, AppError>> create({
    required String displayName,
    required String story,
    required String area,
    required String deliveryTerms,
    String? photoPath,
  }) async {
    createCalls++;
    return Success(KitchenProfile(
      id: 'test-id',
      cookId: 'test-cook',
      displayName: displayName,
      story: story,
      area: area,
      deliveryTerms: deliveryTerms,
      photoPath: photoPath,
    ));
  }

  @override
  Future<Result<KitchenProfile, AppError>> updateField({
    required String id,
    required ConversationStepId field,
    required String value,
  }) async {
    updateCalls++;
    if (failUpdates) {
      return const Failure(AppError(messageKey: 'kitchenConvSaveError'));
    }
    final base = existing!;
    final updated = KitchenProfile(
      id: base.id,
      cookId: base.cookId,
      displayName:
          field == ConversationStepId.displayName ? value : base.displayName,
      story: field == ConversationStepId.story ? value : base.story,
      area: field == ConversationStepId.area ? value : base.area,
      deliveryTerms: field == ConversationStepId.deliveryTerms
          ? value
          : base.deliveryTerms,
      photoPath: base.photoPath,
    );
    existing = updated;
    return Success(updated);
  }

  @override
  Future<Result<String, AppError>> uploadPhoto(Uint8List bytes) async {
    uploadCalls++;
    return const Success('test-cook/kitchen.jpg');
  }
}
