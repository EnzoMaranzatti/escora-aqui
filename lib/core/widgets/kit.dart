import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import '../../core/icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'pressable.dart';

/// Shared building blocks of the in-app screens (after onboarding).
/// Follows style-guide.md: petróleo for structure, terracota/ocre as help
/// type accents, warm greys, calm motion.

const tabular = [FontFeature.tabularFigures()];

/// "Verificado" / "Verificado em 12/09" seal, in petróleo.
class Seal extends StatelessWidget {
  const Seal({super.key, this.label = 'Verificado', this.size = 12});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(color: AppColors.petroleo50, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsFill.sealCheck, size: size + 2, color: AppColors.petroleo600),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppType.label(color: AppColors.petroleo800, size: size).copyWith(height: 1.1),
          ),
        ],
      ),
    );
  }
}

/// Goal progress: 8px petróleo bar on a cinza 200 track that fills once
/// when it appears (style guide: the only recurring graphic element).
class GoalBar extends StatelessWidget {
  const GoalBar({super.key, required this.value, this.height = 8, this.color = AppColors.petroleo600});

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: '${(value * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: AppMotion.smooth,
        builder: (context, v, _) => Container(
          height: height,
          decoration: BoxDecoration(color: AppColors.cinza200, borderRadius: BorderRadius.circular(height)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      ),
    );
  }
}

enum Tone { info, alert, error, success, neutral }

extension ToneColors on Tone {
  Color get bg => switch (this) {
    Tone.info => AppColors.petroleo50,
    Tone.alert => AppColors.ocre50,
    Tone.error => AppColors.erroFundo,
    Tone.success => AppColors.sucessoFundo,
    Tone.neutral => AppColors.cinza100,
  };

  Color get fg => switch (this) {
    Tone.info => AppColors.petroleo800,
    Tone.alert => AppColors.ocre800,
    Tone.error => AppColors.erroTexto,
    Tone.success => AppColors.sucessoTexto,
    Tone.neutral => AppColors.cinza700,
  };

  Color get border => switch (this) {
    Tone.info => AppColors.petroleo100,
    Tone.alert => AppColors.ocre100,
    Tone.error => const Color(0xFFF6D3CF),
    Tone.success => const Color(0xFFCFE5D4),
    Tone.neutral => AppColors.cinza200,
  };

  IconData get icon => switch (this) {
    Tone.info => PhosphorIconsFill.info,
    Tone.alert => PhosphorIconsFill.warningCircle,
    Tone.error => PhosphorIconsFill.warningCircle,
    Tone.success => PhosphorIconsFill.checkCircle,
    Tone.neutral => PhosphorIconsFill.info,
  };
}

/// Non-blocking notice ("aviso não bloqueante") with an optional action.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.text,
    this.tone = Tone.alert,
    this.action,
    this.onAction,
    this.icon,
    this.title,
    this.elevated = false,
  });

  final String text;
  final String? title;
  final Tone tone;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;

  /// Adds a shadow, for banners floating over the map.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
        boxShadow: elevated
            ? [BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? tone.icon, size: 18, color: tone.fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppType.label(color: tone.fg, size: 15).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(text, style: AppType.body(color: tone.fg, size: 14).copyWith(height: 1.35)),
                if (action != null) ...[const SizedBox(height: 6), LinkText(action!, onTap: onAction, color: tone.fg)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline text action ("O que verificamos", "Editar").
class LinkText extends StatelessWidget {
  const LinkText(this.label, {super.key, this.onTap, this.color = AppColors.petroleo700, this.size = 14, this.icon});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: .96,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppType.label(color: color, size: size).copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: color.withValues(alpha: .35),
                  decorationThickness: 1.5,
                ),
              ),
              if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: size + 2, color: color)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft round icon used by empty states and success screens.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color = AppColors.petroleo600,
    this.bg = AppColors.petroleo50,
    this.size = 64,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * .44, color: color),
    );
  }
}

