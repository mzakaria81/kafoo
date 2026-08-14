import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ai/ai.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/kitchen_profile/application/kitchen_conversation_controller.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/features/meal/data/ai_provider.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:kafoo_ui/ui.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'support/fake_kitchen_profile_repository.dart';

/// A fake [SpeechToText] that can be configured with different locale lists.
class FakeSpeechToText implements SpeechToText {
  FakeSpeechToText({this.availableLocales = const []});

  final List<LocaleName> availableLocales;
  bool _initialized = false;
  bool _listening = false;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = const Duration(milliseconds: 2000),
    List<SpeechConfigOption>? options,
  }) async {
    _initialized = true;
    return true;
  }

  @override
  Future<List<LocaleName>> locales() async => availableLocales;

  @override
  bool get isAvailable => _initialized;

  @override
  bool get isListening => _listening;

  @override
  bool get isNotListening => !_listening;

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    _listening = true;
  }

  @override
  Future<void> stop() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  @override
  void changePauseFor(Duration pauseFor) {}

  // Unused members — stubbed because the interface requires them.
  @override
  String get lastRecognizedWords => '';

  @override
  String get lastStatus => '';

  @override
  double get lastSoundLevel => 0;

  @override
  SpeechRecognitionError? get lastError => null;

  @override
  bool get hasRecognized => false;

  @override
  bool get hasError => false;

  @override
  Future<bool> get hasPermission async => true;

  @override
  SpeechErrorListener? errorListener;

  @override
  SpeechStatusListener? statusListener;

  @override
  Future<LocaleName?> systemLocale() async =>
      availableLocales.isNotEmpty ? availableLocales.first : null;

  @override
  SpeechPhraseAggregator? unexpectedPhraseAggregator;
}

