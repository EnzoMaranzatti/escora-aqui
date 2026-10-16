import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/orbit.dart';
import '../../core/widgets/svg_icon.dart';
import '../map/pins.dart';
import '../onboarding/onboarding_state.dart';
import 'account_intro_screen.dart';
import 'step_scaffold.dart';

/// Screen 12 (step 4 of 5): ask for notifications, showing the gain first.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _asking = false;

  Future<void> _enable() async {
    setState(() => _asking = true);
    final status = await Permission.notification.request();
    if (!mounted) return;
    onboarding.notifications = status.isGranted;
    setState(() => _asking = false);
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.cinza900,
          content: Text(
            'Sem problema. Você pode ativar os avisos depois, no seu perfil.',
            style: AppType.body(color: AppColors.white, size: 14),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
    }
    _next();
  }

  void _next() => context.push(const AccountIntroScreen());

  @override
  Widget build(BuildContext context) {
    final withCauses = onboarding.selectedCauses.isNotEmpty;
    return StepScaffold(
      step: 4,
      hero: const _BellOrbit(),
      title: 'Quer saber quando surgir uma meta nova?',
      subtitle: withCauses
          ? 'Avisamos quando uma instituição perto de você abrir uma meta nas causas que você escolheu.'
          : 'Avisamos quando uma instituição perto de você abrir uma meta nova.',
      skipLabel: 'Agora não',
      onSkip: _next,
      primaryLabel: 'Ativar os avisos',
      primaryLoading: _asking,
      onPrimary: _enable,
    );
  }
}

/// Sample notifications shown under the bell, one per ring.
const _samples = [
  ('Nova meta perto de você', 'Casa Exemplo precisa de 40 cobertores até 30/06.'),
  ('Meta quase lá', 'Faltam R\$ 120 para os remédios da Santo Dumont.'),
  ('Nova meta em Educação', 'Escola Viva precisa de 60 cadernos até o fim do mês.'),
];

/// Same language as screen 5: photos float along the ring around the
/// bell. Each time the bell rings, a new sample notification drops in.
class _BellOrbit extends StatefulWidget {
  const _BellOrbit();

  @override
  State<_BellOrbit> createState() => _BellOrbitState();
}

class _BellOrbitState extends State<_BellOrbit> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))
    ..repeat();
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  int _shown = -1;

  static const _height = 372.0;
  static const _radius = 136.0;

  // (photo, angle°, tilt°, w, h), scaled down from the Figma frame.
  static const _photos = [
    (0, 52.6, -27.95, 66.0, 52.0),
    (1, -1.3, -27.95, 52.0, 55.0),
    (2, -43.4, 4.39, 47.0, 54.0),
    (3, -88.0, -23.11, 59.0, 46.0),
    (4, 160.8, -23.11, 59.0, 64.0),
    (5, -140.3, 16.28, 58.0, 47.0),
    (4, 107.3, -5.14, 58.0, 47.0),
  ];

  @override
  void initState() {
    super.initState();
    // First ring once the photos have popped in; then one per cycle,
    // each bringing a new notification.
    _ring.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _ringNext();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _ringNext();
    });
  }

  void _ringNext() {
    setState(() => _shown = (_shown + 1) % _samples.length);
    _ring.forward(from: 0);
  }

  @override
  void dispose() {
    _spin.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, box) {
          final center = Offset(box.maxWidth / 2, 158);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Orbit(
                  turns: _spin,
                  center: center,
                  background: [
                    // Soft warm glow that fades to nothing (no hard edges).
                    Positioned(
                      left: center.dx - 170,
                      top: center.dy - 170,
                      child: Container(
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [AppColors.ocre100.withValues(alpha: .7), AppColors.ocre100.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: center.dx - _radius,
                      top: center.dy - _radius,
                      child: const Ring(diameter: _radius * 2),
                    ),
                    Positioned(
                      left: center.dx - 44,
                      top: center.dy - 44,
                      child: _Bell(ring: _ring, badge: _shown >= 0),
                    ),
                  ],
                  items: [
                    for (final (i, (img, angle, tilt, w, h)) in _photos.indexed)
                      OrbitItem(
                        radius: _radius,
                        angleDeg: angle,
                        bob: 3,
                        child: PopIn(
                          delay: Duration(milliseconds: 150 + 80 * i),
                          child: Transform.rotate(
                            angle: tilt * math.pi / 180,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: AppColors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cinza900.withValues(alpha: .12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.asset(Img.orbit[img], width: w, height: h, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: AppMotion.slow,
                  switchInCurve: AppMotion.pop,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, -.35), end: Offset.zero).animate(a),
                      child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(a), child: child),
                    ),
                  ),
                  child: _shown < 0
                      ? const SizedBox(height: 72)
                      : Center(key: ValueKey(_shown), child: _Notice(_samples[_shown])),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// iOS-style banner with the app mark, as the real notification will look.
class _Notice extends StatelessWidget {
  const _Notice(this.sample);

  final (String, String) sample;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cinza100),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.petroleo600, borderRadius: BorderRadius.circular(10)),
            child: const BrandLogo(size: 24, color: AppColors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sample.$1, style: AppType.strong(size: 13, color: AppColors.cinza900)),
                    ),
                    Text('agora', style: AppType.body(size: 11, color: AppColors.cinza400).copyWith(height: 1)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sample.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 12.5, color: AppColors.cinza700).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.ring, required this.badge});

  final Animation<double> ring;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: AnimatedBuilder(
            animation: ring,
            builder: (context, child) {
              // A short decaying swing at the start of each cycle, then rest.
              final t = ring.value * 3.6;
              final swing = t < .9 ? math.sin(t * 22) * (1 - t / .9) * .28 : 0.0;
              return Transform.rotate(angle: swing, alignment: const Alignment(0, -.85), child: child);
            },
            child: const SvgIcon(Ic.bell, size: 52),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: AnimatedScale(
            scale: badge ? 1 : 0,
            duration: AppMotion.slow,
            curve: AppMotion.pop,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.terracota500,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
