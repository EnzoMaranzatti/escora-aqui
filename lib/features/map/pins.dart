import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/svg_icon.dart';
import '../../data/models.dart';

/// Pin colors per help type (style guide: color + icon, never color alone).
extension HelpTypeStyle on HelpType {
  Color get color => switch (this) {
    HelpType.pix => AppColors.petroleo600,
    HelpType.itens => AppColors.terracota600,
    HelpType.voluntariado => AppColors.ocre600,
  };

  Color get ring => switch (this) {
    HelpType.pix => AppColors.petroleo300,
    HelpType.itens => AppColors.terracota300,
    HelpType.voluntariado => AppColors.ocre300,
  };

  Color get tint => switch (this) {
    HelpType.pix => AppColors.petroleo50,
    HelpType.itens => AppColors.terracota50,
    HelpType.voluntariado => AppColors.ocre50,
  };
}

/// Scales in from nothing with a small overshoot.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.alignment = Alignment.center});

  final Widget child;
  final Duration delay;
  final Alignment alignment;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final s = AppMotion.pop.transform(_c.value);
        return Opacity(
          opacity: Curves.easeOut.transform(_c.value),
          child: Transform.scale(scale: s, alignment: widget.alignment, child: child),
        );
      },
    );
  }
}

/// Round institution pin from Figma: white ring, colored core, white icon.
class InstitutionPin extends StatelessWidget {
  const InstitutionPin({
    super.key,
    required this.icon,
    this.color = AppColors.terracota600,
    this.ring = AppColors.terracota300,
    this.selected = false,
    this.dimmed = false,
    this.size = 30,
  });

  final String icon;
  final Color color;
  final Color ring;
  final bool selected;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = dimmed ? AppColors.cinza400 : color;
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: AppMotion.medium,
      curve: AppMotion.pop,
      child: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.smooth,
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: dimmed ? AppColors.cinza200 : ring),
          boxShadow: [
            BoxShadow(
              color: AppColors.cinza900.withValues(alpha: selected ? .18 : .08),
              blurRadius: selected ? 12 : 4,
              offset: Offset(0, selected ? 4 : 1),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: AppMotion.slow,
          curve: AppMotion.smooth,
          decoration: BoxDecoration(color: core, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgIcon(icon, size: size * 16 / 30, color: AppColors.white),
        ),
      ),
    );
  }
}

/// Map pin with the point's photo: round photo in a ring of the help-type
/// color, a short stem and a dot that sits on the exact spot. The marker's
/// bottom center is the point (use `Alignment.topCenter` on the Marker).
class PhotoPin extends StatelessWidget {
  const PhotoPin({super.key, required this.place, this.selected = false});

  static const head = 46.0;
  static const width = 60.0;
  static const height = head + stem + 8;
  static const stem = 12.0;

  final Place place;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final image = place.image;
    final color = place.primaryType.color;
    return AnimatedScale(
      scale: selected ? 1.18 : 1,
      alignment: Alignment.bottomCenter,
      duration: AppMotion.medium,
      curve: AppMotion.pop,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(
              width: head,
              height: head,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.medium,
                    curve: AppMotion.smooth,
                    width: head,
                    height: head,
                    padding: EdgeInsets.all(selected ? 3 : 2.5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cinza900.withValues(alpha: selected ? .24 : .14),
                          blurRadius: selected ? 14 : 8,
                          offset: Offset(0, selected ? 5 : 2),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                      child: ClipOval(
                        child: image == null
                            ? ColoredBox(
                                color: color,
                                child: Center(child: SvgIcon(place.kind.icon, size: 18, color: AppColors.white)),
                              )
                            : Image(image: ResizeImage(image, width: 150), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 2, height: stem, color: color),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppColors.cinza900.withValues(alpha: .2), blurRadius: 3, offset: const Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List thumbnail for a point: its photo when there is one, else its pin.
/// [badge] adds a small round icon on the corner (e.g. the donation type).
class PlaceThumb extends StatelessWidget {
  const PlaceThumb({super.key, required this.place, this.size = 40, this.badge});

  final Place place;
  final double size;
  final (IconData, Color)? badge;

  @override
  Widget build(BuildContext context) {
    final image = place.image;
    final thumb = image == null
        ? InstitutionPin(
            icon: place.kind.icon,
            color: place.primaryType.color,
            ring: place.primaryType.ring,
            size: size,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * .3),
            child: Image(
              image: ResizeImage(image, width: (size * 3).round()),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
    final b = badge;
    if (b == null) return thumb;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          thumb,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: b.$2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(b.$1, size: 10, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map pin with a label chip under it: white disc with a soft shadow,
/// colored core and icon, and a short "what's missing" chip.
class PlacePin extends StatelessWidget {
  const PlacePin({super.key, required this.icon, required this.color, required this.label, this.selected = false});

  /// Diameter of the round part; the map point sits at its center.
  static const size = 38.0;

  final String icon;
  final Color color;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: selected ? 1.18 : 1,
          duration: AppMotion.medium,
          curve: AppMotion.pop,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.smooth,
            width: size,
            height: size,
            padding: EdgeInsets.all(selected ? 2.5 : 3.5),
            decoration: BoxDecoration(
              color: selected ? color : AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cinza900.withValues(alpha: selected ? .22 : .12),
                  blurRadius: selected ? 14 : 8,
                  offset: Offset(0, selected ? 5 : 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: selected ? 2 : 0),
              ),
              alignment: Alignment.center,
              child: SvgIcon(icon, size: 17, color: AppColors.white),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 6, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(label, style: AppType.strong(size: 10, color: AppColors.cinza800)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft expanding rings behind a point, looping.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.color, this.size = 64, this.period = const Duration(milliseconds: 2200)});

  final Color color;
  final double size;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _PulsePainter(_c.value, widget.color)),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var k = 0; k < 2; k++) {
      final p = (t + k * .5) % 1;
      final e = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(c, size.width / 2 * (.25 + .75 * e), Paint()..color = color.withValues(alpha: (1 - p) * .35));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// "Você está aqui" marker: petróleo dot with a breathing halo.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Pulse(color: AppColors.petroleo500, size: 72),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.petroleo600,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .2), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small loop helper: gentle sway for floating elements.
double sway(double t, {double phase = 0}) => math.sin((t + phase) * 2 * math.pi);
