import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'theme/app_motion.dart';

/// Page transition used across the app: the new screen fades in, rises
/// slightly and settles from 96% scale; the old one drifts back and dims.
/// Going back plays the same motion in mirror, fast start and soft landing.
///
/// Also gives every screen the iOS edge swipe: dragging from the left edge
/// pulls the page sideways with the finger, and the one below comes back.
class EscoraRoute<T> extends PageRoute<T> {
  EscoraRoute(this.page, {super.settings});

  final Widget page;

  /// True while an edge swipe drives (or finishes) any route; the page
  /// below then follows the finger linearly instead of on a curve.
  static bool _swipeActive = false;

  /// True while an edge swipe drives (or finishes) this route.
  bool _swiping = false;

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 420);

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => page;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inA = CurvedAnimation(parent: animation, curve: AppMotion.smooth, reverseCurve: AppMotion.smooth.flipped);
    final outA = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.smooth,
      reverseCurve: AppMotion.smooth.flipped,
    );
    return _EdgeSwipe(
      route: this,
      child: AnimatedBuilder(
        animation: Listenable.merge([inA, outA]),
        child: child,
        builder: (context, child) {
          final o = _swipeActive && !_swiping ? secondaryAnimation.value : outA.value;
          if (_swiping) {
            final w = MediaQuery.sizeOf(context).width;
            final t = animation.value;
            return Transform.translate(
              offset: Offset((1 - t) * w, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cinza900.withValues(alpha: .10 * t),
                      blurRadius: 24,
                      offset: const Offset(-6, 0),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          }
          final i = inA.value;
          return Opacity(
            opacity: (i * (1 - o * .35)).clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, (1 - i) * 28),
              child: Transform.scale(scale: (.96 + .04 * i) * (1 - .04 * o), child: child),
            ),
          );
        },
      ),
    );
  }

  bool get _canSwipe =>
      !isFirst &&
      !willHandlePopInternally &&
      popDisposition != RoutePopDisposition.doNotPop &&
      !fullscreenDialog &&
      animation!.status == AnimationStatus.completed &&
      !navigator!.userGestureInProgress;

  void _swipeStart() {
    _swiping = _swipeActive = true;
    navigator!.didStartUserGesture();
  }

  void _swipeUpdate(double fraction) => controller!.value -= fraction;

  /// [velocity] is in screen widths per second, positive towards the right.
  void _swipeEnd(double velocity) {
    final c = controller!;
    final stay = velocity.abs() >= 1 ? velocity <= 0 : c.value > .5;
    if (stay) {
      c.animateTo(
        1,
        duration: Duration(milliseconds: lerpDouble(320, 0, c.value)!.round()),
        curve: AppMotion.smooth,
      );
    } else {
      navigator!.pop();
      if (c.isAnimating) {
        c.animateBack(
          0,
          duration: Duration(milliseconds: lerpDouble(0, 320, c.value)!.round()),
          curve: AppMotion.smooth,
        );
      }
    }
    void done() {
      _swiping = _swipeActive = false;
      navigator?.didStopUserGesture();
    }

    if (!c.isAnimating) return done();
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        c.removeStatusListener(listener);
        done();
      }
    };
    c.addStatusListener(listener);
  }
}

/// Invisible strip on the left edge that starts the back swipe. Taps go
/// through it, so a back button sitting there keeps working.
class _EdgeSwipe extends StatefulWidget {
  const _EdgeSwipe({required this.route, required this.child});

  final EscoraRoute<dynamic> route;
  final Widget child;

  @override
  State<_EdgeSwipe> createState() => _EdgeSwipeState();
}

class _EdgeSwipeState extends State<_EdgeSwipe> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 20 + MediaQuery.paddingOf(context).left,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              if (!widget.route._canSwipe) return;
              _active = true;
              widget.route._swipeStart();
            },
            onHorizontalDragUpdate: (d) {
              if (_active) widget.route._swipeUpdate(d.primaryDelta! / w);
            },
            onHorizontalDragEnd: (d) {
              if (!_active) return;
              _active = false;
              widget.route._swipeEnd(d.velocity.pixelsPerSecond.dx / w);
            },
            onHorizontalDragCancel: () {
              if (!_active) return;
              _active = false;
              widget.route._swipeEnd(0);
            },
          ),
        ),
      ],
    );
  }
}

extension Nav on BuildContext {
  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(EscoraRoute<T>(page));

  Future<T?> replaceAll<T>(Widget page) => Navigator.of(this).pushAndRemoveUntil<T>(EscoraRoute<T>(page), (_) => false);
}
