/// Kafoo's AI layer.
///
/// Every model call in the product goes through [AiProvider]. Feature code and
/// Flutter code depend on this interface and never import a provider SDK.
/// Adapters live under `lib/src/provider/` and absorb provider quirks there.
/// Swapping OpenAI, Anthropic, or Gemini is a configuration change. See
/// `decisions/0005-route-all-model-calls-through-a-provider-abstraction.md`.
library;

export 'src/conversation_reply_parser.dart';
export 'src/meal_analysis_parser.dart';
export 'src/provider/ai_provider.dart';
export 'src/provider/edge_function_provider.dart';
export 'src/provider/stub_provider.dart';
