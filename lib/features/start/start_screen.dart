import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../donations/donation_detail_screen.dart';
import '../donations/donations_screen.dart';
import '../map/pins.dart';
import '../place/place_screen.dart';
import '../shared/help_ui.dart';
import '../shell/donor_shell.dart';

/// A primeira tela de quem doa.
///
/// O mapa responde "o que tem perto de mim?", mas só quem já sabe o que
/// procura abre um mapa. Esta tela responde antes: o que está acabando o
/// prazo, quem está pertinho e em que pé ficou a última ajuda. O mapa
/// continua a um toque, como a segunda aba.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  String get _saudacao {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  /// Primeiro nome: o título é uma saudação, não um cadastro.
  String get _nome {
    final n = store.name.trim();
    return n.isEmpty ? 'tudo bem?' : '${n.split(' ').first}!';
  }

  LatLng get _here => onboarding.position ?? store.center;

  /// Metas abertas com prazo mais perto, de pontos verificados.
  List<(Place, Goal)> _urgentes() {
    final lista = <(Place, Goal)>[];
    for (final p in store.verifiedPlaces) {
      for (final g in p.openGoals) {
        lista.add((p, g));
      }
    }
    lista.sort((a, b) => a.$2.deadline.compareTo(b.$2.deadline));
    return lista.take(6).toList();
  }

  List<Place> _perto() {
    final lista = store.verifiedPlaces.toList()..sort((a, b) => a.kmFrom(_here).compareTo(b.kmFrom(_here)));
    return lista.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, onboarding]),
      builder: (context, _) {
        final urgentes = _urgentes();
        final perto = _perto();
        final minhas = store.myDonations.take(2).toList();
        final cidade = onboarding.city ?? 'São José do Rio Preto';
        return TabPage(
          title: '$_saudacao, $_nome',
          subtitle: Text(
            'Pontos de apoio verificados em $cidade.',
            style: AppType.body(size: 14.5, color: AppColors.cinza600),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              sliver: SliverList.list(
                children: [
                  if (urgentes.isNotEmpty) ...[
                    SectionTitle(
                      'Acaba logo',
                      trailing: _Link(label: 'Ver no mapa', onTap: () => goToTab(context, mapTab)),
                    ),
                  ],
                ],
              ),
            ),
            if (urgentes.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 252,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    itemCount: urgentes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final (p, g) = urgentes[i];
                      return _MetaCard(place: p, goal: g, km: p.kmFrom(_here));
                    },
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              sliver: SliverList.list(
                children: [
                  SectionTitle(
                    'Pertinho de você',
                    trailing: _Link(label: 'Ver todos', onTap: () => goToTab(context, mapTab)),
                  ),
                  for (final p in perto) ...[_PontoLinha(place: p, km: p.kmFrom(_here)), const SizedBox(height: 10)],
                  const SizedBox(height: 14),
                  if (minhas.isEmpty)
                    _Convite(onTap: () => goToTab(context, mapTab))
                  else ...[
                    SectionTitle(
                      'Você já ajudou',
                      trailing: _Link(
                        label: 'Ver todas',
                        onTap: () => context.push(const DonationsScreen(standalone: true)),
                      ),
                    ),
                    for (final d in minhas) ...[_DoacaoLinha(d: d), const SizedBox(height: 10)],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Ver todos" do lado do título da seção.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: .96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppType.label(size: 13.5, color: AppColors.petroleo600)),
            const SizedBox(width: 2),
            const Icon(PhosphorIconsBold.caretRight, size: 13, color: AppColors.petroleo600),
          ],
        ),
      ),
    );
  }
}

/// A meta que está acabando: foto, o que falta e para quem.
class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.place, required this.goal, required this.km});

  final Place place;
  final Goal goal;
  final double km;

  @override
  Widget build(BuildContext context) {
    final image = place.image;
    final dias = Fmt.dateOnly(goal.deadline).difference(Fmt.dateOnly(DateTime.now())).inDays;
    return Pressable(
      onTap: () => context.push(PlaceScreen(placeId: place.id)),
      scale: .98,
      child: SizedBox(
        width: 232,
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: SizedBox(
                  height: 104,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: goal.type.color,
                        child: image == null ? null : Image(image: ResizeImage(image, width: 480), fit: BoxFit.cover),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _Selo(
                          label: dias <= 0 ? 'Último dia' : (dias == 1 ? 'Falta 1 dia' : 'Faltam $dias dias'),
                          urgente: dias <= 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TypeTag(goal.type),
                        const Spacer(),
                        Text(
                          Fmt.km(km),
                          style: AppType.body(size: 12, color: AppColors.cinza500).copyWith(fontFeatures: tabular),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      goal.quantity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label(size: 15, color: AppColors.cinza900).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 13, color: AppColors.cinza600),
                    ),
                    const SizedBox(height: 10),
                    GoalBar(
                      value: goal.type == HelpType.voluntariado ? goal.enrolled / goal.target : goal.progress,
                      height: 6,
                      color: goal.type.color,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A etiqueta do prazo em cima da foto.
class _Selo extends StatelessWidget {
  const _Selo({required this.label, required this.urgente});

  final String label;
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: urgente ? AppColors.ocre600 : AppColors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(label, style: AppType.strong(size: 11.5, color: urgente ? AppColors.white : AppColors.cinza800)),
    );
  }
}

/// Um ponto perto, em uma linha.
class _PontoLinha extends StatelessWidget {
  const _PontoLinha({required this.place, required this.km});

  final Place place;
  final double km;

  @override
  Widget build(BuildContext context) {
    final g = place.nextGoal;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(PlaceScreen(placeId: place.id)),
      child: Row(
        children: [
          PlaceThumb(place: place, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(size: 15.5, color: AppColors.cinza900),
                ),
                const SizedBox(height: 3),
                Text(
                  g == null ? 'a ${Fmt.km(km)} · sem metas abertas' : 'a ${Fmt.km(km)} · ${g.quantity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 13, color: AppColors.cinza600).copyWith(fontFeatures: tabular),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.cinza400),
        ],
      ),
    );
  }
}

/// Uma doação recente, em uma linha.
class _DoacaoLinha extends StatelessWidget {
  const _DoacaoLinha({required this.d});

  final Donation d;

  @override
  Widget build(BuildContext context) {
    final p = store.place(d.placeId);
    final confirmada = d.status == DonationStatus.confirmed;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(DonationDetailScreen(d.id)),
      child: Row(
        children: [
          PlaceThumb(place: p, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle(size: 15.5, color: AppColors.cinza900),
                ),
                const SizedBox(height: 4),
                StatusTag(
                  confirmada ? 'Confirmada' : 'Aguardando confirmação',
                  tone: confirmada ? Tone.success : Tone.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.cinza400),
        ],
      ),
    );
  }
}

/// Quem ainda não ajudou não tem histórico para ver: ganha um convite.
class _Convite extends StatelessWidget {
  const _Convite({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.petroleo600,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comece por um ponto perto', style: AppType.cardTitle(size: 16, color: AppColors.white)),
                const SizedBox(height: 4),
                Text(
                  'Dá para ajudar com Pix, com itens ou com um dia do seu tempo.',
                  style: AppType.body(size: 13.5, color: AppColors.white.withValues(alpha: .82)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(PhosphorIconsBold.arrowUpRight, size: 20, color: AppColors.white),
        ],
      ),
    );
  }
}
