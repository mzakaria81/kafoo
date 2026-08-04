import 'package:kafoo_ai/ai.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'edge_function_invoker.dart';

part 'ai_provider.g.dart';

/// The default [AiProvider]. Tests override this via ProviderScope.
@Riverpod(keepAlive: true)
AiProvider aiProvider(Ref ref) =>
    EdgeFunctionAiProvider(invoker: createEdgeFunctionInvoker());
