import 'package:kafoo_domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How many times the recovery-email invitation may be declined before Kafoo
/// stops offering it (FR-029, SC-010).
///
/// Two. Repeating an ask someone has already refused is a dark pattern the
/// constitution forbids outright, so the cap is small enough that a person who
/// means "no" is believed the second time.
const int recoveryEmailDeclineCap = 2;

/// The user-metadata key holding the decline count.
///
/// Metadata is writable by the person it belongs to, so this is a preference,
/// never a permission. Nothing is withheld on the strength of it.
const String recoveryEmailDeclinesKey = 'recovery_email_declines';

/// Identity operations that are not sign-in itself.
abstract interface class AccountRepository {
  /// Removes the signed-in person and everything attached to them.
  ///
  /// Sends no arguments: the Edge Function reads identity from the verified
  /// JWT, so there is nothing here that could name the wrong person.
  Future<Result<void, AppError>> removeAccount();

  /// How many times this person has declined the recovery-email invitation.
  int declineCount();

  /// Whether the invitation may still be shown.
  bool mayOfferRecoveryEmail();

  /// Records a decline. Withholds nothing — it only stops the asking.
  Future<Result<int, AppError>> declineRecoveryEmail();

  /// Attaches an email address to the identity already signed in.
  ///
  /// Attaching from *inside* the account is what stops an address claiming an
  /// identity it was never given (FR-007). There is deliberately no route that
  /// attaches an address from outside.
  Future<Result<void, AppError>> attachRecoveryEmail(String email);

  /// Sends a sign-in code to an address that is already attached to somebody.
  ///
  /// Never creates a new person: an unknown address must fail rather than
  /// quietly become a second identity.
  Future<Result<void, AppError>> sendEmailSignInCode(String email);

  /// Verifies an emailed sign-in code, reaching the identity the address was
  /// attached to.
  Future<Result<void, AppError>> verifyEmailSignInCode({
    required String email,
    required String token,
  });

  /// Moves this identity to a new phone number, keeping everything attached to
  /// it. The previous number stops reaching the identity once confirmed.
  Future<Result<void, AppError>> changePhoneNumber(String phone);

  /// Verifies the code sent to the new number, completing the change.
  Future<Result<void, AppError>> verifyPhoneChange({
    required String phone,
    required String token,
  });
}

class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Result<void, AppError>> removeAccount() async {
    try {
      await _client.functions.invoke('delete-account');
      // The token is worthless now; drop it so nothing retries with it.
      await _client.auth.signOut();
      return const Success(null);
    } on Object catch (e) {
      // The account still exists and is still usable. Say so rather than
      // leaving someone unsure whether they are half-erased.
      return Failure(AppError(messageKey: 'removeAccountError', cause: e));
    }
  }

  @override
  int declineCount() {
    final raw =
        _client.auth.currentUser?.userMetadata?[recoveryEmailDeclinesKey];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  @override
  bool mayOfferRecoveryEmail() {
    // Someone who already has an address is never invited to add one.
    final email = _client.auth.currentUser?.email;
    if (email != null && email.isNotEmpty) return false;
    return declineCount() < recoveryEmailDeclineCap;
  }

  @override
  Future<Result<int, AppError>> declineRecoveryEmail() async {
    final next = declineCount() + 1;
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {recoveryEmailDeclinesKey: next}),
      );
      return Success(next);
    } on Object catch (e) {
      // Failing to record a decline must not cost the person anything, and
      // must not be surfaced — they said no, and that is what matters.
      return Failure(AppError(messageKey: 'recoveryEmailError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> attachRecoveryEmail(String email) async {
    try {
      await _client.auth.updateUser(UserAttributes(email: email));
      return const Success(null);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'recoveryEmailError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> sendEmailSignInCode(String email) async {
    try {
      // shouldCreateUser: false is the whole guarantee of FR-007. With it
      // true, an unknown address would silently become a second identity —
      // exactly the claim this route must not allow.
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(messageKey: 'emailSignInUnknown', cause: e));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'signInNetworkError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> verifyEmailSignInCode({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      return const Success(null);
    } on AuthException catch (e) {
      return Failure(AppError(messageKey: 'codeWrongCode', cause: e));
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'signInNetworkError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> changePhoneNumber(String phone) async {
    try {
      await _client.auth.updateUser(UserAttributes(phone: phone));
      return const Success(null);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'changePhoneError', cause: e));
    }
  }

  @override
  Future<Result<void, AppError>> verifyPhoneChange({
    required String phone,
    required String token,
  }) async {
    try {
      // phoneChange, not sms: this confirms a change on an existing identity
      // rather than signing somebody in. The old number stops working the
      // moment this succeeds.
      await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.phoneChange,
      );
      return const Success(null);
    } on Object catch (e) {
      return Failure(AppError(messageKey: 'changePhoneError', cause: e));
    }
  }
}
