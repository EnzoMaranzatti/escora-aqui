import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/svg_icon.dart';
import '../onboarding/onboarding_state.dart';
import 'notifications_screen.dart';
import 'step_scaffold.dart';

/// Screen 11 (step 3 of 5): causes to follow.
class CausesScreen extends StatefulWidget {
  const CausesScreen({super.key});

  @override
  State<CausesScreen> createState() => _CausesScreenState();
}

class _CausesScreenState extends State<CausesScreen> {
  final _sun = GlobalKey<_SunBuddyState>();

  void _toggle(String c) {
    final adding = !onboarding.selectedCauses.contains(c);
    onboarding.toggleCause(c);
    if (adding) _sun.currentState?.cheer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // The eyes follow wherever the finger touches.
      onPointerDown: (e) => _sun.currentState?.lookAt(e.position),
      onPointerMove: (e) => _sun.currentState?.lookAt(e.position),
      child: ListenableBuilder(
        listenable: onboarding,
        builder: (context, _) => StepScaffold(
          step: 3,
          hero: _SunBuddy(key: _sun, mood: (onboarding.selectedCauses.length / 4).clamp(0.0, 1.0)),
          title: 'O que mais te interessa?',
          subtitle: 'Escolha as causas que quer acompanhar.',
          skipLabel: 'Pular',
          onSkip: _next,
          content: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final c in causes)
                _CauseChip(label: c, selected: onboarding.selectedCauses.contains(c), onTap: () => _toggle(c)),
            ],
          ),
          primaryLabel: 'Continuar',
          onPrimary: onboarding.selectedCauses.isEmpty ? null : _next,
        ),
      ),
    );
  }

  void _next() => context.push(const NotificationsScreen());
}

