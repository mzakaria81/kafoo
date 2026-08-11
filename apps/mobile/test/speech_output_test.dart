import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [FlutterTts] that answers from a list instead of from a phone.
///
/// Subclassed rather than mocked because the methods that matter are the two
/// deciding whether Kafoo has a voice at all — what languages the device
/// offers, and whether asking throws.
class _FakeTts extends FlutterTts {
  _FakeTts(this.languages, {this.throwOnLanguages = false});

  final List<String> languages;
  final bool throwOnLanguages;

  final List<String> spoken = [];
  final List<double> volumes = [];
  int stops = 0;
  String? language;

  @override
  Future<dynamic> get getLanguages async {
    if (throwOnLanguages) throw StateError('no engine on this handset');
    return languages;
  }

  @override
  Future<dynamic> setLanguage(String value) async => language = value;

  @override
  Future<dynamic> setSpeechRate(double rate) async {}

  @override
  Future<dynamic> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<dynamic> setQueueMode(int mode) async {}

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async =>
      spoken.add(text);

  @override
  Future<dynamic> stop() async => stops++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DeviceSpeechOutput picks a voice', () {
    test('prefers Egyptian Arabic', () async {
      final tts = _FakeTts(['en-US', 'ar-SA', 'ar-EG']);
      final speech = DeviceSpeechOutput(tts: tts);

      expect(await speech.initialize(), isTrue);
      expect(speech.voiceMatch, SpeechVoiceMatch.exact);
      expect(tts.language, 'ar-eg');
    });

    test('accepts another Arabic voice, and says that is what it got',
        () async {
      // Understandable, wrong accent. A Cook being spoken to in Gulf Arabic is
      // a different situation from silence, and a caller has to tell them
      // apart.
      final speech = DeviceSpeechOutput(tts: _FakeTts(['en-US', 'ar-SA']));

      expect(await speech.initialize(), isTrue);
      expect(speech.voiceMatch, SpeechVoiceMatch.fallback);
      expect(speech.canSpeak, isTrue);
    });

    test('matches whatever separator and case the platform uses', () async {
      final speech = DeviceSpeechOutput(tts: _FakeTts(['AR_EG']));

      expect(await speech.initialize(), isTrue);
      expect(speech.voiceMatch, SpeechVoiceMatch.exact);
    });

    test('a handset with no Arabic voice goes quiet and says so', () async {
      // THE LIKELY REAL-WORLD CASE, not the exceptional one. Android ships
      // text-to-speech language data separately from the engine, so plenty of
      // Egyptian handsets carry no Arabic voice — the same trap the speech
      // recogniser already fell into.
      final speech = DeviceSpeechOutput(tts: _FakeTts(['en-US', 'fr-FR']));

      expect(await speech.initialize(), isFalse);
      expect(speech.voiceMatch, SpeechVoiceMatch.none);
      expect(speech.canSpeak, isFalse);
    });

