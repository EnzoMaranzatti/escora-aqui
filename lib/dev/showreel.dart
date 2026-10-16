import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../features/auth/login_screen.dart';
import '../features/intro/intro_screen.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/signup/account_intro_screen.dart';
import '../features/signup/causes_screen.dart';
import '../features/signup/help_type_screen.dart';
import '../features/signup/location_screen.dart';
import '../features/signup/notifications_screen.dart';
import '../features/splash/splash_screen.dart';

/// Dev-only presentation scene (`--dart-define=START=showreel`): a grid of
/// phones in perspective, each running a real onboarding screen, while the
/// camera drifts and a soft light sweeps across. Everything repeats every
/// [ShowreelScreen.loop], so a recording can be cut into a seamless loop.
///
/// The 4:3 landscape scene is drawn rotated a quarter turn so it fills the
/// portrait simulator; the recording is rotated back in post.
class ShowreelScreen extends StatefulWidget {
  const ShowreelScreen({super.key});

  static const loop = Duration(seconds: 12);

  @override
  State<ShowreelScreen> createState() => _ShowreelScreenState();
}

class _ShowreelScreenState extends State<ShowreelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: ShowreelScreen.loop)..repeat();

  @override
  void initState() {
    super.initState();
    // Filled-in choices, so the later steps show their selected states.
    if (onboarding.city == null) {
      onboarding
        ..setPlace(city: 'São José do Rio Preto', uf: 'SP', position: const LatLng(-20.8197, -49.3794), fromGps: true)
        ..toggleHelp(HelpType.pix)
        ..toggleHelp(HelpType.voluntariado)
        ..notifications = true;
      for (final c in causes.take(4)) {
        onboarding.toggleCause(c);
      }
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: w,
          height: w * 4 / 3,
          child: RotatedBox(
            quarterTurns: 1,
            child: FittedBox(
              child: SizedBox(
                width: 1600,
                height: 1200,
                child: ClipRect(
                  child: IgnorePointer(child: _Scene(t: _t)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Slot {
  const _Slot(this.col, this.row, this.screen, {this.dark = false});

  final int col;
  final int row;
  final Widget screen;

  /// Status bar drawn in white (petróleo cover).
  final bool dark;
}

final _slots = [
  const _Slot(-1, 0, SplashScreen(startAtEnd: true), dark: true),
  const _Slot(0, 0, IntroScreen()),
  const _Slot(1, 0, IntroScreen(initialPage: 2)),
  const _Slot(-1, -1, LoginScreen()),
  const _Slot(0, -1, HelpTypeScreen()),
  const _Slot(1, -1, NotificationsScreen()),
  const _Slot(-1, 1, IntroScreen(initialPage: 1)),
  const _Slot(0, 1, CausesScreen()),
  const _Slot(1, 1, AccountIntroScreen()),
  const _Slot(-2, 0, LocationScreen()),
  const _Slot(2, 0, CausesScreen()),
];

/// Column stagger, like phones dropped on a table.
const _stagger = {-2: 330.0, -1: -70.0, 0: 30.0, 1: -110.0, 2: 250.0};

class _Scene extends StatelessWidget {
  const _Scene({required this.t});

  final Animation<double> t;

  static const _phone = Size(426, 898);
  static const _gapX = 500.0;
  static const _gapY = 980.0;

  @override
  Widget build(BuildContext context) {
    // Built once; only the camera transform and the light change per frame.
    final plane = SizedBox(
      width: 3000,
      height: 3200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final s in _slots)
            Positioned(
              left: 1500 + s.col * _gapX - _phone.width / 2,
              top: 1600 + s.row * _gapY + _stagger[s.col]! - _phone.height / 2,
              child: RepaintBoundary(
                child: _Phone(screen: s.screen, darkStatus: s.dark),
              ),
            ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Warm light-mode table.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.2, -.3),
              radius: 1.1,
              colors: [Color(0xFFFBF9F6), Color(0xFFEAE5DE)],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: t,
          child: plane,
          builder: (context, child) {
            final a = t.value * 2 * math.pi;
            final m = Matrix4.identity()
              ..setEntry(3, 2, .00042)
              ..translateByDouble(70 * math.sin(a), 36 * math.sin(2 * a), 0, 1)
              ..rotateX(.5)
              ..rotateY(-.16 + .035 * math.sin(a))
              ..rotateZ(-.22 + .012 * math.cos(a))
              ..scaleByDouble(1.12, 1.12, 1.12, 1);
            return OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform(alignment: Alignment.center, transform: m, child: child),
            );
          },
        ),
        // Light sweep: a soft diagonal band crossing once per loop.
        AnimatedBuilder(
          animation: t,
          builder: (context, _) => CustomPaint(painter: _SweepPainter(t.value)),
        ),
        // Gentle vignette to frame the scene.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.05,
                colors: [const Color(0x00000000), AppColors.cinza900.withValues(alpha: .14)],
                stops: const [.65, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Crosses during the first half of the loop, then rests off screen.
    final k = (t / .55).clamp(0.0, 1.0);
    if (k == 0 || k == 1) return;
    final x = -.5 + 2 * Curves.easeInOutSine.transform(k);
    final center = Offset(size.width * x, size.height * .5);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.5);
    final r = Rect.fromCenter(center: Offset.zero, width: 520, height: size.height * 2.2);
    canvas.drawRect(
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .5),
            Colors.white.withValues(alpha: .7),
            Colors.white.withValues(alpha: .5),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .35, .5, .65, 1],
        ).createShader(r),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t;
}

/// Light titanium iPhone with a real screen inside.
class _Phone extends StatelessWidget {
  const _Phone({required this.screen, required this.darkStatus});

  final Widget screen;
  final bool darkStatus;

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.of(context);
    const pad = EdgeInsets.only(top: 62, bottom: 34);
    return Container(
      width: _Scene._phone.width,
      height: _Scene._phone.height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(68),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F1EE), Color(0xFFD9D5CF), Color(0xFFF1EEEA)],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .22), blurRadius: 70, offset: const Offset(36, 46)),
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 8, offset: const Offset(2, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(56),
        child: MediaQuery(
          data: base.copyWith(size: const Size(402, 874), padding: pad, viewPadding: pad, viewInsets: EdgeInsets.zero),
          child: SizedBox(
            width: 402,
            height: 874,
            child: Stack(
              children: [
                Positioned.fill(child: screen),
                _StatusBar(light: darkStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS status bar and Dynamic Island, drawn since the screens don't own one.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.light});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = light ? AppColors.white : AppColors.cinza900;
    return SizedBox(
      height: 54,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, .1),
            child: Container(
              width: 124,
              height: 36,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
            ),
          ),
          Positioned(
            left: 50,
            top: 20,
            child: Text('9:41', style: AppType.strong(size: 17, color: c)),
          ),
          Positioned(
            right: 34,
            top: 23,
            child: Row(
              children: [
                for (final h in [5.0, 7.5, 10.0, 12.0]) ...[
                  Container(
                    width: 3.5,
                    height: h,
                    margin: const EdgeInsets.only(right: 1.8),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(Icons.wifi_rounded, size: 17, color: c),
                const SizedBox(width: 6),
                Container(
                  width: 26,
                  height: 12.5,
                  padding: const EdgeInsets.all(1.6),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.withValues(alpha: .4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2.2)),
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
