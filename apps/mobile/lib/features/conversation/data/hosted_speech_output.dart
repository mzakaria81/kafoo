import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'speech_output.dart';

/// Which of the two Cairene voices the assistant uses.
///
/// §10.11: two voices, male and female, both Cairene, and **each account chooses
/// its own.** Stored per device and never switched on its own.
enum AssistantVoiceRole {
  /// Ghozlan — Soft Clear Conversational. The default, because ADR-0010 exists
  /// to address a Cook as a woman and she is who hears this most.
  female,

  /// Ahmad — Conversational AI Voice.
  male;

  /// The word `speak` accepts. **A role, never an id** — the ids live in the
  /// Edge Function and nowhere else, so a voice cannot be chosen from here.
  String get wireName => this == AssistantVoiceRole.female ? 'female' : 'male';
}

/// The assistant's voice, spoken by the Cairene voices the founder chose.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **THE KEY IS NOT IN THIS FILE, AND COULD NOT BE.** `.claude/rules/ai.md`: the
/// call to a model provider happens in an Edge Function, not in Dart, because a
/// provider key compiled into the app is extractable by anyone who downloads it
/// and rotating it does not reach handsets already installed. This class asks
/// Kafoo's own `speak` function for audio; only that function knows the provider
/// or the voice ids.
///
/// **IT FALLS BACK TO THE DEVICE'S OWN VOICE RATHER THAN GOING QUIET.** A paid
/// voice needs the network and a working account; the device voice needs
/// neither. ADR-0014 chose the device voice precisely because it always works,
/// and that reasoning does not stop applying now there is something better —
/// it becomes the floor. The seam's own contract says silence is never silent
/// about itself, so a Cook on the metro hears a machine rather than nothing.
/// ─────────────────────────────────────────────────────────────────────────────
class HostedSpeechOutput with StoredMutePreference implements SpeechOutput {
  /// [fallback] is what speaks when the network or the account cannot.
  ///
  /// [fetchAudio], [playAudio] and [stopAudio] are injected only so a test can
  /// drive this without a network or a speaker.
  ///
  /// **Playback is a function rather than an [AudioPlayer], and that is
  /// deliberate.** Taking the player itself made the successful path
  /// untestable: `AudioPlayer` is a concrete class over a platform channel, so
  /// a widget test either hangs on it or needs the plugin faked at the channel
  /// level. Every test of the *fallback* passed while every test of a line that
  /// actually played timed out — which is the wrong half to have covered.
  HostedSpeechOutput({
    required SpeechOutput fallback,
    Future<Uint8List?> Function(String line, String voice)? fetchAudio,
    Future<void> Function(Uint8List audio, double volume)? playAudio,
    Future<void> Function()? stopAudio,
  })  : _fallback = fallback,
        _fetchAudio = fetchAudio,
        _playAudio = playAudio,
        _stopAudio = stopAudio;

  final SpeechOutput _fallback;
  final Future<Uint8List?> Function(String line, String voice)? _fetchAudio;
  final Future<void> Function(Uint8List audio, double volume)? _playAudio;
  final Future<void> Function()? _stopAudio;
  AudioPlayer? _player;

  AssistantVoiceRole _role = AssistantVoiceRole.female;
  bool _ready = false;

  /// Bumped every time the assistant is told to stop.
  ///
  /// **THIS IS WHAT STOPS THE ASSISTANT TALKING INTO A LIVE MICROPHONE**, and
  /// nothing else does. The paid voice fetches audio over the network *before*
  /// playing it, so hushing while a fetch is in flight stops nothing — there is
  /// nothing playing yet. The fetch then completes and plays into a microphone
  /// that has since opened, which is the exact failure the whole design forbids
  /// and the worst in a loud kitchen, which is where this product lives.
  ///
  /// So `speak` captures this number before fetching and checks it after. A
  /// sentence hushed mid-fetch is discarded rather than played late. Found by
  /// three independent reviewers on #461 converging on the same timing.
  int _generation = 0;

