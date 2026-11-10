import 'dart:math' as math;

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
          child: Icon(size * .5 <= 22 ? icon.bold : icon, size: size * .5, color: color),
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
    this.leading,
  });

  final String title;

  /// Botão de voltar, quando a tela é empurrada em vez de ser uma aba.
  final Widget? leading;
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
                if (leading != null) ...[
                  Align(alignment: Alignment.centerLeft, child: leading!),
                  const SizedBox(height: 14),
                ],
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
      child: Material(
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
///
/// A pílula branca é **uma só**, desenhada atrás dos itens, e viaja até a aba
/// tocada. Antes cada item pintava o próprio fundo e animava a largura: o
/// branco sumia de um lado e nascia do outro, o que se lê como teletransporte
/// mesmo com a animação no lugar. Aqui ela percorre o caminho, e estica um
/// pouco no meio da travessia — o esticão vai na largura, nunca na posição,
/// senão a pílula passaria da borda da barra ao ir para a última aba.
class AppNavBar extends StatefulWidget {
  const AppNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.medium, value: 1);

  /// De onde a pílula saiu e para onde vai. Fora da travessia os dois são
  /// iguais e o controlador fica parado em 1.
  late int _de = widget.index;
  late int _para = widget.index;

  @override
  void didUpdateWidget(AppNavBar old) {
    super.didUpdateWidget(old);
    if (widget.index != _para) {
      _de = _para;
      _para = widget.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Largura que o rótulo do item ativo ocupa, medida de verdade: é ela que
  /// decide o quanto a pílula branca cresce. Medir evita tanto o texto
  /// cortado quanto a folga sobrando à direita.
  double _labelWidth(String label) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: AppType.label(size: 14).copyWith(fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// A largura de cada célula no arranjo em que [ativo] é o item escolhido.
  /// O ativo é uma pílula com ícone + rótulo; os outros são só o ícone, num
  /// alvo de toque de 48. O que sobra vai para a pílula.
  List<double> _larguras(double total, int ativo) {
    const inativo = 48.0;
    final livre = total - inativo * (widget.items.length - 1);
    // O badge vive dentro da pílula quando a aba está aberta, então ele
    // também pede largura.
    final folga = widget.items[ativo].badge > 0 ? 95.0 : 72.0;
    final pilula = livre.clamp(76.0, _labelWidth(widget.items[ativo].label) + folga);
    final resto = (total - pilula) / (widget.items.length - 1);
    return [for (var i = 0; i < widget.items.length; i++) i == ativo ? pilula : resto];
  }

  static double _entre(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, pad.bottom > 0 ? pad.bottom - 4 : 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(color: AppColors.cinza900.withValues(alpha: .22), blurRadius: 28, offset: const Offset(0, 12)),
          ],
        ),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: AppColors.petroleo800, borderRadius: BorderRadius.circular(34)),
          child: LayoutBuilder(
            builder: (context, box) {
              final rotulos = [for (final it in widget.items) _labelWidth(it.label)];
              final antes = _larguras(box.maxWidth, _de);
              final depois = _larguras(box.maxWidth, _para);
              final saiDe = antes.take(_de).fold(0.0, (s, x) => s + x);
              final vaiPara = depois.take(_para).fold(0.0, (s, x) => s + x);
              return AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = AppMotion.smooth.transform(_c.value);
                  // O esticão nasce e morre dentro da travessia (seno), então
                  // começa e termina exatamente na largura certa.
                  final estica = ((vaiPara - saiDe).abs() * .14).clamp(0.0, 18.0) * math.sin(math.pi * _c.value);
                  final larg = _entre(antes[_de], depois[_para], t) + estica;
                  final left = (_entre(saiDe, vaiPara, t) - estica / 2).clamp(0.0, box.maxWidth - larg);
                  final larguras = [for (var i = 0; i < widget.items.length; i++) _entre(antes[i], depois[i], t)];
                  // Quanto de cada aba está debaixo da pílula agora. A tinta
                  // escura segue a pílula, não o relógio: assim o ícone por
                  // onde ela passa escurece na hora certa, mesmo sendo uma
                  // aba do meio do caminho que ninguém escolheu.
                  var x = 0.0;
                  final sob = <double>[];
                  for (final w in larguras) {
                    final fim = math.min(x + w, left + larg);
                    final ini = math.max(x, left);
                    sob.add(w <= 0 ? 0 : ((fim - ini) / w).clamp(0.0, 1.0));
                    x += w;
                  }
                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: 7,
                        width: larg,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(26)),
                        ),
                      ),
                      Row(
                        children: [
                          for (final (i, item) in widget.items.indexed)
                            Semantics(
                              button: true,
                              selected: i == _para,
                              label: item.semantic,
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (i != widget.index) HapticFeedback.selectionClick();
                                  widget.onTap(i);
                                },
                                child: SizedBox(
                                  width: larguras[i],
                                  height: 64,
                                  // O conteúdo acompanha a pílula: o item que
                                  // perde a vez devolve o rótulo enquanto o
                                  // outro recebe o dele.
                                  child: _NavCell(
                                    item: item,
                                    labelWidth: rotulos[i],
                                    sob: sob[i],
                                    t: i == _para ? t : (i == _de ? 1 - t : 0),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Uma aba. [t] vai de 0 (em repouso, sobre o fundo escuro) a 1 (sob a
/// pílula branca) e é o mesmo valor que move a pílula, para o ícone trocar de
/// cor exatamente enquanto ela passa por baixo dele.
class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.t, required this.sob, required this.labelWidth});

  final NavItem item;
  final double t;

  /// Quanto desta aba a pílula branca cobre agora, de 0 a 1. É o que decide a
  /// tinta: escura sobre o branco, clara sobre o petróleo.
  final double sob;

  /// Largura do rótulo inteiro, já medida pela barra.
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(AppColors.petroleo200, AppColors.petroleo700, sob)!;
    // Com o rótulo aberto, o badge sai de cima do ícone e vai para o fim da
    // pílula: sobre o ícone ele caía em cima da primeira letra do texto.
    final badgeNoFim = t > 0 && item.badge > 0;
    final icone = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(sob > .5 ? item.activeIcon : item.icon, size: 22, color: color),
        Positioned(right: -11, top: -6, child: CountBadge(badgeNoFim ? 0 : item.badge)),
      ],
    );
    if (t <= 0) return Center(child: icone);
    // O rótulo só aparece no item ativo (o inativo fica só com o ícone, como
    // nas referências). Quem usa leitor de tela continua ouvindo `semantic`.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icone,
        SizedBox(width: 8 * t),
        // O texto é **revelado**, não espremido: ele mantém a largura
        // inteira dentro de uma janela que abre. Num Flexible, o texto
        // encolhia e, no ponto em que deixava de caber, o Row recolocava o
        // ícone de uma vez — o travanco no meio da travessia.
        SizedBox(
          width: labelWidth * t,
          child: ClipRect(
            child: OverflowBox(
              minWidth: labelWidth,
              maxWidth: labelWidth,
              alignment: Alignment.centerLeft,
              child: Opacity(
                opacity: sob,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: AppType.label(size: 14, color: color).copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
            ),
          ),
        ),
        if (badgeNoFim) ...[SizedBox(width: 5 * t), Opacity(opacity: t, child: CountBadge(item.badge))],
      ],
    );
  }
}

