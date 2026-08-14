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

/// Fetches a signed URL from Kafoo. Injected so a test never needs a key.
typedef SignedUrlSource = Future<String?> Function();

/// The default source: Kafoo's own Edge Function.
Future<String?> fetchSignedUrl() async {
  try {
    final response = await Supabase.instance.client.functions.invoke(
      'agent-session',
      body: const <String, Object?>{},
    );
    final data = response.data;
    if (data is Map && data['url'] is String) return data['url'] as String;
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
    SignedUrlSource? signedUrl,
    AudioRecorder? recorder,
    WebSocketChannel Function(Uri url)? connect,
  })  : _signedUrl = signedUrl ?? fetchSignedUrl,
        _recorder = recorder ?? AudioRecorder(),
        _connect = connect ?? WebSocketChannel.connect;

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

    final url = await _signedUrl();
    if (url == null) return false;

    final WebSocketChannel channel;
    try {
      channel = _connect(Uri.parse(url));
    } on Object {
      return false;
    }
    _channel = channel;
    _running = true;

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
