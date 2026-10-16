import 'package:flutter/widgets.dart';

import '../theme/app_motion.dart';
import 'balanced_text.dart';

/// Fades a child in while it rises a few pixels. Use [delay] to stagger.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.slow,
    this.offset = 16,
    this.scaleFrom = 1,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: AppMotion.smooth);

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
      animation: _a,
      child: widget.child,
      builder: (context, child) {
        final v = _a.value;
        return Opacity(
          opacity: v.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.offset),
            child: Transform.scale(scale: widget.scaleFrom + (1 - widget.scaleFrom) * v, child: child),
          ),
        );
      },
    );
  }
}

/// Cross-fades text when its content changes, with a short vertical slide.
class SwapText extends StatelessWidget {
  const SwapText(this.text, {super.key, required this.style, this.textAlign = TextAlign.center});

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.slow,
      switchInCurve: AppMotion.smooth,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .15), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: BalancedText(text, key: ValueKey(text), style: style, textAlign: textAlign),
    );
  }
}
