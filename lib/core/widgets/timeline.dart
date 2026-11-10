import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'kit.dart';
import 'reveal.dart';

/// Em que pé está uma etapa.
enum TrackState {
  /// Já aconteceu: bolinha cheia e linha sólida até a próxima.
  done,

  /// É onde a doação está agora: bolinha com anel e título em destaque.
  current,

  /// Ainda vai acontecer: bolinha vazia e linha tracejada.
  future,
}

class TimelineStep {
  const TimelineStep({
    required this.title,
    this.detail,
    required this.state,
    this.alert = false,
    this.progress,
    this.note,
  });

  final String title;

  /// Data, hora ou uma frase curta explicando a etapa.
  final String? detail;
  final TrackState state;

  /// A etapa atual passou do prazo: o ponto e o pulso vão para o ocre, para
  /// a espera deixar de parecer normal.
  final bool alert;

  /// Quanto do prazo desta etapa já correu, de 0 a 1. Desenha uma barra fina
  /// embaixo do detalhe: a espera deixa de ser uma frase e passa a ser uma
  /// quantidade, que a pessoa vê encher.
  final double? progress;

  /// Uma linha a mais, menor, presa ao canto direito da barra — o prazo em
  /// si ("até 13/11"), para a barra não ficar sem escala.
  final String? note;
}

