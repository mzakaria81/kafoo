import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('returns the canned reply for a stubbed prompt', () async {
    final provider = StubAiProvider({'meal-analysis': 'كشري'});
    const request = AiRequest(promptId: 'meal-analysis', tier: ModelTier.fast);

    final result = await provider.complete(request);

    expect(result, isA<Success<AiResponse, AppError>>());

    final success = result as Success<AiResponse, AppError>;
    expect(success.value.text, 'كشري');
  });

  test('fails loudly when a prompt was never stubbed', () async {
    final provider = StubAiProvider({});
    const request = AiRequest(promptId: 'unstubbed', tier: ModelTier.fast);

    final result = await provider.complete(request);

    expect(result, isA<Failure<AiResponse, AppError>>());

    final failure = result as Failure<AiResponse, AppError>;
    expect(failure.error.messageKey, 'aiPromptNotStubbed');
  });
}
