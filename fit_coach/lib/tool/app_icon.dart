import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws the FitCoach launcher icon.
///
/// Prefers a runtime read of [ui.Image] over a committed binary so that a
/// change to the brand teal can be followed here in one line. The dumbbell is
/// built from rounded rectangles — deliberately no glyph, because a font is
/// not guaranteed to be loaded when this runs, and a launcher icon must never
/// depend on one.
///
/// See `test/tool/generate_icon_test.dart` for how to run it (it needs the
/// Flutter engine, so it is not a plain `dart run`).
const int iconSize = 1024;

/// FitCoach's brand teal, matching `AppTheme.seed`.
const ui.Color _background = ui.Color(0xFF0F766E);

/// White, for contrast against the teal at every launcher size.
const ui.Color _foreground = ui.Color(0xFFFFFFFF);

/// Renders the icon and returns the encoded PNG bytes.
Future<Uint8List> renderAppIcon({int size = iconSize}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
  );

  _paint(canvas, size.toDouble());

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  if (data == null) {
    throw StateError('The icon could not be encoded to PNG.');
  }
  return data.buffer.asUint8List();
}

void _paint(ui.Canvas canvas, double s) {
  final center = s / 2;

  // Full bleed: Android masks the icon itself, so padding here would shrink
  // the plate inside the mask and leave the mark looking lost.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, s, s),
    ui.Paint()..color = _background,
  );

  final platePaint = ui.Paint()..color = _foreground;

  // The bar of the dumbbell.
  final barHeight = s * 0.075;
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: ui.Offset(center, center),
        width: s * 0.42,
        height: barHeight,
      ),
      ui.Radius.circular(barHeight / 2),
    ),
    platePaint,
  );

  // Two plates a side: tall then short, which is what makes the shape read as
  // a dumbbell rather than a cross.
  final plateWidth = s * 0.075;
  final innerGap = s * 0.055;

  void plate(double dx, double heightFactor) {
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromCenter(
          center: ui.Offset(center + dx, center),
          width: plateWidth,
          height: s * heightFactor,
        ),
        ui.Radius.circular(plateWidth * 0.4),
      ),
      platePaint,
    );
  }

  for (final side in [-1.0, 1.0]) {
    plate(side * (s * 0.21 + innerGap), 0.34);
    plate(side * (s * 0.21 + innerGap * 2 + plateWidth), 0.22);
  }
}
