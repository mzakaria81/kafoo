/// The nine voice states, their three channels, and the eleven glance words.
///
/// No Flutter, no Supabase. This file is the domain statement of
/// `docs/design/DESIGN.md` §10 — what Kafoo says, shows and does at each moment
/// of a spoken exchange. It holds no strings a person reads or hears: a spoken
/// line is named by its ARB key, because `CLAUDE.md` forbids a user-facing
/// string outside the locale files and a spoken sentence is no exception.
///
/// **Why the states live here rather than in widgets.** ADR-0013 made the
/// assistant's voice the primary surface, and `specs/ROADMAP.md` records the
/// consequence: the voice system "cannot be built per-screen without producing
/// nine slightly different versions of each state." Declared once, in the
/// domain, a tenth state cannot appear by accident and a missing channel cannot
/// pass review — `voice_test.dart` fails on both.
library;

/// What Kafoo is doing, from the point of view of the person in front of it.
///
/// §10.2: "all nine are components". Each defines four things — visual
/// treatment, the spoken line, the haptic, and the tap fallback. The first three
/// are declared in [voiceStates]; the fourth belongs to whatever screen renders
/// the state, because tap is a complete alternative rather than one shape.
enum VoiceState {
  /// The orb at rest, inviting. Spoken once on arrival.
  idle,

  /// The person is talking. Rings expand and the bars follow the real input
  /// level — §10.2 is explicit that a fake animation destroys trust in every
  /// other state.
  listening,

  /// Kafoo is working. Visible before 400 ms, per the performance budget.
  thinking,

  /// Kafoo is talking. The sentence is shown large as it is said, because the
  /// screen is the receipt of what was heard.
  speaking,

  /// Recognition failed. Never blames the speaker — §10.7.
  didNotCatch,

  /// A value changed. Only the changed value animates, and it is always repeated
  /// aloud.
  correcting,

  /// The person talked over Kafoo. Speech stops mid-sentence and listening
  /// resumes, with no message about it at all.
  interrupted,

  /// No network. What may be *promised* here is constrained — see
  /// [VoiceAnnouncement.spokenAlternative].
  offline,

  /// Too much noise to work with. Asks the person to come closer, never to speak
  /// more clearly.
  tooNoisy,
}

/// What the assistant says in a state — or why it deliberately says nothing.
///
/// **A sealed type rather than a nullable string, and that is the enforcement.**
/// Several states are silent on purpose: Kafoo must not talk over somebody who
/// is mid-sentence. So the rule cannot be "every state speaks". It is that
/// silence is *declared*, with a reason — which makes forgetting a spoken line
/// a different thing from choosing not to have one, and only the second is
/// allowed.
sealed class SpokenLine {
  /// Creates a spoken line.
  const SpokenLine();
}

/// The assistant speaks the sentence at [lineKey].
final class Says extends SpokenLine {
  /// Creates a spoken line naming an ARB key.
  const Says(this.lineKey);

  /// The ARB key of the sentence, in `spoken*` form.
  ///
  /// Never the sentence itself. The Arabic lives in `app_ar.arb` beside the
  /// visible strings, paired by name — `mealPublished` is what the screen shows
  /// and `spokenMealPublished` is what the assistant says. They are different
  /// sentences: one is a label, the other is speech.
  final String lineKey;

  @override
  String toString() => 'Says($lineKey)';
}

/// The assistant deliberately says nothing, [because] of this.
final class Silent extends SpokenLine {
  /// Creates a declared silence.
  const Silent(this.because);

  /// Why this state is silent. Required, and asserted non-empty by the tests:
  /// an unexplained silence is indistinguishable from a forgotten line.
  final String because;

  @override
  String toString() => 'Silent($because)';
}

/// What the phone does in the hand.
///
/// §10.1: a kitchen is noisy, a street is bright, a phone may be face-down, so
/// every state must also be felt. The vocabulary is closed for the same reason
/// the glance words are — a pattern nobody recognises is worse than none.
enum Haptic {
  /// Nothing. Declared rather than absent.
  none,

  /// One short pulse. Something began.
  shortPulse,

  /// Two short pulses. Kafoo is about to speak, or a value just changed.
  twoShortPulses,

  /// One long pulse. Something went wrong or stopped.
  longPulse,
}

/// Everything one state does, on all three channels at once.
///
/// **A screen asks for a state, never for a channel.** That is what makes
/// §10.1's "every state reaches the user three ways" structural rather than
/// remembered: there is no way to request only the sentence, so there is no way
/// to ship a state that is visible and mute.
final class VoiceAnnouncement {
  /// Creates an announcement. Every channel is required, including silence and
  /// [Haptic.none].
  const VoiceAnnouncement({
    required this.spoken,
    required this.haptic,
    this.spokenAfter,
    this.speakAfter,
    this.spokenAlternative,
  });

  /// What is said the moment the state begins.
  final SpokenLine spoken;

  /// What the phone does.
  final Haptic haptic;

  /// A line said only if the state is still current after [speakAfter].
  ///
  /// Exists for exactly one case in §10.2 — thinking is silent, and after two
  /// seconds says «لسه معاك، ثانية.» A second field rather than a timer, for the
  /// same reason [ConfirmationGate.onSilenceElapsed] takes an event: the rule is
  /// testable and the clock belongs to the caller.
  final SpokenLine? spokenAfter;

  /// How long before [spokenAfter] is said.
  final Duration? speakAfter;

