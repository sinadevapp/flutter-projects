import 'dart:io';

import 'package:fit_coach/tool/app_icon.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regenerates the launcher icon.
///
/// It lives under `test/` because drawing with `dart:ui` needs the Flutter
/// engine, and `flutter test` is the way to get one without launching an app.
/// Running this is a deliberate act, not part of the suite: it writes a file,
/// and a normal `flutter test` must stay side-effect free. It is skipped
/// unless the environment asks for it:
///
///     GENERATE_ICON=1 flutter test test/tool/generate_icon_test.dart
void main() {
  test('writes assets/icon/app_icon.png', () async {
    final bytes = await renderAppIcon();

    // A 1024x1024 PNG is tens of kilobytes; anything tiny means the canvas
    // came out blank and the icon would ship as an empty square.
    expect(bytes.length, greaterThan(3000));

    final out = File('assets/icon/app_icon.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);

    // PNG magic number, so a failed encode cannot ship as a broken asset.
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  }, skip: Platform.environment['GENERATE_ICON'] != '1');
}
