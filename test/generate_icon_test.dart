import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whackamoe/widgets/mole_painter.dart';

// Run once to produce assets/icon/icon.png, then run:
//   dart run flutter_launcher_icons
void main() {
  testWidgets('render hedgehog icon to PNG', (tester) async {
    const double size = 1024;
    const double padding = size * 0.10;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, size, size),
    );

    // Dark background matching the app theme
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFF0D0D1A),
    );

    // Hedgehog centred with breathing room on all sides
    canvas.save();
    canvas.translate(padding, padding);
    HedgehogPainter().paint(
      canvas,
      const Size(size - padding * 2, size - padding * 2),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    // tester.runAsync escapes the fake-async environment so GPU image ops complete.
    final image = await tester.runAsync(() => picture.toImage(size.toInt(), size.toInt()));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));

    final outFile = File('assets/icon/icon.png');
    outFile.createSync(recursive: true);
    outFile.writeAsBytesSync(byteData!.buffer.asUint8List());

    expect(outFile.existsSync(), isTrue);
    expect(outFile.lengthSync(), greaterThan(0));
  });
}
