import 'dart:convert';

import 'package:kafoo_ai/src/provider/ai_provider.dart';
import 'package:kafoo_ai/src/provider/edge_function_provider.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('EdgeFunctionAiProvider', () {
    test('happy path: returns the analysis text and model_id', () async {
      final analysisPayload = jsonEncode({
        'type': 'analysis',
        'ingredients': ['عدس', 'رز'],
        'calories': 850,
        'allergens': ['جلوتين'],
        'cuisine': 'egyptian',
        'category': 'main',
        'basis': <String, String>{'cuisine': 'كشري طبق مصري تقليدي'},
        'model_id': 'test-model-42',
        'used_photo': false,
      });
      final sseBody = 'data: $analysisPayload\n\n';

      Future<FunctionReply> fakeInvoker(
        String name,
        Map<String, Object?> body,
      ) async {
        expect(name, 'analyze-meal');
        return FunctionReply(status: 200, body: sseBody);
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Success<AiResponse, AppError>>());
      final success = result as Success<AiResponse, AppError>;
      expect(success.value.text, analysisPayload);
      expect(success.value.modelId, 'test-model-42');
    });

    test(
      'analysis frame preceded by other frames still returns the analysis',
      () async {
        final statusPayload = jsonEncode({
          'type': 'status',
          'message': 'processing',
        });
        final analysisPayload = jsonEncode({
          'type': 'analysis',
          'ingredients': <String>['دجاج'],
          'calories': null,
          'allergens': <String>[],
          'cuisine': 'egyptian',
          'category': 'main',
          'basis': <String, String>{},
          'model_id': 'm1',
          'used_photo': false,
        });
        final sseBody = 'data: $statusPayload\n\n'
            'data: $analysisPayload\n\n';

        Future<FunctionReply> fakeInvoker(
          String _,
          Map<String, Object?> __,
        ) async {
          return FunctionReply(status: 200, body: sseBody);
        }

        final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
        const request = AiRequest(
          promptId: 'meal-analysis',
          tier: ModelTier.fast,
          variables: {'said': 'عملت فراخ'},
        );

        final result = await provider.complete(request);

        expect(result, isA<Success<AiResponse, AppError>>());
        final success = result as Success<AiResponse, AppError>;
        expect(success.value.text, analysisPayload);
        expect(success.value.modelId, 'm1');
      },
    );

    test('error frame maps to a Failure with the right messageKey', () async {
      final errorPayload = jsonEncode({'type': 'error', 'error': 'timeout'});
      final sseBody = 'data: $errorPayload\n\n';

      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return FunctionReply(status: 504, body: sseBody);
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
      final failure = result as Failure<AiResponse, AppError>;
      expect(failure.error.messageKey, 'analyzeMealTimeout');
    });

    test('unrecognised error code falls back to unknown key', () async {
      final errorPayload = jsonEncode({
        'type': 'error',
        'error': 'some_future_code',
      });
      final sseBody = 'data: $errorPayload\n\n';

      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return FunctionReply(status: 500, body: sseBody);
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
      final failure = result as Failure<AiResponse, AppError>;
      expect(failure.error.messageKey, 'analyzeMealUnknownError');
    });

    test('non-2xx status with JSON error body maps to Failure', () async {
      final jsonBody = jsonEncode({'error': 'meal_not_owned'});

      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return FunctionReply(status: 403, body: jsonBody);
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
      final failure = result as Failure<AiResponse, AppError>;
      expect(failure.error.messageKey, 'analyzeMealNotOwned');
    });

    test('non-2xx status with no parseable error body is a Failure', () async {
      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return const FunctionReply(
          status: 500,
          body: 'Internal Server Error',
        );
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
      final failure = result as Failure<AiResponse, AppError>;
      expect(failure.error.messageKey, 'analyzeMealUnknownError');
    });

    test('body that is not SSE at all is a Failure', () async {
      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return const FunctionReply(status: 200, body: 'hello world');
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
    });

    test('SSE with no analysis frame is a Failure', () async {
      final statusPayload = jsonEncode({
        'type': 'status',
        'message': 'still working',
      });
      final sseBody = 'data: $statusPayload\n\n';

      Future<FunctionReply> fakeInvoker(
        String _,
        Map<String, Object?> __,
      ) async {
        return FunctionReply(status: 200, body: sseBody);
      }

      final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
      const request = AiRequest(
        promptId: 'meal-analysis',
        tier: ModelTier.fast,
        variables: {'said': 'عملت كشري'},
      );

      final result = await provider.complete(request);

      expect(result, isA<Failure<AiResponse, AppError>>());
    });

    test(
      'body sent to invoker contains only said, meal_id, photo_path — never cook_id or other keys',
      () async {
        Map<String, Object?>? capturedBody;

        Future<FunctionReply> fakeInvoker(
          String _,
          Map<String, Object?> body,
        ) async {
          capturedBody = body;
          final analysisPayload = jsonEncode({
            'type': 'analysis',
            'ingredients': <String>[],
            'calories': null,
            'allergens': <String>[],
            'cuisine': 'egyptian',
            'category': 'main',
            'basis': <String, String>{},
            'model_id': 'm1',
            'used_photo': false,
          });
          return FunctionReply(
            status: 200,
            body: 'data: $analysisPayload\n\n',
          );
        }

        final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
        const request = AiRequest(
          promptId: 'meal-analysis',
          tier: ModelTier.fast,
          variables: {
            'said': 'عملت كشري',
            'meal_id': 'uuid-here',
            'photo_path': 'meal-photos/uid/mid.jpg',
            'cook_id': 'should-not-be-sent',
            'user_id': 'also-not-sent',
          },
        );

        await provider.complete(request);

        expect(capturedBody, isNotNull);
        expect(capturedBody!.containsKey('cook_id'), isFalse);
        expect(capturedBody!.containsKey('user_id'), isFalse);
        expect(capturedBody!.containsKey('said'), isTrue);
        expect(capturedBody!.containsKey('meal_id'), isTrue);
        expect(capturedBody!.containsKey('photo_path'), isTrue);
        expect(capturedBody!.length, 3);
      },
    );

    test('all known error codes map to the correct messageKey', () async {
      final knownCodes = <String, String>{
        'unauthorized': 'analyzeMealUnauthorized',
        'meal_not_owned': 'analyzeMealNotOwned',
        'rate_limit': 'analyzeMealRateLimited',
        'timeout': 'analyzeMealTimeout',
        'invalid_response': 'analyzeMealInvalidResponse',
        'provider_auth': 'analyzeMealProviderError',
        'upstream': 'analyzeMealProviderError',
        'provider_misconfigured': 'analyzeMealProviderError',
        'meal_lookup_failed': 'analyzeMealServerError',
        'prompt_missing': 'analyzeMealServerError',
        'misconfigured': 'analyzeMealServerError',
      };

      for (final entry in knownCodes.entries) {
        final errorPayload = jsonEncode({
          'type': 'error',
          'error': entry.key,
        });
        final sseBody = 'data: $errorPayload\n\n';

        Future<FunctionReply> fakeInvoker(
          String _,
          Map<String, Object?> __,
        ) async {
          return FunctionReply(status: 500, body: sseBody);
        }

        final provider = EdgeFunctionAiProvider(invoker: fakeInvoker);
        const request = AiRequest(
          promptId: 'meal-analysis',
          tier: ModelTier.fast,
          variables: {'said': 'test'},
        );

        final result = await provider.complete(request);

        expect(result, isA<Failure<AiResponse, AppError>>(), reason: entry.key);
        final failure = result as Failure<AiResponse, AppError>;
        expect(failure.error.messageKey, entry.value, reason: entry.key);
      }
    });
  });
}
