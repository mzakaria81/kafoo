import 'dart:async';
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

  /// Numbers a code was requested for, in order. Records that the SEND
  /// happened, which is the half a resend test needs.
  final List<String> sentTo = <String>[];

  /// Codes offered to [verifyPhoneSignInCode], in order.
  final List<String> verified = <String>[];

  /// When set, [sendPhoneSignInCode] fails with this error.
  ///
  /// An [AppError] rather than a bare key string, so the key a test uses is a
  /// literal the gate can see. Holding the key in a local variable and passing
  /// that variable put a variable name where the gate expects a quoted string —
  /// the "error keys are localized" check reads whatever token follows the named
  /// argument, so it dutifully reported a missing translation for a string
  /// called "key". The check was right; the shape was wrong.
  ///
  /// **And the first version of this very comment broke it again**, by quoting
  /// the offending line verbatim: the check greps source, comments included, so
  /// prose about a defect reproduced the defect. Do not name that token here.
  AppError? failSendWith;

  /// When set, [verifyPhoneSignInCode] fails with this error.
  AppError? failVerifyWith;

  /// What a successful verify reports: true means this created a new identity.
  bool verifyReturnsNewAccount = false;

  /// Held open to observe the loading state. Without it every call resolves in
  /// the same microtask and a spinner never renders, so a test of one would pass
  /// while asserting nothing.
  Completer<void>? gate;

  @override
  Future<Result<void, AppError>> sendPhoneSignInCode(String phone) async {
    if (gate != null) await gate!.future;
    sentTo.add(phone);
    final failure = failSendWith;
    if (failure != null) return Failure(failure);
    return const Success(null);
  }

  @override
  Future<Result<bool, AppError>> verifyPhoneSignInCode({
    required String phone,
    required String token,
  }) async {
    if (gate != null) await gate!.future;
    verified.add(token);
    final failure = failVerifyWith;
    if (failure != null) return Failure(failure);
    return Success(verifyReturnsNewAccount);
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