/// Strip pinned to the top while the institution or team mode is on, so
/// the person always knows whose donations they are looking at.
class ModeStrip extends StatelessWidget {
  const ModeStrip({
    super.key,
    required this.label,
    required this.onExit,
    this.icon = PhosphorIconsFill.storefront,
    this.action = 'Voltar ao modo doador',
  });

  final String label;
  final VoidCallback onExit;
  final IconData icon;

  /// Texto do botão à direita. A equipe e o parceiro não têm modo doador:
  /// a conta deles serve a um objetivo só, então ali a saída é da conta.
  final String action;

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
            Icon(icon.bold, size: 16, color: AppColors.petroleo200),
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
                  action,
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

/// Quando é `true`, a barra de abas desliza para fora da tela. Quem liga é
/// a tela (o mapa liga enquanto a pessoa arrasta); quem desliza é o
/// [TabShell]. É um notifier global porque a barra não é filha da tela.
final navBarAway = ValueNotifier<bool>(false);

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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: navBarAway,
            builder: (context, away, child) => AnimatedSlide(
              // 1.4 e não 1: a sombra também tem de sair do quadro.
              offset: Offset(0, away ? 1.4 : 0),
              duration: AppMotion.slow,
              curve: AppMotion.smooth,
              child: IgnorePointer(ignoring: away, child: child),
            ),
            child: bar,
          ),
        ),
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
