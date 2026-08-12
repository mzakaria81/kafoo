import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/hosted_speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The paid Cairene voice, and what happens when it cannot speak.
///
/// **The group that matters is the second one.** A paid voice needs the network,
/// a working account and an allowance that has not run out; the device voice
/// needs none of those. ADR-0014 chose the device voice because it always works,
/// and that reasoning did not stop applying when something better arrived — it
/// became the floor. A Cook on the metro must hear a machine rather than
/// silence, because the seam's own contract is that silence is never silent
/// about itself.
///
/// No network and no speaker are involved here: the fetch and the player are
/// injected, so these assert what actually leaves and what actually plays.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Uint8List audio(int marker) => Uint8List.fromList([0x49, 0x44, 0x33, marker]);

  ({
    HostedSpeechOutput speech,
    FakeSpeechOutput fallback,
    List<({String line, String voice})> asked,
    List<({Uint8List audio, double volume})> played,
  }) build({
    Uint8List? Function(String line, String voice)? respond,
    SpeechVoiceMatch fallbackMatch = SpeechVoiceMatch.exact,
  }) {
    final asked = <({String line, String voice})>[];
    final played = <({Uint8List audio, double volume})>[];
    final fallback = FakeSpeechOutput(voiceMatch: fallbackMatch);
    final speech = HostedSpeechOutput(
      fallback: fallback,
      fetchAudio: (line, voice) async {
        asked.add((line: line, voice: voice));
        return (respond ?? (l, v) => audio(1))(line, voice);
      },
      playAudio: (bytes, volume) async =>
          played.add((audio: bytes, volume: volume)),
      stopAudio: () async {},
    );
    return (
      speech: speech,
      fallback: fallback,
      asked: asked,
      played: played,
    );
  }

  group('asking Kafoo to speak', () {
    test('the female voice is the default — ADR-0010 addresses a Cook as her',
        () async {
      final t = build();
      await t.speech.initialize();
      expect(t.speech.role, AssistantVoiceRole.female);
    });

    test('a line is sent with the chosen voice, as a role and never an id',
        () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.speak('تمام، الأكلة منشورة');

      expect(t.asked, hasLength(1));
      expect(t.asked.single.line, 'تمام، الأكلة منشورة');
      expect(t.asked.single.voice, 'female');
      // The ids live in the Edge Function. If one ever appears here, the app can
      // choose a voice and therefore choose what Kafoo is billed for.
      expect(t.asked.single.voice.length, lessThan(12));
    });

    test('choosing the male voice changes what is asked for, and persists',
        () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.setRole(AssistantVoiceRole.male);
      await t.speech.speak('أيوة');

      expect(t.asked.single.voice, 'male');

      final again = build();
      await again.speech.initialize();
      expect(
        again.speech.role,
        AssistantVoiceRole.male,
        reason:
            'the voice reverted on the next launch — §10.11 says it persists',
      );
    });

    test('a repeated line is bought once', () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.speak('تمام');
      await t.speech.speak('تمام');
      await t.speech.speak('تمام');

      expect(
        t.asked,
        hasLength(1),
        reason: 'the same sentence was billed three times',
      );
    });

    test('the same line in the other voice IS bought again', () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.speak('تمام');
      await t.speech.setRole(AssistantVoiceRole.male);
      await t.speech.speak('تمام');

      expect(t.asked.map((a) => a.voice), ['female', 'male']);
    });

    test('a muted assistant sends nothing at all', () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.setMuted(muted: true);
      await t.speech.speak('تمام');

      expect(t.asked, isEmpty, reason: 'muted, and it still spent money');
      expect(t.fallback.spoken, isEmpty);
    });

    test('an empty line is never sent', () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.speak('');
      expect(t.asked, isEmpty);
    });
  });

  group('when the paid voice cannot speak, the device voice does', () {
    test('a failed request falls back rather than going quiet', () async {
      final t = build(respond: (line, voice) => null);
      await t.speech.initialize();
      await t.speech.speak('تمام، الأكلة منشورة');

      expect(
        t.fallback.spoken.map((s) => s.line),
        ['تمام، الأكلة منشورة'],
        reason: 'the Cook heard nothing — silence is never silent about itself',
      );
    });

    test('an empty body counts as a failure, not as silence', () async {
      final t = build(respond: (line, voice) => Uint8List(0));
      await t.speech.initialize();
      await t.speech.speak('أيوة');
      expect(t.fallback.spoken, hasLength(1));
    });

    test('a thrown error falls back too', () async {
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => throw StateError('no client'),
        playAudio: (bytes, volume) async {},
        stopAudio: () async {},
      );
      await speech.initialize();
      await speech.speak('أيوة');

      expect(fallback.spoken, hasLength(1));
    });

    test('a failure is not cached — the next line tries again', () async {
      var calls = 0;
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async {
          calls++;
          return calls == 1 ? null : audio(2);
        },
        playAudio: (bytes, volume) async {},
        stopAudio: () async {},
      );
      await speech.initialize();
      await speech.speak('تمام');
      await speech.speak('تمام');

      expect(calls, 2, reason: 'a blip permanently silenced that sentence');
    });

    test('quiet is carried into the fallback — money stays quiet either way',
        () async {
      final t = build(respond: (line, voice) => null);
      await t.speech.initialize();
      await t.speech.speak('مية وعشرين جنيه', quiet: true);

      expect(t.fallback.spoken.single.quiet, isTrue);
    });

    test('muting reaches the fallback, or a mute leaks when the network drops',
        () async {
      final t = build(respond: (line, voice) => null);
      await t.speech.initialize();
      await t.speech.setMuted(muted: true);

      expect(t.fallback.isMuted, isTrue);
    });
  });

  group('the assistant must not talk into a live microphone', () {
    test('a line hushed while its audio is in flight is discarded', () async {
      // THE BUG THREE REVIEWERS FOUND ON #461. The paid voice fetches over the
      // network before playing, so hushing mid-fetch stopped nothing — there was
      // nothing playing yet — and the audio arrived afterwards, into a
      // microphone that had since opened.
      final release = Completer<Uint8List?>();
      final played = <Uint8List>[];
      final speech = HostedSpeechOutput(
        fallback: FakeSpeechOutput(),
        fetchAudio: (line, voice) => release.future,
        playAudio: (bytes, volume) async => played.add(bytes),
        stopAudio: () async {},
      );
      await speech.initialize();

      final speaking = speech.speak('تمام، الأكلة منشورة');
      await speech.stop(); // she tapped the microphone
      release.complete(Uint8List.fromList([1, 2, 3]));
      await speaking;

      expect(
        played,
        isEmpty,
        reason: 'the sentence played after the microphone opened',
      );
    });

    test('a stalled network falls back inside the budget, never hangs',
        () async {
      // Silent AND still is the one thing a voice flow may never be. Without a
      // timeout a dropping connection leaves the app doing nothing, forever.
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) => Completer<Uint8List?>().future,
        playAudio: (bytes, volume) async {},
        stopAudio: () async {},
      );
      await speech.initialize();

      await speech.speak('أيوة').timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail('speak never returned — the app hung'),
          );

      expect(fallback.spoken, hasLength(1));
    });

    test('a stalled PLAYBACK falls back too, not just a stalled fetch',
        () async {
      // The fetch timeout was half a fix: the bytes are local by then, and a
      // platform audio call that never returns is the same silent-and-still
      // failure one step later.
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) => Completer<void>().future,
        stopAudio: () async {},
      );
      await speech.initialize();

      await speech.speak('تمام').timeout(
            const Duration(seconds: 10),
            onTimeout: () => fail('speak never returned — the app hung'),
          );

      expect(fallback.spoken, hasLength(1));
    });

    test('a playback that resolves AFTER its timeout never doubles up',
        () async {
      // A timeout stops waiting, not the call. If the abandoned play starts a
      // moment later it lands on top of the machine voice already talking.
      final played = <Uint8List>[];
      var stops = 0;
      final release = Completer<void>();
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) async {
          await release.future;
          played.add(bytes);
        },
        stopAudio: () async => stops++,
      );
      await speech.initialize();

      await speech.speak('تمام');
      expect(fallback.spoken, hasLength(1), reason: 'no fallback after stall');
      expect(stops, greaterThan(0),
          reason: 'the abandoned playback was never silenced');

      release.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test('a hush during a stalled playback stops the fallback speaking too',
        () async {
      final fallback = FakeSpeechOutput();
      late HostedSpeechOutput speech;
      speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) async {
          // She taps the microphone while playback is stalling.
          await speech.stop();
          await Completer<void>().future;
        },
        stopAudio: () async {},
      );
      await speech.initialize();

      await speech.speak('تمام');

      expect(
        fallback.spoken,
        isEmpty,
        reason: 'the machine voice spoke after she opened the microphone',
      );
    });

    test('the whole failure path stays inside the voice budget', () async {
      expect(
        HostedSpeechOutput.worstCaseBeforeAnyVoice,
        lessThan(const Duration(seconds: 2)),
        reason: 'only the founder may raise a budget',
      );
    });

    test('speaking stops whatever is already being said, both voices',
        () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.speak('الأولى');
      await t.speech.speak('التانية');

      expect(
        t.fallback.stopped,
        isTrue,
        reason: 'the fallback engine was left talking under the new line',
      );
    });
  });

  group('what a screen is told', () {
    test('the accent is Cairene, not whatever the handset installed', () async {
      final t = build();
      await t.speech.initialize();
      expect(t.speech.voiceMatch, SpeechVoiceMatch.exact);
    });

    test('it can speak even on a handset with no Arabic voice data', () async {
      // The paid voice does not depend on the handset having Arabic installed,
      // which is the whole reason it is worth paying for.
      final t = build(fallbackMatch: SpeechVoiceMatch.none);
      await t.speech.initialize();
      expect(t.speech.canSpeak, isTrue);
    });

    test('stopping stops the fallback as well', () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.stop();
      expect(t.fallback.stopped, isTrue);
    });
  });
}
