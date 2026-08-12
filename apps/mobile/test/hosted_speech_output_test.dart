import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/hosted_speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/voice_clip_store.dart';
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
    test('Ahmad is the voice a Cook hears until she chooses otherwise',
        () async {
      // Founder's decision, 2026-08-12, made by ear on a handset. It is not a
      // preference one person set for themselves: §10.11's chooser does not
      // exist, so this is the voice EVERY Cook gets.
      final t = build();
      await t.speech.initialize();
      expect(t.speech.role, AssistantVoiceRole.male);
    });

    test('a stored value that is neither name falls back to the default',
        () async {
      // Not hypothetical the day a default changes. Written as "is it male,
      // else female", an unreadable value resolved to whichever voice sat on
      // the else branch — so changing the default silently changed what a
      // corrupted preference meant, on handsets nobody could see.
      SharedPreferences.setMockInitialValues(
        {HostedSpeechOutput.voicePreferenceKey: 'ghozlan'},
      );
      final t = build();
      await t.speech.initialize();
      expect(t.speech.role, AssistantVoiceRole.defaultRole);
    });

    test('a Cook who chose Ghozlan keeps Ghozlan across the default changing',
        () async {
      // The half that matters more than the default itself: §10.11 says the
      // choice persists until changed and never switches on its own. Shipping a
      // new default must not reach past somebody who already answered.
      SharedPreferences.setMockInitialValues(
        {HostedSpeechOutput.voicePreferenceKey: 'female'},
      );
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
      expect(t.asked.single.voice, 'male');
      // The ids live in the Edge Function. If one ever appears here, the app can
      // choose a voice and therefore choose what Kafoo is billed for.
      expect(t.asked.single.voice.length, lessThan(12));
    });

    test('choosing the other voice changes what is asked for, and persists',
        () async {
      final t = build();
      await t.speech.initialize();
      await t.speech.setRole(AssistantVoiceRole.female);
      await t.speech.speak('أيوة');

      expect(t.asked.single.voice, 'female');

      final again = build();
      await again.speech.initialize();
      expect(
        again.speech.role,
        AssistantVoiceRole.female,
        reason:
            'the voice reverted on the next launch — §10.11 says it persists',
      );
    });

    test('choosing the voice that is ALREADY the default is still stored',
        () async {
      // §10.11: the choice persists until changed and never switches on its
      // own. setRole used to return early when the role was unchanged, so a
      // Cook who deliberately picked today's default stored nothing — and the
      // next change of default would move her silently, which is exactly what
      // "never switches on its own" forbids. Invisible until a default changes,
      // and one just did.
      final t = build();
      await t.speech.initialize();
      await t.speech.setRole(AssistantVoiceRole.defaultRole);

      expect(
        SharedPreferences.getInstance().then(
          (p) => p.getString(HostedSpeechOutput.voicePreferenceKey),
        ),
        completion(AssistantVoiceRole.defaultRole.wireName),
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
      await t.speech.setRole(AssistantVoiceRole.female);
      await t.speech.speak('تمام');

      expect(t.asked.map((a) => a.voice), ['male', 'female']);
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
      //
      // **THIS TEST HAS BEEN VACUOUS TWICE, and the second time is the more
      // interesting one.** The first version asserted a stop was CALLED, never
      // that the audio stayed silent. The second modelled suppression — but
      // `speak` silences BEFORE it fetches, so the flag was already set before
      // playback was ever attempted, and the test passed with the actual fix
      // deleted. Found by tracing the counterfactual, which is the only way to
      // catch a test that agrees with you.
      //
      // So suppression is now gated on a stop that arrives AFTER a play has
      // genuinely begun. The leading silence cannot satisfy it.
      var playStarted = false;
      var suppressedAfterPlayBegan = false;
      final played = <Uint8List>[];
      final release = Completer<void>();
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) async {
          playStarted = true;
          await release.future;
          if (suppressedAfterPlayBegan) return;
          played.add(bytes);
        },
        stopAudio: () async {
          if (playStarted) suppressedAfterPlayBegan = true;
        },
      );
      await speech.initialize();

      await speech.speak('تمام');
      expect(fallback.spoken, hasLength(1), reason: 'no fallback after stall');

      release.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        played,
        isEmpty,
        reason: 'the abandoned line played on top of the machine voice',
      );
    });

    test('a stop that stalls neither hangs nor skips silencing the fallback',
        () async {
      // Sequenced, a native stop that never returned meant the fallback engine
      // was never told to stop at all — so an old machine-voice sentence could
      // keep talking under a new one. They run together now.
      final fallback = FakeSpeechOutput();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) => Completer<void>().future,
        stopAudio: () => Completer<void>().future,
      );
      await speech.initialize();

      final started = DateTime.now();
      await speech.speak('تمام').timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('speak never returned — the app hung'),
          );
      final elapsed = DateTime.now().difference(started);

      expect(fallback.spoken, hasLength(1));
      expect(
        fallback.stopped,
        isTrue,
        reason: 'a hung native stop skipped silencing the machine voice',
      );
      // Budget-relevant rather than a loose ceiling: a regression that made the
      // bounds compound instead of staying independent would show up here.
      expect(
        elapsed,
        lessThan(HostedSpeechOutput.worstCaseBeforeAnyVoice +
            const Duration(milliseconds: 500)),
      );
    });

    test('the microphone gate is NOT bounded — it waits for a real stop',
        () async {
      // `hush()` calls stop(), and the conversation awaits it before opening the
      // microphone. Bounding it made the guarantee a hope: on a slow handset the
      // microphone opened while a stop was still in progress. It waits now.
      final fallback = FakeSpeechOutput();
      final stopping = Completer<void>();
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => null,
        playAudio: (bytes, volume) async {},
        stopAudio: () => stopping.future,
      );
      await speech.initialize();

      // **PAST THE BOUND, NOT INSIDE IT.** This waited 50 ms, and at 50 ms the
      // call has not returned whether the gate is bounded or not — so the
      // assertion held with the fix deleted. Only a stall that OUTLIVES
      // `stopBound` tells the two apart, and taking the figure from the class
      // means it cannot drift apart from it.
      var returned = false;
      unawaited(speech.stop().then((_) => returned = true));
      await Future<void>.delayed(
        HostedSpeechOutput.stopBound + const Duration(milliseconds: 100),
      );

      expect(
        returned,
        isFalse,
        reason: 'stop gave up early — the microphone could open mid-stop',
      );

      stopping.complete();
      await Future<void>.delayed(Duration.zero);
      expect(returned, isTrue);
    });

    test('an EXTERNAL hush mid-playback is not undone by the fallback',
        () async {
      // The Cook taps the microphone while the assistant is mid-sentence. That
      // is a different path from the internal timeout: the stop arrives from
      // outside, after playback has genuinely begun.
      //
      // Restored rather than inferred. The round-five edit replaced this
      // scenario with the internal-timeout one and left this covered only by
      // hand-tracing the generation counter — and hand-tracing this file has
      // been wrong three times.
      final fallback = FakeSpeechOutput();
      var playing = false;
      final speech = HostedSpeechOutput(
        fallback: fallback,
        fetchAudio: (line, voice) async => Uint8List.fromList([1, 2, 3]),
        playAudio: (bytes, volume) {
          playing = true;
          return Completer<void>().future;
        },
        stopAudio: () async {},
      );
      await speech.initialize();

      unawaited(speech.speak('تمام'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(playing, isTrue, reason: 'playback never started — test is moot');

      // She taps. The assistant must not finish the abandoned sentence in the
      // machine voice a moment later.
      await speech.stop();
      await Future<void>.delayed(
        HostedSpeechOutput.worstCaseBeforeAnyVoice +
            const Duration(milliseconds: 200),
      );

      expect(
        fallback.spoken,
        isEmpty,
        reason: 'the hushed line came back in the machine voice',
      );
    });

    test('a sentence Kafoo already owns is never bought again', () async {
      // The 36 bundled sentences. If this ever regresses, nothing looks broken:
      // the Cook still hears Ghozlan, and Kafoo silently pays for every fixed
      // line on every launch — which is the bill this whole seam exists to end.
      final temp = Directory.systemTemp.createTempSync('kafoo_owned');
      addTearDown(() => temp.deleteSync(recursive: true));
      const line = 'تمام، شلتها من المنيو.';
      final name = VoiceClipStore.nameFor(line);
      final voice = AssistantVoiceRole.defaultRole.wireName;

      final asked = <String>[];
      final played = <Uint8List>[];
      final speech = HostedSpeechOutput(
        fallback: FakeSpeechOutput(),
        clips: VoiceClipStore(
          loadAsset: (key) async => key == 'assets/voice/$voice/$name.mp3'
              ? ByteData.view(audio(7).buffer)
              : throw Exception('not bundled'),
          cacheDirectory: () async => temp,
        ),
        fetchAudio: (l, v) async {
          asked.add(l);
          return audio(1);
        },
        playAudio: (bytes, volume) async => played.add(bytes),
        stopAudio: () async {},
      );
      await speech.initialize();
      await speech.speak(line);

      expect(asked, isEmpty, reason: 'a bundled sentence went to the network');
      expect(played.single, equals(audio(7)));
    });

    test('a sentence that HAD to be bought is kept for the next launch',
        () async {
      // The Meal-list greeting — the one sentence carrying a Cook's own counts,
      // so the one sentence that cannot be bundled. Before this, it was re-bought
      // every single time she opened Kafoo.
      final temp = Directory.systemTemp.createTempSync('kafoo_bought');
      addTearDown(() => temp.deleteSync(recursive: true));
      const greeting = 'عندك تلات أكلات، منهم واحدة على المنيو.';
      final voice = AssistantVoiceRole.defaultRole.wireName;
      final clips = VoiceClipStore(
        loadAsset: (_) async => throw Exception('not bundled'),
        cacheDirectory: () async => temp,
      );

      var purchases = 0;
      final speech = HostedSpeechOutput(
        fallback: FakeSpeechOutput(),
        clips: clips,
        fetchAudio: (l, v) async {
          purchases++;
          return audio(3);
        },
        playAudio: (bytes, volume) async {},
        stopAudio: () async {},
      );
      await speech.initialize();
      await speech.speak(greeting);
      expect(purchases, 1);

      // The write is deliberately not awaited inside speak, so that the Cook is
      // never made to wait on bookkeeping. Give it the turn it needs.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await clips.read(greeting, voice), equals(audio(3)));
    });

    test('the whole failure path stays inside the voice budget', () async {
      expect(
        HostedSpeechOutput.worstCaseBeforeAnyVoice,
        // RAISED FROM 2 s BY THE FOUNDER ON 2026-08-12, and the reason is
        // recorded here because a number nobody can explain is a number the
        // next person quietly lowers again. The 1000 ms fetch wait this sum was
        // built around was never measured against ElevenLabs; the first
        // measurement was 1064, 1070 and 2612 ms, so the paid voice he had just
        // bought lost every race and the Cook always heard the machine.
        //
        // The 2 s budget still governs the path that works — a successful fetch
        // speaks at about 1.1 s. This ceiling bounds only the broken path.
        lessThan(const Duration(seconds: 4)),
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
