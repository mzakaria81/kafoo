import 'dart:async';
import 'dart:typed_data';

import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/kitchen_profile/data/kitchen_profile_repository.dart';

/// Records every write it is asked to make, so a test can assert which writes
/// happened — and, more usefully, that none did.
class FakeKitchenProfileRepository implements KitchenProfileRepository {
  FakeKitchenProfileRepository(
      {this.existing, this.failUpdates = false, this.failFindMine = false});

  /// What [findMine] returns. Null means this person owns no kitchen yet.
  KitchenProfile? existing;

  /// When true, [findMine] returns a Failure.
  bool failFindMine;

  /// Set to hold [findMine] open until the test completes it. Null — the
  /// default, and what every other test uses — returns immediately.
  Completer<void>? findMineGate;

  /// When true, [updateField] fails — the case where the previous version must
  /// remain what the Cook sees.
  bool failUpdates;

  int createCalls = 0;

  /// What the last create() was told to store. Recorded so a test can prove the
  /// Cook's answer reached the repository rather than only reaching the draft.
  AddressForm? createdAddressForm;
  int uploadCalls = 0;
  int updateCalls = 0;

  @override
  Future<Result<KitchenProfile?, AppError>> findMine() async {
    // Held open when a test supplies [findMineGate], so the caller's
    // not-yet-loaded state can actually be observed. Without it this returns in
    // the same microtask and every loading branch is unreachable — a test of
    // one would pass on its first run while asserting nothing.
    if (findMineGate != null) await findMineGate!.future;
    if (failFindMine) {
      return const Failure(AppError(messageKey: 'kitchenConvSaveError'));
    }
    return Success(existing);
  }

  @override
  Future<Result<KitchenProfile, AppError>> create({
    required String displayName,
    required String story,
    required String area,
    required String deliveryTerms,
    required AddressForm? addressForm,
    String? photoPath,
  }) async {
    createCalls++;
    createdAddressForm = addressForm;
    return Success(KitchenProfile(
      id: 'test-id',
      cookId: 'test-cook',
      displayName: displayName,
      story: story,
      area: area,
      deliveryTerms: deliveryTerms,
      photoPath: photoPath,
      addressForm: addressForm,
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
