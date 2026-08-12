import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Audio Kafoo already owns for a sentence, so it is never bought twice.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// **TWO STORES, AND THE DIFFERENCE BETWEEN THEM IS WHO PAYS.**
///
/// - **Bundled** — the 36 sentences with no variable in them, bought once by
///   `scripts/generate-voice-clips.ts` and shipped inside the app. Free forever,
///   for every Cook, however many Cooks there are. Plays in milliseconds and
///   needs no signal, so «تمام، شلتها من المنيو» is a Cairene voice on the metro
///   rather than the machine one.
/// - **On disk** — sentences bought at runtime because they carry something only
///   this Cook's account knows. **Two of them, and the second was missed on the
///   first pass:** the Meal-list greeting, which carries her Meal counts, and
///   the row's «اسمعيها», which reads back a Meal's own name, status and price.
///   Kept so each is bought once rather than on every launch.
///
/// The memory cache in `HostedSpeechOutput` sits above both. This class is what
/// survives the app closing.
///
/// **KEYED ON THE SENTENCE, NOT ON A STRING ID, BECAUSE THAT IS ALL THE SEAM
/// HAS.** `SpeechOutput.speak` takes finished words — by the time a line
/// reaches here, which ARB key produced it is long gone. Hashing the words is
/// the only question that can be asked, and it buys a property worth more than
/// the tidier alternative: **editing a line of Arabic changes its hash, so the
/// lookup misses and the new wording is bought.** A clip can go stale, but it
/// can never be spoken after the words it was made from have changed.
/// ─────────────────────────────────────────────────────────────────────────────
class VoiceClipStore {
  /// [loadAsset] and [cacheDirectory] are injected only so a test can run
  /// without the real asset bundle or the real filesystem.
  VoiceClipStore({
    Future<ByteData> Function(String key)? loadAsset,
    Future<Directory> Function()? cacheDirectory,
  })  : _loadAsset = loadAsset ?? rootBundle.load,
        _cacheDirectory = cacheDirectory ?? getApplicationSupportDirectory;

  final Future<ByteData> Function(String key) _loadAsset;
  final Future<Directory> Function() _cacheDirectory;

  /// Set once the support directory has been asked for, so a handset that
  /// cannot give one — or a web build, where `path_provider` has nothing to
  /// return — is asked once rather than on every sentence.
  Directory? _directory;
  bool _directoryResolved = false;

  /// The name a sentence's audio is filed under, in both stores.
  ///
  /// **TRIMMED FIRST, AND THAT IS NOT A TIDINESS HABIT.** The generator trims
  /// each sentence before hashing it, `handleSpeak` trims before sending it to
  /// the provider, and an ARB value with one trailing space would otherwise
  /// hash differently here than it did at build time — every clip would miss,
  /// silently, and Kafoo would go back to paying for all 36 of them while the
  /// files sat unused in the app. Nothing would look broken.
  static String nameFor(String line) =>
      sha1.convert(utf8.encode(line.trim())).toString();

  /// Audio Kafoo already has for [line] in [voice], or null if it must be bought.
  Future<Uint8List?> read(String line, String voice) async {
    final name = nameFor(line);
    return await _readBundled(name, voice) ?? await _readDisk(name, voice);
  }

  /// Remembers audio that was bought, so the next launch does not buy it again.
  ///
  /// Only ever writes to disk. The bundle is built by the generator and is
  /// read-only at runtime.
  Future<void> keep(String line, String voice, Uint8List audio) async {
    final directory = await _resolveDirectory();
    if (directory == null || audio.isEmpty) return;
    try {
      final file = File('${directory.path}/voice/$voice/${nameFor(line)}.mp3');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(audio, flush: true);
    } on Object catch (_) {
      // A full disk, a sandbox that refuses, a web build with no filesystem.
      // Costs a repeat purchase next launch and nothing else — never a screen.
    }
  }

  Future<Uint8List?> _readBundled(String name, String voice) async {
    try {
      final data = await _loadAsset('assets/voice/$voice/$name.mp3');
      // OFFSET AND LENGTH, NOT THE WHOLE BUFFER. `asUint8List()` with no
      // arguments hands back a view over the entire underlying ByteBuffer
      // rather than this ByteData's own range. Identical today, because
      // `rootBundle.load` happens to return a ByteData sized exactly to the
      // asset — but if that ever stops being true the clip gains bytes at one
      // end, and the failure is either a refusal to decode or an audible click,
      // with nothing in this path to report it. Raised by release-engineer
      // on #462.
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on Object catch (_) {
      // Not a bundled sentence — the ordinary answer for anything carrying a
      // Cook's own numbers, and for a line whose Arabic has been edited since
      // the clips were last generated.
      return null;
    }
  }

  Future<Uint8List?> _readDisk(String name, String voice) async {
    final directory = await _resolveDirectory();
    if (directory == null) return null;
    try {
      final file = File('${directory.path}/voice/$voice/$name.mp3');
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      // A truncated write — the app was killed mid-save — is not audio. Refuse
      // it rather than handing the player something it cannot decode.
      return bytes.isEmpty ? null : bytes;
    } on Object catch (_) {
      return null;
    }
  }

  /// ponytail: the disk store is never pruned, and the first version of this
  /// note undercounted what that means.
  ///
  /// It holds a sentence per (Meal count, published count) pair a Cook passes
  /// through — **and one per Meal she asks the row to read aloud**, which was
  /// missed because `mealRowSemanticLabel` is named like a screen-reader label
  /// and is in fact spoken. That second set grows with her Meals rather than
  /// with her counts, and a renamed or re-priced Meal is a new sentence with a
  /// new hash, so the old one is left behind.
  ///
  /// At roughly 50 KB each it still settles in the low megabytes for a Cook
  /// with tens of Meals — but it grows with editing rather than converging.
  /// Found by localization-reviewer on #462. Add a size cap here when a
  /// device complains; nothing above this class needs to change for that.
  Future<Directory?> _resolveDirectory() async {
    if (_directoryResolved) return _directory;
    _directoryResolved = true;
    try {
      _directory = await _cacheDirectory();
    } on Object catch (_) {
      // No filesystem to speak of. Bundled clips still work; runtime ones are
      // bought again each launch, which is what happened before this existed.
      _directory = null;
    }
    return _directory;
  }
}
