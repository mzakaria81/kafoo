import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Plays the assistant's voice as it arrives, chunk by chunk.
///
/// The agent streams 16 kHz mono signed 16-bit PCM with no container. Nothing
/// in the app's audio stack takes raw samples, so each chunk gets a 44-byte WAV
/// header put in front of it and is played as a tiny file.
///
/// **THIS IS A KNOWN-CEILING SIMPLIFICATION AND THE CEILING IS AUDIBLE.**
/// Playing each chunk as its own clip leaves a short seam between chunks, so
/// long replies can sound slightly clipped at the joins. The alternative is a
/// real streaming sink, which on Flutter means a platform channel per OS. That
/// is worth doing when a Cook says the voice sounds broken, and not before —
/// `docs/mvp-deferred.md` carries the row.
///
/// **[clear] exists for the interruption state and is not optional.** When she
/// talks over the assistant, everything already queued has to be dropped rather
/// than drained: a sentence that keeps playing after she interrupted is the app
/// telling her it is not listening.
class PcmPlayer {
  PcmPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final _queue = <Uint8List>[];
  bool _playing = false;
  bool _disposed = false;

  /// Queues a chunk and starts playback if nothing is playing.
  void add(Uint8List pcm) {
    if (_disposed || pcm.isEmpty) return;
    _queue.add(pcm);
    if (!_playing) unawaited(_drain());
  }

  /// Drops everything queued and stops what is playing. The interruption state.
  Future<void> clear() async {
    _queue.clear();
    _playing = false;
    await _player.stop();
  }

  Future<void> _drain() async {
    _playing = true;
    while (_queue.isNotEmpty && !_disposed) {
      final chunk = _queue.removeAt(0);
      try {
        await _player.play(BytesSource(wav(chunk)));
        await _player.onPlayerComplete.first;
      } on Object {
        // A chunk that will not play is one seam in a sentence. Dropping it and
        // carrying on is better than ending the reply — she can always ask
        // again, and a dead player cannot be recovered mid-conversation.
        continue;
      }
    }
    _playing = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    await _player.dispose();
  }
}

/// Wraps raw PCM in a WAV header. Public so a test can read the header back
/// rather than trusting 44 bytes of arithmetic nobody checked.
Uint8List wav(
  Uint8List pcm, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final out = BytesBuilder();
  final header = ByteData(44);

  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // format: uncompressed PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  out.add(header.buffer.asUint8List());
  out.add(pcm);
  return out.toBytes();
}
