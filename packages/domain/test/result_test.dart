import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('Success carries its value', () {
    const result = Success<int, AppError>(42);

    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
    expect(result.value, 42);
  });

  test('Failure carries its error', () {
    const error = AppError(messageKey: 'orderRejected');
    const result = Failure<int, AppError>(error);

    expect(result.isFailure, isTrue);
    expect(result.isSuccess, isFalse);
    expect(result.error.messageKey, 'orderRejected');
  });

  test('switching over a Result is exhaustive', () {
    const Result<int, AppError> result = Success(1);

    final value = switch (result) {
      Success(:final value) => value,
      Failure() => -1,
    };

    expect(value, 1);
  });
}
