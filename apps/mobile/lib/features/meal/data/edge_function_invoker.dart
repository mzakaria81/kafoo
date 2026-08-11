import 'dart:convert';

import 'package:kafoo_ai/ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a [FunctionInvoker] from the app's Supabase client.
///
/// This is the ONLY place the Supabase function call is written, and it is
/// what keeps `packages/ai` pure — the provider takes its transport by
/// injection rather than importing Supabase or `http`.
FunctionInvoker createEdgeFunctionInvoker() {
  return (String functionName, Map<String, Object?> body) async {
    final client = Supabase.instance.client;
    final FunctionResponse response;
    try {
      response = await client.functions.invoke(functionName, body: body);
    } on FunctionException catch (e) {
      // **A NON-2XX REPLY IS AN ANSWER, NOT AN ACCIDENT, AND UNTIL 2026-08-11
      // THIS LET IT ESCAPE AS A THROW.** `invoke` throws for every non-2xx
      // status. `EdgeFunctionAiProvider` is written to READ those replies — it
      // pulls the error code out of the body and turns it into a sentence in
      // Egyptian Arabic — and it never got the chance, because the exception
      // flew past it and out through an `unawaited` call in the controller.
      //
      // The founder's symptom: «تقديرات المساعد» spinning forever, with no way
      // to finish putting a Meal on offer.
      //
      // Converting it back into a reply is what puts the response where the
      // code that understands it can see it. `analyze-meal` answering 500 with
      // `{"error":"provider_misconfigured"}` now reaches the Cook as "the
      // assistant is not available right now, write the details yourself".
      return FunctionReply(
        status: e.status,
        body: switch (e.details) {
          final String s => s,
          final Map<String, dynamic> m => jsonEncode(m),
          final List<dynamic> l => jsonEncode(l),
          null => '',
          final other => other.toString(),
        },
      );
    }
    return FunctionReply(
      status: response.status,
      body: await readFunctionBody(response.data),
    );
  };
}

/// Turns whatever `functions.invoke` handed back into the reply text.
///
/// **A SEPARATE, TESTABLE FUNCTION BECAUSE THE INLINE VERSION SILENTLY THREW
/// AWAY EVERY ANALYSIS THE ASSISTANT HAS EVER PRODUCED.**
///
/// 2026-08-11, and this is the end of a chain of five wrong guesses. The founder
/// added a cake. `analyze-meal` answered 200 in 2.365 seconds and logged
/// `analyze_meal_shape` with all five fields filled AND all five explained, from
/// the photograph. A perfect reply. His screen said «حصل مشكلة مش متوقعة» — an
/// unexpected problem.
///
/// `functions_client` 2.7.1 returns `response.data` as a LIVE `Stream` when the
/// reply carries `Content-Type: text/event-stream` and a success status:
///
///     } else if (responseType == 'text/event-stream' && isSuccessStatus) {
///       data = response.stream;
///
/// `analyze-meal` streams by design — the constitution requires it for a
/// conversational response. So the switch here matched no typed case, fell to
/// `.toString()`, and produced the literal text `Instance of 'ByteStream'`. No
/// `data:` frame in that, so the provider reported "no analysis and no error",
/// which maps to the unknown-error message. **The assistant's answer was never
/// read, on any Meal, ever.** Every estimate this product has produced was
/// discarded one line before it could be parsed.
///
/// Nothing caught it because the two halves either side are both tested and this
/// join is not: `StubAiProvider` replaces the provider entirely, and
/// `edge_function_provider_test.dart` feeds the parser a `String` from a fake
/// invoker. The only untested seam is the one that talks to Supabase — and it is
/// the only one that can see this type.
Future<String> readFunctionBody(Object? data) async => switch (data) {
      final String s => s,
      // The SSE case, and the one that was missing. `ByteStream` is a
      // `Stream<List<int>>`; draining it is the whole fix.
      final Stream<List<int>> stream => await utf8.decodeStream(stream),
      final Map<String, dynamic> m => jsonEncode(m),
      final List<dynamic> l => jsonEncode(l),
      null => '',
      // Deliberately last and deliberately lossy. Reaching it means the client
      // returned a shape nothing above expects, and `Instance of '...'` in a log
      // is a better clue than an empty string that reads like an empty reply.
      final other => other.toString(),
    };
