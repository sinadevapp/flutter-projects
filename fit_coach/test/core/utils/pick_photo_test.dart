import 'package:fit_coach/core/utils/pick_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../../helpers/fake_gallery.dart';

void main() {
  late FakeGallery gallery;

  setUp(() {
    gallery = FakeGallery(XFile.fromData(tinyPng()));
    installGallery(gallery);
  });
  tearDown(restoreGallery);

  test('reads back the bytes the gallery chose', () async {
    final picked = await pickStudentPhoto();

    expect(picked, isNotNull);
    expect(picked, tinyPng());
    expect(gallery.source, ImageSource.gallery);
  });

  test('asks for a bounded, compressed image — the whole point of it', () async {
    await pickStudentPhoto();

    // These three are what keep a 12-megapixel gallery photo out of SQLite at
    // about 40 kB instead of 5 MB. They are applied on the picker's side, so
    // the only way to know they were asked for is to ask the picker — which is
    // exactly the contract no test could check before this.
    expect(gallery.maxWidth, 512);
    expect(gallery.maxHeight, 512);
    expect(gallery.imageQuality, 70);
  });

  test('cancelling returns null rather than throwing', () async {
    installGallery(FakeGallery());

    expect(await pickStudentPhoto(), isNull);
  });
}