/// Empty state: icon, title, description and up to two actions.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? text;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 8 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon, size: compact ? 52 : 64),
          SizedBox(height: compact ? 12 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.cardTitle(size: compact ? 17 : 19, color: AppColors.cinza900).copyWith(height: 1.25),
          ),
          if (text != null) ...[
            const SizedBox(height: 6),
            Text(text!, textAlign: TextAlign.center, style: AppType.body(size: 15)),
          ],
          if (primary != null) ...[
            const SizedBox(height: 18),
            SoftButton(label: primary!, onTap: onPrimary, filled: true),
          ],
          if (secondary != null) ...[const SizedBox(height: 8), SoftButton(label: secondary!, onTap: onSecondary)],
        ],
      ),
    );
  }
}

/// Compact button for cards, rows and empty states (the full-width
/// [PrimaryButton] stays reserved for the main action of a screen).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
    this.color = AppColors.petroleo600,
    this.expand = false,
    this.height = 44,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;
  final Color color;
  final bool expand;
  final double height;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final base = destructive ? AppColors.erroBase : color;
    final enabled = onTap != null;
    final bg = !enabled
        ? AppColors.cinza200
        : filled
        ? base
        : AppColors.white;
    final fg = !enabled
        ? AppColors.cinza500
        : filled
        ? AppColors.white
        : (destructive ? AppColors.erroTexto : AppColors.cinza900);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: filled || !enabled ? null : Border.all(color: AppColors.cinza200),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label(color: fg, size: 15).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card on the grouped (cinza 50) background.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cinza100),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, scale: .985, child: card);
  }
}

/// Section heading inside a page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 10)});

  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: AppType.cardTitle(size: 19, color: AppColors.cinza900).copyWith(height: 1.25)),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Settings-like row: title, optional value below and trailing action.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.title,
    this.value,
    this.action,
    this.onTap,
    this.icon,
    this.trailing,
    this.titleColor = AppColors.cinza900,
    this.chevron = false,
  });

  final String title;
  final String? value;
  final String? action;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? trailing;
  final Color titleColor;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.cinza50, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: AppColors.cinza700),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.label(color: titleColor, size: 15)),
                  if (value != null) ...[const SizedBox(height: 2), Text(value!, style: AppType.body(size: 14))],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              Text(
                action!,
                style: AppType.label(color: AppColors.petroleo700, size: 14).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            ?trailing,
            if (chevron) ...[
              const SizedBox(width: 8),
              const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza500),
            ],
          ],
        ),
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.only(left: indent),
    color: AppColors.cinza100,
  );
}

