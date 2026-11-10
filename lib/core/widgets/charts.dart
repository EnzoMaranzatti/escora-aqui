import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import 'kit.dart';

/// Números e gráficos do resumo. Tudo desenhado à mão: o style guide pede
/// grafismo sóbrio (preenchimento sólido, sem gradiente nem textura) e o
/// projeto não entra pacote de gráfico só para três formas.

/// Um número grande com rótulo embaixo. Usado em grade de dois.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.trend,
    this.onTap,
  });

  final String value;
  final String label;

  /// Linha fina embaixo ("3 na semana passada").
  final String? hint;
  final Widget? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.display(size: 26).copyWith(height: 1.1, fontFeatures: tabular),
                ),
              ),
              if (trend != null) ...[const SizedBox(width: 6), trend!],
            ],
          ),
          const SizedBox(height: 6),
          // Uma linha cada, sempre: é o que faz os quatro tiles da grade
          // terminarem na mesma altura, em qualquer tamanho de fonte.
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.label(color: AppColors.cinza800, size: 14),
          ),
          const SizedBox(height: 2),
          Text(
            hint ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body(size: 12.5),
          ),
        ],
      ),
    );
  }
}

/// "+18%" com a seta. Subida é sucesso; queda é neutra de propósito —
/// uma semana mais fraca não é erro, e vermelho piscando é anti-padrão.
class TrendPill extends StatelessWidget {
  const TrendPill(this.percent, {super.key});

  /// Nulo quando não há período anterior para comparar.
  final double? percent;

  @override
  Widget build(BuildContext context) {
    final p = percent;
    if (p == null) return const SizedBox.shrink();
    final up = p >= 0;
    final tone = up ? Tone.success : Tone.neutral;
    final n = p.abs() >= 100 ? p.abs().round() : double.parse(p.abs().toStringAsFixed(0));
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown, size: 13, color: tone.fg),
          const SizedBox(width: 3),
          Text(
            '${up ? '+' : '−'}${n.toStringAsFixed(0)}%',
            style: AppType.label(color: tone.fg, size: 12.5).copyWith(height: 1.1, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Uma barra do gráfico.
class Bar {
  const Bar({required this.label, required this.value, this.caption});

  final String label;
  final double value;

  /// Texto do balão quando a barra é tocada ("R$ 180,00").
  final String? caption;
}

/// Colunas verticais com rótulo embaixo. A última barra é a atual e vem
/// em petróleo cheio; as outras ficam em petróleo claro. Tocar numa barra
/// seleciona ela e mostra o valor em cima.
class BarChart extends StatefulWidget {
  const BarChart({super.key, required this.bars, this.height = 132});

  final List<Bar> bars;
  final double height;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) return const SizedBox.shrink();
    final max = bars.map((b) => b.value).reduce((a, b) => a > b ? a : b);
    final sel = _touched ?? bars.length - 1;
    final b = bars[sel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              b.caption ?? b.value.toStringAsFixed(0),
              style: AppType.cardTitle(size: 17, color: AppColors.cinza900).copyWith(fontFeatures: tabular),
            ),
            const SizedBox(width: 6),
            Text(b.label, style: AppType.body(size: 13.5)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, bar) in bars.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // onTap, não onTapDown: com onTapDown, rolar a tela por
                    // cima do gráfico trocava a barra selecionada.
                    onTap: () => setState(() => _touched = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final h = max <= 0 ? 0.0 : (bar.value / max) * box.maxHeight;
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: h < 3 && bar.value > 0 ? 3 : h),
                                    duration: AppMotion.slow,
                                    curve: AppMotion.smooth,
                                    builder: (context, v, _) => Container(
                                      height: v,
                                      decoration: BoxDecoration(
                                        color: i == sel ? AppColors.petroleo600 : AppColors.petroleo100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bar.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: AppType.body(
                              size: 11.5,
                              color: i == sel ? AppColors.cinza800 : AppColors.cinza600,
                            ).copyWith(fontWeight: i == sel ? FontWeight.w700 : FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Uma fatia da barra de composição.
class Slice {
  const Slice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Barra horizontal única dividida por tipo, com legenda embaixo. Faz o
/// trabalho de um gráfico de pizza ocupando um terço do espaço.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.slices});

  final List<Slice> slices;

  @override
  Widget build(BuildContext context) {
    final shown = slices.where((s) => s.value > 0).toList();
    final total = shown.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final (i, s) in shown.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(flex: (s.value * 1000 / total).round().clamp(1, 1000), child: ColoredBox(color: s.color)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in shown)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(s.label, style: AppType.body(size: 13.5)),
                  const SizedBox(width: 5),
                  Text(
                    '${(s.value * 100 / total).round()}%',
                    style: AppType.label(
                      color: AppColors.cinza900,
                      size: 13.5,
                    ).copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
