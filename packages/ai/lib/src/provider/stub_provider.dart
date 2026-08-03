import 'package:kafoo_ai/src/provider/ai_provider.dart';
import 'package:kafoo_domain/domain.dart';

/// An [AiProvider] returning canned replies, with no network and no real
/// provider behind it.
///
/// ADR-0005 claims that swapping providers is a configuration change. This stub
/// is how that claim is tested rather than asserted: golden cases run against
/// it and against real adapters, and a leak in the abstraction shows up as a
/// difference between them.
final class StubAiProvider implements AiProvider {
  /// Creates a stub that answers each [promptId] from [replies].
  ///
  /// A prompt with no entry in [replies] yields a [Failure], so a test that
  /// forgets to stub a call fails loudly instead of silently passing.
  StubAiProvider(this.replies);

  /// Canned reply text, keyed by `promptId`.
  final Map<String, String> replies;

  /// The most recent request, for tests that need to prove untrusted input
  /// reached the provider unchanged rather than being scrubbed on the way in.
  AiRequest? lastRequest;

  @override
  Future<Result<AiResponse, AppError>> complete(AiRequest request) async {
    lastRequest = request;
    final reply = replies[request.promptId];
    if (reply == null) {
      return const Failure(AppError(messageKey: 'aiPromptNotStubbed'));
    }
    return Success(AiResponse(text: reply, modelId: 'stub'));
  }
}
