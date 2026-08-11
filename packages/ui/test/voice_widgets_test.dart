import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_ui/ui.dart';

Widget _host(Widget child, {double textScale = 1}) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: kafooTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );

void main() {
  group('KafooTalkButton', () {
    Widget orb({
      TalkOrbState state = TalkOrbState.idle,
      double amplitude = 0,
      VoidCallback? onStart,
      VoidCallback? onEnd,
    }) =>
        KafooTalkButton(
          state: state,
          amplitude: amplitude,
          label: 'دوسي واتكلمي',
          onPressStart: onStart ?? () {},
          onPressEnd: onEnd ?? () {},
        );

    testWidgets('is 88dp, not merely compliant', (tester) async {
      await tester.pumpWidget(_host(orb()));
      final size = tester.getSize(find.byType(AnimatedContainer));
      expect(size.width, KafooSpacing.talkButton);
      expect(size.height, KafooSpacing.talkButton);
      expect(size.width, greaterThan(KafooSpacing.minTapTarget));
    });

    testWidgets('acknowledges the press on pointer down, not on release',
        (tester) async {
      // The 150ms promise. Half a second of silence reads as "the button didn't
      // work", so the user presses again and cuts off their own speech — which
      // is why this fires before the finger lifts rather than after.
      var started = 0;
      var ended = 0;
      await tester.pumpWidget(
        _host(orb(onStart: () => started++, onEnd: () => ended++)),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Icon)));
      await tester.pump();
      expect(started, 1);
      expect(ended, 0, reason: 'nothing may wait for the release');

      await gesture.up();
      await tester.pump();
      expect(ended, 1);
    });

    testWidgets('a cancelled pointer still ends the recording', (tester) async {
      // A finger that slides off the orb, or a system gesture stealing the
      // pointer, must not leave the microphone open.
      var ended = 0;
      await tester.pumpWidget(_host(orb(onEnd: () => ended++)));
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Icon)));
      await gesture.cancel();
      await tester.pump();
      expect(ended, 1);
    });

    testWidgets('the bars move with the real level, not on their own',
        (tester) async {
      // A bar that animates while the microphone is muted or broken destroys
      // trust in every other state, so height must be a function of amplitude
      // and nothing else.
      // The middle bar, which reacts most.
      double middleBar() =>
          tester.getSize(find.byKey(amplitudeBarKey(2))).height;

      await tester.pumpWidget(
        _host(orb(state: TalkOrbState.listening, amplitude: 0)),
      );
      final quiet = middleBar();

      await tester.pumpWidget(
        _host(orb(state: TalkOrbState.listening, amplitude: 1)),
      );
      final loud = middleBar();

      expect(loud, greaterThan(quiet));

      // And a muted or broken microphone reports zero, so the bars sit still.
      // A bar that moves anyway is the one thing that would make every other
      // voice state untrustworthy.
      await tester.pumpWidget(
        _host(orb(state: TalkOrbState.listening, amplitude: 0)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(middleBar(), quiet);
    });

    test('only the recording states report a live microphone', () {
      // There is no silent listening in Kafoo, not even for a wake word.
      expect(
        TalkOrbState.values.where((s) => s.isRecording).toSet(),
        {TalkOrbState.listening, TalkOrbState.tooNoisy},
      );
    });

    testWidgets('does not clip at 200% text scale', (tester) async {
      await tester.pumpWidget(_host(orb(), textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('KafooMuteButton', () {
    testWidgets('meets the tap target and says what pressing will do',
        (tester) async {
      var muted = false;
      await tester.pumpWidget(
        _host(KafooMuteButton(
          muted: muted,
          label: 'اسكت صوت المساعد',
          onChanged: (v) => muted = v,
        )),
      );
      expect(
        tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(KafooSpacing.minTapTarget),
      );

      await tester.tap(find.byType(IconButton));
      expect(muted, isTrue);
    });
  });

  group('KafooConfirmationGate', () {
    Widget gate({VoidCallback? onYes, VoidCallback? onNo}) =>
        KafooConfirmationGate(
          spokenReadback: 'محشي ورق عنب بمية وعشرين جنيه، هينشر دلوقتي.',
          question: 'تنشر؟',
          confirmLabel: 'أيوة، انشريها',
          rejectLabel: 'لأ، استنى',
          footnote: 'لو مقولتيش حاجة، مفيش حاجة هتحصل.',
          amount: '١٢٠',
          amountUnit: 'جنيه',
          onConfirm: onYes ?? () {},
          onReject: onNo ?? () {},
        );

    testWidgets('silence never confirms', (tester) async {
      // No timer, no default, no auto-dismiss. Time passing must change
      // nothing at all — this pumps well past any plausible timeout.
      var confirmed = 0;
      var rejected = 0;
      await tester.pumpWidget(_host(gate(
        onYes: () => confirmed++,
        onNo: () => rejected++,
      )));

      await tester.pump(const Duration(minutes: 5));
      expect(confirmed, 0);
      expect(rejected, 0);
      expect(find.text('تنشر؟'), findsOneWidget);
    });

    testWidgets('the yes is bigger than the no, and both are unmissable',
        (tester) async {
      await tester.pumpWidget(_host(gate()));
      final yes = tester.getSize(find.widgetWithText(
        ElevatedButton,
        'أيوة، انشريها',
      ));
      final no = tester.getSize(find.widgetWithText(
        ElevatedButton,
        'لأ، استنى',
      ));

      expect(yes.height, greaterThanOrEqualTo(KafooSpacing.confirmYes));
      expect(no.height, greaterThanOrEqualTo(KafooSpacing.confirmNo));
      expect(yes.height, greaterThan(no.height));
      // The no is never hidden, greyed, or slower to reach.
      expect(no.height, greaterThan(KafooSpacing.minTapTarget));
    });

    testWidgets('both answers work, and each fires once', (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(_host(gate(onYes: () => confirmed++)));
      await tester.tap(find.text('أيوة، انشريها'));
      await tester.pump();
      expect(confirmed, 1);

      var rejected = 0;
      await tester.pumpWidget(_host(gate(onNo: () => rejected++)));
      await tester.tap(find.text('لأ، استنى'));
      await tester.pump();
      expect(rejected, 1);
    });

    testWidgets('shows the whole read-back, not a summary', (tester) async {
      await tester.pumpWidget(_host(gate()));
      expect(
        find.text('محشي ورق عنب بمية وعشرين جنيه، هينشر دلوقتي.'),
        findsOneWidget,
      );
      expect(find.text('لو مقولتيش حاجة، مفيش حاجة هتحصل.'), findsOneWidget);
    });

    testWidgets('the number is the largest thing on the screen',
        (tester) async {
      await tester.pumpWidget(_host(gate()));
      final amount = tester.widget<Text>(find.text('١٢٠')).style!;
      final question = tester.widget<Text>(find.text('تنشر؟')).style!;
      expect(amount.fontSize, 48);
      expect(amount.fontSize, greaterThan(question.fontSize!));
    });

    testWidgets('does not clip at 200% text scale', (tester) async {
      await tester.pumpWidget(_host(gate(), textScale: 2));
      expect(tester.takeException(), isNull);
    });
  });
}
