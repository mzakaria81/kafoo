import 'package:kafoo_domain/domain.dart';
import 'package:kafoo_mobile/features/identity/data/account_repository.dart';

/// Records what it was asked to do, so a test can assert what a screen did —
/// and, more usefully, what it did not.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    this.fails = false,
    this.declines = 0,
    this.email,
    this.addressIsUnknown = false,
  });

  /// Every operation fails. Used to prove a failure leaves things unchanged.
  bool fails;

  /// How many times the recovery-email invitation has already been declined.
  int declines;

  /// The address already attached, if any.
  String? email;

  /// The address is not attached to anybody — the case that must never become
  /// a second identity.
  bool addressIsUnknown;

  int removeCalls = 0;
  int attachCalls = 0;
  int declineCalls = 0;
  int emailCodeCalls = 0;
  int phoneChangeCalls = 0;

  @override
  Future<Result<void, AppError>> removeAccount() async {
    removeCalls++;
    if (fails) {
      return const Failure(AppError(messageKey: 'removeAccountError'));
    }
    return const Success(null);
  }

  @override
  int declineCount() => declines;

  @override
  bool mayOfferRecoveryEmail() {
    if (email != null && email!.isNotEmpty) return false;
    return declines < recoveryEmailDeclineCap;
  }

  @override
  Future<Result<int, AppError>> declineRecoveryEmail() async {
    declineCalls++;
    declines++;
    if (fails) {
      return const Failure(AppError(messageKey: 'recoveryEmailError'));
    }
    return Success(declines);
  }

  @override
  Future<Result<void, AppError>> attachRecoveryEmail(String address) async {
    attachCalls++;
    if (fails) {
      return const Failure(AppError(messageKey: 'recoveryEmailError'));
    }
    email = address;
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> sendEmailSignInCode(String address) async {
    emailCodeCalls++;
    if (addressIsUnknown) {
      return const Failure(AppError(messageKey: 'emailSignInUnknown'));
    }
    if (fails) {
      return const Failure(AppError(messageKey: 'signInNetworkError'));
    }
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> verifyEmailSignInCode({
    required String email,
    required String token,
  }) async {
    if (fails) return const Failure(AppError(messageKey: 'codeWrongCode'));
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> changePhoneNumber(String phone) async {
    phoneChangeCalls++;
    if (fails) {
      return const Failure(AppError(messageKey: 'changePhoneError'));
    }
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> verifyPhoneChange({
    required String phone,
    required String token,
  }) async {
    if (fails) {
      return const Failure(AppError(messageKey: 'changePhoneError'));
    }
    return const Success(null);
  }
}