class _CauseChip extends StatelessWidget {
  const _CauseChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: .94,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          height: 40,
          padding: EdgeInsets.only(left: selected ? 10 : 14, right: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.petroleo600 : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.petroleo600 : AppColors.cinza100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: (selected ? AppColors.petroleo600 : AppColors.cinza900).withValues(alpha: selected ? .22 : .03),
                blurRadius: selected ? 12 : 6,
                offset: Offset(0, selected ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.smooth,
                child: selected
                    ? const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SvgIcon(Ic.checkSmall, size: 14, color: AppColors.white),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedDefaultTextStyle(
                duration: AppMotion.medium,
                style: AppType.label(color: selected ? AppColors.white : AppColors.cinza800, size: 14),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sun buddy, in the flat Figma style: a sun with thin rays that turn and
/// two white eyes that wander, blink and follow the finger. Each picked
/// cause makes it hop, squint and send out a ring; the more causes, the
/// longer and faster the rays.
class _SunBuddy extends StatefulWidget {
  const _SunBuddy({super.key, required this.mood});

  /// 0 (nothing picked) to 1 (several causes).
  final double mood;

  @override
  State<_SunBuddy> createState() => _SunBuddyState();
}

class _SunBuddyState extends State<_SunBuddy> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rand = math.Random();
  Duration _now = Duration.zero;

  double _spin = 0;
  double _mood = 0;
  Offset _look = Offset.zero; // -1..1
  Offset? _touch;
  Duration _touchUntil = Duration.zero;

  double _blink = 0;
  Duration _nextBlink = const Duration(milliseconds: 1400);
  Duration? _blinkStart;
  bool _double = false;

  Duration? _cheerStart;
  double _joy = 0;
  double _hop = 0;
  final _ripples = <Duration>[];

  static const _size = Size(180, 150);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void lookAt(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final d = box.globalToLocal(global) - Offset(box.size.width / 2, 70);
    _touch = Offset((d.dx / 160).clamp(-1.0, 1.0), (d.dy / 220).clamp(-1.0, 1.0));
    _touchUntil = _now + const Duration(milliseconds: 2200);
  }

  void cheer() {
    _cheerStart = _now;
    _ripples.add(_now);
  }

  void _tick(Duration now) {
    final dt = (now - _now).inMicroseconds / 1e6;
    _now = now;
    final t = now.inMicroseconds / 1e6;

    _mood += (widget.mood - _mood) * .06;
    _spin += dt * (.25 + .9 * _mood + 2.2 * _joy);

    final wander = Offset(math.sin(t * .9) * .7 + math.sin(t * 2.3) * .15, math.sin(t * .6 + 1) * .5);
    final target = (_touch != null && now < _touchUntil) ? _touch! : wander;
    _look = Offset.lerp(_look, target, .1)!;

    if (_blinkStart == null && now >= _nextBlink) {
      _blinkStart = now;
      _double = _rand.nextDouble() < .25;
    }
    if (_blinkStart != null) {
      final ms = (now - _blinkStart!).inMilliseconds;
      const cycle = 240;
      final k = ms % cycle / cycle;
      _blink = k < .35 ? Curves.easeIn.transform(k / .35) : 1 - Curves.easeOut.transform((k - .35) / .65);
      if (ms >= cycle * (_double ? 2 : 1)) {
        _blinkStart = null;
        _blink = 0;
        _nextBlink = now + Duration(milliseconds: 2000 + _rand.nextInt(2600));
      }
    }

    if (_cheerStart != null) {
      final ms = (now - _cheerStart!).inMilliseconds;
      _joy = ms < 120 ? ms / 120 : (ms < 800 ? 1 : math.max(0, 1 - (ms - 800) / 300));
      _hop = ms < 520 ? math.sin(ms / 520 * math.pi) : 0;
      if (ms > 1100) _cheerStart = null;
    }
    _ripples.removeWhere((at) => (now - at).inMilliseconds > 1400);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: _size,
      child: CustomPaint(
        painter: _SunPainter(
          t: _now.inMicroseconds / 1e6,
          spin: _spin,
          mood: _mood,
          look: _look,
          blink: _blink,
          joy: _joy,
          hop: _hop,
          ripples: [for (final at in _ripples) (_now - at).inMilliseconds / 1400],
        ),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  _SunPainter({
    required this.t,
    required this.spin,
    required this.mood,
    required this.look,
    required this.blink,
    required this.joy,
    required this.hop,
    required this.ripples,
  });

  final double t;
  final double spin;
  final double mood;
  final Offset look;
  final double blink;
  final double joy;
  final double hop;

  /// Progress 0–1 of each ring sent out by a picked cause.
  final List<double> ripples;

  static const _sun = AppColors.sunshine;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 46.0;
    final bob = 2 * math.sin(t * 1.6);
    final c = Offset(size.width / 2, 72 - 14 * hop + bob);

    // A clean ring opens outward for each picked cause.
    for (final k in ripples) {
      final e = Curves.easeOutCubic.transform(k);
      canvas.drawCircle(
        c,
        r + 8 + 46 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _sun.withValues(alpha: .7 * (1 - k)),
      );
    }

    // Thin geometric rays; longer and brighter as the mood rises.
    final rays = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _sun.withValues(alpha: .45 + .35 * mood);
    for (var i = 0; i < 16; i++) {
      final a = spin + i * math.pi / 8;
      final len = (i.isEven ? 10 : 6) + 6 * mood + 4 * joy;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (r + 8), c + dir * (r + 8 + len), rays);
    }

    // Flat body, squashed a touch on take-off.
    final squash = 1 + .05 * math.sin(hop * math.pi * 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 / squash, squash);
    canvas.drawCircle(Offset.zero, r, Paint()..color = _sun);
    canvas.restore();

    // Two tall white eyes (Figma); they glide with the gaze, blink and
    // squint when a cause is picked.
    final close = math.max(blink, joy * .6);
    final shrink = 1 - look.dx.abs() * .08;
    for (final s in [-1, 1]) {
      final e = c + Offset(s * 15 + look.dx * 9, -6 + look.dy * 6 + joy * 3);
      canvas.drawOval(
        Rect.fromCenter(center: e, width: 12 * shrink * (1 + joy * .08), height: 22 * shrink * (1 - close * .9)),
        Paint()..color = AppColors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) => true;
}
