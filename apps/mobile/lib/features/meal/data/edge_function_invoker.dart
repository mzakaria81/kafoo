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
    final bodyText = switch (response.data) {
      final String s => s,
      final Map<String, dynamic> m => jsonEncode(m),
      final List<dynamic> l => jsonEncode(l),
      _ => response.data?.toString() ?? '',
    };
    return FunctionReply(
      status: response.status,
      body: bodyText,
    );
  };
}
