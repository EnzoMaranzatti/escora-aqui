import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/pressable.dart';
import '../../core/icons.dart';
import '../auth/login_screen.dart';
import '../intro/intro_screen.dart';
import '../signup/create_account_screen.dart';

/// Screens 1 → 2 → 3 as one continuous timeline:
/// the clover turns a quarter and grows (2), turns again while rising to its
/// final spot (3), then the logotype is revealed and the buttons arrive.
/// Tapping anywhere skips to the end.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.startAtEnd = false});

  /// Shows screen 3 directly (e.g. when coming back from the intro).
  final bool startAtEnd;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));

  // Figma sizes for the three stages.
  static const _s1 = 113.0, _s2 = 132.0, _s3 = 174.0;

  // Final column: logo + logotype + gap + two buttons.
  static const _logotypeH = 112.0;
  static const _groupH = _s3 + _logotypeH + 64 + 118;

  @override
  void initState() {
    super.initState();
    widget.startAtEnd ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve curve = AppMotion.smooth]) =>
      curve.transform(Interval(a, b).transform(_c.value));

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.petroleo500,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_c.value < .75) _c.animateTo(1, duration: AppMotion.slow, curve: Curves.easeOut);
          },
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final groupTop = math.max(24.0, (h - _groupH) / 2);
              final finalCenterY = groupTop + _s3 / 2;

              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final appear = _seg(0, .1, Curves.easeOut);
                  final stage2 = _seg(.14, .4);
                  final stage3 = _seg(.44, .72);
                  final size = lerpDouble(lerpDouble(_s1, _s2, stage2), _s3, stage3)!;
                  final angle = (stage2 + stage3) * math.pi / 2;
                  final cy = lerpDouble(h / 2, finalCenterY, stage3)!;

                  final word = _seg(.6, .86);
                  final aqui = _seg(.68, .92);
                  final buttons = _seg(.74, 1);

                  return Stack(
                    children: [
                      Positioned(
                        left: w / 2 - size / 2,
                        top: cy - size / 2,
                        child: Opacity(
                          opacity: appear,
                          child: Transform.rotate(
                            angle: angle,
                            child: Transform.scale(
                              scale: .9 + .1 * appear,
                              child: BrandLogo(size: size),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: groupTop + _s3,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _Logotype(word: word, aqui: aqui),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: groupTop + _s3 + _logotypeH + 64,
                        child: Column(
                          children: [
                            _rise(buttons, 0, CoverButton(label: 'Começar agora', onPressed: _start)),
                            const SizedBox(height: 6),
                            _rise(
                              buttons,
                              .2,
                              CoverButton(label: 'Já tenho um cadastro', filled: false, onPressed: _login),
                            ),
                            const SizedBox(height: 10),
                            _rise(
                              buttons,
                              .4,
                              Pressable(
                                onTap: _institution,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIconsRegular.storefront,
                                        size: 18,
                                        color: AppColors.white.withValues(alpha: .8),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Represento uma instituição',
                                        style: AppType.label(size: 15, color: AppColors.white.withValues(alpha: .8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _rise(double t, double delay, Widget child) {
    final v = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    return IgnorePointer(
      ignoring: v < .5,
      child: Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
    );
  }

  void _start() => context.replaceAll(const IntroScreen());

  void _login() => context.push(const LoginScreen());

  void _institution() => context.push(const CreateAccountScreen(forInstitution: true));
}

/// "Escora / Aqui" logotype. "Escora" is wiped in from left to right
/// with a soft edge; "Aqui" opens its letter-spacing as it fades in.
class _Logotype extends StatelessWidget {
  const _Logotype({required this.word, required this.aqui});

  final double word;
  final double aqui;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Escora aqui',
      child: SizedBox(
        width: 187,
        height: _SplashScreenState._logotypeH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 8 + 10 * (1 - word),
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => LinearGradient(
                  colors: const [Colors.white, Colors.transparent],
                  stops: [word * 1.2 - .2, word * 1.2],
                ).createShader(r),
                child: Text('Escora', style: AppType.logotype(68, -5.44), maxLines: 1, softWrap: false),
              ),
            ),
            Positioned(
              right: 0,
              top: 68,
              child: Opacity(
                opacity: aqui,
                child: Transform.translate(
                  offset: Offset(0, 6 * (1 - aqui)),
                  child: Text('Aqui', style: AppType.logotype(36, 5.4 * aqui)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
