import 'package:kafoo_domain/domain.dart';

/// Which class of model a call needs.
///
/// Extraction and classification use [fast]. [reasoning] is reserved for
/// genuinely hard tasks and its use must be justified at the call site, because
/// it costs both money and latency against a 2-second voice budget.
enum ModelTier {
  /// Cheap and quick. The default for extraction and classification.
  fast,

  /// Slower and more capable. Requires a stated reason.
  reasoning,
}

/// A single request to a language model.
///
/// [promptId] names a file in `prompts/`, never inline prompt text: a prompt is
/// version-controlled content with its own eval history, not a string literal.
final class AiRequest {
  /// Creates a request against the prompt named [promptId].
  const AiRequest({
    required this.promptId,
    required this.tier,
    this.variables = const {},
  });

  /// The `id` of the prompt file in `prompts/` driving this call.
  final String promptId;

  /// The class of model this call needs.
  final ModelTier tier;

  /// Values interpolated into the prompt.
  ///
  /// Treat every value sourced from a person as untrusted. A Cook can write
  /// anything into a Meal description, including instructions aimed at the
  /// model.
  final Map<String, String> variables;
}

/// A model's reply.
final class AiResponse {
  /// Creates a response.
  const AiResponse({required this.text, this.modelId});

  /// The raw text the model returned.
  ///
  /// Structured calls validate this against a schema before use. Never parse a
  /// model response with a regular expression.
  final String text;

  /// The concrete model that served the call, for logging and evals.
  final String? modelId;
}

/// The single seam between Kafoo and any language-model provider.
///
/// Implementations live beside this file and absorb provider-specific
/// behaviour —
/// token limits, tool-call formats, response shapes, retry semantics. A quirk
/// that reaches a caller means the abstraction has failed; fix the adapter
/// rather than working around it at the call site.
abstract interface class AiProvider {
  /// Completes [request].
  ///
  /// Returns a [Failure] for anything a person can legitimately cause, such as
  /// a timeout or a refusal. Exceptions are reserved for programmer error.
  Future<Result<AiResponse, AppError>> complete(AiRequest request);
}
