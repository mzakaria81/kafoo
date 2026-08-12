import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/voice_clip_store.dart';
import 'package:kafoo_mobile/l10n/app_localizations_ar.dart';

/// **THE POINT OF THIS FILE IS THE FIRST GROUP, AND IT GUARDS A FAILURE THAT
/// WOULD BE COMPLETELY INVISIBLE.**
///
/// A bundled clip is found by hashing the sentence the app is about to say. If
/// the Arabic that reaches [VoiceClipStore] differs from the Arabic the
/// generator hashed by so much as one trailing space, every lookup misses —
/// and nothing breaks. The Cook still hears a Cairene voice, because the app
/// quietly buys all 36 sentences from the provider instead, every launch,
/// forever.
/// The 3.5 MB of clips ride along in the app doing nothing. No error, no
/// failing assertion, no symptom on any screen: just the bill this whole
/// change exists to remove, back again.
///
/// So the test does not compare the ARB file against the assets — that would
/// pass while the app was still missing. It calls the **real generated
/// localization getters**, the ones the screens call, and asks whether what
/// comes out is a sentence Kafoo already owns.
void main() {
  final ar = AppLocalizationsAr();

  // ADR-0010: every line addressed to a Cook exists in two grammars and both
  // are bought. A line that does not inflect is one sentence, not two.
  const forms = ['feminine', 'other'];

  /// Exactly what the generator writes, and what the app reads at runtime.
  File clip(String line, String voice) =>
      File('assets/voice/$voice/${VoiceClipStore.nameFor(line)}.mp3');

  void expectOwned(String label, String line) {
    for (final voice in ['female', 'male']) {
      final file = clip(line, voice);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Kafoo will re-buy «$line» ($label, $voice voice) on every '
            'launch. Either the Arabic changed and the clips were not '
            'regenerated, or what reaches VoiceClipStore is not byte-for-byte '
            'what the generator hashed. Regenerate with '
            'scripts/generate-voice-clips.ts.',
      );
      expect(file.lengthSync(), greaterThan(0), reason: 'empty clip: $line');
    }
  }

  group('every fixed sentence Kafoo says is already paid for', () {
    test('the sentences said today, by the Meal list and its row sheet', () {
      expectOwned('taken off menu', ar.mealSpokenTakenOffMenu);
      expectOwned('back on menu', ar.mealSpokenBackOnMenu);
      expectOwned('draft deleted', ar.mealSpokenDraftDeleted);
      expectOwned('retired', ar.mealSpokenRetired);
      // Read back in full before «أيوة». An irreversible action's gate is the
      // worst possible place to drop to the machine voice.
      expectOwned('retire warning', ar.mealRetireWarning);
      for (final form in forms) {
        expectOwned('last on offer ($form)', ar.mealLastOnOfferWarning(form));
        expectOwned('delete draft ($form)', ar.mealDeleteDraftWarning(form));
      }
    });

    test('the sentences said today, by the Meal conversation', () {
      expectOwned('dish', ar.mealConvPromptDish);
      expectOwned('photo', ar.mealConvPromptPhoto);
      for (final form in forms) {
        expectOwned('description ($form)', ar.mealConvPromptDescription(form));
        expectOwned('price ($form)', ar.mealConvPromptPrice(form));
      }
    });

    test('the sentences written to be spoken by screens that are still silent',
        () {
      // Bundled ahead of the screens that will say them — founder's decision,
      // 2026-08-12 — so that giving those screens a voice costs nothing later.
      expectOwned('cuisine', ar.mealConvPromptCuisine);
      expectOwned('category', ar.mealConvPromptCategory);
      expectOwned('kitchen name', ar.kitchenConvPromptDisplayName);
      expectOwned('delivery', ar.kitchenConvPromptDeliveryTerms);
      expectOwned('address form', ar.kitchenConvPromptAddressForm);
      for (final form in forms) {
        expectOwned('empty list ($form)', ar.myMealsEmptySpoken(form));
        expectOwned('story ($form)', ar.kitchenConvPromptStory(form));
        expectOwned('area ($form)', ar.kitchenConvPromptArea(form));
        expectOwned('kitchen save ($form)', ar.kitchenConvSummaryConfirm(form));
        expectOwned('publish ($form)', ar.mealSummaryConfirm(form));
        expectOwned('estimates ($form)', ar.mealSummaryEstimatesNotice(form));
        expectOwned('no estimates ($form)', ar.mealSummaryNoEstimates(form));
        expectOwned('ai unavailable ($form)', ar.aiPromptNotStubbed(form));
      }
    });

    test('the ONE sentence that carries a Cook\'s numbers is NOT bundled', () {
      // Not an oversight — the guard in the generator refuses it. Pre-rendering
      // every version costs more than a month's allowance for a Cook with
      // twenty Meals, so this one is bought and kept on disk instead. If it
      // ever appears in the bundle, something is shipping a clip that says the
      // wrong number aloud.
      final greeting = ar.myMealsSpokenSummary('feminine', 20, 16);
      expect(clip(greeting, 'female').existsSync(), isFalse);
    });
  });

  group('where a sentence\'s audio comes from', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('kafoo_clips'));
    tearDown(() => temp.deleteSync(recursive: true));

    VoiceClipStore store({Map<String, List<int>> bundle = const {}}) =>
        VoiceClipStore(
          loadAsset: (key) async {
            final bytes = bundle[key];
            // What rootBundle does for an asset that is not in the bundle.
            if (bytes == null) throw Exception('no asset $key');
            return ByteData.view(Uint8List.fromList(bytes).buffer);
          },
          cacheDirectory: () async => temp,
        );

    test('a bundled sentence is found without touching the network or disk',
        () async {
      const line = 'تمام، شلتها من المنيو.';
      final name = VoiceClipStore.nameFor(line);
      final clips = store(bundle: {
        'assets/voice/female/$name.mp3': [1, 2, 3]
      });

      expect(await clips.read(line, 'female'), equals([1, 2, 3]));
    });

    test('the same sentence in the other voice is a different clip', () async {
      const line = 'تمام، شلتها من المنيو.';
      final name = VoiceClipStore.nameFor(line);
      final clips = store(bundle: {
        'assets/voice/female/$name.mp3': [1]
      });

      expect(await clips.read(line, 'female'), isNotNull);
      expect(
        await clips.read(line, 'male'),
        isNull,
        reason: 'Ahmad and Ghozlan must never be served each other\'s audio',
      );
    });

    test('a sentence bought once survives the app closing', () async {
      const greeting = 'عندك 20 أكلة، منهم 16 على المنيو.';
      final clips = store();

      expect(await clips.read(greeting, 'female'), isNull);
      await clips.keep(greeting, 'female', Uint8List.fromList([9, 9]));

      // A different instance, because that is what the next launch is.
      expect(await store().read(greeting, 'female'), equals([9, 9]));
    });

    test('editing the Arabic misses rather than playing the old words',
        () async {
      const before = 'تمام، شلتها من المنيو.';
      const after = 'تمام، شيلتها من المنيو.';
      final clips = store();
      await clips.keep(before, 'female', Uint8List.fromList([1]));

      expect(
        await clips.read(after, 'female'),
        isNull,
        reason: 'a clip may go stale, but it must never be spoken after the '
            'words it was made from have changed',
      );
    });

    test('surrounding whitespace is not a different sentence', () async {
      // The generator trims; an ARB value with a trailing space must not send
      // every lookup to the provider.
      final clips = store();
      await clips.keep('تمام', 'female', Uint8List.fromList([7]));
      expect(await clips.read('  تمام ', 'female'), equals([7]));
    });

    test('a truncated write is refused rather than played as audio', () async {
      const line = 'تمام';
      final file = File(
        '${temp.path}/voice/female/${VoiceClipStore.nameFor(line)}.mp3',
      );
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(<int>[]);

      expect(await store().read(line, 'female'), isNull);
    });

    test('a handset with no writable directory still speaks', () async {
      // A web build, or a sandbox that refuses. Bundled clips must keep working
      // and nothing may throw into a screen.
      final clips = VoiceClipStore(
        loadAsset: (key) async => ByteData.view(Uint8List.fromList([4]).buffer),
        cacheDirectory: () async => throw const FileSystemException('no'),
      );

      expect(await clips.read('تمام', 'female'), equals([4]));
      await clips.keep('تمام', 'female', Uint8List.fromList([5]));
    });
  });
}
