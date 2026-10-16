import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/reveal.dart';

/// Calm confirmation (no confetti, no exclamation, as the visual direction
/// asks): a soft disc whose check draws itself in, title, text and actions.
class DoneView extends StatefulWidget {
  const DoneView({
    super.key,
    required this.title,
    required this.text,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.icon,
    this.extra,
  });

  final String title;
  final String text;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  /// Replaces the check with an icon (e.g. the report flag).
  final IconData? icon;

  /// Drawn under the text (a summary card).
  final Widget? extra;

  @override
  State<DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends State<DoneView> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onPrimary();
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Padding(
            padding: EdgeInsets.fromLTRB(20, pad.top + 20, 20, AppSpacing.bottom + pad.bottom - 8),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Reveal(scaleFrom: .9, child: _Disc(icon: widget.icon)),
                const SizedBox(height: 28),
                Reveal(
                  delay: const Duration(milliseconds: 260),
                  child: BalancedText(widget.title, style: AppType.display(size: 28)),
                ),
                const SizedBox(height: 10),
                Reveal(
                  delay: const Duration(milliseconds: 340),
                  child: BalancedText(widget.text, style: AppType.body(size: 16)),
                ),
                if (widget.extra != null) ...[
                  const SizedBox(height: 24),
                  Reveal(delay: const Duration(milliseconds: 420), child: widget.extra!),
                ],
                const Spacer(flex: 4),
                Reveal(
                  delay: const Duration(milliseconds: 500),
                  child: Column(
                    children: [
                      PrimaryButton(label: widget.primary, icon: null, onPressed: widget.onPrimary),
                      if (widget.secondary != null) ...[
                        const SizedBox(height: 4),
                        GhostButton(label: widget.secondary!, onPressed: widget.onSecondary),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({this.icon});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(color: AppColors.petroleo50, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: AppColors.petroleo600, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 30, color: AppColors.white)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: AppMotion.smooth,
                builder: (context, t, _) => CustomPaint(size: const Size(30, 30), painter: _Check(t)),
              ),
      ),
    );
  }
}

class _Check extends CustomPainter {
  _Check(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .18, s.height * .52)
      ..lineTo(s.width * .41, s.height * .74)
      ..lineTo(s.width * .84, s.height * .28);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_Check old) => old.t != t;
}
