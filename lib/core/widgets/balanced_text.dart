import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Text with balanced line lengths (like CSS `text-wrap: balance`, which the
/// Figma titles use): finds the narrowest width that keeps the same number
/// of lines, so a title never ends with a lonely word.
///
/// Implemented as a render box (not a LayoutBuilder) so it also works
/// inside intrinsic-sizing parents such as `SliverFillRemaining`.
class BalancedText extends StatelessWidget {
  const BalancedText(this.text, {super.key, required this.style, this.textAlign = TextAlign.center});

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return _Balance(
      text: text,
      style: style,
      scaler: MediaQuery.textScalerOf(context),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}

class _Balance extends SingleChildRenderObjectWidget {
  const _Balance({required this.text, required this.style, required this.scaler, required super.child});

  final String text;
  final TextStyle style;
  final TextScaler scaler;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBalance(text, style, scaler);

  @override
  void updateRenderObject(BuildContext context, _RenderBalance render) {
    render
      ..text = text
      ..style = style
      ..scaler = scaler
      ..markNeedsLayout();
  }
}

class _RenderBalance extends RenderShiftedBox {
  _RenderBalance(this.text, this.style, this.scaler) : super(null);

  String text;
  TextStyle style;
  TextScaler scaler;

  double _balancedWidth(double max) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
    int lines(double w) {
      painter.layout(maxWidth: w);
      return painter.computeLineMetrics().length;
    }

    final target = lines(max);
    if (target <= 1) {
      final w = painter.width;
      painter.dispose();
      return w;
    }
    var lo = max / 2, hi = max;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      if (lines(mid) > target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    painter.dispose();
    return (hi.ceilToDouble() + 1).clamp(0, max);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final max = constraints.maxWidth;
    final w = max.isFinite ? _balancedWidth(max) : max;
    final childSize = c.getDryLayout(constraints.copyWith(minWidth: 0, maxWidth: w));
    return constraints.constrain(Size(max.isFinite ? max : childSize.width, childSize.height));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    final max = constraints.maxWidth;
    final w = max.isFinite ? _balancedWidth(max) : max;
    c.layout(constraints.copyWith(minWidth: 0, maxWidth: w), parentUsesSize: true);
    size = constraints.constrain(Size(max.isFinite ? max : c.size.width, c.size.height));
    (c.parentData! as BoxParentData).offset = Offset((size.width - c.size.width) / 2, 0);
  }
}
