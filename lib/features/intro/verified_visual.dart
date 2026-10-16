import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/orbit.dart';
import '../../core/widgets/svg_icon.dart';

/// Screen 5. Icons float around two rings while the circular
/// "Instituição verificada" text turns at the same speed. The stack of
/// cards deals itself in, the "Verificada" chip pops and the numbers count up.
class VerifiedVisual extends StatefulWidget {
  const VerifiedVisual({super.key, required this.active});

  final bool active;

  @override
  State<VerifiedVisual> createState() => _VerifiedVisualState();
}

class _VerifiedVisualState extends State<VerifiedVisual> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 48));
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  static const _center = Offset(196, 210);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VerifiedVisual old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (_enter.isDismissed) _enter.forward();
      _spin.repeat();
      _float.repeat();
    } else {
      _spin.stop();
      _float.stop();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _spin.dispose();
    _float.dispose();
    super.dispose();
  }

  double _e(double a, double b, [Curve c = AppMotion.smooth]) => c.transform(Interval(a, b).transform(_enter.value));

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed warm glow (a gradient, not a live blur): no hard
        // edges and nearly free to draw.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.05),
              radius: .85,
              colors: [AppColors.ocre100, AppColors.ocre50, AppColors.white],
              stops: [0, .45, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [.75, 1],
              colors: [Color(0x00FFFFFF), AppColors.white],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _enter,
          builder: (context, _) {
            final rings = _e(0, .35);
            return DesignCanvas(
              width: 390,
              height: 426,
              children: [
                Positioned.fill(
                  child: Orbit(
                    turns: _spin,
                    center: _center,
                    background: [
                      for (final d in [450.0, 320.0])
                        Positioned(
                          left: _center.dx - d / 2,
                          top: _center.dy - d / 2,
                          child: Opacity(
                            opacity: rings,
                            child: Transform.scale(
                              scale: .85 + .15 * rings,
                              child: Ring(diameter: d, width: d == 450 ? 1.2 : 1),
                            ),
                          ),
                        ),
                      Positioned(
                        left: _center.dx - 76,
                        top: _center.dy - 78,
                        child: _Seal(spin: _spin, appear: _e(.1, .5, AppMotion.pop)),
                      ),
                    ],
                    items: [
                      for (final (i, (icon, r, a)) in const [
                        (Ic.schoolDark, 160.0, -26.6),
                        (Ic.starOutline, 225.0, -57.9),
                        (Ic.medal, 157.0, -117.0),
                        (Ic.starShining, 227.0, -150.7),
                        (Ic.handsHeart, 155.0, 167.7),
                        (Ic.heartMedicineDark, 219.0, 45.0),
                      ].indexed)
                        OrbitItem(
                          radius: r,
                          angleDeg: a,
                          bob: 3,
                          child: _Bubble(icon: icon, appear: _e(.2 + i * .06, .55 + i * .06, AppMotion.pop)),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 40,
                  top: 233,
                  width: 310,
                  height: 192,
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (context, child) =>
                        Transform.translate(offset: Offset(0, math.sin(_float.value * 2 * math.pi) * 3), child: child),
                    child: _CardStack(enter: _e),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Seal extends StatelessWidget {
  const _Seal({required this.spin, required this.appear});

  final Animation<double> spin;
  final double appear;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: appear.clamp(0, 1),
      child: Transform.scale(
        scale: appear,
        child: SizedBox(
          width: 152,
          height: 156,
          child: Stack(
            children: [
              RotationTransition(turns: spin, child: const SvgIcon(Brand.circularText, width: 152, height: 156)),
              const Positioned(left: 20, top: 19, child: BrandLogo(size: 113, color: AppColors.petroleo500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.appear});

  final String icon;
  final double appear;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: appear.clamp(0, 1),
      child: Transform.scale(
        scale: appear,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: AppColors.white.withValues(alpha: .7)),
          ),
          child: SvgIcon(icon, size: 24),
        ),
      ),
    );
  }
}

class _CardStack extends StatelessWidget {
  const _CardStack({required this.enter});

  final double Function(double a, double b, [Curve c]) enter;

  @override
  Widget build(BuildContext context) {
    final back = enter(.35, .7);
    final mid = enter(.4, .76);
    final front = enter(.45, .85);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _deal(back, 30, 61, 249, 131, 60),
        _deal(mid, 15, 32, 280, 147, 50),
        Positioned(
          left: 0,
          top: 0,
          child: Opacity(
            opacity: front,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - front)),
              child: Transform.rotate(
                angle: -.05 * (1 - front),
                child: Transform.scale(
                  scale: .92 + .08 * front,
                  child: _FrontCard(enter: enter),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _deal(double t, double l, double top, double w, double h, double dy) => Positioned(
    left: l,
    top: top,
    child: Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, dy * (1 - t)),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
          ),
        ),
      ),
    ),
  );
}

class _FrontCard extends StatelessWidget {
  const _FrontCard({required this.enter});

  final double Function(double a, double b, [Curve c]) enter;

  @override
  Widget build(BuildContext context) {
    final chip = enter(.7, .9, AppMotion.pop);
    final sign = enter(.72, 1);
    final count = enter(.7, 1, Curves.easeOutCubic);
    return Container(
      width: 310,
      height: 163,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 167,
            top: 36,
            child: Opacity(
              opacity: sign,
              child: Transform.scale(scale: .8 + .2 * sign, child: const SvgIcon(Ic.signCheck, size: 154)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: chip,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.sucessoFundo, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SvgIcon(Ic.checkSmall, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          'Verificada em 12/09',
                          style: AppType.label(color: AppColors.sucessoTexto, size: 9).copyWith(height: 1),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: Text(
                    'Instituição Santo Dumont',
                    style: AppType.cardTitle(size: 14, color: AppColors.cinza900),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 171,
                  child: Text('CNPJ, endereço e foto do local conferidos pela equipe.', style: AppType.body(size: 10)),
                ),
                const Spacer(),
                SizedBox(
                  width: 170,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Ic.starSmall,
                          value: (4.9 * count).toStringAsFixed(1).replaceAll('.', ','),
                          label: 'Pontuação',
                        ),
                      ),
                      Expanded(
                        child: _Stat(icon: Ic.usersSmall, value: '${(32 * count).round()}', label: 'Apoiadores'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgIcon(icon, size: 10),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppType.strong(
                size: 10,
              ).copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppType.body(size: 10, color: AppColors.cinza700).copyWith(height: 1)),
          ],
        ),
      ],
    );
  }
}
