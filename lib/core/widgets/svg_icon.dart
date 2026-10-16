import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a Figma-exported SVG, optionally recolored.
class SvgIcon extends StatelessWidget {
  const SvgIcon(this.asset, {super.key, this.size, this.width, this.height, this.color});

  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width ?? size,
      height: height ?? size,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
