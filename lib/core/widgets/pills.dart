import 'dart:ui';

import 'package:flutter/material.dart';

import '../assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';
import 'svg_icon.dart';

enum PillStyle {
  /// Frosted glass over imagery/maps (top of screens 4–8).
  glass,

  /// Solid grey inside the white step cards (screens 9–12).
  solid,
}

/// "Voltar" pill.
class BackPill extends StatelessWidget {
  const BackPill({super.key, this.onTap, this.style = PillStyle.glass});

  final VoidCallback? onTap;
  final PillStyle style;

  @override
  Widget build(BuildContext context) {
    final glass = style == PillStyle.glass;
    return Semantics(
      button: true,
      label: 'Voltar',
      child: TextPill(
        style: style,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        leading: SvgIcon(glass ? Ic.arrowLeft : Ic.arrowLeftSm, size: glass ? 24 : 20),
        label: 'Voltar',
      ),
    );
  }
}

/// Generic rounded pill ("Pular", "Agora não").
class TextPill extends StatelessWidget {
  const TextPill({super.key, required this.label, required this.onTap, this.leading, this.style = PillStyle.solid});

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final PillStyle style;

  @override
  Widget build(BuildContext context) {
    final glass = style == PillStyle.glass;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: glass ? AppColors.white.withValues(alpha: .6) : AppColors.sheetBorder,
        borderRadius: BorderRadius.circular(32),
        border: glass ? Border.all(color: AppColors.pillBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 2)],
          Text(
            label,
            style: AppType.label(color: AppColors.ink, size: glass ? 16 : 14),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: glass ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: content) : content,
      ),
    );
  }
}
