import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// An item placed on a circle around the orbit center.
class OrbitItem {
  const OrbitItem({required this.radius, required this.angleDeg, required this.child, this.bob = 0});

  final double radius;

  /// Start angle in degrees (0 = right, clockwise).
  final double angleDeg;
  final Widget child;

  /// Extra up/down floating, in pixels.
  final double bob;
}

/// Positions [items] on circles and spins them with [turns]
/// (an animation where 1.0 equals a full revolution). Items stay upright.
class Orbit extends StatelessWidget {
  const Orbit({super.key, required this.turns, required this.items, required this.center, this.background = const []});

  final Animation<double> turns;
  final List<OrbitItem> items;

  /// Orbit center inside this widget's box.
  final Offset center;

  /// Widgets painted under the items (rings, glows).
  final List<Widget> background;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turns,
      builder: (context, _) {
        final spin = turns.value * 2 * math.pi;
        return Stack(
          clipBehavior: Clip.none,
          children: [...background, for (final (i, item) in items.indexed) _place(item, spin, i)],
        );
      },
    );
  }

  Widget _place(OrbitItem item, double spin, int i) {
    final a = item.angleDeg * math.pi / 180 + spin;
    final bob = item.bob * math.sin(spin * 6 + i);
    final p = center + Offset(math.cos(a) * item.radius, math.sin(a) * item.radius + bob);
    return Positioned(
      left: p.dx,
      top: p.dy,
      child: FractionalTranslation(translation: const Offset(-.5, -.5), child: item.child),
    );
  }
}
