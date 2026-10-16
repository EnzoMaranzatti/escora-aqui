import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'svg_icon.dart';

/// Account-creation progress ("Component 1" in Figma).
///
/// 5 tall bars mark the steps, with 5 thin ticks between each. Moving to a
/// new step fills the ticks one after another, like a wave, while each one
/// changes color and gives a small hop. When [complete] turns true, the
/// ticks shrink into dots, gather at the center and turn into a check badge.
class StepProgress extends StatefulWidget {
  const StepProgress({super.key, required this.step, this.fromStep, this.complete = false, this.onCompleted});

  /// Current step, 1 to 5.
  final int step;

  /// Step to animate from when the widget first appears (previous screen).
  final int? fromStep;

  final bool complete;
  final VoidCallback? onCompleted;

  static const steps = 5;

  @override
  State<StepProgress> createState() => _StepProgressState();
}

class _StepProgressState extends State<StepProgress> with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _done;
  late Animation<double> _fillValue;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _done = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onCompleted?.call();
      });
    final from = (widget.fromStep ?? widget.step) - 1.0;
    _animateTo(from, widget.step - 1.0, delay: const Duration(milliseconds: 280));
    if (widget.complete) _done.forward();
  }

  void _animateTo(double from, double to, {Duration delay = Duration.zero}) {
    _fillValue = Tween(begin: from, end: to).animate(CurvedAnimation(parent: _fill, curve: Curves.easeInOutCubic));
    _fill.value = 0;
    Future.delayed(delay, () {
      if (mounted) _fill.forward();
    });
  }

  @override
  void didUpdateWidget(StepProgress old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) _animateTo(_fillValue.value, widget.step - 1.0);
    if (widget.complete && !old.complete) _done.forward(from: 0);
    if (!widget.complete && old.complete) _done.value = 0;
  }

  @override
  void dispose() {
    _fill.dispose();
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Passo ${widget.step} de ${StepProgress.steps}',
      child: SizedBox(
        width: _ProgressPainter.totalWidth,
        height: 40,
        child: AnimatedBuilder(
          animation: Listenable.merge([_fill, _done]),
          builder: (context, _) {
            final c = _done.value;
            final check = AppMotion.pop.transform(const Interval(.62, 1).transform(c));
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: const Size(_ProgressPainter.totalWidth, 40),
                  painter: _ProgressPainter(fill: _fillValue.value, complete: c),
                ),
                if (check > 0)
                  Transform.rotate(
                    angle: (1 - check) * -math.pi / 2,
                    child: Transform.scale(
                      scale: check,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(color: AppColors.ocre300, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const SvgIcon(Ic.checkWhite, size: 14),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.fill, required this.complete});

  final double fill;
  final double complete;

  static const count = 25;
  static const gap = 8.0;
  static const totalWidth = 5 * 8.0 + 20 * 4.0 + (count - 1) * gap;

  @override
  void paint(Canvas canvas, Size size) {
    final shrink = Curves.easeInOutCubic.transform(const Interval(0, .4).transform(complete));
    final gather = Curves.easeInCubic.transform(const Interval(.35, .75).transform(complete));
    final fade = const Interval(.6, .8).transform(complete);
    final centerX = size.width / 2;
    final midY = size.height / 2;
    final paint = Paint();

    var x = 0.0;
    for (var i = 0; i < count; i++) {
      final big = i % 6 == 0;
      final w = big ? 8.0 : 4.0;
      final t = i / 6;
      final lit = ((fill - t) * 6 + 1).clamp(0.0, 1.0);
      final hop = math.sin(math.pi * lit) * 5;

      final baseH = (big ? 40.0 : 24.0) + hop;
      final h = baseH + (w - baseH) * shrink;
      final cx = x + w / 2;
      final drawX = cx + (centerX - cx) * gather;

      final on = big ? AppColors.ocre300 : AppColors.ocre100;
      final color = Color.lerp(AppColors.cinza100, on, lit)!;
      paint.color = color.withValues(alpha: color.a * (1 - fade));

      final rect = Rect.fromCenter(center: Offset(drawX, midY), width: w, height: h);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), paint);
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) => old.fill != fill || old.complete != complete;
}