Widget _testApp(Widget child, {FakeKitchenProfileRepository? repo}) {
  return ProviderScope(
    overrides: [
      kitchenProfileRepositoryProvider
          .overrideWithValue(repo ?? FakeKitchenProfileRepository()),
      // Recorded rather than spoken. Left real the conversation reaches Kafoo's
      // `speak` function — and a paid provider — from a widget test.
      speechOutputProvider.overrideWithValue(FakeSpeechOutput()),
      aiProviderProvider.overrideWithValue(StubAiProvider(const {})),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  group('VoiceInput locale resolution', () {
    // THE DIFFERENCE THAT DECIDES WHICH SENTENCE A PERSON READS. A device with a
    // working recogniser and no Arabic is told to add Arabic in its settings; a
    // device with no recogniser at all is told voice does not work here. Both
    // used to produce the second message, which is why granting the microphone
    // permission and then being told voice does not work was the whole
    // experience the founder had.
    test(
        'a working recogniser with no Arabic is unavailable BUT engine-available',
        () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('en_US', 'English (US)'),
          LocaleName('fr_FR', 'French'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      final available = await voice.initialize();

      expect(available, isFalse,
          reason: 'no Arabic means no Arabic-first voice');
      expect(voice.engineAvailable, isTrue,
          reason:
              'the microphone and recogniser are fine — only the language is missing');
      expect(voice.localeMatch, equals(VoiceLocaleMatch.none));
    });

    test('no locales at all is still engine-available', () async {
      final voice = VoiceInput(speech: FakeSpeechToText());
      expect(await voice.initialize(), isFalse);
      expect(voice.engineAvailable, isTrue);
    });

    test('ar-EG on the device resolves to exact match', () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_EG', 'Arabic (Egypt)'),
          LocaleName('en_US', 'English (US)'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      final available = await voice.initialize();

      expect(available, isTrue);
      expect(voice.isAvailable, isTrue);
      expect(voice.localeMatch, equals(VoiceLocaleMatch.exact));
      expect(voice.resolvedLocaleId, equals('ar_EG'));
    });

    test('ar-EG with dash separator also resolves to exact match', () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar-EG', 'Arabic (Egypt)'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      await voice.initialize();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.exact));
      expect(voice.resolvedLocaleId, equals('ar-EG'));
    });

    test('ar_SA with no ar-EG resolves to fallback', () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_SA', 'Arabic (Saudi Arabia)'),
          LocaleName('en_US', 'English (US)'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      final available = await voice.initialize();

      expect(available, isTrue);
      expect(voice.isAvailable, isTrue);
      expect(voice.localeMatch, equals(VoiceLocaleMatch.fallback));
      expect(voice.resolvedLocaleId, equals('ar_SA'));
    });

    test('no Arabic locale resolves to none and isAvailable is false',
        () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('en_US', 'English (US)'),
          LocaleName('fr_FR', 'French (France)'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      final available = await voice.initialize();

      expect(available, isFalse);
      expect(voice.isAvailable, isFalse);
      expect(voice.localeMatch, equals(VoiceLocaleMatch.none));
      expect(voice.resolvedLocaleId, isNull);
    });

    test('empty locale list resolves to none and isAvailable is false',
        () async {
      final fake = FakeSpeechToText(availableLocales: const []);
      final voice = VoiceInput(speech: fake);
      final available = await voice.initialize();

      expect(available, isFalse);
      expect(voice.isAvailable, isFalse);
      expect(voice.localeMatch, equals(VoiceLocaleMatch.none));
      expect(voice.resolvedLocaleId, isNull);
    });

    test('case-insensitive matching accepts AR-eg', () async {
      final fake = FakeSpeechToText(
        availableLocales: [
          LocaleName('AR-eg', 'Arabic (Egypt)'),
        ],
      );
      final voice = VoiceInput(speech: fake);
      await voice.initialize();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.exact));
    });
  });

  group('ConversationStarted speech_locale attribute', () {
    // These assert the EMITTED EVENT, not the VoiceInput getters. An earlier version of this group
    // carried this name while only re-checking `voice.localeMatch`, which the unit tests above
    // already cover — so deleting `speech_locale` from the call site left the whole suite green.
    // A test group named after the thing it does not test is worse than no group: it answers a
    // grep. The recorder below is what makes the attribute observable at all.
    late List<({String name, Map<String, Object> attributes})> emitted;

    setUp(() {
      emitted = [];
      debugEventRecorder = (name, attributes) => emitted
          .add((name: name, attributes: Map<String, Object>.from(attributes)));
    });

    tearDown(() => debugEventRecorder = null);

    Map<String, Object> conversationStarted() => emitted
        .firstWhere((event) => event.name == EventNames.conversationStarted)
        .attributes;

    testWidgets('voice available with ar-EG records the locale id',
        (tester) async {
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_EG', 'Arabic (Egypt)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          pickPhoto: () async => null,
          voiceInput: voice,
        ),
      ));
      await tester.pumpAndSettle();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.exact));
      expect(voice.resolvedLocaleId, equals('ar_EG'));
      expect(find.byType(KafooTalkButton), findsOneWidget);

      final attributes = conversationStarted();
      expect(attributes['speech_locale'], equals('ar_EG'));
      expect(attributes['input'], equals('voice'));
    });

    testWidgets('voice available with ar-SA only records the fallback locale',
        (tester) async {
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_SA', 'Arabic (Saudi Arabia)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          pickPhoto: () async => null,
          voiceInput: voice,
        ),
      ));
      await tester.pumpAndSettle();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.fallback));
      expect(voice.resolvedLocaleId, equals('ar_SA'));
      expect(find.byType(KafooTalkButton), findsOneWidget);

      // The whole point of the attribute: this conversation is an Egyptian Cook being transcribed
      // by a model trained on another dialect, and it must be distinguishable from the exact case
      // in the data rather than only in the app's memory.
      final attributes = conversationStarted();
      expect(attributes['speech_locale'], equals('ar_SA'));
      expect(attributes['speech_locale'], isNot(equals('ar_EG')));
      expect(attributes['input'], equals('voice'));
    });

    testWidgets('no Arabic locale records none and shows typing fallback',
        (tester) async {
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('en_US', 'English (US)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          pickPhoto: () async => null,
          voiceInput: voice,
        ),
      ));
      await tester.pumpAndSettle();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.none));
      expect(voice.isAvailable, isFalse);
      expect(voice.resolvedLocaleId, isNull);

      final attributes = conversationStarted();
      expect(attributes['speech_locale'], equals('none'));
      expect(attributes['input'], equals('typed'));
      // THE ORB IS STILL DRAWN, and that is the 2026-08-14 fix rather than an
      // oversight. A missing on-device language pack says nothing about whether
      // a hosted conversation can hear her, and until that day it was the thing
      // deciding whether the orb existed at all.
      expect(find.byType(KafooTalkButton), findsOneWidget);

      // Typing is hers to ask for and is never a consequence of a handset
      // lacking a language pack, so the box is not on screen until she says so.
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kitchen-talk-type')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
