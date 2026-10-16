import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'kit.dart';
import 'pressable.dart';
import 'reveal.dart';
import 'segment_progress.dart';
import 'sheets.dart';

/// Task flow screen (doar, declarar, denunciar, cadastrar…): no tab bar,
/// round back button, optional "Passo X de N", left-aligned title, scroll
/// content and the actions pinned to the bottom.
class FlowScaffold extends StatelessWidget {
  const FlowScaffold({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.loading = false,
    this.step,
    this.steps = 5,
    this.onBack,
    this.primaryIcon,
    this.note,
    this.background = AppColors.white,
    this.header,
    this.closeIcon = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final bool loading;

  /// 1-based; shows the segment bar and "Passo X de N".
  final int? step;
  final int steps;
  final VoidCallback? onBack;
  final String? primaryIcon;
  final Widget? note;
  final Color background;

  /// Drawn above the title (e.g. a reminder card or an illustration).
  final Widget? header;

  /// Shows an "x" instead of the back arrow (closing a finished flow).
  final bool closeIcon;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final back = onBack ?? () => Navigator.of(context).maybePop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 0),
              child: step == null
                  ? Row(
                      children: [
                        closeIcon
                            ? RoundIconButton(icon: PhosphorIconsRegular.x, label: 'Fechar', onTap: back)
                            : RoundBackButton(onTap: back),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: step! - 2.0, end: step! - 1.0),
                          duration: const Duration(milliseconds: 900),
                          curve: AppMotion.smooth,
                          builder: (context, v, _) => SegmentProgress(count: steps, position: v, onBack: back),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (step != null) ...[
                      Text(
                        'Passo $step de $steps',
                        style: AppType.label(
                          color: AppColors.petroleo700,
                          size: 13.5,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (header != null) ...[Reveal(child: header!), const SizedBox(height: 20)],
                    if (title != null)
                      Reveal(
                        delay: const Duration(milliseconds: 60),
                        offset: 10,
                        child: Semantics(
                          header: true,
                          child: Text(title!, style: AppType.display(size: 27).copyWith(height: 1.18)),
                        ),
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Reveal(
                        delay: const Duration(milliseconds: 100),
                        offset: 10,
                        child: Text(subtitle!, style: AppType.body(size: 15.5)),
                      ),
                    ],
                    if (title != null || subtitle != null) const SizedBox(height: 24),
                    Reveal(
                      delay: const Duration(milliseconds: 150),
                      offset: 12,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                    ),
                  ],
                ),
              ),
            ),
            if (primary != null)
              ActionArea(
                primary: primary!,
                onPrimary: onPrimary,
                secondary: secondary,
                onSecondary: onSecondary,
                loading: loading,
                icon: primaryIcon,
                note: note,
              ),
          ],
        ),
      ),
    );
  }
}

/// White round button with an icon (close, more, center map).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 40,
    this.color = AppColors.cinza900,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: .92,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(icon, size: size * .5, color: color),
        ),
      ),
    );
  }
}

/// Main page of a tab: large title, optional trailing action, content on
/// the grouped background and room for the floating tab bar.
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.top,
    this.onRefresh,
    this.subtitle,
  });

  final String title;
  final Widget? subtitle;
  final List<Widget> slivers;
  final Widget? trailing;

  /// Pinned under the title (filters, segmented tabs).
  final Widget? top;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, pad.top + 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(header: true, child: Text(title, style: AppType.display(size: 30))),
                    ),
                    ?trailing,
                  ],
                ),
                if (subtitle != null) ...[const SizedBox(height: 6), subtitle!],
                if (top != null) ...[const SizedBox(height: 16), top!],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 110)),
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: ColoredBox(
        color: AppColors.cinza50,
        child: Stack(
          children: [
            onRefresh == null
                ? scroll
                : RefreshIndicator(color: AppColors.petroleo600, onRefresh: onRefresh!, child: scroll),
            // Content scrolls under the status bar on a soft fade.
            if (pad.top > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: pad.top + 12,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, .7, 1],
                        colors: [AppColors.cinza50, AppColors.cinza50, Color(0x00F8F6F3)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NavItem {
  const NavItem({
    required this.label,
    required this.semantic,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });

  final String label;

  /// Screen reader description ("Avisos, 3 não lidos").
  final String semantic;
  final IconData icon;
  final IconData activeIcon;
  final int badge;
}

/// Floating tab bar: frosted capsule, labels always visible (copy rule),
/// the active tab sits on a soft petróleo pill.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, pad.bottom > 0 ? pad.bottom - 6 : 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(color: AppColors.cinza900.withValues(alpha: .14), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 68,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .86),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.white.withValues(alpha: .9)),
              ),
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
                            color: AppColors.petroleo50,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final (i, item) in items.indexed)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: i == index,
                                label: item.semantic,
                                excludeSemantics: true,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (i != index) HapticFeedback.selectionClick();
                                    onTap(i);
                                  },
                                  child: _NavCell(item: item, active: i == index),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.active});

  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.petroleo700 : AppColors.cinza600;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.medium,
              transitionBuilder: (c, a) => ScaleTransition(
                scale: Tween(begin: .8, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Icon(active ? item.activeIcon : item.icon, key: ValueKey(active), size: 23, color: color),
            ),
            Positioned(right: -11, top: -6, child: CountBadge(item.badge)),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: AppMotion.medium,
          style: AppType.label(
            size: 11.5,
            color: color,
          ).copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w500, height: 1.1),
          child: Text(item.label, maxLines: 1),
        ),
      ],
    );
  }
}

/// Strip pinned to the top while the institution or team mode is on, so
/// the person always knows whose donations they are looking at.
class ModeStrip extends StatelessWidget {
  const ModeStrip({super.key, required this.label, required this.onExit, this.icon = PhosphorIconsFill.storefront});

  final String label;
  final VoidCallback onExit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.petroleo800,
        padding: EdgeInsets.fromLTRB(16, pad.top + 4, 8, 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.petroleo200),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.label(color: AppColors.white, size: 13).copyWith(height: 1.25),
              ),
            ),
            Pressable(
              onTap: onExit,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Voltar ao modo doador',
                  style: AppType.label(color: AppColors.white, size: 12.5).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shell for a group of tabs: keeps each tab alive and cross-fades
/// between them, with the floating bar on top.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.index, required this.pages, required this.bar, this.strip});

  final int index;
  final List<Widget> pages;
  final Widget bar;
  final Widget? strip;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        for (final (i, p) in pages.indexed)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: AppMotion.medium,
                curve: Curves.easeOut,
                child: TickerMode(enabled: i == index, child: p),
              ),
            ),
          ),
        Positioned(left: 0, right: 0, bottom: 0, child: bar),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.cinza50,
      resizeToAvoidBottomInset: false,
      body: strip == null
          ? body
          : Column(
              children: [
                strip!,
                Expanded(
                  child: MediaQuery.removePadding(context: context, removeTop: true, child: body),
                ),
              ],
            ),
    );
  }
}
