import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'speech_output.dart';
import 'voice_clip_store.dart';

/// Which of the two Cairene voices the assistant uses.
///
/// §10.11: two voices, male and female, both Cairene, and **each account chooses
/// its own.** Stored per device and never switched on its own.
///
/// **NOBODY CAN ACTUALLY CHOOSE YET, WHICH IS WHY [defaultRole] MATTERS MORE
/// THAN IT SHOULD.** [setRole] works and persists, and nothing in the app calls
/// it — §10.11's voice cards and the aloud question on first launch are designed
/// and unbuilt. Until they exist, the default is not a starting point a Cook can
/// move away from; it is the only voice anybody gets.
enum AssistantVoiceRole {
  /// Ghozlan — Soft Clear Conversational.
  female,

  /// Ahmad — Conversational AI Voice. **The default since 2026-08-12.**
  ///
  /// The founder chose it by ear, having heard both on a handset. It replaced
  /// Ghozlan, whose only claim to the position was a comment in this file
  /// reasoning from ADR-0010 — and ADR-0010 is about the grammar Kafoo uses to
  /// *address* a Cook, not about who does the speaking. So this is a decision
  /// being made rather than one being overturned.
  ///
  /// **It is a decision for every Cook, not a setting for one person**, and it
  /// stays that way until §10.11's chooser is built.
  male;