  /// How long to wait for playback to start before falling back.
  ///
  /// **The fetch timeout alone was half a fix.** The bytes are already local by
  /// this point, so starting playback should be near-instant — but a platform
  /// audio call that stalls leaves `speak` never returning and nothing falling
  /// back, which is the same silent-and-still state one step later.
  static const Duration _playTimeout = Duration(milliseconds: 300);

  /// How long to wait for a stop to take effect.
  ///
  /// **The fix for a stalled call must not itself be able to stall**, which is
  /// the mistake the previous two rounds each made one layer down. `_silence()`
  /// is a platform-channel call in exactly the same family as the one that
  /// needed a timeout in the first place, and it was added inside the timeout
  /// handler with no bound of its own. Found by release-engineer on #461,
  /// round four.
  static const Duration _stopTimeout = Duration(milliseconds: 300);

  /// How long to wait for the paid voice before falling back.
  ///
  /// A stalled connection with no timeout is an app that is silent AND still —
  /// the one thing a voice flow may never be. Falling back to the machine voice
  /// is a worse voice; waiting forever is no voice at all.
  static const Duration _fetchTimeout = Duration(milliseconds: 1000);

  /// **EVERY WAIT ON THE FAILURE PATH, ADDED UP, AND THAT IS THE POINT OF THE
  /// GETTER.** The voice response budget is 2 seconds. The worst case is a fetch
  /// that stalls, then a playback that stalls, then the stop that abandons it
  /// stalling too — **and the silence at the START of `speak` stalling as well,
  /// which the first version of this sum also missed.** 300 + 1000 + 300 + 300
  /// = 1900 ms before the machine voice starts.
  ///
  /// It has been wrong twice, in the same way both times — a new wait was added
  /// inside the handler for the previous one and not counted. First 2000 + 700,
  /// which shipped 700 ms over a budget only the founder may raise. Then the
  /// stop call, which was unbounded and invisible to this sum. **Any new await
  /// on this path belongs in this figure, and the test below is what refuses a
  /// total over budget.**
  ///
  /// None of the three is measured on a handset. What is guaranteed is the
  /// ceiling, not the accuracy of any part of it.
  static Duration get worstCaseBeforeAnyVoice =>
      _stopTimeout + _fetchTimeout + _playTimeout + _stopTimeout;

  /// The stored answer to "which voice should the assistant use".
  static const String voicePreferenceKey = 'kafoo.voice.role';

  /// Money and addresses, per §10.8. Homes are shared and income is private.
  static const double _quietVolume = 0.4;
  static const double _normalVolume = 1;

  /// Audio already heard, so a repeated line costs nothing and plays instantly.
  ///
  /// A Cook hears «تمام، الأكلة منشورة» many times a week and it is the same
  /// bytes every time. The Edge Function marks the response immutable for the
  /// same reason; this is the half of it the app controls.
  ///
  /// ponytail: in memory, so it is lost on restart. A disk cache under
  /// `path_provider` is the upgrade if the monthly bill ever justifies it —
  /// measured at 997 characters for the whole fixed vocabulary, it does not yet.
  final Map<String, Uint8List> _heard = {};

  /// Which voice is speaking.
  AssistantVoiceRole get role => _role;

  @override
  SpeechVoiceMatch get voiceMatch =>
      // Ghozlan and Ahmad are both Cairene — chosen by ear from the twenty-five
      // Egyptian voices in the provider's library, 2026-08-11. There is no
      // `fallback` case here the way there is for a device voice, because the
      // accent is not whatever the handset happened to install.
      _ready ? SpeechVoiceMatch.exact : _fallback.voiceMatch;

  @override
  bool get canSpeak => _ready || _fallback.canSpeak;

  @override
  Future<bool> initialize() async {
    await loadMutePreference();
    await _loadVoicePreference();
    // The fallback is initialized too, and always: it is what speaks when this
    // one cannot, and an engine initialized lazily at the moment of failure is
    // an engine that fails twice.
    await _fallback.initialize();
    _ready = true;
    return canSpeak;
  }

