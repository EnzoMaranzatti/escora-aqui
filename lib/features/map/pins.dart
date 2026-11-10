import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/svg_icon.dart';
import '../../data/models.dart';

/// Pin colors per help type (style guide: color + icon, never color alone).
extension HelpTypeStyle on HelpType {
  Color get color => switch (this) {
    HelpType.pix => AppColors.petroleo600,
    HelpType.itens => AppColors.terracota600,
    HelpType.voluntariado => AppColors.ocre600,
  };

  Color get ring => switch (this) {
    HelpType.pix => AppColors.petroleo300,
    HelpType.itens => AppColors.terracota300,
    HelpType.voluntariado => AppColors.ocre300,
  };

  Color get tint => switch (this) {
    HelpType.pix => AppColors.petroleo50,
    HelpType.itens => AppColors.terracota50,
    HelpType.voluntariado => AppColors.ocre50,
  };
}

/// Scales in from nothing with a small overshoot.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero, this.alignment = Alignment.center});

  final Widget child;
  final Duration delay;
  final Alignment alignment;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

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
        final s = AppMotion.pop.transform(_c.value);
        return Opacity(
          opacity: Curves.easeOut.transform(_c.value),
          child: Transform.scale(scale: s, alignment: widget.alignment, child: child),
        );
      },
    );
  }
}

/// Round institution pin from Figma: white ring, colored core, white icon.
class InstitutionPin extends StatelessWidget {
  const InstitutionPin({
    super.key,
    required this.icon,
    this.color = AppColors.terracota600,
    this.ring = AppColors.terracota300,
    this.selected = false,
    this.dimmed = false,
    this.size = 30,
  });

  final String icon;
  final Color color;
  final Color ring;
  final bool selected;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = dimmed ? AppColors.cinza400 : color;
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: AppMotion.medium,
      curve: AppMotion.pop,
      child: AnimatedContainer(
        duration: AppMotion.slow,
        curve: AppMotion.smooth,
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: dimmed ? AppColors.cinza200 : ring),
          boxShadow: [
            BoxShadow(
              color: AppColors.cinza900.withValues(alpha: selected ? .18 : .08),
              blurRadius: selected ? 12 : 4,
              offset: Offset(0, selected ? 4 : 1),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: AppMotion.slow,
          curve: AppMotion.smooth,
          decoration: BoxDecoration(color: core, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SvgIcon(icon, size: size * 16 / 30, color: AppColors.white),
        ),
      ),
    );
  }
}

/// Pino do ponto no mapa, em dois tamanhos. Em repouso é um disco pequeno
/// com o ícone do tipo de ajuda: vinte e cinco fotos de 46px lado a lado
/// viram sopa, e o mapa precisa ser lido antes dos pontos. Ao ser escolhido,
/// a cabeça cresce para a foto do lugar e o pé se alonga, sem sair do ponto
/// exato — o que move é o tamanho, nunca a coordenada.
///
/// O centro de baixo do marcador é a coordenada (use `Alignment.topCenter`
/// no [Marker]).
/// O pino do mapa: a gota clássica, com a foto da instituição dentro.
///
/// A foto é o que faz a pessoa reconhecer o lugar da rua dela — melhor que
/// um ícone, que só diz a categoria. O anel colorido continua dizendo o tipo
/// de ajuda, porque o guia pede cor **e** forma, nunca cor sozinha.
///
/// O que anima é uma escala sobre um desenho pronto: animar tamanho, borda e
/// sombra quadro a quadro trava com 25 pinos na tela.
class PhotoPin extends StatelessWidget {
  const PhotoPin({super.key, required this.place, this.selected = false, this.dimmed = false});

  /// Diâmetro da cabeça do pino aberto. O fechado é o mesmo desenho menor.
  static const head = 58.0;

  /// A ponta fica a 1.62 raio do centro: é a proporção que dá a gota de
  /// mapa, nem bolha nem lágrima esticada.
  static const _drop = 1.62;
  static const pinH = head / 2 * (1 + _drop);
  static const _closed = .72;

  static const width = head + 10;
  static const height = pinH + 8;

  final Place place;
  final bool selected;

