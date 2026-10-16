import 'package:flutter/material.dart';

import '../assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';
import 'svg_icon.dart';

/// Main CTA: petróleo 600 with the soft bevel from Figma
/// (inset highlight on top, inset shade at the bottom).
/// Passing a null [onPressed] renders the disabled state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = _defaultIcon,
    this.loading = false,
  });

  static const _defaultIcon = 'assets/icons/arrow_right.svg';

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final fg = _enabled || loading ? AppColors.white : AppColors.cinza500;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: Pressable(
        onTap: _enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          height: 56,
          decoration: BoxDecoration(
            color: _enabled || loading ? AppColors.petroleo600 : AppColors.cinza200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            foregroundPainter: _BevelPainter(visible: _enabled || loading),
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                switchInCurve: AppMotion.smooth,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(a), child: child),
                ),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.white),
                      )
                    : Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label, style: AppType.label(color: fg)),
                          if (icon != null) ...[
                            const SizedBox(width: 8),
                            SvgIcon(icon!, size: icon == _defaultIcon ? 24 : 20, color: fg),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BevelPainter extends CustomPainter {
  _BevelPainter({required this.visible});

  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.save();
    canvas.clipRRect(rrect);
    _inset(canvas, rrect, const Offset(0, 2), AppColors.petroleo300);
    _inset(canvas, rrect, const Offset(0, -2), AppColors.petroleo800.withValues(alpha: .65));
    canvas.restore();
  }

  // Inset shadow: paint a ring outside the shifted shape and blur it inward.
  void _inset(Canvas canvas, RRect rrect, Offset offset, Color color) {
    final outer = Path()..addRect(rrect.outerRect.inflate(20));
    final hole = Path()..addRRect(rrect.shift(offset));
    final ring = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
  }

  @override
  bool shouldRepaint(_BevelPainter old) => old.visible != visible;
}

/// Text-only secondary action ("Pular", "Escolher cidade").
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon, this.iconSize = 20});

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppType.label()),
              if (icon != null) ...[const SizedBox(width: 8), SvgIcon(icon!, size: iconSize)],
            ],
          ),
        ),
      ),
    );
  }
}

/// White and outlined buttons used on the petróleo cover.
class CoverButton extends StatelessWidget {
  const CoverButton({super.key, required this.label, required this.onPressed, this.filled = true});

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.white : null,
          borderRadius: BorderRadius.circular(16),
          border: filled ? null : Border.all(color: AppColors.white.withValues(alpha: .2)),
        ),
        child: Text(label, style: AppType.label(color: filled ? const Color(0xFF323232) : AppColors.white)),
      ),
    );
  }
}

/// Outlined "Continuar com Google" (create account and login).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.cinza200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        foregroundColor: AppColors.cinza800,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Continuar com Google', style: AppType.label()),
          const SizedBox(width: 8),
          const SvgIcon(Ic.google, width: 16, height: 16.33),
        ],
      ),
    );
  }
}
