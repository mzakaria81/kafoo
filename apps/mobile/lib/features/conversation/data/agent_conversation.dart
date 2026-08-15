import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One live voice conversation with the hosted agent (ADR-0017).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **WHAT THIS REPLACES.** Until now a turn was four steps queued end to end:
/// the phone recognised speech, an Edge Function called a model, a whole
/// sentence of audio was synthesised, downloaded, then played. Three to five
/// seconds of silence after a Cook stopped talking, and no way to interrupt.
///
/// Here the four overlap. The microphone streams while she is still speaking,
/// the reply is spoken as it is generated, and cutting in works.
///
/// **NO PROVIDER KEY IS IN THIS FILE OR ANYWHERE NEAR IT.** [start] asks Kafoo's
/// own `agent-session` function for a short-lived signed URL and opens the
/// socket with that. This is the hinge ADR-0009 died on for a different provider
/// and it is the reason this class takes a URL it did not build.
///
/// **RAW AUDIO IS NEVER PERSISTED, at either end.** Microphone frames go
/// straight to the socket and are not written to disk; the agent is configured
/// with recording off and zero retention. `business-rules.md` — "voice
/// recordings are transcribed and discarded" — needed no exception and none was
/// taken.
/// ─────────────────────────────────────────────────────────────────────────────

/// Something the conversation reported.
sealed class AgentEvent {
  const AgentEvent();
}

/// What the Cook said, as the agent heard it.
///
/// **Never shown to her.** ADR-0013 rule 2: the assistant paraphrases and does
/// not display a transcript. This reaches the controller so the facts inside it
/// can be captured, and stops there.
final class AgentHeard extends AgentEvent {
  const AgentHeard(this.text);
  final String text;
}

/// What the assistant said back. This is what the screen shows.
final class AgentSaid extends AgentEvent {
  const AgentSaid(this.text);
  final String text;
}

/// The Cook started talking over the assistant, and the assistant stopped.
///
/// The audio already queued for playback must be dropped, not drained — a
/// sentence that keeps playing after she interrupted is the app not listening.
final class AgentInterrupted extends AgentEvent {
  const AgentInterrupted();
}

/// A chunk of the assistant's voice, 16 kHz mono signed 16-bit PCM.
final class AgentAudio extends AgentEvent {
  const AgentAudio(this.pcm);
  final Uint8List pcm;
}

/// The conversation ended, by either side or by failure.
final class AgentEnded extends AgentEvent {
  const AgentEnded({this.failed = false});
  final bool failed;
}

/// Which conversation the orb is opening.
///
/// **Kafoo has two and had one agent, which is how the Kitchen Profile orb
/// greeted a Cook with «قوليلي عملتي إيه النهاردة؟» and asked her about a
/// dish.** The app names the KIND and never an agent id — the id lives in the
/// Edge Function beside the key, the same way `speak` takes a role and never a
/// voice id.
enum AgentConversationKind {
  meal,
  kitchen;

  /// The word the function checks against its closed set. Never renamed.
  String get wireName =>
      this == AgentConversationKind.kitchen ? 'kitchen' : 'meal';
}

/// What Kafoo hands back so a conversation can be opened.
final class AgentSession {
  const AgentSession({required this.url, this.voiceId});

  /// A bearer credential for fifteen minutes. Never logged.
  final String url;

  /// The voice the function chose from the role the app asked for, or null.
  ///
  /// The app never names an id — it names «صوت ست» or «صوت رجل» and echoes back
  /// whatever came home, because the provider reads a voice override only from
  /// the opening frame of the socket and the socket belongs to the client.
  ///
  /// **NULLABLE, AND THAT IS A DEPLOY-ORDER RULE RATHER THAN AN OVERSIGHT.** An
  /// app is on a phone for as long as its owner leaves it there, so it will
  /// meet a function older than itself. A version that answers with a URL and
  /// no voice id is a working conversation in the agent's own voice — insisting
  /// on the id would turn a cosmetic gap into no voice at all.
  final String? voiceId;
}

/// Fetches a session from Kafoo. Injected so a test never needs a key.
typedef SignedUrlSource = Future<AgentSession?> Function(
  AgentConversationKind kind,
  String? voice,
);

/// The default source: Kafoo's own Edge Function.
Future<AgentSession?> fetchSignedUrl(
  AgentConversationKind kind,
  String? voice,
) async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'agent-session',
      body: <String, Object?>{
        'kind': kind.wireName,
        if (voice != null) 'voice': voice,
      },
    );
    final data = response.data;
    if (data is Map && data['url'] is String) {
      return AgentSession(
        url: data['url'] as String,
        voiceId: data['voiceId'] is String ? data['voiceId'] as String : null,
      );
    }
    return null;
  } on Object {
    // Nothing is logged and nothing is rethrown. A signed URL is a bearer
    // credential; an error carrying one into a log is the defect this whole
    // path exists to avoid. The caller falls back to typing, which is a
    // complete alternative rather than a degraded one.
    return null;
  }
}

