import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';

/// "Denúncias abertas", grouped by point.
class TeamReportsScreen extends StatelessWidget {
  const TeamReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final groups = store.openReports.entries.toList()
          ..sort(
            (a, b) => b.value
                .map((r) => r.date)
                .reduce((x, y) => x.isAfter(y) ? x : y)
                .compareTo(a.value.map((r) => r.date).reduce((x, y) => x.isAfter(y) ? x : y)),
          );
        return TabPage(
          title: 'Denúncias abertas',
          slivers: [
            if (groups.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: EmptyState(icon: PhosphorIconsRegular.flag, title: 'Nenhuma denúncia aberta.'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = store.place(groups[i].key);
                    final list = groups[i].value;
                    final last = list.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
                    final scam = list.any((r) => r.reason == 'Suspeito de golpe');
                    return AppCard(
                      onTap: () => context.push(ReportDetailScreen(placeId: p.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: AppType.label(
                                    color: AppColors.cinza900,
                                    size: 15.5,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza400),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_mostCommon(list)} · ${list.length} ${list.length == 1 ? 'denúncia' : 'denúncias'} · última há ${Fmt.ago(last)}',
                            style: AppType.body(size: 13.5),
                          ),
                          if (scam) ...[
                            const SizedBox(height: 8),
                            const StatusTag('Suspeita de golpe', tone: Tone.error, icon: PhosphorIconsFill.warning),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

String _mostCommon(List<Report> list) {
  final count = <String, int>{};
  for (final r in list) {
    count[r.reason] = (count[r.reason] ?? 0) + 1;
  }
  return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.placeId});

  final String placeId;

  Future<void> _keep(BuildContext context, Place p) async {
    final r = await confirmSheet(
      context,
      title: 'Encerrar a denúncia e manter ${p.name} no mapa?',
      field: const SheetField(label: 'O que vocês conferiram', required: true, help: 'Fica só no registro interno.'),
      confirm: 'Manter no mapa',
      cancel: 'Voltar',
    );
    if (r == null || !context.mounted) return;
    store.keepOnMap(p.id);
    Navigator.pop(context);
  }

  Future<void> _pause(BuildContext context, Place p) async {
    final r = await confirmSheet(
      context,
      icon: PhosphorIconsRegular.pauseCircle,
      iconTone: Tone.alert,
      title: 'Pausar ${p.name}?',
      text:
          'O ponto sai do mapa e as metas ficam paradas até você reativar. A instituição recebe um aviso com o motivo.',
      field: const SheetField(label: 'Motivo', required: true, help: 'Aparece para a instituição.'),
      confirm: 'Pausar ponto',
      cancel: 'Voltar',
    );
    if (r == null || !context.mounted) return;
    store.pause(p.id, r);
    Navigator.pop(context);
  }

  Future<void> _remove(BuildContext context, Place p) async {
    final r = await confirmSheet(
      context,
      title: 'Remover ${p.name} do Escora aqui?',
      text:
          'O ponto sai do mapa de forma definitiva e as metas abertas são encerradas. Doadores com doações aguardando confirmação recebem um aviso.',
      field: const SheetField(label: 'Motivo da remoção', required: true),
      confirm: 'Remover ponto',
      cancel: 'Pausar em vez disso',
      destructive: true,
      onCancel: () => _pause(context, p),
    );
    if (r == null || !context.mounted) return;
    store.remove(p.id, r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = store.place(placeId);
    final list = store.openReports[placeId] ?? const <Report>[];
    return FlowScaffold(
      title: p.name,
      subtitle: '${p.typeLabel} · ${p.neighborhood}',
      background: AppColors.cinza50,
      primary: 'Manter no mapa',
      primaryIcon: null,
      onPrimary: () => _keep(context, p),
      secondary: 'Pausar ponto',
      onSecondary: () => _pause(context, p),
      children: [
        for (final r in list) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.reason,
                        style: AppType.label(color: AppColors.cinza900, size: 15).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(Fmt.day(r.date), style: AppType.body(size: 13)),
                  ],
                ),
                if (r.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.text, style: AppType.body(size: 14.5, color: AppColors.cinza700)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        Center(
          child: LinkText('Remover ponto', color: AppColors.erroTexto, onTap: () => _remove(context, p)),
        ),
      ],
    );
  }
}
