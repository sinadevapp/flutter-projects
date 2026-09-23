import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Picks one photo from the gallery, ready to store in a row.
///
/// Returns null when the coach cancels — which is how "no photo" is set, and
/// must not be confused with a failure.
///
/// The resize bounds are the whole point. `image_picker` decodes and scales
/// *before* handing the bytes back, so a 12-megapixel gallery photo arrives at
/// most 512px on its long edge and about 40 kB instead of 5 MB — which matters
/// because these bytes go straight into SQLite on every platform, including
/// the browser.
Future<Uint8List?> pickStudentPhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 70,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
