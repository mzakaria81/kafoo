import 'dart:convert';

import 'package:kafoo_ai/src/provider/ai_provider.dart';
import 'package:kafoo_domain/domain.dart';

/// What the Edge Function replied. `body` is the raw response text.
final class FunctionReply {
  const FunctionReply({required this.status, required this.body});

  /// HTTP status code of the response.
  final int status;

  /// The raw response body text.
  final String body;
}

/// Calls a named Kafoo Edge Function. Supplied by the app, which owns the
/// Supabase client.
///
/// This is the seam that keeps `packages/ai` pure: the provider takes its
/// transport by injection rather than importing Supabase or `http`.
typedef FunctionInvoker = Future<FunctionReply> Function(
  String functionName,
  Map<String, Object?> body,
);

/// An [AiProvider] that talks to Kafoo's own `analyze-meal` Edge Function.
///
/// The function replies with Server-Sent Events, not plain JSON. This adapter
/// parses the SSE frames, finds the `analysis` frame, and hands back its raw
/// JSON text. It does NOT call `parseMealAnalysis` — that is the caller's step.
final class EdgeFunctionAiProvider implements AiProvider {
  /// Creates a provider that calls the given [invoker].
  EdgeFunctionAiProvider({required FunctionInvoker invoker})
      : _invoker = invoker;

  final FunctionInvoker _invoker;

  @override
  Future<Result<AiResponse, AppError>> complete(AiRequest request) async {
    // Build the request body from known keys only. NEVER forward anything
    // identifying the caller — identity comes from the verified JWT inside
    // the function, and a cook_id in a body is a vulnerability.
    final body = <String, Object?>{
      if (request.variables['said'] case final said?) 'said': said,
      if (request.variables['meal_id'] case final mealId?) 'meal_id': mealId,
      if (request.variables['photo_path'] case final photoPath?)
        'photo_path': photoPath,
    };

    final reply = await _invoker('analyze-meal', body);

    return _parseResponse(reply);
  }

  Result<AiResponse, AppError> _parseResponse(FunctionReply reply) {
    final (analysisJson, errorCode) = _parseSseFrames(reply.body);

    // An error frame always wins — even if an analysis frame somehow also
    // exists, the function is telling us something went wrong.
    if (errorCode != null) {
      return Failure(_errorForCode(errorCode));
    }

    if (analysisJson != null) {
      late final String? modelId;
      try {
        final decoded = jsonDecode(analysisJson) as Map<String, dynamic>;
        modelId = decoded['model_id'] as String?;
      } on FormatException {
        return const Failure(
          AppError(messageKey: 'analyzeMealInvalidResponse'),
        );
      }
      return Success(AiResponse(text: analysisJson, modelId: modelId));
    }

    // No analysis frame and no error frame. If the status is non-2xx, try to
    // extract an error code from a plain JSON body. Otherwise it is an
    // unexpected response shape.
    if (reply.status < 200 || reply.status >= 300) {
      final code = _tryExtractErrorCode(reply.body);
      if (code != null) {
        return Failure(_errorForCode(code));
      }
    }

    return const Failure(AppError(messageKey: 'analyzeMealUnknownError'));
  }

  /// Parses SSE frames from [body]. Returns the raw JSON of the `analysis`
  /// frame (if any) and the error code from an `error` frame (if any).
  (String? analysisJson, String? errorCode) _parseSseFrames(String body) {
    String? analysisJson;
    String? errorCode;

    const prefix = 'data: ';
    final frames = body.split('\n\n');

    for (final rawFrame in frames) {
      final trimmed = rawFrame.trim();
      if (!trimmed.startsWith(prefix)) continue;

      final jsonStr = trimmed.substring(prefix.length);
      if (jsonStr.isEmpty) continue;

      late final Object? decoded;
      try {
        decoded = jsonDecode(jsonStr);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;

      final type = decoded['type'] as String?;
      if (type == 'analysis') {
        analysisJson = jsonStr;
      } else if (type == 'error') {
        errorCode = decoded['error'] as String?;
      }
    }

    return (analysisJson, errorCode);
  }

  /// Maps an error code emitted by the Edge Function onto a localized
  /// [AppError]. A code that is not recognised falls back to the shared
  /// unknown key — a new code appearing later must degrade to a message,
  /// never to a crash or a blank screen.
  AppError _errorForCode(String code) {
    return switch (code) {
      'unauthorized' => const AppError(messageKey: 'analyzeMealUnauthorized'),
      'meal_not_owned' => const AppError(messageKey: 'analyzeMealNotOwned'),
      'rate_limit' => const AppError(messageKey: 'analyzeMealRateLimited'),
      'timeout' => const AppError(messageKey: 'analyzeMealTimeout'),
      'invalid_response' =>
        const AppError(messageKey: 'analyzeMealInvalidResponse'),
      'provider_auth' ||
      'upstream' ||
      'provider_misconfigured' =>
        const AppError(messageKey: 'analyzeMealProviderError'),
      'meal_lookup_failed' ||
      'prompt_missing' ||
      'misconfigured' =>
        const AppError(messageKey: 'analyzeMealServerError'),
      _ => const AppError(messageKey: 'analyzeMealUnknownError'),
    };
  }

  /// Tries to extract an error code from a plain JSON body (non-SSE).
  /// Returns null if the body is not JSON or has no `error` field.
  String? _tryExtractErrorCode(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['error'] as String?;
    } on FormatException {
      return null;
    }
  }
}