/// Linha do tempo vertical de uma doação.
///
/// A pessoa doa e some: fica sem saber se chegou, se a instituição viu, se
/// precisa fazer mais alguma coisa. A régua aqui é a da encomenda que se
/// acompanha — cada etapa com a hora em que aconteceu, a atual em destaque e
/// as futuras apagadas, para o estado ser lido de relance.
///
/// O movimento conta a mesma história: as etapas entram de cima para baixo,
/// a linha cheia desce atrás delas e a etapa atual fica pulsando — é o que
/// diz "parou aqui" sem precisar de uma frase a mais.
class DonationTimeline extends StatelessWidget {
  const DonationTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed)
          Reveal(
            delay: Duration(milliseconds: 90 * i),
            duration: AppMotion.slow,
            offset: 12,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        _Dot(state: step.state, alert: step.alert),
                        if (i < steps.length - 1)
                          Expanded(
                            child: _Line(
                              // A linha até a próxima etapa é sólida só quando
                              // esta já aconteceu.
                              solid: step.state == TrackState.done,
                              // Saindo da etapa atual, os tracinhos escorrem
                              // para baixo: a doação está a caminho da
                              // próxima etapa, e não parada.
                              flowing: step.state == TrackState.current,
                              alert: step.alert,
                              delay: Duration(milliseconds: 90 * i + 160),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: switch (step.state) {
                              TrackState.current => AppType.cardTitle(size: 17, color: AppColors.cinza900),
                              TrackState.done => AppType.label(size: 15.5, color: AppColors.cinza800),
                              TrackState.future => AppType.label(size: 15.5, color: AppColors.cinza500),
                            },
                          ),
                          if (step.detail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              step.detail!,
                              style: AppType.body(
                                size: 13.5,
                                color: step.alert
                                    ? AppColors.ocre700
                                    : step.state == TrackState.future
                                    ? AppColors.cinza500
                                    : AppColors.cinza600,
                              ),
                            ),
                          ],
                          if (step.progress != null) ...[
                            const SizedBox(height: 10),
                            _Prazo(value: step.progress!, alert: step.alert, note: step.note),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.state, this.alert = false});

  final TrackState state;
  final bool alert;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (widget.state == TrackState.current) _c.repeat();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.state == TrackState.current && !_c.isAnimating) {
      _c.repeat();
    } else if (widget.state != TrackState.current && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.alert ? AppColors.ocre600 : AppColors.petroleo600;
    final halo = widget.alert ? AppColors.ocre50 : AppColors.petroleo50;

    // A etapa atual ganha um halo e um pulso: é o único ponto da coluna que
    // o olho precisa achar sem procurar.
    if (widget.state == TrackState.current) {
      return SizedBox(
        width: 22,
        height: 22,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Duas ondas defasadas em meio ciclo: uma só deixa um silêncio
            // longo entre as batidas, e o olho lê como travada.
            for (final fase in const [0.0, .5])
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = Curves.easeOut.transform((_c.value + fase) % 1);
                  return Opacity(
                    opacity: (1 - t) * .45,
                    child: Container(
                      width: 13 + 15 * t,
                      height: 13 + 15 * t,
                      decoration: BoxDecoration(color: cor.withValues(alpha: .5), shape: BoxShape.circle),
                    ),
                  );
                },
              ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: halo, shape: BoxShape.circle),
            ),
            // O miolo respira junto com a onda: 2% de tamanho, o bastante
            // para o ponto parecer vivo sem puxar o olho da leitura.
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) =>
                  Transform.scale(scale: 1 + .06 * math.sin(_c.value * 2 * math.pi), child: child),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: cor, width: 4),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cheio = widget.state == TrackState.done;
    return SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.spring,
          width: cheio ? 12 : 10,
          height: cheio ? 12 : 10,
          decoration: BoxDecoration(
            color: cheio ? AppColors.petroleo600 : AppColors.white,
            shape: BoxShape.circle,
            border: cheio ? null : Border.all(color: AppColors.cinza300, width: 2),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatefulWidget {
  const _Line({required this.solid, this.flowing = false, this.alert = false, this.delay = Duration.zero});

  final bool solid;

  /// Sai da etapa atual: os tracinhos escorrem para baixo.
  final bool flowing;
  final bool alert;
  final Duration delay;

  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));

  @override
  void initState() {
    super.initState();
    if (widget.flowing && !widget.solid) _c.repeat();
  }

  @override
  void didUpdateWidget(_Line old) {
    super.didUpdateWidget(old);
    final correr = widget.flowing && !widget.solid;
    if (correr && !_c.isAnimating) {
      _c.repeat();
    } else if (!correr && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A linha cheia desce atrás da etapa que entrou; a tracejada já nasce
    // pronta, porque ela é só o lugar onde a doação ainda não chegou.
    if (!widget.solid) {
      final cor = widget.alert ? AppColors.ocre600 : AppColors.petroleo600;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: const Size(2, double.infinity),
          painter: _LinePainter(solid: false, progress: 1, phase: widget.flowing ? _c.value : null, accent: cor),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Interval((widget.delay.inMilliseconds / 900).clamp(0.0, .6), 1, curve: AppMotion.glide),
      builder: (context, t, _) => CustomPaint(
        size: const Size(2, double.infinity),
        painter: _LinePainter(solid: true, progress: t),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({required this.solid, required this.progress, this.phase, this.accent});

  final bool solid;

  /// Quanto da linha já desceu (0 a 1).
  final double progress;

  /// Onde está a onda que escorre pelos tracinhos (0 a 1), ou nulo quando a
  /// linha está parada.
  final double? phase;
  final Color? accent;

  static const _passo = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = solid ? AppColors.petroleo300 : AppColors.cinza300
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    final fim = 2 + (size.height - 4) * progress;
    if (solid) {
      if (fim > 2) canvas.drawLine(Offset(x, 2), Offset(x, fim), p);
      return;
    }
    // Tracejada: 4 de traço, 5 de respiro, até o fim.
    for (var y = 2.0; y < size.height - 2; y += _passo) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, size.height - 2)), p);
    }
    final t = phase;
    if (t == null || accent == null) return;
    // Por cima, um tracinho aceso que desce e se apaga no fim do caminho:
    // dá direção à espera sem acender a linha inteira.
    final alto = size.height - 4;
    final y = 2 + alto * t;
    final fade = (1 - t) * (t < .15 ? t / .15 : 1);
    canvas.drawLine(
      Offset(x, y),
      Offset(x, (y + 4).clamp(0, size.height - 2)),
      Paint()
        ..color = accent!.withValues(alpha: .85 * fade)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.solid != solid || old.progress != progress || old.phase != phase || old.accent != accent;
}

/// A barra do prazo.
///
/// "Aguardando confirmação" é uma frase sem fim; a barra dá fim a ela. Ela
/// enche uma vez ao abrir a tela, para a pessoa ver onde a espera está, e
/// vira ocre quando passa do combinado — é a mesma barra da meta, de
/// propósito: a interface já ensinou que barra cheia é coisa resolvida.
class _Prazo extends StatelessWidget {
  const _Prazo({required this.value, required this.alert, this.note});

  final double value;
  final bool alert;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final cor = alert ? AppColors.ocre600 : AppColors.petroleo600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A mesma barra da meta, mais fina: a interface já ensinou o que uma
        // barra dessas quer dizer, e o prazo se lê sem explicação nova.
        GoalBar(value: value, height: 5, color: cor),
        if (note != null) ...[
          const SizedBox(height: 5),
          Text(note!, style: AppType.body(size: 12, color: alert ? AppColors.ocre700 : AppColors.cinza500)),
        ],
      ],
    );
  }
}
