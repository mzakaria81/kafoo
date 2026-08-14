import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafoo_mobile/features/conversation/data/pcm_player.dart';

void main() {
  // The agent streams raw samples with no container, and the header this puts
  // in front of them is 44 bytes of arithmetic nobody would notice being wrong
  // — a bad sample rate plays the assistant's voice at the wrong pitch rather
  // than failing, which is the kind of defect that reaches a phone.
  test('the WAV header describes 16 kHz mono 16-bit, and the samples follow',
      () {
    final pcm = Uint8List.fromList(List<int>.generate(320, (i) => i % 256));
    final out = wav(pcm);
    final view = ByteData.sublistView(out);

    expect(out.length, 44 + pcm.length);
    expect(String.fromCharCodes(out.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(out.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(out.sublist(36, 40)), 'data');

    expect(view.getUint32(4, Endian.little), 36 + pcm.length);
    expect(view.getUint16(20, Endian.little), 1, reason: 'uncompressed PCM');
    expect(view.getUint16(22, Endian.little), 1, reason: 'mono');
    expect(view.getUint32(24, Endian.little), 16000);
    expect(view.getUint32(28, Endian.little), 32000, reason: 'byte rate');
    expect(view.getUint16(32, Endian.little), 2, reason: 'block align');
    expect(view.getUint16(34, Endian.little), 16);
    expect(view.getUint32(40, Endian.little), pcm.length);

    expect(out.sublist(44), pcm);
  });
}
