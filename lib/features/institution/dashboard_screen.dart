import 'package:flutter/material.dart';
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
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../shared/help_ui.dart';
import 'donations_inbox_screen.dart';
import 'goal_flow.dart';
import 'goals_screen.dart';
import 'institution_shell.dart';
import 'register/register_flow.dart';

/// "Falar com a equipe": opens an e-mail to the team.
Future<void> contactTeam() =>
    launchUrl(Uri.parse('mailto:equipe@escoraaqui.app?subject=Meu%20ponto%20no%20Escora%20aqui'));

/// Start of the institution mode: what needs attention first. Pending
/// donations always come before goals (a donor is waiting).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late bool _showApproved;

  @override
  void initState() {
    super.initState();
    final p = store.myPoint!;
    _showApproved = p.status == PlaceStatus.active && !store.approvalSeen;
    if (p.status == PlaceStatus.active) store.approvalSeen = true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.myPoint!;
        final active = p.status == PlaceStatus.active;
        final inbox = store.incoming(p);
        final pending = store.pendingFor(p);
        final late = inbox
            .where(
              (d) =>
                  (d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed) &&
                  DateTime.now().difference(d.date).inDays >= 3,
            )
            .length;
        final weekEnd = DateTime.now().add(const Duration(days: 7));
        final volunteers = inbox
            .where((d) => d.status == DonationStatus.enrolled && d.when != null && d.when!.isBefore(weekEnd))
            .length;
        final open = p.goals.where((g) => g.status == GoalStatus.open).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final expired = p.goals.where((g) => g.status == GoalStatus.expired).toList();
        final done = p.goals.where((g) => g.status == GoalStatus.done && !g.seenDone).toList();
        final monthly = store.monthlyDonors(p.id);

        return TabPage(
          title: p.name,
          subtitle: p.verifiedAt == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Seal(label: 'Verificado em ${Fmt.day(p.verifiedAt!)}', size: 13),
                ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  ..._status(context, p),
                  if (active && late > 0) ...[
                    NoticeBanner(
                      tone: Tone.alert,
                      text:
                          '$late ${late == 1 ? 'doação está' : 'doações estão'} esperando confirmação há mais de 3 dias. Quem doou fica sem resposta até você conferir.',
                      action: 'Confirmar agora',
                      onAction: () => institutionTab.value = 2,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (active && p.daysSinceReview > 90) ...[
                    _StatusCard(
                      icon: PhosphorIconsRegular.clockCounterClockwise,
                      tone: Tone.alert,
                      title: 'As informações do ponto precisam de uma revisão.',
                      text:
                          'Faz ${p.daysSinceReview} dias que você não confere endereço, horários e chave Pix. Revise para o ponto continuar no mapa.',
                      primary: 'Revisar informações',
                      onPrimary: () => institutionTab.value = 3,
                      secondary: 'Está tudo certo',
                      onSecondary: () {
                        store.renewReview(p);
                        Toast.show(context, 'Alterações salvas.');
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (active) ...[
                    for (final g in done) ...[DoneGoalCard(goal: g), const SizedBox(height: 14)],
                    for (final g in expired) ...[ExpiredGoalCard(goal: g), const SizedBox(height: 14)],
                    const SizedBox(height: 6),
                    const SectionTitle('Pendências'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          InfoRow(
                            icon: PhosphorIconsRegular.tray,
                            title: 'Doações para confirmar: $pending',
                            action: 'Confirmar',
                            onTap: () => institutionTab.value = 2,
                          ),
                          const Hairline(indent: 48),
                          InfoRow(
                            icon: PhosphorIconsRegular.usersThree,
                            title: 'Voluntários inscritos nesta semana: $volunteers',
                            action: 'Ver lista',
                            onTap: () {
                              inboxTab.value = 2;
                              institutionTab.value = 2;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (monthly.isNotEmpty) ...[
                      const SectionTitle('Doações mensais'),
                      AppCard(
                        child: Row(
                          children: [
                            const IconTile(icon: PhosphorIconsFill.arrowsClockwise, color: AppColors.petroleo600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${Fmt.money(monthly.fold(0.0, (t, m) => t + m.amount))} por mês',
                                    style: AppType.cardTitle(
                                      size: 18,
                                      color: AppColors.cinza900,
                                    ).copyWith(fontFeatures: tabular),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${monthly.length} ${monthly.length == 1 ? 'pessoa doa' : 'pessoas doam'} todo mês. Cada Pix chega na lista para confirmar.',
                                    style: AppType.body(size: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                  ],
                  if (p.status != PlaceStatus.refused && p.status != PlaceStatus.removed) ...[
                    SectionTitle(
                      'Metas abertas',
                      trailing: open.isEmpty
                          ? null
                          : LinkText('Criar meta', onTap: () => context.push(const GoalFlow())),
                    ),
                    if (open.isEmpty)
                      AppCard(
                        child: EmptyState(
                          compact: true,
                          icon: PhosphorIconsRegular.target,
                          title: 'Seu ponto ainda não tem metas.',
                          text: 'Uma meta mostra a quem está perto o que vocês precisam agora, e por quê.',
                          primary: 'Criar primeira meta',
                          onPrimary: () => context.push(const GoalFlow()),
                        ),
                      )
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(
                          children: [
                            for (final (i, g) in open.indexed) ...[if (i > 0) const Hairline(), _GoalLine(goal: g)],
                          ],
                        ),
                      ),
                    if (open.any((g) => !g.published)) ...[
                      const SizedBox(height: 10),
                      Text(
                        'A meta fica salva e aparece no mapa quando o ponto for aprovado.',
                        style: AppType.body(size: 13.5),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _status(BuildContext context, Place p) {
    final card = switch (p.status) {
      PlaceStatus.review => _StatusCard(
        icon: PhosphorIconsRegular.hourglassMedium,
        tone: Tone.info,
        title: 'Cadastro em análise',
        text: 'Nossa equipe confere CNPJ, endereço, foto e chave Pix. Leva até 3 dias úteis, e avisamos por aqui.',
        support: 'Enquanto isso, você já pode preparar suas metas. Elas aparecem no mapa quando o ponto for aprovado.',
        primary: 'Preparar primeira meta',
        onPrimary: () => context.push(const GoalFlow()),
      ),
      PlaceStatus.awaitingIndication => _StatusCard(
        icon: PhosphorIconsRegular.handshake,
        tone: Tone.info,
        title: 'Aguardando a indicação de ${p.indicatedBy}',
        text: 'Enviamos o pedido. Quando ${p.indicatedBy} aceitar, seu cadastro segue para a análise da equipe.',
        secondary: 'Escolher outra instituição',
        onSecondary: () => openRegisterAt(context, p, step: 2),
      ),
      PlaceStatus.adjust => _StatusCard(
        icon: PhosphorIconsRegular.pencilSimple,
        tone: Tone.alert,
        title: 'Precisamos de um ajuste no seu cadastro.',
        text: 'Motivo: ${p.statusReason}.${(p.statusMessage ?? '').isEmpty ? '' : ' ${p.statusMessage}'}',
        support: 'Corrija e envie de novo. A nova análise leva até 3 dias úteis.',
        primary: 'Corrigir cadastro',
        onPrimary: () => openRegisterAt(context, p),
      ),
      PlaceStatus.refused => _StatusCard(
        icon: PhosphorIconsRegular.prohibit,
        tone: Tone.neutral,
        title: 'Não foi possível aprovar este cadastro.',
        text: 'Motivo: ${p.statusReason}. Se você acredita que houve um engano, fale com a nossa equipe.',
        primary: 'Falar com a equipe',
        onPrimary: contactTeam,
      ),
      PlaceStatus.paused => _StatusCard(
        icon: PhosphorIconsRegular.pauseCircle,
        tone: Tone.alert,
        title: 'Seu ponto está pausado.',
        text:
            'Recebemos uma denúncia e pausamos o ponto enquanto analisamos. Motivo: ${p.statusReason}. Suas metas ficam paradas até a análise terminar.',
        support: 'Se precisar, nossa equipe entra em contato pelo telefone cadastrado.',
        primary: 'Falar com a equipe',
        onPrimary: contactTeam,
      ),
      PlaceStatus.active when _showApproved => _StatusCard(
        icon: PhosphorIconsFill.sealCheck,
        tone: Tone.success,
        title: '${p.name} está no mapa.',
        text:
            'Seu ponto foi verificado em ${Fmt.day(p.verifiedAt ?? DateTime.now())}. Agora quem está perto já pode ver o que vocês precisam.',
        primary: 'Criar uma meta',
        onPrimary: () {
          setState(() => _showApproved = false);
          context.push(const GoalFlow());
        },
      ),
      _ => null,
    };
    if (card == null) return const [];
    return [Reveal(child: card), const SizedBox(height: 14)];
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.text,
    this.support,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final IconData icon;
  final Tone tone;
  final String title;
  final String text;
  final String? support;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, size: 46, color: tone.fg, bg: tone.bg),
          const SizedBox(height: 14),
          Text(title, style: AppType.title().copyWith(fontSize: 21, height: 1.25)),
          const SizedBox(height: 6),
          Text(text, style: AppType.body(size: 15, color: AppColors.cinza700)),
          if (support != null) ...[const SizedBox(height: 10), Text(support!, style: AppType.body(size: 14))],
          if (primary != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: primary!, icon: null, onPressed: onPrimary),
          ],
          if (secondary != null) ...[
            SizedBox(height: primary == null ? 12 : 4),
            primary == null
                ? SoftButton(label: secondary!, expand: true, height: 50, onTap: onSecondary)
                : GhostButton(label: secondary!, onPressed: onSecondary),
          ],
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final volunteer = g.type == HelpType.voluntariado;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(g.type.iconFill, size: 17, color: g.type.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  volunteer ? '${g.action!.name} · ${Fmt.day(g.deadline)}' : g.headline,
                  style: AppType.label(
                    color: AppColors.cinza900,
                    size: 15,
                  ).copyWith(fontWeight: FontWeight.w600, fontFeatures: tabular),
                ),
              ),
              Text(
                volunteer ? '${g.enrolled} de ${g.target.round()}' : g.progressLabel,
                style: AppType.body(size: 13.5).copyWith(fontFeatures: tabular),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GoalBar(value: volunteer ? (g.enrolled / g.target).clamp(0, 1) : g.progress, height: 6, color: g.type.color),
        ],
      ),
    );
  }
}
