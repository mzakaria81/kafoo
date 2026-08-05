import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Picks a kitchen photo and returns its bytes, or null if the person backed
/// out. Injected as a function so the summary can be tested without a platform
/// channel, and so the picker can be swapped without touching the screen.
typedef PickPhoto = Future<Uint8List?> Function();

/// The default picker: one image from the device gallery.
Future<Uint8List?> pickPhotoFromGallery() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
