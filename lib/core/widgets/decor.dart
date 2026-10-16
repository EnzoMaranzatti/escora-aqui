import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'svg_icon.dart';

/// Soft blurred color blobs from Figma. The SVG filter isn't supported by
/// flutter_svg, so the blur is applied here instead.
class BlurredShape extends StatelessWidget {
  const BlurredShape(this.asset, {super.key, required this.sigma, this.opacity = 1, this.width, this.height});

  final String asset;
  final double sigma;
  final double opacity;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
          child: SvgPicture.asset(asset, width: width, height: height, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

/// Lays out a decorative composition in Figma coordinates
/// ([width]×[height], usually the 390pt frame) and scales it to cover the
/// available box, so illustrations keep their proportions on any phone.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.children,
    this.alignment = Alignment.center,
  });

  final double width;
  final double height;
  final List<Widget> children;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: alignment,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    );
  }
}

/// Thin warm-grey ring (Figma "Ellipse 1/2/15/16").
class Ring extends StatelessWidget {
  const Ring({super.key, required this.diameter, this.color = AppColors.cinza100, this.width = 1});

  final double diameter;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: width),
      ),
    );
  }
}

/// Brand clover, recolorable.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.size, this.color = AppColors.cinza50});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgIcon(Brand.logo, size: size, color: color);
}

/// Simple dot pagination for the account carousel (screens 13–16).
class CarouselDots extends StatelessWidget {
  const CarouselDots({super.key, required this.count, required this.page});

  final int count;

  /// Fractional page while swiping, for a fluid indicator.
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Builder(
            builder: (context) {
              final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                width: 8 + 10 * t,
                height: 8,
                decoration: BoxDecoration(
                  color: Color.lerp(AppColors.ocre100, AppColors.ocre300, t),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Black tooltip bubble used over the map.
class MapTooltip extends StatelessWidget {
  const MapTooltip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: AppColors.tooltip, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.body(color: AppColors.white, size: 11).copyWith(height: 1.2),
      ),
    );
  }
}
