import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'hosted_speech_output.dart';
import 'speech_output.dart';

part 'speech_output_provider.g.dart';

/// **The line that changed when Kafoo bought a voice, and it was one line.**
///
/// ADR-0014 chose the device's own engine to start — free, offline, no account,
/// and it sounds like a machine — with a paid Cairene voice to follow "once the
/// flows are settled and there are real sentences to audition". Both happened on
/// 2026-08-11: the founder auditioned twenty-five Egyptian voices, chose
/// **Ghozlan** and **Ahmad** by ear, and took the $6 plan.
///
/// **The device voice did not leave. It became the floor.** [HostedSpeechOutput]
/// takes it as its fallback, so a Cook with no signal, an exhausted allowance or
/// a provider outage hears the machine rather than nothing — which is the
/// seam's own rule that silence is never silent about itself, and the reason
/// ADR-0014's choice keeps earning its place after being superseded.
///
/// Nothing else in the app names an engine, and nothing anywhere in the app
/// names a *voice*: the two ids live in the `speak` Edge Function, which is also
/// the only thing holding the provider key. `.claude/rules/ai.md` — the call to
/// a model provider happens in a function, never in Dart, because a key
/// compiled into the app is extractable by anyone who downloads it.
///
/// `keepAlive` because the engine holds a resolved voice, a stored mute
/// preference and the audio it has already heard: rebuilding it per screen would
/// re-run resolution on every navigation, lose a mute mid-session, and re-buy
/// every sentence.
@Riverpod(keepAlive: true)
SpeechOutput speechOutput(Ref ref) =>
    HostedSpeechOutput(fallback: DeviceSpeechOutput());