class AgentConversation {
  AgentConversation({
    required this.kind,
    this.voice,
    SignedUrlSource? signedUrl,
    AudioRecorder? recorder,
    WebSocketChannel Function(Uri url)? connect,
  })  : _signedUrl = signedUrl ?? fetchSignedUrl,
        _recorder = recorder ?? AudioRecorder(),
        _connect = connect ?? WebSocketChannel.connect;

  /// Which conversation this is. Required, so a new caller has to decide rather
  /// than inheriting whichever agent happened to be the default.
  final AgentConversationKind kind;

  /// The ROLE she chose in Settings — «female» or «male», never an id.
  ///
  /// **Sent as an override on the way in, and the agent has to permit it.** A
  /// Cook who picks «صوت ست» and then hears a man the moment she presses the orb
  /// has been given a control that governs half of what it claims to. If the
  /// agent's configuration forbids the override the provider ignores it and the
  /// conversation still opens — worse than intended, never broken.
  final String? voice;

  final SignedUrlSource _signedUrl;
  final AudioRecorder _recorder;
  final WebSocketChannel Function(Uri url) _connect;

  final _events = StreamController<AgentEvent>.broadcast();
  Stream<AgentEvent> get events => _events.stream;

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _mic;
  bool _running = false;

  bool get isRunning => _running;

  /// Opens the conversation. Returns false when it could not start, without
  /// throwing — every failure here has the same answer for the Cook, and it is
  /// «اتكلمي بالكتابة» rather than a crash.
  Future<bool> start() async {
    if (_running) return true;

    if (!await _recorder.hasPermission()) return false;

    final session = await _signedUrl(kind, voice);
    if (session == null) return false;

    final WebSocketChannel channel;
    try {
      channel = _connect(Uri.parse(session.url));
    } on Object {
      return false;
    }
    _channel = channel;
    _running = true;

    // THE FIRST MESSAGE, BEFORE ANY AUDIO. The provider reads overrides only
    // from the opening frame; sending it later is sending it never.
    final chosenVoice = session.voiceId;
    if (chosenVoice != null) {
      channel.sink.add(jsonEncode({
        'type': 'conversation_initiation_client_data',
        'conversation_config_override': {
          'tts': {'voice_id': chosenVoice},
        },
      }));
    }

    channel.stream.listen(
      _onMessage,
      onError: (_) => _finish(failed: true),
      onDone: () => _finish(failed: false),
      cancelOnError: true,
    );

    // 16 kHz mono PCM, which is what the agent is configured to expect on both
    // directions. Anything else arrives as noise rather than as an error, so
    // the sample rate is written once, here, and matched in the agent config.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _mic = stream.listen((chunk) {
      if (!_running) return;
      channel.sink.add(jsonEncode({'user_audio_chunk': base64Encode(chunk)}));
    });

    return true;
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    switch (decoded['type']) {
      // THE PING MUST BE ANSWERED OR THE SOCKET IS CLOSED UNDER US. The provider
      // sends a ping carrying an event id and expects the same id back; a
      // client that ignores it looks dead and is disconnected mid-sentence.
      case 'ping':
        final event = decoded['ping_event'];
        if (event is Map && event['event_id'] != null) {
          _channel?.sink
              .add(jsonEncode({'type': 'pong', 'event_id': event['event_id']}));
        }
      case 'audio':
        final event = decoded['audio_event'];
        if (event is Map && event['audio_base_64'] is String) {
          _events.add(
            AgentAudio(base64Decode(event['audio_base_64'] as String)),
          );
        }
      case 'user_transcript':
        final event = decoded['user_transcription_event'];
        if (event is Map && event['user_transcript'] is String) {
          _events.add(AgentHeard(event['user_transcript'] as String));
        }
      case 'agent_response':
        final event = decoded['agent_response_event'];
        if (event is Map && event['agent_response'] is String) {
          _events.add(AgentSaid(event['agent_response'] as String));
        }
      case 'interruption':
        _events.add(const AgentInterrupted());
    }
  }

  /// Ends the conversation. Safe to call twice.
  Future<void> stop() async {
    if (!_running) return;
    await _finish(failed: false);
  }

  Future<void> _finish({required bool failed}) async {
    if (!_running) return;
    _running = false;
    await _mic?.cancel();
    _mic = null;
    await _recorder.stop();
    await _channel?.sink.close();
    _channel = null;
    _events.add(AgentEnded(failed: failed));
  }

  Future<void> dispose() async {
    await _finish(failed: false);
    await _recorder.dispose();
    await _events.close();
  }
}
