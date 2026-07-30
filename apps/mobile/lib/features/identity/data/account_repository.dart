import 'package:kafoo_domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Removing an account. The only layer that touches Supabase for it.
abstract interface class AccountRepository {
  /// Removes the signed-in person and everything attached to them.
  ///
  /// Sends no arguments: the Edge Function reads identity from the verified
  /// JWT, so there is nothing here that could name the wrong person.
  Future<Result<void, AppError>> removeAccount();
}

class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository();

  @override
  Future<Result<void, AppError>> removeAccount() async {
    try {
      await Supabase.instance.client.functions.invoke('delete-account');
      // The token is worthless now; drop it so nothing retries with it.
      await Supabase.instance.client.auth.signOut();
      return const Success(null);
    } on Object catch (e) {
      // The account still exists and is still usable. Say so rather than
      // leaving someone unsure whether they are half-erased.
      return Failure(AppError(messageKey: 'removeAccountError', cause: e));
    }
  }
}
