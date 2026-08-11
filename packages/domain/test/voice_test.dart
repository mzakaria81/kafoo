import 'package:kafoo_domain/voice.dart';
import 'package:test/test.dart';

/// The nine voice states and the eleven glance words — `DESIGN.md` §10.2, §10.4
/// and §10.12.
///
/// **These tests exist to make two rules mechanical rather than remembered.**
///
/// The first: a state is not implemented until it says what happens on all
/// three channels — drawn, spoken, felt. §10.1's fourth principle is that every
/// state reaches the user three ways and any one alone suffices, and §10.2 says
/// plainly that "a state missing its spoken line is not implemented."
///
/// The second, and it is the subtler one: **several states are deliberately
/// silent, so the rule cannot be "every state speaks."** Listening is silent
/// because the person is talking and speaking over them would be the defect.
/// The enforceable version is that silence must be *declared, with its reason* —
/// you cannot arrive at silence by forgetting.
void main() {
  group('every state declares all three channels', () {
    test('all nine states are in the table — a tenth cannot hide', () {
      expect(VoiceState.values.length, 9);
      for (final state in VoiceState.values) {
        expect(
          voiceStates[state],
          isNotNull,
          reason: '${state.name} has no declared announcement',
        );
      }
    });

    test('the table declares nothing that is not a state', () {
      expect(voiceStates.length, VoiceState.values.length);
    });

    test('silence always carries a reason — you cannot forget your way to it',
        () {
      for (final entry in voiceStates.entries) {
        final spoken = entry.value.spoken;
        if (spoken is Silent) {
          expect(
            spoken.because.trim(),
            isNotEmpty,
            reason: '${entry.key.name} is silent for no stated reason',
          );
        }
      }
    });

    test('a spoken line names an ARB key, never display text', () {
      for (final entry in voiceStates.entries) {
        final spoken = entry.value.spoken;
        if (spoken is Says) {
          // An ARB key, so it is lowerCamelCase and carries no spaces and no
          // Arabic. A literal sentence here would be a hardcoded user-facing
          // string, which CLAUDE.md forbids outright.
          expect(
            RegExp(r'^spoken[A-Z][A-Za-z0-9]*$').hasMatch(spoken.lineKey),
            isTrue,
            reason: '${entry.key.name} has line key "${spoken.lineKey}"',
          );
        }
      }
    });
  });

  group('the states match §10.2, line by line', () {
    test('idle invites, and does not buzz — nothing has happened yet', () {
      final idle = voiceStates[VoiceState.idle]!;
      expect(idle.spoken, isA<Says>());
      expect(idle.haptic, Haptic.none);
    });

    test('listening is silent, and buzzes once at the start', () {
      final listening = voiceStates[VoiceState.listening]!;
      expect(listening.spoken, isA<Silent>());
      expect(listening.haptic, Haptic.shortPulse);
    });

    test('thinking speaks only after a wait, and never buzzes', () {
      final thinking = voiceStates[VoiceState.thinking]!;
      expect(thinking.spoken, isA<Silent>());
      expect(thinking.haptic, Haptic.none);
      // The «لسه معاك، ثانية.» line is a *later* event, not this state's line.
      expect(thinking.spokenAfter, isA<Says>());
      expect(thinking.speakAfter, const Duration(seconds: 2));
    });

    test('speaking buzzes twice BEFORE it speaks', () {
      final speaking = voiceStates[VoiceState.speaking]!;
      expect(speaking.spoken, isA<Says>());
      expect(speaking.haptic, Haptic.twoShortPulses);
    });

    test('didNotCatch apologises once and buzzes long', () {
      final s = voiceStates[VoiceState.didNotCatch]!;
      expect(s.spoken, isA<Says>());
      expect(s.haptic, Haptic.longPulse);
    });

    test('correcting always repeats the new value aloud', () {
      final s = voiceStates[VoiceState.correcting]!;
      expect(s.spoken, isA<Says>());
      expect(s.haptic, Haptic.twoShortPulses);
    });

    test('interrupted says nothing at all — no message, §10.2', () {
      final s = voiceStates[VoiceState.interrupted]!;
      expect(s.spoken, isA<Silent>());
      expect(s.haptic, Haptic.shortPulse);
    });

    test('offline and tooNoisy both speak and both buzz long', () {
      for (final state in [VoiceState.offline, VoiceState.tooNoisy]) {
        expect(voiceStates[state]!.spoken, isA<Says>());
        expect(voiceStates[state]!.haptic, Haptic.longPulse);
      }
    });
  });

  group('the offline state may not promise what the phone cannot deliver', () {
    test('offline has a second line for when nothing was transcribed', () {
      // business-rules.md, Privacy: «محفوظ» must never be said over words that
      // were not captured. On a handset with no `ar-EG` there is no transcript
      // to queue, because the thing that makes transcripts needs the network
      // that just went away. Two lines, not one.
      final offline = voiceStates[VoiceState.offline]!;
      expect(offline.spoken, isA<Says>());
      expect(offline.spokenAlternative, isA<Says>());
      expect(
        (offline.spoken as Says).lineKey,
        isNot((offline.spokenAlternative! as Says).lineKey),
      );
    });
  });

  group('glance words are a closed set — §10.4 and §10.12', () {
    test('there are exactly eleven', () {
      expect(GlanceWord.values.length, 11);
    });

    test('every one has an ARB key, so none is a literal in a widget', () {
      for (final word in GlanceWord.values) {
        expect(
          RegExp(r'^glance[A-Z][A-Za-z0-9]*$').hasMatch(word.lineKey),
          isTrue,
          reason: '${word.name} has line key "${word.lineKey}"',
        );
      }
    });

    test('each carries a meaning colour, so the word need not be read', () {
      // §10.4: "Colour must carry the same meaning as the word, redundantly —
      // if the word is not read, the colour alone must land."
      for (final word in GlanceWord.values) {
        expect(word.meaning, isNotNull);
      }
    });

    test('the eleven are the ones §10.4 and §10.12 name, and no others', () {
      expect(
        GlanceWord.values.map((w) => w.name).toSet(),
        {
          'published',
          'draft',
          'unavailable',
          'archived',
          'newOrder',
          'arrived',
          'cancelled',
          'saved',
          'noNetwork',
          'sent',
          'read',
        },
      );
    });
  });
}