  Future<void> _loadVoicePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(voicePreferenceKey);
      _role = stored == AssistantVoiceRole.male.wireName
          ? AssistantVoiceRole.male
          : AssistantVoiceRole.female;
    } on Object catch (_) {
      // The documented default. Never a silent switch to the other voice.
      _role = AssistantVoiceRole.female;
    }
  }

  /// Chooses a voice, and remembers it. §10.11: persists until changed.
  Future<void> setRole(AssistantVoiceRole role) async {
    if (role == _role) return;
    _role = role;
    // The cache is keyed by voice, so nothing has to be thrown away — but stop
    // talking, because finishing a sentence in the old voice after the Cook
    // chose a new one is the app arguing with her.
    await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(voicePreferenceKey, role.wireName);
    } on Object catch (_) {
      // The choice still holds for this session.
    }
  }

  @override
  Future<void> speak(String line, {bool quiet = false}) async {
    if (isMuted || line.isEmpty) return;

    // STAMPED SYNCHRONOUSLY, BEFORE THE FIRST `await`, AND THAT ORDERING IS THE
    // WHOLE FIX. Capturing it after any await lets a hush land in the gap and
    // be captured as though it had already happened, so the check compares a
    // number against itself and the sentence plays into the open microphone
    // anyway. The first version of this did exactly that and the test caught it.
    final generation = ++_generation;

    // BOTH VOICES STOP BEFORE EITHER STARTS. The interface promises a new line
    // interrupts whatever is being said, and this class has two things that can
    // be saying it — the player and the fallback engine. Stopping only one left
    // the fail-then-recover sequence with two voices talking over each other.
    await _silenceBounded();

    final audio = await _audioFor(line);

    // Hushed, or overtaken by a newer line, while the audio was in flight.
    // Discard it: the microphone may be open now, and a sentence arriving late
    // is worse than one that never came.
    if (generation != _generation || isMuted) return;

    if (audio == null) {
      // Network, quota, key, or a provider outage. The Cook hears the machine
      // voice rather than nothing.
      await _fallback.speak(line, quiet: quiet);
      return;
    }

    try {
      final play = _playAudio ?? _playThroughDevice;
      await play(audio, quiet ? _quietVolume : _normalVolume)
          .timeout(_playTimeout);
    } on Object catch (_) {
      // **A TIMEOUT STOPS WAITING; IT DOES NOT CANCEL THE CALL.** The abandoned
      // playback can still start a moment later, so it is silenced before the
      // machine voice begins — otherwise the two talk over each other, or the
      // late one arrives in a microphone that has since opened. That is the
      // same bug this file already fixed twice, reopened through the timeout
      // added to fix it. Found by three reviewers on #461, round three.
      //
      // **AND WHETHER THIS ACTUALLY PREEMPTS THE STALLED CALL IS UNVERIFIED.**
      // `.timeout()` stops waiting; it does not cancel. Whether a platform
      // `stop()` reliably interrupts an in-flight `play()` on Android and iOS is
      // plugin behaviour that nothing in this repository can prove — the class
      // cannot exercise real playback at all, which is why playback is injected.
      // So this is an accepted, unverified risk rather than a closed fix, and it
      // needs one check on a real handset before the overlap bug is called shut.
      // Raised by conversation-designer on #461, round four.
      await _silenceBounded();

      // And the same re-check the fetch path does. A hush or a mute during the
      // stalled playback must not be undone by the fallback speaking anyway.
      if (generation != _generation || isMuted) return;

      await _fallback.speak(line, quiet: quiet);
    }
  }

  Future<Uint8List?> _audioFor(String line) async {
    final key = '${_role.wireName}:$line';
    final cached = _heard[key];
    if (cached != null) return cached;

    final fetch = _fetchAudio ?? _invokeSpeak;
    try {
      final audio = await fetch(line, _role.wireName).timeout(_fetchTimeout);
      if (audio == null || audio.isEmpty) return null;
      _heard[key] = audio;
      return audio;
    } on Object catch (_) {
      // `on Object` for the usual reason: an uninitialised client throws
      // StateError and a missing plugin a TypeError, and both must land on the
      // fallback rather than taking a screen down.
      return null;
    }
  }

  /// Asks Kafoo's own function. **Never the provider.**
  Future<Uint8List?> _invokeSpeak(String line, String voice) async {
    final response = await Supabase.instance.client.functions.invoke(
      'speak',
      body: {'line': line, 'voice': voice},
    );
    final data = response.data;
    if (data is Uint8List) return data;
    // A JSON body here means the function refused — an over-long line, or the
    // provider being unavailable. Both are the fallback's problem, not an error
    // to show a Cook.
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String && data.isNotEmpty) {
      // Defensive: if the content type ever stops being octet-stream, the
      // client hands back a utf8-decoded string. That is mangled audio rather
      // than audio, so it is refused rather than played.
      return null;
    }
    return null;
  }

  /// Plays the bytes on the device's speaker.
  ///
  /// Stops first: the assistant says one thing at a time, and an interrupted
  /// sentence must not resume behind the next one.
  Future<void> _playThroughDevice(Uint8List audio, double volume) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.setVolume(volume);
    await player.play(BytesSource(audio));
  }

  @override
  Future<void> stop() async {
    // Before anything else, so a fetch already in flight is invalidated even if
    // the two stops below throw.
    _generation++;
    await _silence();
  }

  /// Stops both voices without invalidating anything.
  ///
  /// Separate from [stop] because `speak` needs to silence what is playing
  /// without discarding the line it is about to say.
  ///
  /// **BOUNDED HERE RATHER THAN AT THE CALL SITES, and that is the whole point
  /// of putting it in one place.** The bound was first added at one call site —
  /// the timeout handler — and a test with a stop that never resolves then hung
  /// on the OTHER call, the silence at the start of `speak`, before a single
  /// byte had been fetched. Bounding the funnel rather than the entrances is the
  /// same lesson the search-consent gate already carries: entrances keep being
  /// added, and the one that forgets is invisible.
  /// Bounded, for the paths where the budget is what matters.
  ///
  /// Used by `speak` only. Giving up here means falling back to a worse voice a
  /// fraction early, which is a cost worth paying to stay inside the budget.
  Future<void> _silenceBounded() =>
      _silence().timeout(_stopTimeout, onTimeout: () {});

  /// **UNBOUNDED, AND [stop] USES THIS ONE ON PURPOSE.**
  ///
  /// `AssistantVoice.hush()` calls [stop], and the Meal conversation awaits it
  /// before opening the microphone — that call IS the guarantee of silence
  /// before listening starts. Bounding it made the guarantee a hope: on a slow
  /// handset the microphone would open while a real stop was still in progress,
  /// which is the very failure the whole class exists to prevent, reintroduced
  /// through its own safety gate. Found by conversation-designer on #461,
  /// round five, as a regression I had just added.
  ///
  /// So this waits as long as it takes. A slow stop delays the microphone; an
  /// abandoned stop talks over a Cook. Only one of those is acceptable.
  ///
  /// **THE TWO STOPS RUN TOGETHER, NOT ONE AFTER THE OTHER.** Sequenced, a
  /// native stop that never returns meant the fallback engine was never told to
  /// stop at all — so an old machine-voice sentence could keep talking under a
  /// new one. Found by release-engineer in the same round.
  ///
  /// **What none of this proves:** whether a platform `stop()` actually
  /// preempts an in-flight `play()` on Android and iOS. Nothing here can test
  /// real playback, which is why playback is injected. That assumption needs one
  /// check on a handset before the overlap bug is called closed.
  Future<void> _silence() async {
    await Future.wait<void>([
      _stopPlayer(),
      _fallback.stop(),
    ]);
  }

  Future<void> _stopPlayer() async {
    try {
      if (_stopAudio != null) {
        await _stopAudio();
      } else {
        await _player?.stop();
      }
    } on Object catch (_) {
      // Already not playing, or the player is gone.
    }
  }

  @override
  Future<void> setMuted({required bool muted}) async {
    if (muted) await stop();
    await storeMutePreference(muted: muted);
    // Kept in step, so a mute survives a fall back to the device voice.
    await _fallback.setMuted(muted: muted);
  }
}
