import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kit.dart';
import '../../data/store.dart';
import '../map/pins.dart';
import 'donation_screen.dart' show DonationScreen;
import '../../core/routes.dart';

/// Resumo das doações do ponto: quanto entrou, quando e de quem. Tudo é
/// calculado aqui, em cima das doações que já vieram no carregamento — não
/// há consulta nova no banco.
class DonationsSummary extends StatefulWidget {
  const DonationsSummary({super.key, required this.place});

  final Place place;

  @override
  State<DonationsSummary> createState() => _DonationsSummaryState();
}

class _DonationsSummaryState extends State<DonationsSummary> {
  /// false = últimas 8 semanas; true = últimos 6 meses.
  bool _porMes = false;

  @override
  Widget build(BuildContext context) {
    final hoje = Fmt.dateOnly(DateTime.now());
    final todas = store.incoming(widget.place).where((d) => d.status != DonationStatus.cancelled).toList();
    final ok = todas.where((d) => d.status == DonationStatus.confirmed).toList();

    if (todas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: EmptyState(
          icon: PhosphorIconsRegular.chartBar,
          title: 'Ainda não há o que resumir.',
          text: 'Quando as primeiras doações chegarem, os números desta aba começam a contar a história do ponto.',
        ),
      );
    }

    // ── Mês atual contra o mês passado ────────────────────────
    final inicioMes = DateTime(hoje.year, hoje.month);
    final inicioMesPassado = DateTime(hoje.year, hoje.month - 1);
    final mes = ok.where((d) => !d.date.isBefore(inicioMes)).toList();
    final mesPassado = ok
        .where((d) => !d.date.isBefore(inicioMesPassado) && d.date.isBefore(inicioMes))
        .toList();
    final dinheiroMes = _money(mes);
    final dinheiroMesPassado = _money(mesPassado);

    // ── Semana atual contra a semana passada ──────────────────
    final inicioSemana = hoje.subtract(Duration(days: hoje.weekday - 1));
    final inicioSemanaPassada = inicioSemana.subtract(const Duration(days: 7));
    final semana = ok.where((d) => !d.date.isBefore(inicioSemana)).toList();
    final semanaPassada = ok
        .where((d) => !d.date.isBefore(inicioSemanaPassada) && d.date.isBefore(inicioSemana))
        .toList();

    final pessoas = mes.map((d) => d.donorId ?? d.donor).toSet().length;
    final itens = mes.where((d) => d.type == HelpType.itens).fold<double>(0, (a, d) => a + d.amount);
    final esperando = todas.where((d) => d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroMes(dinheiroMes, mes.length, dinheiroMesPassado),
        const SizedBox(height: 12),
        // Rótulos curtos de propósito: cada tile tem uma linha de rótulo e
        // uma de apoio, e é isso que deixa os quatro com a mesma altura.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  value: '${semana.length}',
                  label: 'Nesta semana',
                  hint: '${semanaPassada.length} na semana passada',
                  trend: TrendPill(_percent(semana.length.toDouble(), semanaPassada.length.toDouble())),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '$pessoas',
                  label: pessoas == 1 ? 'Pessoa no mês' : 'Pessoas no mês',
                  hint: 'Ao menos uma doação',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatTile(
                  value: Fmt.count(itens),
                  label: 'Itens no mês',
                  hint: itens == 0 ? 'Nenhuma entrega ainda' : 'Entregas confirmadas',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  value: '${esperando.length}',
                  label: 'Esperando você',
                  hint: esperando.isEmpty ? 'Fila vazia' : 'Na aba Fila',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(
          _porMes ? 'Últimos 6 meses' : 'Últimas 8 semanas',
          trailing: Row(
            children: [
              ChoiceChipPill(label: 'Semanas', selected: !_porMes, onTap: () => setState(() => _porMes = false)),
              const SizedBox(width: 6),
              ChoiceChipPill(label: 'Meses', selected: _porMes, onTap: () => setState(() => _porMes = true)),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: BarChart(bars: _porMes ? _barrasMes(ok, hoje) : _barrasSemana(ok, inicioSemana)),
        ),
        const SizedBox(height: 22),
        const SectionTitle('De onde vem a ajuda'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entre as ${ok.length} ${ok.length == 1 ? 'doação confirmada' : 'doações confirmadas'} do ponto.',
                style: AppType.body(size: 13.5),
              ),
              const SizedBox(height: 14),
              SplitBar(
                slices: [
                  for (final t in HelpType.values)
                    Slice(
                      label: t.label,
                      value: ok.where((d) => d.type == t).length.toDouble(),
                      color: t.color,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ..._topDoadores(ok),
      ],
    );
  }

  /// Só Pix vira dinheiro; itens e voluntariado contam em outro lugar.
  double _money(List<Donation> list) =>
      list.where((d) => d.type == HelpType.pix).fold<double>(0, (a, d) => a + d.amount);

  /// Variação contra o período anterior. Nula quando não havia nada antes:
  /// "+100%" em cima de zero não informa nada.
  double? _percent(double agora, double antes) {
    if (antes <= 0) return null;
    return (agora - antes) * 100 / antes;
  }

  Widget _heroMes(double agora, int quantas, double antes) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recebido em ${Fmt.month(DateTime.now())}', style: AppType.body(size: 14)),
              const Spacer(),
              TrendPill(_percent(agora, antes)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Fmt.money(agora),
            style: AppType.display(size: 34).copyWith(height: 1.05, fontFeatures: tabular),
          ),
          const SizedBox(height: 6),
          Text(
            antes <= 0
                ? '$quantas ${quantas == 1 ? 'doação confirmada' : 'doações confirmadas'} no mês'
                : '$quantas ${quantas == 1 ? 'doação confirmada' : 'doações confirmadas'} · '
                      '${Fmt.money(antes)} no mês passado',
            style: AppType.body(size: 14),
          ),
        ],
      ),
    );
  }