/// Small status label ("Aguardando confirmação").
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: tone.fg), const SizedBox(width: 4)],
          Text(
            label,
            style: AppType.label(color: tone.fg, size: 12.5).copyWith(height: 1.1, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Pill tabs with a sliding white thumb (Todas · Aguardando · Confirmadas).
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.index, required this.onChanged, this.dense = false});

  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final h = dense ? 34.0 : 40.0;
    return Container(
      height: h,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.cinza100, borderRadius: BorderRadius.circular(h / 2)),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.slow,
                curve: AppMotion.smooth,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(h / 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cinza900.withValues(alpha: .08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, label) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.medium,
                              style: AppType.label(
                                size: dense ? 13 : 14,
                                color: i == index ? AppColors.cinza900 : AppColors.cinza600,
                              ).copyWith(fontWeight: i == index ? FontWeight.w600 : FontWeight.w500),
                              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Selectable card (radio or checkbox) in the style of the onboarding
/// choices: petróleo border and a check that draws itself in.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multi = false,
    this.iconColor,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: !multi,
      button: true,
      child: Pressable(
        onTap: onTap,
        scale: .98,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          padding: EdgeInsets.fromLTRB(14, subtitle == null ? 14 : 13, 14, subtitle == null ? 14 : 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.petroleo50.withValues(alpha: .55) : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.petroleo600 : AppColors.cinza200, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                AnimatedContainer(
                  duration: AppMotion.medium,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.white : AppColors.cinza50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 21,
                    color: iconColor ?? (selected ? AppColors.petroleo600 : AppColors.cinza700),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.label(color: AppColors.cinza900, size: 15.5)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppType.body(size: 13.5).copyWith(height: 1.35)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CheckMark(selected: selected, square: multi),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circle (or rounded square) that fills while its check draws itself in.
class CheckMark extends StatelessWidget {
  const CheckMark({super.key, required this.selected, this.square = false, this.size = 22});

  final bool selected;
  final bool square;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: AppMotion.slow,
      curve: AppMotion.smooth,
      builder: (context, t, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CheckPainter(t, square)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.square);

  final double t;
  final bool square;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Color.lerp(AppColors.cinza400, AppColors.petroleo600, t)!;
    final fill = Paint()..color = AppColors.petroleo600;
    final k0 = AppMotion.pop.transform(math.min(1, t * 1.6));
    if (square) {
      final rect = RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r - .75), const Radius.circular(6));
      canvas.drawRRect(rect, stroke);
      if (t > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r * k0), Radius.circular(6 * k0)),
          fill,
        );
      }
    } else {
      canvas.drawCircle(c, r - .75, stroke);
      if (t > 0) canvas.drawCircle(c, r * k0, fill);
    }
    final k = ((t - .35) / .65).clamp(0.0, 1.0);
    if (k == 0) return;
    final path = Path()
      ..moveTo(size.width * .29, size.height * .52)
      ..lineTo(size.width * .44, size.height * .66)
      ..lineTo(size.width * .72, size.height * .37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.square != square;
}

/// Toggle chip (filters, units, types).
class ChoiceChipPill extends StatelessWidget {
  const ChoiceChipPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = AppColors.petroleo600,
    this.elevated = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;
  final bool elevated;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.cinza800;
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.smooth,
          height: 36,
          padding: EdgeInsets.only(left: icon == null ? 14 : 11, right: trailing == null ? 14 : 10),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: elevated || selected ? null : Border.all(color: AppColors.cinza200),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: AppColors.cinza900.withValues(alpha: .10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Text(label, style: AppType.label(size: 14, color: fg)),
              if (trailing != null) ...[const SizedBox(width: 4), Icon(trailing, size: 14, color: fg)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only star row.
class Stars extends StatelessWidget {
  const Stars(this.value, {super.key, this.size = 14});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= value.round() ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
            size: size,
            color: i <= value.round() ? AppColors.ocre400 : AppColors.cinza300,
          ),
      ],
    );
  }
}

/// Tappable 1–5 stars; each one pops when chosen.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          Semantics(
            button: true,
            selected: i <= value,
            label: '$i de 5 estrelas',
            child: Pressable(
              onTap: () => onChanged(i),
              scale: .85,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  scale: i <= value ? 1 : .92,
                  duration: AppMotion.medium,
                  curve: AppMotion.pop,
                  child: Icon(
                    i <= value ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                    size: 40,
                    color: i <= value ? AppColors.ocre400 : AppColors.cinza300,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// iOS switch in brand colors.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: AppColors.petroleo600);
  }
}

/// Unread badge ("3", "9+").
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.color = AppColors.terracota500});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (c, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: AppMotion.pop),
        child: c,
      ),
      child: count <= 0
          ? const SizedBox.shrink(key: ValueKey(0))
          : Container(
              key: ValueKey(count > 9 ? 10 : count),
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: AppType.strong(size: 10.5, color: AppColors.white).copyWith(fontFeatures: tabular),
              ),
            ),
    );
  }
}

/// Square photo/placeholder for a point.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.color = AppColors.petroleo600, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(size * .3)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * .48, color: color),
    );
  }
}
