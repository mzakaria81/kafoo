/// The outcome of an operation that can fail in an expected way.
///
/// Kafoo reserves exceptions for programmer error. Anything a person can
/// legitimately cause — a rejected Order, a failed transcription, a network
/// timeout — is modelled here, so a caller cannot forget to handle it.
sealed class Result<T, E> {
  /// Creates a result.
  const Result();

  /// Whether this result carries a value.
  bool get isSuccess => this is Success<T, E>;

  /// Whether this result carries a failure.
  bool get isFailure => this is Failure<T, E>;
}

/// A successful [Result] carrying a [value].
final class Success<T, E> extends Result<T, E> {
  /// Creates a successful result around [value].
  const Success(this.value);

  /// The produced value.
  final T value;
}

/// A failed [Result] carrying an [error].
final class Failure<T, E> extends Result<T, E> {
  /// Creates a failed result around [error].
  const Failure(this.error);

  /// The reason the operation failed.
  final E error;
}

/// A failure a person can legitimately cause.
///
/// Every message reaching a person must be localized and actionable.
/// 'Something went wrong' is not acceptable copy, so [messageKey] names an ARB
/// entry rather than carrying display text.
final class AppError {
  /// Creates an error naming the ARB [messageKey] that describes it.
  const AppError({required this.messageKey, this.cause});

  /// The ARB key for the message shown to the person, in their locale.
  final String messageKey;

  /// The underlying cause, for logs only. Never shown to a person.
  final Object? cause;

  @override
  String toString() => 'AppError($messageKey)';
}
