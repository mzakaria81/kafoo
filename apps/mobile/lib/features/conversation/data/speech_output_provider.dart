import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'speech_output.dart';

part 'speech_output_provider.g.dart';

/// **The one line that changes when Kafoo buys a voice.**
///
/// The founder chose the device's own engine to start: free, offline, no
/// account, and it sounds like a machine. A paid Cairene voice follows once the
/// flows are settled and there are real sentences to audition — and when it
/// does, the whole change is the constructor below.
/// `decisions/0014-speak-with-the-devices-own-voice-first.md` is the reasoning.
///
/// Nothing else in the app names an engine. Screens and controllers depend on
/// [SpeechOutput], the same way feature code depends on `AiProvider` and never
/// on a particular model provider.
///
/// `keepAlive` because the engine holds a resolved voice and a stored mute
/// preference: rebuilding it per screen would re-run language resolution on
/// every navigation and could lose a mute mid-session.
@Riverpod(keepAlive: true)
SpeechOutput speechOutput(Ref ref) => DeviceSpeechOutput();