  /// The line to say instead of [spoken] when the state's usual promise is not
  /// true.
  ///
  /// **One state needs this and the reason is a founder decision, not a
  /// nicety.** The offline state's natural line is «مفيش نت. كلامك محفوظ
  /// وهيتبعت أول ما النت يرجع.» — *no network, your words are saved.* On a
  /// handset with no `ar-EG` speech there is nothing to save, because the thing
  /// that makes transcripts needs the network that just went away
  /// (`docs/ops/measuring-transcription.md`). `business-rules.md` is explicit:
  /// never say «كلامك محفوظ» over words that were not captured, because losing a
  /// Cook's sentence after telling her it was safe is worse than telling her the
  /// truth immediately. So the state carries both sentences and the caller picks
  /// by what actually happened.
  final SpokenLine? spokenAlternative;
}

/// The nine states, declared once — §10.2's table, in code.
///
/// Adding a tenth state means adding a row here, and `voice_test.dart` fails
/// until it exists. That is the point: the table is the specification, and a
/// state that is not in it cannot be announced.
const Map<VoiceState, VoiceAnnouncement> voiceStates = {
  VoiceState.idle: VoiceAnnouncement(
    spoken: Says('spokenIdleInvitation'),
    // Nothing has happened. A buzz on arrival would be Kafoo tapping somebody
    // on the shoulder for no reason.
    haptic: Haptic.none,
  ),
  VoiceState.listening: VoiceAnnouncement(
    spoken: Silent(
      'the person is talking, and talking over them is the defect this state '
      'exists to avoid',
    ),
    haptic: Haptic.shortPulse,
  ),
  VoiceState.thinking: VoiceAnnouncement(
    spoken: Silent('there is nothing to say yet, and filler would be noise'),
    haptic: Haptic.none,
    spokenAfter: Says('spokenStillWithYou'),
    speakAfter: Duration(seconds: 2),
  ),
  VoiceState.speaking: VoiceAnnouncement(
    spoken: Says('spokenReply'),
    // BEFORE the sentence, not with it: the buzz is what tells somebody looking
    // away that words are coming, in time to listen to them.
    haptic: Haptic.twoShortPulses,
  ),
  VoiceState.didNotCatch: VoiceAnnouncement(
    spoken: Says('spokenDidNotCatch'),
    haptic: Haptic.longPulse,
  ),
  VoiceState.correcting: VoiceAnnouncement(
    // §10.2: "repeats the new value aloud, always." A correction the person
    // cannot see confirmed is a correction they cannot trust.
    spoken: Says('spokenCorrected'),
    haptic: Haptic.twoShortPulses,
  ),
  VoiceState.interrupted: VoiceAnnouncement(
    spoken: Silent(
      'the person cut in deliberately; announcing it would be arguing with them',
    ),
    haptic: Haptic.shortPulse,
  ),
  VoiceState.offline: VoiceAnnouncement(
    spoken: Says('spokenOfflineQueued'),
    haptic: Haptic.longPulse,
    spokenAlternative: Says('spokenOfflineNotCaptured'),
  ),
  VoiceState.tooNoisy: VoiceAnnouncement(
    spoken: Says('spokenTooNoisy'),
    haptic: Haptic.longPulse,
  ),
};

/// What a glance word means, so the colour can carry it without the word.
///
/// §10.4: "Colour must carry the same meaning as the word, redundantly — if the
/// word is not read, the colour alone must land." The meaning is named here and
/// mapped to a token in `packages/ui/`, so the domain does not know about
/// colours and the design system does not decide what a word means.
enum GlanceMeaning {
  /// Live, arrived, done. Reads as green.
  good,

  /// Paused or not yet real. Reads as muted.
  quiet,

  /// Needs attention. Reads as the assistant's own colour.
  attention,

  /// Stopped or failed. Reads as red.
  bad,
}

/// The closed set of Arabic words that may appear at glance size — §10.4, §10.12.
///
/// **Eleven, and a twelfth is a change to this enum before it is a change to any
/// screen.** These are recognised by silhouette rather than read, which only
/// works if the shape is already familiar: §10.4 is blunt that "an unrecognised
/// shape is worse than no word."
///
/// §10.4 named nine. §10.12 added `sent` and `read` for message delivery,
/// because a Cook needs to know her words arrived and cannot be asked to read
/// small text to find out.
enum GlanceWord {
  /// منشورة — the Meal is on offer.
  published(GlanceMeaning.good),

  /// مسودة — started, not finished.
  draft(GlanceMeaning.quiet),

  /// مش متاحة — off the menu today.
  unavailable(GlanceMeaning.quiet),

  /// أرشيف — retired, still readable in history.
  archived(GlanceMeaning.quiet),

  /// طلب جديد — an Order needs an answer.
  newOrder(GlanceMeaning.attention),

  /// وصل — it got there.
  arrived(GlanceMeaning.good),

  /// اتلغى — it was cancelled.
  cancelled(GlanceMeaning.bad),

  /// محفوظ — held safely. Only ever said when it is true.
  saved(GlanceMeaning.attention),

  /// مفيش نت — no network.
  noNetwork(GlanceMeaning.bad),

  /// اتبعت — the Message left.
  sent(GlanceMeaning.attention),

  /// اتقرت — the other person read it.
  read(GlanceMeaning.good);

  const GlanceWord(this.meaning);

  /// What this word means, for the colour to carry redundantly.
  final GlanceMeaning meaning;

  /// The ARB key holding the Arabic word.
  ///
  /// A key rather than the word, for the same reason as [Says.lineKey]: the
  /// Arabic belongs in the locale files. `glanceCancelled` rather than «اتلغى».
  String get lineKey => 'glance${name[0].toUpperCase()}${name.substring(1)}';
}