  List<Bar> _barrasSemana(List<Donation> ok, DateTime inicioSemana) {
    return [
      for (var i = 7; i >= 0; i--)
        () {
          final ini = inicioSemana.subtract(Duration(days: 7 * i));
          final fim = ini.add(const Duration(days: 7));
          final n = ok.where((d) => !d.date.isBefore(ini) && d.date.isBefore(fim)).toList();
          return Bar(
            label: '${ini.day}/${ini.month}',
            value: n.length.toDouble(),
            caption: '${n.length} ${n.length == 1 ? 'doação' : 'doações'}',
          );
        }(),
    ];
  }

  List<Bar> _barrasMes(List<Donation> ok, DateTime hoje) {
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final ini = DateTime(hoje.year, hoje.month - i);
          final fim = DateTime(hoje.year, hoje.month - i + 1);
          final n = ok.where((d) => !d.date.isBefore(ini) && d.date.isBefore(fim)).toList();
          return Bar(
            label: Fmt.month(ini).substring(0, 3),
            value: n.length.toDouble(),
            caption: '${n.length} ${n.length == 1 ? 'doação' : 'doações'}',
          );
        }(),
    ];
  }

  /// Quem mais apareceu. Toca e vai para a doação mais recente da pessoa,
  /// que é por onde se chega ao contato dela.
  List<Widget> _topDoadores(List<Donation> ok) {
    final porPessoa = <String, List<Donation>>{};
    for (final d in ok) {
      porPessoa.putIfAbsent(d.donorId ?? 'nome:${d.donor}', () => []).add(d);
    }
    final top = porPessoa.values.toList()
      ..sort((a, b) {
        final c = b.length.compareTo(a.length);
        return c != 0 ? c : _money(b).compareTo(_money(a));
      });
    if (top.length < 2) return const [];
    return [
      const SectionTitle('Quem mais ajudou'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final (i, lista) in top.take(5).indexed) ...[
              if (i > 0) const Hairline(),
              _LinhaDoador(lista: lista, posicao: i + 1),
            ],
          ],
        ),
      ),
    ];
  }
}

class _LinhaDoador extends StatelessWidget {
  const _LinhaDoador({required this.lista, required this.posicao});

  final List<Donation> lista;
  final int posicao;

  @override
  Widget build(BuildContext context) {
    final nome = lista.first.donor;
    final dinheiro = lista
        .where((d) => d.type == HelpType.pix)
        .fold<double>(0, (a, d) => a + d.amount);
    final recente = lista.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    return InfoRow(
      title: nome,
      value:
          '${lista.length} ${lista.length == 1 ? 'doação' : 'doações'}'
          '${dinheiro > 0 ? ' · ${Fmt.money(dinheiro)}' : ''}',
      chevron: true,
      onTap: () => context.push(DonationScreen(recente.id)),
      trailing: posicao == 1
          ? const StatusTag('Topo', tone: Tone.alert)
          : null,
    );
  }
}
