import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'mole_painter.dart';

class HoleWidget extends StatefulWidget {
  final HoleContent content;
  final Uint8List? customImageBytes;
  final bool customImageIsSegmented;
  final void Function(HoleContent) onTap;

  const HoleWidget({
    super.key,
    required this.content,
    required this.onTap,
    this.customImageBytes,
    this.customImageIsSegmented = false,
  });

  @override
  State<HoleWidget> createState() => _HoleWidgetState();
}

class _HoleWidgetState extends State<HoleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<double> _scaleAnim;
  HoleContent _displayed = HoleContent.empty;
  bool _whacked = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(HoleWidget old) {
    super.didUpdateWidget(old);
    if (widget.content == old.content) return;

    if (widget.content != HoleContent.empty) {
      _whacked = false;
      setState(() => _displayed = widget.content);
      _ctrl.forward(from: 0);
    } else if (!_whacked) {
      _ctrl.reverse().then((_) {
        if (mounted) setState(() => _displayed = HoleContent.empty);
      });
    }
  }

  void _handleTap() {
    if (_displayed == HoleContent.empty || _whacked) return;
    _whacked = true;
    widget.onTap(_displayed);
    _ctrl.animateTo(0, duration: const Duration(milliseconds: 120), curve: Curves.easeIn).then((_) {
      if (mounted) setState(() => _displayed = HoleContent.empty);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fill the full available space so the mole's head is always tappable.
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // Hole sits in the bottom 25% of the total height.
      final holeH = h * 0.25;
      final holeW = w * 0.90;
      // Character is sized relative to width.
      final charSize = w * 0.78;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Hole background — anchored to bottom
              Positioned(
                bottom: 0,
                left: (w - holeW) / 2,
                child: _HoleBackground(width: holeW, height: holeH),
              ),
              // Character slides up out of the hole
              if (_displayed != HoleContent.empty)
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final slide = _slideAnim.value;
                    final scale = _whacked
                        ? _ctrl.value
                        : (0.6 + 0.4 * _scaleAnim.value).clamp(0.0, 1.2);
                    // Bottom of character rises from inside the hole to above it.
                    final charBottom = holeH * 0.2 + slide * (charSize * 0.80);
                    return Positioned(
                      bottom: charBottom,
                      left: (w - charSize) / 2,
                      child: Transform.scale(
                        scale: scale,
                        child: HoleCharacter(
                          isMole: _displayed == HoleContent.mole,
                          customImageBytes: widget.customImageBytes,
                          customImageIsSegmented: widget.customImageIsSegmented,
                          size: charSize,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _HoleBackground extends StatelessWidget {
  final double width;
  final double height;

  const _HoleBackground({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _HolePainter(),
    );
  }
}

class _HolePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Dirt rim
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
      Paint()..color = const Color(0xFF6B4226),
    );
    // Dark inner hole
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: w * 0.80, height: h * 0.64),
      Paint()..color = const Color(0xFF1A0A00),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