  /// Outro ponto está escolhido: este sai um pouco de cena.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = place.primaryType.color;
    final image = place.image;
    const inset = 4.0;
    const photo = head - inset * 2;
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedOpacity(
        duration: AppMotion.medium,
        curve: AppMotion.smooth,
        opacity: dimmed ? .5 : 1,
        child: AnimatedScale(
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          alignment: Alignment.bottomCenter,
          scale: selected ? 1 : _closed,
          child: RepaintBoundary(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: head,
                height: pinH,
                child: Stack(
                  children: [
                    // A silhueta inteira num caminho só: círculo em cima,
                    // duas tangentes descendo até o bico que toca o endereço.
                    Positioned.fill(child: CustomPaint(painter: const _DropPainter())),
                    Positioned(
                      left: inset,
                      top: inset,
                      width: photo,
                      height: photo,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: color, width: 2.5),
                        ),
                        child: ClipOval(
                          child: image == null
                              ? const Center(child: Icon(PhosphorIconsFill.mapPin, size: 22, color: AppColors.white))
                              : Image(image: ResizeImage(image, width: 160), fit: BoxFit.cover, gaplessPlayback: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A gota branca: um círculo e as duas retas que o fecham no bico.
class _DropPainter extends CustomPainter {
  const _DropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final d = size.height - r;

    // Onde as retas encostam no círculo sem cruzá-lo.
    final beta = math.acos((r / d).clamp(-1.0, 1.0));
    final rect = Rect.fromCircle(center: c, radius: r);
    final path = Path()
      ..moveTo(c.dx - r * math.sin(beta), c.dy + r * math.cos(beta))
      ..arcTo(rect, math.pi / 2 + beta, 2 * math.pi - 2 * beta, false)
      ..lineTo(c.dx, c.dy + d)
      ..close();

    canvas.drawShadow(path, AppColors.cinza900.withValues(alpha: .45), 5, false);
    canvas.drawPath(path, Paint()..color = AppColors.white);
  }

  @override
  bool shouldRepaint(_DropPainter old) => false;
}

/// List thumbnail for a point: its photo when there is one, else its pin.
/// [badge] adds a small round icon on the corner (e.g. the donation type).
class PlaceThumb extends StatelessWidget {
  const PlaceThumb({super.key, required this.place, this.size = 40, this.badge});

  final Place place;
  final double size;
  final (IconData, Color)? badge;

  @override
  Widget build(BuildContext context) {
    final image = place.image;
    final thumb = image == null
        ? InstitutionPin(
            icon: place.kind.icon,
            color: place.primaryType.color,
            ring: place.primaryType.ring,
            size: size,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * .3),
            child: Image(
              image: ResizeImage(image, width: (size * 3).round()),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
    final b = badge;
    if (b == null) return thumb;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          thumb,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: b.$2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Icon(b.$1, size: 10, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Map pin with a label chip under it: white disc with a soft shadow,
/// colored core and icon, and a short "what's missing" chip.
class PlacePin extends StatelessWidget {
  const PlacePin({super.key, required this.icon, required this.color, required this.label, this.selected = false});

  /// Diameter of the round part; the map point sits at its center.
  static const size = 38.0;

  final String icon;
  final Color color;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: selected ? 1.18 : 1,
          duration: AppMotion.medium,
          curve: AppMotion.pop,
          child: AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.smooth,
            width: size,
            height: size,
            padding: EdgeInsets.all(selected ? 2.5 : 3.5),
            decoration: BoxDecoration(
              color: selected ? color : AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cinza900.withValues(alpha: selected ? .22 : .12),
                  blurRadius: selected ? 14 : 8,
                  offset: Offset(0, selected ? 5 : 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: selected ? 2 : 0),
              ),
              alignment: Alignment.center,
              child: SvgIcon(icon, size: 17, color: AppColors.white),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .10), blurRadius: 6, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(label, style: AppType.strong(size: 10, color: AppColors.cinza800)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft expanding rings behind a point, looping.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.color, this.size = 64, this.period = const Duration(milliseconds: 2200)});

  final Color color;
  final double size;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(painter: _PulsePainter(_c.value, widget.color)),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var k = 0; k < 2; k++) {
      final p = (t + k * .5) % 1;
      final e = Curves.easeOutCubic.transform(p);
      canvas.drawCircle(c, size.width / 2 * (.25 + .75 * e), Paint()..color = color.withValues(alpha: (1 - p) * .35));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}

/// "Você está aqui" marker: petróleo dot with a breathing halo.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Pulse(color: AppColors.petroleo500, size: 72),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.petroleo600,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [
              BoxShadow(color: AppColors.cinza900.withValues(alpha: .2), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small loop helper: gentle sway for floating elements.
double sway(double t, {double phase = 0}) => math.sin((t + phase) * 2 * math.pi);
