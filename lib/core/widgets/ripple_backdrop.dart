import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'decor.dart';

/// Quiet background: the warm glow and thin rings used across the flow,
/// plus one hairline wave that opens slowly from the focus point and fades.
class RippleBackdrop extends StatefulWidget {
  const RippleBackdrop({super.key, this.focusY = .42, this.scale = 1});

  /// Vertical center of the glow, rings and wave, as a fraction of height.
  final double focusY;

  /// Size of the rings and wave relative to the screen width.
  final double scale;

  @override
  State<RippleBackdrop> createState() => _RippleBackdropState();
}

class _RippleBackdropState extends State<RippleBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final center = Offset(w / 2, h * widget.focusY);
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, center.dy / h * 2 - 1),
                    radius: .9,
                    colors: const [AppColors.petroleo50, AppColors.white],
                  ),
                ),
              ),
            ),
            for (final d in [w * .95 * widget.scale, w * 1.45 * widget.scale])
              Positioned(
                left: center.dx - d / 2,
                top: center.dy - d / 2,
                child: Ring(diameter: d),
              ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(painter: _WavePainter(center, w * widget.scale, _c.value)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.center, this.width, this.t);

  final Offset center;
  final double width;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final e = Curves.easeOutCubic.transform(t);
    // Fades in quickly, then out as it reaches the outer ring.
    final alpha = math.min(t / .12, 1) * (1 - t);
    canvas.drawCircle(
      center,
      width * (.4 + .35 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.petroleo300.withValues(alpha: .7 * alpha),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}
