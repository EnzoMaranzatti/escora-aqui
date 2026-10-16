import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../map/pins.dart';

/// "Todos os pontos": active, paused and overdue for review.
class TeamPointsScreen extends StatefulWidget {
  const TeamPointsScreen({super.key});

  @override
  State<TeamPointsScreen> createState() => _TeamPointsScreenState();
}

class _TeamPointsScreenState extends State<TeamPointsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.places.where((p) => p.verifiedAt != null && p.status != PlaceStatus.removed).toList();
        bool overdue(Place p) => p.status == PlaceStatus.active && p.daysSinceReview > 90;
        final list = switch (_tab) {
          0 => all.where((p) => p.status == PlaceStatus.active).toList(),
          1 => all.where((p) => p.status == PlaceStatus.paused).toList(),
          _ => all.where(overdue).toList(),
        }..sort((a, b) => a.name.compareTo(b.name));
        return TabPage(
          title: 'Todos os pontos',
          top: Segmented(
            dense: true,
            items: const ['Ativos', 'Pausados', 'Atualização vencida'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          slivers: [
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    switch (_tab) {
                      1 => 'Nenhum ponto pausado.',
                      2 => 'Nenhum ponto com atualização vencida.',
                      _ => 'Nenhum ponto ativo.',
                    },
                    textAlign: TextAlign.center,
                    style: AppType.body(size: 15.5),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    final paused = p.status == PlaceStatus.paused;
                    final (label, tone) = paused
                        ? ('Pausado', Tone.alert)
                        : overdue(p)
                        ? ('Atualização vencida há ${p.daysSinceReview - 90} dias', Tone.alert)
                        : ('Ativo', Tone.success);
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (paused)
                                InstitutionPin(icon: p.kind.icon, ring: p.primaryType.ring, dimmed: true, size: 38)
                              else
                                PlaceThumb(place: p, size: 38),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: AppType.label(
                                        color: AppColors.cinza900,
                                        size: 15.5,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('verificado em ${Fmt.day(p.verifiedAt!)}', style: AppType.body(size: 13.5)),
                                  ],
                                ),
                              ),
                              StatusTag(label, tone: tone),
                            ],
                          ),
                          if (paused) ...[
                            const SizedBox(height: 12),
                            SoftButton(
                              label: 'Reativar ponto',
                              icon: PhosphorIconsRegular.playCircle,
                              filled: true,
                              expand: true,
                              onTap: () {
                                store.reactivate(p.id);
                                Toast.show(context, '${p.name} está de volta no mapa. A instituição recebeu um aviso.');
                              },
                            ),
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
