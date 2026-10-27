import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../donate/monthly_screen.dart';
import '../donate/items_screen.dart';
import '../donate/pix_screen.dart';
import '../donate/volunteer_screen.dart';
import '../map/escora_map.dart';
import '../map/pins.dart';
import '../shared/help_ui.dart';
import 'report_screen.dart';

/// Who the institution is, what it needs now and why, and how to help.
/// The reason always comes before the help button (strategy rule).
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.placeId, this.preview = false});

  final String placeId;

  /// Opened by the institution itself: no help buttons nor report link.
  final bool preview;

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // A point can leave the map while open (paused by the team).
        final p = store.placeOrNull(widget.placeId);
        if (p == null) {
          return const FlowScaffold(
            title: 'Este ponto saiu do mapa.',
            subtitle: 'A equipe está conferindo as informações dele. Seus registros continuam em Minhas doações.',
            children: [],
          );
        }
        final pad = MediaQuery.paddingOf(context);
        final here = onboarding.position ?? store.center;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: AppColors.cinza50,
            body: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(place: p, map: _map),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, pad.bottom + 32),
                      sliver: SliverList.list(
                        children: [
                          Reveal(
                            offset: 10,
                            child: _Identity(place: p, distance: p.kmFrom(here)),
                          ),
                          const SizedBox(height: 28),
                          if (p.pixPaused) ...[
                            const NoticeBanner(
                              tone: Tone.alert,
                              text: 'Doações via Pix pausadas enquanto a instituição atualiza seus dados.',
                            ),
                            const SizedBox(height: 20),
                          ],
                          Reveal(
                            delay: const Duration(milliseconds: 80),
                            child: _Needs(place: p, preview: widget.preview),
                          ),
                          if (!widget.preview &&
                              !p.pixPaused &&
                              p.accepts.contains(HelpType.pix) &&
                              (p.pixKey ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            MonthlyCta(place: p),
                          ],
                          if ((p.distributes ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 28),
                            const SectionTitle('O que distribui'),
                            AppCard(
                              child: Text(p.distributes!, style: AppType.body(size: 15.5, color: AppColors.cinza700)),
                            ),
                          ],
                          const SizedBox(height: 28),
                          const SectionTitle('Sobre'),
                          _About(place: p),
                          const SizedBox(height: 28),
                          _Reviews(place: p),
                          if (!widget.preview) ...[
                            const SizedBox(height: 28),
                            Center(
                              child: LinkText(
                                'Denunciar este ponto',
                                icon: PhosphorIconsRegular.flag,
                                color: AppColors.cinza600,
                                onTap: () => context.push(ReportScreen(placeId: p.id)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: pad.top + 6,
                  left: 16,
                  child: RoundBackButton(onTap: () => Navigator.of(context).maybePop()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.place, required this.map});

  final Place place;
  final MapController map;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final h = 230 + pad.top;
    final photo = place.image;
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image(image: photo, fit: BoxFit.cover)
          else
            IgnorePointer(
              child: EscoraMap(
                controller: map,
                initialCenter: place.point,
                initialZoom: 15.4,
                interactive: false,
                children: [
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: place.point,
                        width: 72,
                        height: 72,
                        child: Center(
                          child: InstitutionPin(
                            icon: place.kind.icon,
                            color: place.primaryType.color,
                            ring: place.primaryType.ring,
                            size: 44,
                            selected: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // Fade into the page, full width, no visible edge.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .55, 1],
                colors: [Color(0x00F8F6F3), Color(0x00F8F6F3), AppColors.cinza50],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.place, required this.distance});

  final Place place;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final verified = place.verifiedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.name, style: AppType.display(size: 28)),
        const SizedBox(height: 4),
        Text('${place.typeLabel} · ${place.neighborhood}', style: AppType.body(size: 15.5)),
        const SizedBox(height: 12),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (verified != null) Seal(label: 'Verificado em ${Fmt.day(verified)}', size: 13),
            if (verified != null) LinkText('O que verificamos', onTap: () => showVerifiedSheet(context, place)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(PhosphorIconsRegular.mapPin, size: 16, color: AppColors.cinza600),
            const SizedBox(width: 4),
            Text('a ${Fmt.km(distance)} de você', style: AppType.body(size: 14.5)),
          ],
        ),
      ],
    );
  }
}

/// "Como este ponto foi verificado": says exactly what is checked and
/// what isn't ("honesto sobre o que garante").
Future<void> showVerifiedSheet(BuildContext context, Place p) {
  return showAppSheet<void>(
    context,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          icon: PhosphorIconsFill.sealCheck,
          title: 'Como este ponto foi verificado',
          text: p.cnpj == null
              ? 'Este ponto não tem CNPJ. Ele foi indicado por ${p.indicatedBy ?? 'uma instituição verificada'}, que já é verificada, e teve endereço e foto conferidos pela nossa equipe.'
              : 'Antes de aparecer no mapa, a equipe do Escora aqui conferiu o CNPJ em base pública, o endereço e uma foto do local. A verificação confirma que a instituição existe e está ativa. As metas e os valores são informados pela própria instituição.',
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Entendi', icon: null, onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

class _Needs extends StatelessWidget {
  const _Needs({required this.place, required this.preview});

  final Place place;
  final bool preview;

  void _follow(BuildContext context) {
    store.follow(place.id);
    HapticFeedback.mediumImpact();
    Toast.show(context, 'Pronto. Você vai receber um aviso quando ${place.name} abrir uma meta.');
  }

  @override
  Widget build(BuildContext context) {
    final open = place.openGoals;
    final closed = place.recentClosed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('O que precisa agora'),
        if (open.isEmpty)
          AppCard(
            child: EmptyState(
              compact: true,
              icon: PhosphorIconsRegular.bellSimple,
              title: '${place.name} não tem metas abertas agora.',
              text: 'Quer ser avisado quando surgir uma nova?',
              primary: preview || store.followed.contains(place.id) ? null : 'Acompanhar este ponto',
              onPrimary: () => _follow(context),
            ),
          ),
        for (final g in open) ...[
          GoalCard(place: place, goal: g, preview: preview, onFollow: () => _follow(context)),
          const SizedBox(height: 12),
        ],
        for (final g in closed) ...[
          if (open.isEmpty) const SizedBox(height: 12),
          GoalCard(place: place, goal: g, preview: true),
          if (open.isNotEmpty) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// One goal: quantity + deadline, reason, confirmed progress and the
/// help button for its type.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.place, required this.goal, this.preview = false, this.onFollow});

  final Place place;
  final Goal goal;
  final bool preview;
  final VoidCallback? onFollow;

  void _help(BuildContext context) {
    final page = switch (goal.type) {
      HelpType.pix => PixScreen(placeId: place.id, goalId: goal.id),
      HelpType.itens => ItemsScreen(placeId: place.id, goalId: goal.id),
      HelpType.voluntariado => VolunteerScreen(placeId: place.id, goalId: goal.id),
    };
    context.push(page);
  }

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final done = g.status == GoalStatus.done;
    final expired = g.status == GoalStatus.expired;
    final active = !done && !expired;
    final volunteer = g.type == HelpType.voluntariado;
    final full = volunteer && g.slotsLeft == 0;
    final pixPaused = g.type == HelpType.pix && place.pixPaused;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      color: active ? AppColors.white : AppColors.cinza50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeTag(g.type),
              const Spacer(),
              if (done)
                StatusTag(
                  'Meta concluída em ${Fmt.day(g.doneAt ?? g.deadline)}',
                  tone: Tone.success,
                  icon: PhosphorIconsFill.checkCircle,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (volunteer && g.action != null) ...[
            Text(g.action!.name, style: AppType.title().copyWith(fontSize: 20, height: 1.2)),
            const SizedBox(height: 4),
            Text(g.action!.when, style: AppType.body(size: 14.5, color: AppColors.cinza700)),
          ] else
            Text(g.headline, style: AppType.title().copyWith(fontSize: 21, height: 1.2, fontFeatures: tabular)),
          const SizedBox(height: 8),
          Text('Motivo: ${g.reason}', style: AppType.body(size: 15, color: AppColors.cinza700)),
          const SizedBox(height: 14),
          GoalBar(
            value: volunteer ? (g.enrolled / g.target).clamp(0, 1) : g.progress,
            color: active ? AppColors.petroleo600 : AppColors.cinza400,
          ),
          const SizedBox(height: 8),
          if (expired)
            Text(
              'Prazo encerrado. ${g.progressLabel} arrecadados.',
              style: AppType.body(size: 13.5, color: AppColors.cinza700).copyWith(fontFeatures: tabular),
            )
          else if (volunteer)
            Text(
              '${g.slotsLeft} de ${g.target.round()} vagas disponíveis',
              style: AppType.body(size: 13.5).copyWith(fontFeatures: tabular),
            )
          else
            Text(
              '${g.progressLabel} · confirmado pela instituição',
              style: AppType.body(size: 13.5).copyWith(fontFeatures: tabular),
            ),
          if (active && !preview && !pixPaused) ...[
            const SizedBox(height: 14),
            if (full)
              NoticeBanner(
                tone: Tone.neutral,
                icon: PhosphorIconsRegular.usersThree,
                title: 'As vagas desta ação acabaram.',
                text: 'Quer ser avisado quando ${place.name} abrir outra ação?',
                action: store.followed.contains(place.id) ? null : 'Acompanhar este ponto',
                onAction: onFollow,
              )
            else
              SoftButton(
                label: g.type.action,
                icon: g.type.icon,
                filled: true,
                color: g.type.color,
                expand: true,
                height: 50,
                onTap: () => _help(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About({required this.place});

  final Place place;

  Future<void> _directions() async {
    final p = place.point;
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=${p.latitude},${p.longitude}&dirflg=d')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(place.about, style: AppType.body(size: 15.5, color: AppColors.cinza700)),
          const SizedBox(height: 14),
          const Hairline(),
          _Line(icon: PhosphorIconsRegular.mapPin, label: 'Endereço', value: place.address),
          const Hairline(indent: 30),
          _Line(icon: PhosphorIconsRegular.clock, label: 'Horário para receber doações', value: place.hours),
          const SizedBox(height: 8),
          SoftButton(
            label: 'Como chegar',
            icon: PhosphorIconsRegular.navigationArrow,
            expand: true,
            onTap: _directions,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.cinza600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body(size: 13)),
                const SizedBox(height: 2),
                Text(value, style: AppType.label(color: AppColors.cinza900, size: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final r = place.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Avaliações de quem doou'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      place.rating.toStringAsFixed(1).replaceAll('.', ','),
                      style: AppType.display(size: 28).copyWith(fontFeatures: tabular),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stars(place.rating, size: 15),
                        const SizedBox(height: 2),
                        Text(
                          '${place.rating.toStringAsFixed(1).replaceAll('.', ',')} de 5 · ${r.length} ${r.length == 1 ? 'avaliação' : 'avaliações'}',
                          style: AppType.body(size: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(
                r.isEmpty
                    ? 'Este ponto ainda não tem avaliações. Quem doar e tiver a doação confirmada pode avaliar.'
                    : 'Só avalia quem teve uma doação confirmada por esta instituição.',
                style: AppType.body(size: 13.5),
              ),
              for (final rv in r.take(2)) ...[
                const SizedBox(height: 12),
                const Hairline(),
                const SizedBox(height: 12),
                ReviewTile(review: rv),
              ],
              if (r.length > 2) ...[
                const SizedBox(height: 10),
                LinkText('Ver todas as avaliações', onTap: () => context.push(ReviewsScreen(placeId: place.id))),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${review.name} · ${Fmt.day(review.date)}', style: AppType.label(color: AppColors.cinza900, size: 14)),
            const Spacer(),
            Stars(review.stars.toDouble(), size: 13),
          ],
        ),
        if (review.comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(review.comment, style: AppType.body(size: 14.5, color: AppColors.cinza700)),
        ],
      ],
    );
  }
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    final p = store.place(placeId);
    return FlowScaffold(
      title: 'Avaliações de quem doou',
      subtitle: '${p.rating.toStringAsFixed(1).replaceAll('.', ',')} de 5 · ${p.reviews.length} avaliações',
      background: AppColors.cinza50,
      children: [
        for (final r in p.reviews) ...[AppCard(child: ReviewTile(review: r)), const SizedBox(height: 10)],
      ],
    );
  }
}
