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
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );
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