    test('a missing engine leaves the app usable rather than crashing',
        () async {
      final speech = DeviceSpeechOutput(
        tts: _FakeTts([], throwOnLanguages: true),
      );

      expect(await speech.initialize(), isFalse);
      expect(speech.canSpeak, isFalse);
    });
  });

  group('DeviceSpeechOutput speaks', () {
    test('says the line, and stops the previous one first', () async {
      // Two sentences at once is worse than either. Some engines queue and some
      // truncate, so the stop is explicit rather than assumed.
      final tts = _FakeTts(['ar-EG']);
      final speech = DeviceSpeechOutput(tts: tts);
      await speech.initialize();

      await speech.speak('عندك خمس أكلات');
      expect(tts.spoken, ['عندك خمس أكلات']);
      expect(tts.stops, 1);
    });

    test('money is spoken quietly', () async {
      // Homes are shared and income is private.
      final tts = _FakeTts(['ar-EG']);
      final speech = DeviceSpeechOutput(tts: tts);
      await speech.initialize();

      await speech.speak('محشي، منشورة، ١٢٠ جنيه', quiet: true);
      expect(tts.volumes.last, lessThan(1));

      await speech.speak('عايزة تعملي إيه؟');
      expect(tts.volumes.last, 1);
    });

    test('says nothing on a handset with no Arabic voice', () async {
      final tts = _FakeTts(['en-US']);
      final speech = DeviceSpeechOutput(tts: tts);
      await speech.initialize();

      await speech.speak('حاجة');
      expect(tts.spoken, isEmpty);
    });

    test('says nothing while muted', () async {
      final tts = _FakeTts(['ar-EG']);
      final speech = DeviceSpeechOutput(tts: tts);
      await speech.initialize();
      await speech.setMuted(muted: true);

      await speech.speak('حاجة');
      expect(tts.spoken, isEmpty);
    });

    test('muting stops a sentence already in progress', () async {
      // Pressing mute mid-sentence has to be immediate. Anything else means the
      // Cook pressed it in a room with people in it and the app kept talking.
      final tts = _FakeTts(['ar-EG']);
      final speech = DeviceSpeechOutput(tts: tts);
      await speech.initialize();
      await speech.speak('جملة طويلة');
      final before = tts.stops;

      await speech.setMuted(muted: true);
      expect(tts.stops, greaterThan(before));
    });
  });

  group('the mute preference outlives the app', () {
    test('the assistant talks by default', () async {
      final speech = DeviceSpeechOutput(tts: _FakeTts(['ar-EG']));
      await speech.initialize();
      expect(speech.isMuted, isFalse);
    });

    test('muting persists until reversed', () async {
      final first = DeviceSpeechOutput(tts: _FakeTts(['ar-EG']));
      await first.initialize();
      await first.setMuted(muted: true);

      final second = DeviceSpeechOutput(tts: _FakeTts(['ar-EG']));
      await second.initialize();
      expect(second.isMuted, isTrue);

      await second.setMuted(muted: false);
      final third = DeviceSpeechOutput(tts: _FakeTts(['ar-EG']));
      await third.initialize();
      expect(third.isMuted, isFalse);
    });

    test('a broken preference store leaves the assistant audible', () async {
      // Never silently muted. A Cook who cannot hear the app and never chose
      // that has no way to find out why.
      SharedPreferences.setMockInitialValues({
        StoredMutePreference.preferenceKey: 'not a boolean',
      });
      final speech = DeviceSpeechOutput(tts: _FakeTts(['ar-EG']));
      await speech.initialize();
      expect(speech.isMuted, isFalse);
    });

    test('every implementation shares one persistence rule', () async {
      // The mixin exists so a swapped engine cannot lose the preference along
      // with the voice.
      await UnvoicedSpeechOutput().setMuted(muted: true);
      final next = UnvoicedSpeechOutput();
      await next.initialize();
      expect(next.isMuted, isTrue);
    });
  });

  group('UnvoicedSpeechOutput', () {
    test('is what a handset with no Arabic voice falls back to', () async {
      final speech = UnvoicedSpeechOutput();
      expect(await speech.initialize(), isFalse);
      expect(speech.canSpeak, isFalse);
      expect(speech.voiceMatch, SpeechVoiceMatch.none);
    });
  });

  group('FakeSpeechOutput', () {
    test('records the line and whether it was quiet', () async {
      final speech = FakeSpeechOutput();
      await speech.initialize();
      await speech.speak('تمام، الأكلة منشورة');
      await speech.speak('١٢٠ جنيه', quiet: true);

      expect(
        speech.spoken.map((s) => s.line),
        ['تمام، الأكلة منشورة', '١٢٠ جنيه'],
      );
      expect(speech.spoken.last.quiet, isTrue);
    });

    test('can pretend the handset has no Arabic voice', () async {
      final speech = FakeSpeechOutput(voiceMatch: SpeechVoiceMatch.none);
      await speech.initialize();
      await speech.speak('حاجة');
      expect(speech.spoken, isEmpty);
    });
  });
}
