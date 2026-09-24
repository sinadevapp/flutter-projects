import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// A real 1×1 PNG — small enough to hand round, real enough to decode.
///
/// Bytes that are not an image make `MemoryImage` throw "Invalid image data",
/// so anything reaching a widget needs to actually be one.
Uint8List tinyPng() => Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );

/// A gallery that returns [result] and records what it was asked for.
///
/// Overrides `getImage`, not `getImageFromSource`: the base class implements
/// the latter by forwarding to the former, so one override covers both the
/// path `ImagePicker.pickImage` takes and the options it carries.
class FakeGallery extends ImagePickerPlatform {
  FakeGallery([this.result]);

  final XFile? result;
  ImageSource? source;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) {
    this.source = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    return Future.value(result);
  }
}

/// The gallery the app would otherwise talk to, saved for [restoreGallery].
///
/// Captured rather than reconstructed: the default is a `MethodChannel`
/// instance and rebuilding it would be guessing at the package's own choice.
final ImagePickerPlatform originalGallery = ImagePickerPlatform.instance;

void installGallery(FakeGallery gallery) =>
    ImagePickerPlatform.instance = gallery;

void restoreGallery() => ImagePickerPlatform.instance = originalGallery;
