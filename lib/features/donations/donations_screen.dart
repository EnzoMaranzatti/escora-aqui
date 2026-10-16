import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../donate/monthly_screen.dart';
import '../map/pins.dart';
import '../donate/pix_screen.dart';
import '../place/place_screen.dart';
import '../shared/help_ui.dart';
import '../shell/donor_shell.dart';

/// Tab "Doações": what the person did and the status of each donation.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.myDonations
            .where((d) => d.status != DonationStatus.cancelled && d.status != DonationStatus.absent)
            .toList();
        final list = switch (_tab) {
          1 => all.where((d) => d.pending).toList(),
          2 => all.where((d) => d.status == DonationStatus.confirmed).toList(),
          _ => all,
        };
        final monthly = store.myMonthly;
        final helped = store.helpedPlaces;
        final confirmed = store.confirmedCount;
        return TabPage(
          title: 'Minhas doações',
          subtitle: all.isEmpty
              ? null
              : Text(
                  'Você já ajudou $helped ${helped == 1 ? 'ponto' : 'pontos'}. $confirmed ${confirmed == 1 ? 'doação confirmada' : 'doações confirmadas'}.',
                  style: AppType.body(size: 15.5).copyWith(fontFeatures: tabular),
                ),
          top: all.isEmpty
              ? null
              : Segmented(
                  items: const ['Todas', 'Aguardando', 'Confirmadas'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
          slivers: [
            if (monthly.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverList.list(
                  children: [
                    const SectionTitle('Doações mensais'),
                    for (final (i, m) in monthly.indexed) ...[
                      if (i > 0) const SizedBox(height: 10),
                      MonthlyTile(key: ValueKey(m.id), m: m),
                    ],
                    if (all.isNotEmpty) ...[const SizedBox(height: 26), const SectionTitle('Histórico')],
                  ],
                ),
              ),
            if (all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                  child: Center(
                    child: EmptyState(
                      icon: PhosphorIconsRegular.receipt,
                      title: 'Você ainda não fez nenhuma doação.',
                      text: 'Quando você ajudar um ponto, o histórico e a confirmação aparecem aqui.',
                      primary: 'Ver pontos perto de você',
                      onPrimary: () => goToTab(context, 0),
                    ),
                  ),
                ),
              )
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Text(
                    'Nenhuma doação ${_tab == 1 ? 'aguardando' : 'confirmada'} por enquanto.',
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
                  itemBuilder: (context, i) => Reveal(
                    key: ValueKey(list[i].id),
                    delay: Duration(milliseconds: 40 * i.clamp(0, 6)),
                    offset: 10,
                    child: _DonationTile(d: list[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DonationTile extends StatelessWidget {
  const _DonationTile({required this.d});

  final Donation d;

  @override
  Widget build(BuildContext context) {
    final p = store.place(d.placeId);
    final g = store.goal(p, d.goalId);
    final what = switch (d.type) {
      HelpType.pix => Fmt.money(d.amount),
      HelpType.itens => g?.amount(d.amount) ?? Fmt.count(d.amount),
      HelpType.voluntariado => g?.action == null ? '' : '${Fmt.hour(g!.action!.start)} às ${Fmt.hour(g.action!.end)}',
    };
    final (label, tone, support, action) = switch (d.status) {
      DonationStatus.waiting => (
        'Aguardando confirmação',
        Tone.alert,
        'A ${p.name} ainda vai conferir o recebimento.',
        null,
      ),
      DonationStatus.confirmed => (
        'Confirmada pela instituição',
        Tone.success,
        'Confirmada em ${Fmt.day(d.confirmedAt ?? d.date)}.',
        d.rated ? null : 'Avaliar ${p.name}',
      ),
      DonationStatus.notFound => (
        'Não encontrada pela instituição',
        Tone.neutral,
        'A ${p.name} não localizou esta doação. Confira o comprovante e registre de novo, se precisar.',
        'Registrar de novo',
      ),
      DonationStatus.enrolled => (
        'Inscrito',
        Tone.info,
        g?.action == null ? '' : '${Fmt.weekdayDay(g!.action!.day)}, ${g.action!.hours}.',
        'Cancelar inscrição',
      ),
      DonationStatus.itemsAgreed => ('Entrega combinada', Tone.info, 'Levar até ${Fmt.day(d.when ?? d.date)}.', null),
      _ => ('', Tone.neutral, '', null),
    };
    return AppCard(
      onTap: () => context.push(PlaceScreen(placeId: p.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlaceThumb(place: p, size: 42, badge: (d.type.iconFill, d.type.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: AppType.label(color: AppColors.cinza900, size: 15.5).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        d.type.label,
                        if (what.isNotEmpty) what,
                        Fmt.day(d.type == HelpType.voluntariado ? (d.when ?? d.date) : d.date),
                      ].join(' · '),
                      style: AppType.body(size: 14).copyWith(fontFeatures: tabular),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatusTag(label, tone: tone),
          if (support.isNotEmpty) ...[const SizedBox(height: 6), Text(support, style: AppType.body(size: 14))],
          if (action != null) ...[const SizedBox(height: 10), LinkText(action, onTap: () => _act(context, p, g))],
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, Place p, Goal? g) async {
    switch (d.status) {
      case DonationStatus.confirmed:
        await showRateSheet(context, d);
      case DonationStatus.notFound:
        context.push(DeclareScreen(placeId: p.id, goalId: d.goalId));
      case DonationStatus.enrolled:
        final name = g?.action?.name ?? 'esta ação';
        final ok = await confirmSheet(
          context,
          title: 'Cancelar sua inscrição em $name?',
          text: 'Sua vaga fica livre para outra pessoa, e a ${p.name} é avisada.',
          confirm: 'Cancelar inscrição',
          cancel: 'Manter inscrição',
          destructive: true,
        );
        if (ok != null) store.cancelEnrollment(d);
      default:
    }
  }
}

/// "Avaliar instituição": only after a confirmed donation.
Future<void> showRateSheet(BuildContext context, Donation d) {
  return showAppSheet<void>(context, builder: (_) => _RateSheet(d: d));
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.d});

  final Donation d;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _stars = 0;
  String _comment = '';

  @override
  Widget build(BuildContext context) {
    final p = store.place(widget.d.placeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Como foi ajudar a ${p.name}?', style: AppType.title().copyWith(fontSize: 22, height: 1.25)),
        const SizedBox(height: 20),
        StarPicker(
          value: _stars,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _stars = v);
          },
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Comentário',
          hint: 'Conte como foi a entrega, o atendimento ou a organização (opcional)',
          maxLines: 4,
          minLines: 3,
          capitalization: TextCapitalization.sentences,
          onChanged: (v) => _comment = v,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(PhosphorIconsRegular.info, size: 16, color: AppColors.cinza600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Sua avaliação aparece no perfil do ponto com seu primeiro nome.',
                style: AppType.body(size: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Publicar avaliação',
          icon: null,
          onPressed: _stars == 0
              ? null
              : () {
                  store.rate(widget.d, _stars, _comment);
                  Toast.show(context, 'Avaliação publicada no perfil da ${p.name}.');
                  Navigator.pop(context);
                },
        ),
        GhostButton(label: 'Agora não', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
