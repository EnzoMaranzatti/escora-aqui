import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/svg_icon.dart';
import '../onboarding/onboarding_state.dart';
import 'causes_screen.dart';
import 'step_scaffold.dart';

/// Screen 10 (step 2 of 5): how the person wants to help.
/// Multiple choice; "Continuar" waits for at least one option.
class HelpTypeScreen extends StatefulWidget {
  const HelpTypeScreen({super.key});

  @override
  State<HelpTypeScreen> createState() => _HelpTypeScreenState();
}

class _HelpTypeScreenState extends State<HelpTypeScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: onboarding,
      builder: (context, _) => StepScaffold(
        step: 2,
        hero: _ChoiceHero(selected: onboarding.helpTypes),
        title: 'Como você quer ajudar?',
        subtitle: 'Escolha uma ou mais. Dá para mudar depois.',
        skipLabel: 'Pular',
        onSkip: _next,
        content: Column(
          children: [
            for (final t in HelpType.values) ...[
              _HelpOption(type: t, selected: onboarding.helpTypes.contains(t), onTap: () => onboarding.toggleHelp(t)),
              if (t != HelpType.values.last) const SizedBox(height: 10),
            ],
          ],
        ),
        primaryLabel: 'Continuar',
        onPrimary: onboarding.helpTypes.isEmpty ? null : _next,
      ),
    );
  }

  void _next() => context.push(const CausesScreen());
}

extension on HelpType {
  String get icon => switch (this) {
    HelpType.pix => Ic.money,
    HelpType.itens => Ic.bag,
    HelpType.voluntariado => Ic.usersGroup,
  };
}

/// Three tilted tiles, one per way to help, floating gently. Each one
/// lights up in petróleo when its option is picked below.
class _ChoiceHero extends StatefulWidget {
  const _ChoiceHero({required this.selected});

  final Set<HelpType> selected;

  @override
  State<_ChoiceHero> createState() => _ChoiceHeroState();
}

class _ChoiceHeroState extends State<_ChoiceHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const tilt = [-8.0, 0.0, 8.0];
    const lift = [6.0, -6.0, 6.0];
    return SizedBox(
      height: 96,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, t) in HelpType.values.indexed) ...[
              if (i > 0) const SizedBox(width: 14),
              Transform.translate(
                offset: Offset(0, lift[i] + 3 * math.sin((_c.value + i / 3) * 2 * math.pi)),
                child: Transform.rotate(
                  angle: tilt[i] * math.pi / 180,
                  child: _HeroTile(icon: t.icon, on: widget.selected.contains(t)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.icon, required this.on});

  final String icon;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: on ? 1.08 : 1,
      duration: AppMotion.slow,
      curve: AppMotion.pop,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.smooth,
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.petroleo600 : AppColors.cinza50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: on ? AppColors.petroleo600 : AppColors.cinza100),
          boxShadow: [
            BoxShadow(
              color: (on ? AppColors.petroleo600 : AppColors.cinza900).withValues(alpha: on ? .28 : .04),
              blurRadius: on ? 20 : 8,
              offset: Offset(0, on ? 8 : 2),
            ),
          ],
        ),
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: on ? AppColors.white : AppColors.cinza400),
          duration: AppMotion.medium,
          builder: (context, c, _) => SvgIcon(icon, size: 30, color: c),
        ),
      ),
    );
  }
}

class _HelpOption extends StatelessWidget {
  const _HelpOption({required this.type, required this.selected, required this.onTap});

  final HelpType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      label: '${type.label}. ${type.description}',
      child: Pressable(
        onTap: onTap,
        scale: .98,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.petroleo600 : AppColors.cinza100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.cinza900.withValues(alpha: selected ? .08 : .04),
                blurRadius: selected ? 18 : 10,
                offset: Offset(0, selected ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.medium,
                curve: AppMotion.smooth,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.petroleo50 : AppColors.cinza50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: selected ? AppColors.petroleo600 : AppColors.cinza700),
                  duration: AppMotion.medium,
                  builder: (context, c, _) => SvgIcon(type.icon, size: 22, color: c),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: AppType.cardTitle(size: 16, color: AppColors.cinza900)),
                    const SizedBox(height: 4),
                    Text(type.description, style: AppType.body(size: 13.5).copyWith(height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CheckMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circle that fills from the center while its check draws itself in.
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: AppMotion.slow,
      curve: AppMotion.smooth,
      builder: (context, t, _) => SizedBox.square(dimension: 24, child: CustomPaint(painter: _CheckPainter(t))),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r - .75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(AppColors.cinza300, AppColors.petroleo600, t)!,
    );
    if (t == 0) return;
    // Fill grows from the center with a slight overshoot.
    canvas.drawCircle(c, r * AppMotion.pop.transform(math.min(1, t * 1.6)), Paint()..color = AppColors.petroleo600);
    // The check draws itself in the second half.
    final k = ((t - .35) / .65).clamp(0.0, 1.0);
    if (k == 0) return;
    final path = Path()
      ..moveTo(size.width * .29, size.height * .52)
      ..lineTo(size.width * .44, size.height * .66)
      ..lineTo(size.width * .72, size.height * .37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}
