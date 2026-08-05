import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/analytics/emit_event.dart';
import 'package:kafoo_mobile/features/analytics/event_names.dart';
import 'package:kafoo_mobile/features/conversation/application/voice_input.dart';
import 'package:kafoo_mobile/features/conversation/presentation/conversation_question.dart';
import 'package:kafoo_mobile/features/kitchen_profile/presentation/conversation.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
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

Widget _testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  group('VoiceInput locale resolution', () {
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
      final repo = FakeKitchenProfileRepository();
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_EG', 'Arabic (Egypt)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          repository: repo,
          pickPhoto: () async => null,
          voiceInput: voice,
        ),
      ));
      await tester.pumpAndSettle();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.exact));
      expect(voice.resolvedLocaleId, equals('ar_EG'));
      expect(find.byIcon(Icons.mic), findsOneWidget);

      final attributes = conversationStarted();
      expect(attributes['speech_locale'], equals('ar_EG'));
      expect(attributes['input'], equals('voice'));
    });

    testWidgets('voice available with ar-SA only records the fallback locale',
        (tester) async {
      final repo = FakeKitchenProfileRepository();
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('ar_SA', 'Arabic (Saudi Arabia)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          repository: repo,
          pickPhoto: () async => null,
          voiceInput: voice,
        ),
      ));
      await tester.pumpAndSettle();

      expect(voice.localeMatch, equals(VoiceLocaleMatch.fallback));
      expect(voice.resolvedLocaleId, equals('ar_SA'));
      expect(find.byIcon(Icons.mic), findsOneWidget);

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
      final repo = FakeKitchenProfileRepository();
      final fakeSpeech = FakeSpeechToText(
        availableLocales: [
          LocaleName('en_US', 'English (US)'),
        ],
      );
      final voice = VoiceInput(speech: fakeSpeech);

      await tester.pumpWidget(_testApp(
        KitchenConversationScreen(
          repository: repo,
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
      // No mic button — the conversation survives by offering typing.
      expect(find.byIcon(Icons.mic), findsNothing);
      // The text field is still present so the Cook can type.
      expect(find.byType(TextField), findsOneWidget);

      // Answering by typing still works — the conversation must not regress.
      await tester.enterText(find.byType(TextField), 'مطبخ بيتي');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationQuestion), findsOneWidget);
    });
  });
}
