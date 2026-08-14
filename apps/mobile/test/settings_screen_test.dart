import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/hosted_speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output.dart';
import 'package:kafoo_mobile/features/conversation/data/speech_output_provider.dart';
import 'package:kafoo_mobile/features/settings/presentation/settings_screen.dart';
import 'package:kafoo_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SETTINGS, AND THE CHOICE THAT EXISTED EVERYWHERE EXCEPT ON A SCREEN.
///
/// Kafoo bought two Cairene voices on 2026-08-11, stored a preference for them,
/// and taught `speak` to take a role. No screen ever offered the choice, so
/// every Cook heard whichever one was the default — a feature complete in every
/// layer but the one a person can reach.
///
/// [FakeSpeechOutput] reports itself as unable to choose, the same way the
/// device engine does, so a test that wants the chooser has to say so. That is
/// deliberate: the chooser must be absent when there is only one voice, and a
/// fake that always offered it could not prove that.
FakeSpeechOutput _twoVoices() => FakeSpeechOutput()..hasVoiceChoice = true;

Widget _app(SpeechOutput speech) => ProviderScope(
      overrides: [speechOutputProvider.overrideWithValue(speech)],
      child: const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('ar'), Locale('en')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SettingsScreen(),
      ),
    );

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('ar'));
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the screen that decides how the assistant sounds speaks first',
      (tester) async {
    final speech = _twoVoices();
    await tester.pumpWidget(_app(speech));
    await tester.pumpAndSettle();

    expect(
      speech.spoken.map((s) => s.line),
      contains(l10n.settingsVoiceQuestion),
      reason: 'A silent screen about the voice is the one place silence is '
          'least defensible.',
    );
  });

  testWidgets('both voices are offered, and the chosen one is marked',
      (tester) async {
    final speech = _twoVoices();
    await tester.pumpWidget(_app(speech));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsVoiceFemale), findsWidgets);
    expect(find.text(l10n.settingsVoiceMale), findsWidgets);
    // The glance word appears exactly once: on the card that is chosen.
    expect(find.text(l10n.settingsVoiceChosen), findsOneWidget);
  });

  testWidgets('choosing a voice stores it and says a line in it',
      (tester) async {
    final speech = _twoVoices();
    await tester.pumpWidget(_app(speech));
    await tester.pumpAndSettle();

    // The default is the male voice, so the female card is the one to choose.
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.settingsVoiceFemale),
    );
    await tester.pumpAndSettle();

    expect(speech.voice, AssistantVoiceRole.female);
    expect(
      speech.spoken.map((s) => s.line),
      contains(l10n.settingsVoicePreview),
      reason: 'A choice whose effect is only audible on the next screen is a '
          'choice made blind.',
    );
    expect(find.text(l10n.settingsVoiceChosen), findsOneWidget);
  });

  testWidgets('hearing a voice does NOT choose it', (tester) async {
    // §10.11: the voice never switches on its own. A preview that quietly
    // committed her would be the app changing it for her — the exact thing the
    // rule forbids, and the easiest bug to write here.
    final speech = _twoVoices();
    await tester.pumpWidget(_app(speech));
    await tester.pumpAndSettle();
    final before = speech.voice;

    await tester.tap(
      find
          .widgetWithText(OutlinedButton, l10n.settingsVoiceHear('other'))
          .first,
    );
    await tester.pumpAndSettle();

    expect(speech.voice, before);
    expect(
      speech.spoken.map((s) => s.line),
      contains(l10n.settingsVoicePreview),
      reason: 'It still has to be heard — that is what the control is for.',
    );
  });

  testWidgets('an engine with one voice says so instead of drawing a chooser',
      (tester) async {
    // The device's own engine has whatever the platform gave it. A chooser over
    // one voice is a control that does nothing, which the design forbids more
    // strongly than it forbids an absent control.
    await tester.pumpWidget(_app(FakeSpeechOutput()));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsVoiceUnavailable), findsOneWidget);
    expect(find.text(l10n.settingsVoiceChosen), findsNothing);
  });

  testWidgets('the search-consent switch is still here and still one switch',
      (tester) async {
    await tester.pumpWidget(_app(FakeSpeechOutput()));
    await tester.pumpAndSettle();

    expect(find.text(l10n.settingsSearchTitle), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