  /// What the assistant speaks with until somebody chooses otherwise.
  ///
  /// Named rather than repeated, because it was written out in three places and
  /// changing the default means changing all three — including the `catch` that
  /// runs when stored preferences cannot be read, which is the one a change
  /// would silently miss and the one that would leave a handset on the old
  /// voice with no way to tell.
  static const AssistantVoiceRole defaultRole = AssistantVoiceRole.male;

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
    VoiceClipStore? clips,
    Future<Uint8List?> Function(String line, String voice)? fetchAudio,
    Future<void> Function(Uint8List audio, double volume)? playAudio,
    Future<void> Function()? stopAudio,
  })  : _fallback = fallback,
        _clips = clips,
        _fetchAudio = fetchAudio,
        _playAudio = playAudio,
        _stopAudio = stopAudio;

  final SpeechOutput _fallback;

  /// Audio Kafoo already owns — the 36 bundled sentences, and anything bought
  /// on a previous launch. Null in tests that are not about the store.
  final VoiceClipStore? _clips;
  final Future<Uint8List?> Function(String line, String voice)? _fetchAudio;
  final Future<void> Function(Uint8List audio, double volume)? _playAudio;
  final Future<void> Function()? _stopAudio;
  AudioPlayer? _player;

  AssistantVoiceRole _role = AssistantVoiceRole.defaultRole;
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

  /// The bound above, exposed so a test can stall *past* it.
  ///
  /// The regression test for the unbounded microphone gate stalled a stop for
  /// 50 ms and asserted the call had not returned — which was true whether the
  /// gate was bounded or not, so the test agreed with the fix instead of
  /// proving it. A stall only distinguishes the two once it outlives this
  /// figure, and a literal in the test would drift the day the figure changes.
  /// Found by accessibility-reviewer on #461, round six.
  static const Duration stopBound = _stopTimeout;

  /// How long to wait for the paid voice before falling back.
  ///
  /// A stalled connection with no timeout is an app that is silent AND still —
  /// the one thing a voice flow may never be. Falling back to the machine voice
  /// is a worse voice; waiting forever is no voice at all.
  ///
  /// **THIS WAS 1000 ms, AND 1000 ms MEANT THE PAID VOICE NEVER PLAYED ONCE.**
  /// The figure was never measured against the provider it bounds — it was
  /// arithmetic backwards from the 2 s budget, and it assumed a synthesis
  /// faster than ElevenLabs has ever delivered. The first real measurement, on
  /// the demo project on 2026-08-12, was three calls the founder triggered
  /// himself: **1064 ms, 1070 ms and 2612 ms**, all of them HTTP 200 with audio
  /// attached. The app abandoned all three and spoke in the machine voice, and
  /// because nothing is cached until a fetch *succeeds*, it never recovered.
  /// Kafoo was billed for every sentence and heard none of them.
  ///
  /// 3000 ms covers the cold start as well as the warm case. **The founder
  /// raised the budget to accept it on 2026-08-12**, having been shown that the
  /// wait only lengthens on the failure path: a fetch that succeeds still
  /// reaches the Cook in about 1.1 s, unchanged and well inside 2 s.
  static const Duration _fetchTimeout = Duration(milliseconds: 3000);

  /// **EVERY WAIT ON THE FAILURE PATH, ADDED UP, AND THAT IS THE POINT OF THE
  /// GETTER.** The worst case is a fetch that stalls, then a playback that
  /// stalls, then the stop that abandons it stalling too — **and the silence at
  /// the START of `speak` stalling as well, which the first version of this sum
  /// also missed.** 300 + 3000 + 300 + 300 = 3900 ms before the machine voice
  /// starts.
  ///
  /// **THIS SUM IS NO LONGER UNDER THE 2 s VOICE BUDGET, AND THAT IS A DECISION
  /// RATHER THAN A REGRESSION.** The founder raised the ceiling on 2026-08-12
  /// once the first measurement of the provider showed that keeping it meant
  /// the paid voice could never play at all — see [_fetchTimeout]. What the
  /// budget still governs is the path that *works*: a successful fetch reaches
  /// the Cook in about 1.1 s. This figure bounds only the broken path, where
  /// the alternative on offer was a machine voice 2 s sooner at the cost of
  /// never hearing the real one.
  ///
  /// It has been wrong twice, in the same way both times — a new wait was added
  /// inside the handler for the previous one and not counted. First 2000 + 700,
  /// which shipped 700 ms over a budget only the founder may raise. Then the
  /// stop call, which was unbounded and invisible to this sum. **Any new await
  /// on this path belongs in this figure, and the test below is what refuses a
  /// total over the ceiling.**
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
  /// **IN MEMORY, AND NO LONGER THE ONLY CACHE.** This one is lost on restart,
  /// which used to mean every sentence was re-bought on every launch. The two
  /// stores in [VoiceClipStore] are what survive that now — bundled clips for
  /// the 36 sentences that never change, and a disk copy of anything bought at
  /// runtime. This is just the fastest tier above them.
  final Map<String, Uint8List> _heard = {};

  /// Which voice is speaking.
  AssistantVoiceRole get role => _role;

  @override
  AssistantVoiceRole get voice => _role;

  /// Two voices, bought and paid for. The whole reason the chooser exists.
  @override
  bool get hasVoiceChoice => true;

  @override
  Future<void> setVoice(AssistantVoiceRole role) => setRole(role);

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

  /// Reads the stored choice, and falls back to [AssistantVoiceRole.defaultRole].
  ///
  /// **BOTH NAMES ARE MATCHED EXPLICITLY, so that an unreadable value is not
  /// mistaken for a choice.** Written as "is it male, else female" this silently
  /// changed meaning the day the default changed: a corrupted or unrecognised
  /// stored value would have resolved to whichever voice happened to be on the
  /// else branch, rather than to the default. Only the two words a Cook's own
  /// choice can produce count as a choice; anything else is no answer at all.
  Future<void> _loadVoicePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(voicePreferenceKey);
      _role = switch (stored) {
        'male' => AssistantVoiceRole.male,
        'female' => AssistantVoiceRole.female,
        _ => AssistantVoiceRole.defaultRole,
      };
    } on Object catch (_) {
      // Never a silent switch to the other voice.
      _role = AssistantVoiceRole.defaultRole;
    }
  }

  /// Chooses a voice, and remembers it. §10.11: persists until changed.
  /// **AN ANSWER IS STORED EVEN WHEN IT MATCHES TODAY'S DEFAULT**, and that is
  /// the whole difference between a default and a choice.
  ///
  /// This returned early when the role was unchanged, which looked like an
  /// obvious saving and quietly broke §10.11's promise that a voice never
  /// switches on its own. A Cook who listened to both and deliberately picked
  /// the one that happened to be the default stored nothing — so she was
  /// indistinguishable from someone who had never been asked, and the next time
  /// Kafoo changed its default she would have been moved without being told.
  /// Exposed on 2026-08-12 by the default changing for the first time.
  Future<void> setRole(AssistantVoiceRole role) async {
    final changed = role != _role;
    _role = role;
    // The cache is keyed by voice, so nothing has to be thrown away — but stop
    // talking, because finishing a sentence in the old voice after the Cook
    // chose a new one is the app arguing with her. Only when it really changed:
    // cutting off a sentence to confirm a voice she is already hearing would be
    // the app interrupting itself for no reason.
    if (changed) await stop();
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

  /// Where a sentence's audio comes from, cheapest source first.
  ///
  /// **THREE OF THESE FOUR COST NOTHING AND BEAT THE NETWORK, WHICH IS THE
  /// WHOLE POINT.** In memory, then bundled in the app, then bought on an
  /// earlier launch, and only then bought again. The provider bills per
  /// character generated, so every sentence that never changes — 36 of the 38
  /// Kafoo says — should be paid for exactly once in the life of the product
  /// rather than once per launch, which is what happened before.
  ///
  /// The two that are not bundled both carry something only this Cook's account
  /// knows: the Meal-list greeting, with her Meal counts, and the row's
  /// «اسمعيها», which reads back a Meal's own name, status and price. They land
  /// in the disk store instead, so each is bought when it changes rather than
  /// every time she opens Kafoo.
  Future<Uint8List?> _audioFor(String line) async {
    final voice = _role.wireName;
    final key = '$voice:$line';
    final cached = _heard[key];
    if (cached != null) return cached;

    // Bundled or already bought. No network, no timeout to lose, no bill — and
    // it works with no signal at all, which is the state a Cook in a lift or on
    // the metro is actually in.
    final owned = await _clips?.read(line, voice);
    if (owned != null && owned.isNotEmpty) {
      _heard[key] = owned;
      return owned;
    }

    final fetch = _fetchAudio ?? _invokeSpeak;
    try {
      final audio = await fetch(line, voice).timeout(_fetchTimeout);
      if (audio == null || audio.isEmpty) return null;
      _heard[key] = audio;
      // Kept for the next launch. Not awaited: the Cook is waiting to hear this
      // sentence, and a disk write she gains nothing from must not sit in front
      // of it — a slow filesystem would spend the voice budget on bookkeeping.
      unawaited(_clips?.keep(line, voice, audio) ?? Future<void>.value());
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
