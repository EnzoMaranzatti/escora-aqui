import 'package:flutter/widgets.dart';

import '../assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'pressable.dart';
import 'svg_icon.dart';

/// Top bar of the signup flow: segments that fill as the steps advance,
/// beside a round back button.
class SegmentProgress extends StatelessWidget {
  const SegmentProgress({super.key, required this.count, required this.position, this.onBack});

  final int count;

  /// Current page as a double, so the fill follows the finger mid-swipe.
  final double position;

  /// Shown only when not null.
  final VoidCallback? onBack;

  static const _button = RoundBackButton.size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Etapa ${position.round() + 1} de $count',
      child: SizedBox(
        height: _button,
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.slow,
              curve: AppMotion.smooth,
              width: onBack == null ? 0 : _button + 10,
              // No clip: it would cut the button's shadow into a square.
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: _button,
                maxWidth: _button,
                child: AnimatedOpacity(
                  duration: AppMotion.medium,
                  opacity: onBack == null ? 0 : 1,
                  child: RoundBackButton(onTap: onBack),
                ),
              ),
            ),
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cinza900.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (position - i + 1).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.cinza900, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round white back button (signup top bar and intro).
class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, this.onTap});

  static const size = 40.0;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voltar',
      child: Pressable(
        onTap: onTap,
        scale: .92,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: const SvgIcon(Ic.arrowLeftSm, size: 20),
        ),
      ),
    );
  }
}

/// Carousel pagination: small pills where the current one stretches,
/// following the finger mid-swipe.
class PagePills extends StatelessWidget {
  const PagePills({super.key, required this.count, required this.position});

  final int count;
  final double position;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Página ${position.round() + 1} de $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Builder(
              builder: (context) {
                // 1 on the current page, 0 one page away.
                final k = (1 - (position - i).abs()).clamp(0.0, 1.0);
                return Container(
                  width: 8 + 16 * k,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color.lerp(AppColors.cinza200, AppColors.cinza900, k),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
