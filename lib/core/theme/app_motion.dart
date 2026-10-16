import 'package:flutter/animation.dart';

/// Motion tokens. Curves approximate the iOS "smooth" spring feel
/// without overshoot, as the style guide asks for calm motion.
abstract final class AppMotion {
  /// Apple-like ease-out (fast start, long soft landing).
  static const smooth = Cubic(0.32, 0.72, 0, 1);

  /// Symmetric ease for elements that travel across the screen.
  static const glide = Cubic(0.65, 0, 0.35, 1);

  /// Tiny overshoot for pop-ins (pins, badges). Kept subtle on purpose.
  static const pop = Cubic(0.34, 1.36, 0.64, 1);

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 520);
  static const page = Duration(milliseconds: 620);
}
