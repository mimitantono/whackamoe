import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// Draws a cute mole emerging from a hole.
class MolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final bodyPaint = Paint()..color = const Color(0xFF8B5E3C);
    final darkPaint = Paint()..color = const Color(0xFF5C3A1E);
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final nosePaint = Paint()..color = const Color(0xFFFF8FAB);
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.7);

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.72), width: w * 0.78, height: h * 0.55),
      bodyPaint,
    );

    // Head
    canvas.drawCircle(Offset(cx, h * 0.38), w * 0.36, bodyPaint);

    // Ears
    canvas.drawCircle(Offset(cx - w * 0.28, h * 0.18), w * 0.13, darkPaint);
    canvas.drawCircle(Offset(cx + w * 0.28, h * 0.18), w * 0.13, darkPaint);
    canvas.drawCircle(Offset(cx - w * 0.28, h * 0.18), w * 0.07, nosePaint);
    canvas.drawCircle(Offset(cx + w * 0.28, h * 0.18), w * 0.07, nosePaint);

    // Eyes (white sclera + pupil + shine)
    canvas.drawCircle(Offset(cx - w * 0.15, h * 0.33), w * 0.11, whitePaint);
    canvas.drawCircle(Offset(cx + w * 0.15, h * 0.33), w * 0.11, whitePaint);
    canvas.drawCircle(Offset(cx - w * 0.13, h * 0.33), w * 0.07, blackPaint);
    canvas.drawCircle(Offset(cx + w * 0.17, h * 0.33), w * 0.07, blackPaint);
    canvas.drawCircle(Offset(cx - w * 0.10, h * 0.30), w * 0.025, shinePaint);
    canvas.drawCircle(Offset(cx + w * 0.20, h * 0.30), w * 0.025, shinePaint);

    // Snout
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.47), width: w * 0.30, height: h * 0.13),
      Paint()..color = const Color(0xFF6B4226),
    );

    // Nose
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.44), width: w * 0.14, height: h * 0.07),
      nosePaint,
    );

    // Smile
    final mouthPath = Path()
      ..moveTo(cx - w * 0.09, h * 0.50)
      ..quadraticBezierTo(cx, h * 0.56, cx + w * 0.09, h * 0.50);
    canvas.drawPath(
      mouthPath,
      Paint()
        ..color = darkPaint.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..strokeCap = StrokeCap.round,
    );

    // Paws
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.38, h * 0.70), width: w * 0.20, height: h * 0.12),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.38, h * 0.70), width: w * 0.20, height: h * 0.12),
      bodyPaint,
    );
    for (int i = -1; i <= 1; i++) {
      final clawPaint = Paint()
        ..color = darkPaint.color
        ..strokeWidth = w * 0.015
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx - w * 0.38 + i * w * 0.055, h * 0.68),
        Offset(cx - w * 0.38 + i * w * 0.055, h * 0.75),
        clawPaint,
      );
      canvas.drawLine(
        Offset(cx + w * 0.38 + i * w * 0.055, h * 0.68),
        Offset(cx + w * 0.38 + i * w * 0.055, h * 0.75),
        clawPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Draws a hedgehog — similar size/silhouette to mole but spiny back + pointy snout.
class HedgehogPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final bellyPaint = Paint()..color = const Color(0xFFD4A96A);
    final spinePaint = Paint()..color = const Color(0xFF3D2B1F);
    final darkPaint = Paint()..color = const Color(0xFF2A1A0E);
    final blackPaint = Paint()..color = Colors.black;
    final nosePaint = Paint()..color = const Color(0xFF1A0A00);

    // Belly / lower body (cream-coloured)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.74), width: w * 0.68, height: h * 0.48),
      bellyPaint,
    );

    // Spiny upper-back dome
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.46), width: w * 0.82, height: h * 0.60),
      spinePaint,
    );

    // Belly face circle (lighter, overlapping the spine dome)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.54), width: w * 0.52, height: h * 0.44),
      bellyPaint,
    );

    // Spines — short sharp lines radiating from the back dome
    final spineLine = Paint()
      ..color = darkPaint.color
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    final spineCount = 16;
    for (int i = 0; i < spineCount; i++) {
      // Span from ~200° to 340° (top arc of hedgehog)
      final angle = (pi * 1.11) + (i / (spineCount - 1)) * (pi * 0.78);
      final originR = w * 0.36;
      final tipR = w * 0.50;
      final ox = cx + originR * cos(angle);
      final oy = h * 0.46 + originR * 0.72 * sin(angle);
      final tx = cx + tipR * cos(angle);
      final ty = h * 0.46 + tipR * 0.72 * sin(angle);
      canvas.drawLine(Offset(ox, oy), Offset(tx, ty), spineLine);
    }

    // Pointy snout (longer than mole's)
    final snoutPath = Path()
      ..moveTo(cx - w * 0.14, h * 0.50)
      ..quadraticBezierTo(cx, h * 0.38, cx + w * 0.14, h * 0.50)
      ..quadraticBezierTo(cx + w * 0.08, h * 0.56, cx, h * 0.62)
      ..quadraticBezierTo(cx - w * 0.08, h * 0.56, cx - w * 0.14, h * 0.50)
      ..close();
    canvas.drawPath(snoutPath, bellyPaint);

    // Small beady eyes (no white — much smaller than mole's)
    canvas.drawCircle(Offset(cx - w * 0.13, h * 0.45), w * 0.055, blackPaint);
    canvas.drawCircle(Offset(cx + w * 0.13, h * 0.45), w * 0.055, blackPaint);
    // Tiny shine
    canvas.drawCircle(Offset(cx - w * 0.10, h * 0.43), w * 0.018,
        Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.drawCircle(Offset(cx + w * 0.16, h * 0.43), w * 0.018,
        Paint()..color = Colors.white.withValues(alpha: 0.6));

    // Black nose at tip of snout
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.60), width: w * 0.10, height: h * 0.055),
      nosePaint,
    );

    // Tiny feet peeking out
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.30, h * 0.88), width: w * 0.18, height: h * 0.09),
      bellyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.30, h * 0.88), width: w * 0.18, height: h * 0.09),
      bellyPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget that shows either the mole/custom image or a hedgehog (danger).
class HoleCharacter extends StatelessWidget {
  final bool isMole;
  final Uint8List? customImageBytes;
  final double size;

  const HoleCharacter({
    super.key,
    required this.isMole,
    required this.size,
    this.customImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (!isMole) {
      return CustomPaint(
        size: Size(size, size),
        painter: HedgehogPainter(),
      );
    }
    if (customImageBytes != null) {
      return ClipOval(
        child: Image.memory(
          customImageBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return CustomPaint(
      size: Size(size, size),
      painter: MolePainter(),
    );
  }
}
