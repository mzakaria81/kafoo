import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/meal/data/edge_function_invoker.dart';

/// THE SEAM THAT THREW AWAY EVERY ANALYSIS THE ASSISTANT EVER PRODUCED.
///
/// 2026-08-11. The founder added a cake — «حاجة حلوة / بيض، سكر، لين، دقيق» —
/// with a photograph. `analyze-meal` answered 200 in 2.365 seconds and logged
/// this, from the demo project's own function logs:
///
///     {"event":"analyze_meal_shape",
///      "filled":["ingredients","calories","allergens","cuisine","category"],
///      "explained":["ingredients","calories","allergens","cuisine","category"],
///      "unexplained":[],"used_photo":true}
///
/// All five fields, every one explained, from the photo. There was nothing wrong
/// with the model, the prompt, the key, or the function. His screen said «حصل
/// مشكلة مش متوقعة» — an unexpected problem — and «المساعد مقدرش يقدّر حاجة».
///
/// `functions_client` 2.7.1 hands back `response.data` as a LIVE STREAM when the
/// reply is `text/event-stream` with a success status. `analyze-meal` streams by
/// design; the constitution requires it. The invoker's switch had no case for a
/// stream, so it fell through to `.toString()` and produced the literal text
/// `Instance of 'ByteStream'`. No `data:` frame in that, so the provider reported
/// "no analysis and no error" — which is the unknown-error message.
///
/// **Nothing caught it because both halves either side are tested and this join
/// is not.** `StubAiProvider` replaces the provider entirely, and
/// `edge_function_provider_test.dart` hands the parser a `String` from a fake
/// invoker. Only the code that talks to Supabase can see a `ByteStream`, and
/// that was the one piece with no test — which is why it is now a named function
/// rather than an expression inside a closure.
void main() {
  group('readFunctionBody', () {
    test('drains a streamed reply, which is how analyze-meal answers',
        () async {
      // The exact frame `sseEvent` produces, split across chunks the way a real
      // network delivers one. A test that sent it as a single chunk would pass on
      // a decoder that only reads the first.
      const frame =
          'data: {"type":"analysis","ingredients":["بيض","سكر","دقيق"],'
          '"calories":420,"allergens":["جلوتين"],"cuisine":"american",'
          '"category":"dessert","basis":{"ingredients":"من وصف الطباخة"}}\n\n';
      final bytes = utf8.encode(frame);
      final stream = Stream<List<int>>.fromIterable([
        bytes.sublist(0, 30),
        bytes.sublist(30, 90),
        bytes.sublist(90),
      ]);

      expect(
        await readFunctionBody(stream),
        frame,
        reason: 'THE BUG. This returned "Instance of \'_StreamImpl<...>\'", so '
            'every analysis was discarded one line before it was parsed.',
      );
    });

    test('a multi-byte Arabic character split across chunks survives',
        () async {
      // Arabic is two bytes per character in UTF-8, so a chunk boundary can land
      // mid-character. Decoding chunk-by-chunk and concatenating would produce
      // replacement characters; `utf8.decodeStream` carries the partial byte
      // across. This product is Arabic-first, so the awkward case is the normal
      // one.
      final bytes = utf8.encode('data: {"basis":"عدس ورز"}\n\n');
      final split = bytes.length ~/ 2;
      final stream = Stream<List<int>>.fromIterable([
        bytes.sublist(0, split),
        bytes.sublist(split),
      ]);

      expect(await readFunctionBody(stream), contains('عدس ورز'));
    });

    test('a plain string is passed through untouched', () async {
      expect(await readFunctionBody('data: {"type":"error"}\n\n'),
          'data: {"type":"error"}\n\n');
    });

    test('a decoded JSON object is re-encoded rather than stringified',
        () async {
      // `functions.invoke` decodes an `application/json` reply for us, and the
      // provider re-parses text — so it has to go back to JSON, not to Dart's
      // `{key: value}` map formatting, which is not JSON and would not parse.
      expect(
        await readFunctionBody({'error': 'provider_misconfigured'}),
        '{"error":"provider_misconfigured"}',
      );
    });

    test('null is empty text, not the word null', () async {
      expect(await readFunctionBody(null), isEmpty);
    });

    test('an unexpected shape keeps its type name', () async {
      // Deliberately lossy rather than empty: reaching this case means the client
      // returned something nothing above expects, and a type name in a log is a
      // better clue than an empty string that reads like an empty reply. This is
      // the case that produced the defect, kept as a last resort rather than
      // removed.
      expect(await readFunctionBody(42), '42');
    });
  });
}
