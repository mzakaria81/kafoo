import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnvoicedSpeechOutput', () {
    test('says nothing, and is named so nobody assumes otherwise', () async {
      // The engine is a pending founder decision, not an oversight. A silent
      // implementation with a neutral name is how a missing voice system gets
      // mistaken for a working one.
      SharedPreferences.setMockInitialValues({});
      final speech = UnvoicedSpeechOutput();
      await speech.load();
      await speech.speak('تمام، الأكلة منشورة');
      expect(speech.isMuted, isFalse,
          reason: 'silent is not the same as muted');
    });

    test('the assistant talks by default', () async {
      // Kafoo reads itself aloud because speech is the primary channel, not an
      // accessibility add-on. Anything that starts silent has to be a decision
      // somebody made.
      SharedPreferences.setMockInitialValues({});
      final speech = UnvoicedSpeechOutput();
      await speech.load();
      expect(speech.isMuted, isFalse);
    });

    test('muting persists until reversed', () async {
      // A Cook who silenced the app in a room with other people in it must not
      // find it talking again on the next launch.
      SharedPreferences.setMockInitialValues({});
      await UnvoicedSpeechOutput().setMuted(muted: true);

      final next = UnvoicedSpeechOutput();
      await next.load();
      expect(next.isMuted, isTrue);

      await next.setMuted(muted: false);
      final third = UnvoicedSpeechOutput();
      await third.load();
      expect(third.isMuted, isFalse);
    });

    test('a broken preference store leaves the assistant audible', () async {
      // Never silently muted. A Cook who cannot hear the app and never chose
      // that has no way to find out why.
      SharedPreferences.setMockInitialValues({
        UnvoicedSpeechOutput.preferenceKey: 'not a boolean',
      });
      final speech = UnvoicedSpeechOutput();
      await speech.load();
      expect(speech.isMuted, isFalse);
    });
  });

  group('FakeSpeechOutput', () {
    test('records what was said', () async {
      final speech = FakeSpeechOutput();
      await speech.speak('تمام، الأكلة منشورة');
      expect(speech.spoken, ['تمام، الأكلة منشورة']);
    });

    test('says nothing while muted', () async {
      final speech = FakeSpeechOutput();
      await speech.setMuted(muted: true);
      await speech.speak('حاجة');
      expect(speech.spoken, isEmpty);
    });
  });
}
