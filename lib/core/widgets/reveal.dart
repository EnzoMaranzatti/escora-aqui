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

  /// A opacidade sobe sem mola: um fade que passa de 1 e volta pisca.
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: AppMotion.smooth);

  /// A subida e a escala, essas sim, passam um pouco do lugar e assentam.
  late final Animation<double> _move = CurvedAnimation(parent: _c, curve: AppMotion.spring);

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
        final m = _move.value;
        return Opacity(
          opacity: _fade.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - m) * widget.offset),
            child: Transform.scale(scale: widget.scaleFrom + (1 - widget.scaleFrom) * m, child: child),
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
