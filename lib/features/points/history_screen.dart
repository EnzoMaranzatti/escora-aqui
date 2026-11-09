import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';

/// "Extrato de pontos": cada entrada e saída, uma por linha. Saiu da aba
/// Pontos para a lista não empurrar o resto da tela para baixo.
class PointsHistoryScreen extends StatelessWidget {
  const PointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.pointsEntries;
        final p = store.points;
        return FlowScaffold(
          title: 'Extrato de pontos',
          subtitle: p == null
              ? null
              : '${Fmt.count(p.balance)} ${p.balance == 1 ? 'ponto' : 'pontos'} no saldo · ${Fmt.count(p.lifetime)} no total',
          background: AppColors.cinza50,
          children: [
            if (list.isEmpty)
              const EmptyState(
                icon: PhosphorIconsRegular.receipt,
                title: 'Nada por aqui ainda.',
                text:
                    'Assim que o primeiro ponto entrar, ele aparece nesta lista com a data e o motivo.',
              )
            else ...[
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, e) in list.indexed) ...[
                      if (i > 0) const Hairline(),
                      PointsEntryRow(entry: e),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Os pontos entram quando a instituição confirma que recebeu. Eles não viram dinheiro: o app não movimenta valor.',
                style: AppType.body(size: 13.5),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Uma linha do extrato. Fica aqui porque a aba Pontos não mostra mais a
/// lista, mas a comemoração e o catálogo ainda podem reaproveitar.
class PointsEntryRow extends StatelessWidget {
  const PointsEntryRow({super.key, required this.entry});

  final PointsEntry entry;

  @override
  Widget build(BuildContext context) {
    final gain = entry.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.note.isEmpty ? entry.reason.label : entry.note,
                  style: AppType.label(color: AppColors.cinza900, size: 15),
                ),
                const SizedBox(height: 2),
                // Sem nota, o título já é o motivo: aqui fica só a data, para
                // não aparecer "Login diário · Login diário".
                Text(
                  entry.note.isEmpty
                      ? Fmt.date(entry.date)
                      : '${entry.reason.label} · ${Fmt.date(entry.date)}',
                  style: AppType.body(size: 13.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${gain ? '+' : '−'}${Fmt.count(entry.amount.abs())}',
            style: AppType.cardTitle(
              size: 16,
              color: gain ? AppColors.petroleo700 : AppColors.cinza600,
            ).copyWith(fontFeatures: tabular),
          ),
        ],
      ),
    );
  }
}
