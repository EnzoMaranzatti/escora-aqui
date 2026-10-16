import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/segment_progress.dart';
import '../signup/location_screen.dart';
import '../splash/splash_screen.dart';
import 'goal_visual.dart';
import 'verified_visual.dart';
import 'welcome_map_visual.dart';

class _IntroPage {
  const _IntroPage(this.title, this.body);

  final String title;
  final String body;
}

const _pages = [
  _IntroPage(
    'Veja quem precisa de ajuda perto de você',
    'Instituições próximas de você mostram o que falta agora, e por quê.',
  ),
  _IntroPage(
    'Todo ponto no mapa foi verificado',
    'Antes de aparecer aqui, cada instituição passa por análise: CNPJ, endereço e foto do local.',
  ),
  _IntroPage(
    'Toda meta tem um motivo',
    'Você vê quanto falta, até quando e para quê. E o Pix vai direto para a instituição, sem taxa.',
  ),
];

/// Screens 4, 5 and 6. Swipeable; the illustration moves with parallax
/// while the text follows the finger. Buttons stay put.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.initialPage = 0});

  final int initialPage;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final _pager = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pager.nextPage(duration: AppMotion.page, curve: AppMotion.smooth);
    } else {
      _skip();
    }
  }

  void _back() {
    if (_index > 0) {
      _pager.previousPage(duration: AppMotion.page, curve: AppMotion.smooth);
    } else {
      context.replaceAll(const SplashScreen(startAtEnd: true));
    }
  }

  void _skip() => context.push(const LocationScreen());

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: LayoutBuilder(
            builder: (context, box) {
              final ratio = box.maxHeight < 740 ? 380 / 844 : 426 / 844;
              final topH = (box.maxHeight * ratio).clamp(260.0, 470.0);
              return Stack(
                children: [
                  PageView.builder(
                    controller: _pager,
                    itemCount: _pages.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) =>
                        _PageBody(pager: _pager, index: i, topHeight: topH, active: _index == i, page: _pages[i]),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: AppSpacing.bottom + pad.bottom,
                    child: Column(
                      children: [
                        PrimaryButton(label: 'Continuar', onPressed: _next),
                        const SizedBox(height: 6),
                        GhostButton(label: 'Pular', onPressed: _skip),
                      ],
                    ),
                  ),
                  Positioned(
                    top: topH + 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _pager,
                        builder: (context, _) => PagePills(
                          count: _pages.length,
                          position: _pager.hasClients && _pager.position.haveDimensions
                              ? _pager.page!
                              : _index.toDouble(),
                        ),
                      ),
                    ),
                  ),
                  // Always present: on the first page it returns to the cover,
                  // which isn't kept underneath (the intro replaces it).
                  Positioned(
                    top: pad.top + 6,
                    left: 16,
                    child: RoundBackButton(onTap: _back),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.pager,
    required this.index,
    required this.topHeight,
    required this.active,
    required this.page,
  });

  final PageController pager;
  final int index;
  final double topHeight;
  final bool active;
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    final visual = switch (index) {
      0 => WelcomeMapVisual(active: active),
      1 => VerifiedVisual(active: active),
      _ => GoalVisual(active: active),
    };
    return AnimatedBuilder(
      animation: pager,
      builder: (context, _) {
        final p = pager.hasClients && pager.position.haveDimensions ? pager.page! : index.toDouble();
        final d = p - index;
        final w = MediaQuery.sizeOf(context).width;
        final compact = MediaQuery.sizeOf(context).height < 740;
        final fade = (1 - d.abs() * 1.4).clamp(0.0, 1.0);
        return Column(
          children: [
            SizedBox(
              height: topHeight,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(d * w * .45, 0),
                  child: Opacity(
                    opacity: (1 - d.abs() * .6).clamp(0.0, 1.0),
                    // Off-screen pages stop animating; each visual paints
                    // in its own layer so it doesn't repaint the text.
                    child: TickerMode(
                      enabled: d.abs() < 1,
                      child: RepaintBoundary(child: visual),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32 + 8 + 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Opacity(
                opacity: fade,
                child: Transform.translate(
                  offset: Offset(-d * 40, 0),
                  child: Column(
                    children: [
                      BalancedText(page.title, style: AppType.display(size: compact ? 26 : 32)),
                      const SizedBox(height: 8),
                      BalancedText(page.body, style: AppType.body(size: compact ? 15 : 16)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
