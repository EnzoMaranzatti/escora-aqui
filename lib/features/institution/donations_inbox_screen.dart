import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/remote.dart' as remote;
import '../../data/store.dart';
import '../shared/help_ui.dart';

/// Tab inside "Doações" (Para confirmar · Confirmadas · Voluntários).
final inboxTab = ValueNotifier<int>(0);

/// Where the institution checks what arrived. Confirming is what moves
/// the goal and answers the donor (modelo B).
class DonationsInboxScreen extends StatelessWidget {
  const DonationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, inboxTab]),
      builder: (context, _) {
        final p = store.myPoint!;
        final all = store.incoming(p).where((d) => d.type != HelpType.voluntariado).toList();
        final pending =
            all.where((d) => d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        final done = all
            .where((d) => d.status == DonationStatus.confirmed || d.status == DonationStatus.notFound)
            .toList();
        final tab = inboxTab.value;
        return TabPage(
          title: 'Doações para confirmar',
          top: Segmented(
            items: const ['Para confirmar', 'Confirmadas', 'Voluntários'],
            index: tab,
            onChanged: (i) => inboxTab.value = i,
            dense: true,
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: switch (tab) {
                  0 => [
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: EmptyState(
                          icon: PhosphorIconsRegular.tray,
                          title: 'Nenhuma doação para confirmar.',
                          text: 'Quando alguém registrar uma doação para o seu ponto, ela aparece aqui.',
                        ),
                      )
                    else ...[
                      const NoticeBanner(
                        tone: Tone.info,
                        icon: PhosphorIconsRegular.lightbulb,
                        text:
                            'Confira o extrato do banco ou o estoque antes de confirmar. A confirmação é o que mostra ao doador que a ajuda chegou.',
                      ),
                      const SizedBox(height: 12),
                      for (final d in pending) ...[_PendingTile(d: d, place: p), const SizedBox(height: 10)],
                    ],
                  ],
                  1 => [
                    if (done.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          'Nenhuma doação confirmada ainda.',
                          textAlign: TextAlign.center,
                          style: AppType.body(size: 15.5),
                        ),
                      ),
                    for (final d in done) ...[_DoneTile(d: d, place: p), const SizedBox(height: 10)],
                  ],
                  _ => [const _Volunteers()],
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

String _what(Donation d, Goal? g) =>
    d.type == HelpType.pix ? Fmt.money(d.amount) : (g?.amount(d.amount) ?? Fmt.count(d.amount));

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.d, required this.place});

  final Donation d;
  final Place place;

  Future<void> _received(BuildContext context, Goal? g) async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsFill.checkCircle,
      iconTone: Tone.success,
      title: 'Confirmar o recebimento de ${_what(d, g)}?',
      text: 'A meta avança e ${d.donor} recebe um aviso.',
      confirm: 'Confirmar recebimento',
      cancel: 'Voltar',
    );
    if (ok == null || !context.mounted) return;
    store.confirm(d);
    Toast.show(
      context,
      g == null ? 'Recebimento confirmado.' : 'Recebimento confirmado. A meta agora está em ${g.progressLabel}.',
    );
  }

  Future<void> _missing(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsRegular.magnifyingGlass,
      iconTone: Tone.neutral,
      title: 'Marcar como não encontrada?',
      text:
          '${d.donor} recebe um aviso para conferir o comprovante e registrar de novo, se precisar. Antes, confira o extrato a partir de ${Fmt.day(d.date)}.',
      confirm: 'Marcar como não encontrada',
      cancel: 'Voltar',
    );
    if (ok != null) store.markNotFound(d);
  }

  void _receipt(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comprovante', style: AppType.title().copyWith(fontSize: 22)),
          const SizedBox(height: 16),
          // The photo the donor sent (private bucket: a link valid for 1 hour).
          if (d.receiptPath case final path?) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FutureBuilder<String>(
                future: remote.receiptUrl(path),
                builder: (context, snap) => snap.hasData
                    ? Image.network(snap.data!, height: 320, fit: BoxFit.contain)
                    : Container(
                        height: 320,
                        color: AppColors.cinza50,
                        alignment: Alignment.center,
                        child: snap.hasError
                            ? Text('Não deu para abrir o comprovante.', style: AppType.body(size: 14))
                            : const CircularProgressIndicator(color: AppColors.petroleo600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cinza50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cinza200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pix enviado', style: AppType.body(size: 14)),
                const SizedBox(height: 4),
                Text(Fmt.money(d.amount), style: AppType.display(size: 30).copyWith(fontFeatures: tabular)),
                const SizedBox(height: 14),
                const Hairline(),
                const SizedBox(height: 12),
                _ReceiptLine('Data', '${Fmt.date(d.date)}, ${Fmt.hour(d.date.hour * 60 + d.date.minute)}'),
                _ReceiptLine('De', d.donor),
                _ReceiptLine('Para', place.payee ?? place.legalName),
                _ReceiptLine('Chave', place.pixKey ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Entendi', icon: null, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = store.goal(place, d.goalId);
    final pix = d.type == HelpType.pix;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: d.type.iconFill, color: d.type.color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pix
                          ? '${d.donor} registrou ${Fmt.money(d.amount)} via Pix em ${Fmt.day(d.date)}'
                          : '${d.donor} vai levar ${_what(d, g)} até ${Fmt.day(d.when ?? d.date)}',
                      style: AppType.label(
                        color: AppColors.cinza900,
                        size: 15,
                      ).copyWith(fontWeight: FontWeight.w600, height: 1.35, fontFeatures: tabular),
                    ),
                    if (g != null) ...[
                      const SizedBox(height: 3),
                      Text('Meta: ${g.headline}', style: AppType.body(size: 13.5)),
                    ],
                    if (pix && d.receipt) ...[
                      const SizedBox(height: 4),
                      LinkText('Ver comprovante', size: 13.5, onTap: () => _receipt(context)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'Recebi',
                  icon: PhosphorIconsBold.check,
                  filled: true,
                  expand: true,
                  onTap: () => _received(context, g),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftButton(
                  label: pix ? 'Não encontrei' : 'Não chegou',
                  expand: true,
                  onTap: () => _missing(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: AppType.body(size: 14))),
          Expanded(
            child: Text(value, style: AppType.label(color: AppColors.cinza900, size: 14)),
          ),
        ],
      ),
    );
  }
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.d, required this.place});

  final Donation d;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final g = store.goal(place, d.goalId);
    final ok = d.status == DonationStatus.confirmed;
    return AppCard(
      child: Row(
        children: [
          IconTile(icon: d.type.iconFill, color: d.type.color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.donor} · ${_what(d, g)}',
                  style: AppType.label(color: AppColors.cinza900, size: 15).copyWith(fontFeatures: tabular),
                ),
                const SizedBox(height: 6),
                StatusTag(
                  ok ? 'Confirmada em ${Fmt.day(d.confirmedAt ?? d.date)}' : 'Não encontrada',
                  tone: ok ? Tone.success : Tone.neutral,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Volunteers extends StatefulWidget {
  const _Volunteers();

  @override
  State<_Volunteers> createState() => _VolunteersState();
}

class _VolunteersState extends State<_Volunteers> {
  /// Presence being marked, per action: donation id → came.
  final _presence = <String, Map<String, bool>>{};

  Future<void> _cancel(Goal g, int n) async {
    final r = await confirmSheet(
      context,
      title: 'Cancelar a ação "${g.action!.name}"?',
      text: 'Os $n inscritos recebem um aviso de que a ação não vai acontecer.',
      field: const SheetField(label: 'Motivo do cancelamento', hint: 'Opcional. Aparece no aviso para os inscritos.'),
      confirm: 'Cancelar ação',
      cancel: 'Manter ação',
      destructive: true,
    );
    if (r != null) store.cancelAction(g);
  }

  @override
  Widget build(BuildContext context) {
    final p = store.myPoint!;
    final actions =
        p.goals
            .where((g) => g.type == HelpType.voluntariado && g.action != null && g.status != GoalStatus.closed)
            .toList()
          ..sort((a, b) => a.action!.day.compareTo(b.action!.day));
    if (actions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: EmptyState(
          icon: PhosphorIconsRegular.usersThree,
          title: 'Nenhum inscrito ainda.',
          text: 'Quando alguém se inscrever, avisamos você.',
        ),
      );
    }
    return Column(
      children: [
        for (final g in actions) ...[_action(p, g), const SizedBox(height: 12)],
      ],
    );
  }

  Widget _action(Place p, Goal g) {
    final a = g.action!;
    final people = store.incoming(p).where((d) => d.goalId == g.id && d.status != DonationStatus.cancelled).toList();
    final enrolled = people.where((d) => d.status == DonationStatus.enrolled).toList();
    final ended = a.endsAt.isBefore(DateTime.now());
    final marks = _presence.putIfAbsent(g.id, () => {});
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.name, style: AppType.cardTitle(size: 18, color: AppColors.cinza900)),
          const SizedBox(height: 4),
          Text(
            '${Fmt.weekdayDay(a.day)}, ${a.hours} · ${g.enrolled} de ${g.target.round()} vagas',
            style: AppType.body(size: 14).copyWith(fontFeatures: tabular),
          ),
          const SizedBox(height: 12),
          const Hairline(),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Nenhum inscrito ainda. Quando alguém se inscrever, avisamos você.',
                style: AppType.body(size: 14),
              ),
            ),
          if (ended && enrolled.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Quem participou de ${a.name}?',
              style: AppType.label(color: AppColors.cinza900, size: 15).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          for (final d in people)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.ocre50,
                    child: Text(d.donor[0], style: AppType.label(color: AppColors.ocre800, size: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${d.donor} · inscrito em ${Fmt.day(d.date)}',
                      style: AppType.body(size: 14.5, color: AppColors.cinza800),
                    ),
                  ),
                  if (ended && d.status == DonationStatus.enrolled) ...[
                    _Mark(
                      label: 'Participou',
                      on: marks[d.id] == true,
                      onTap: () => setState(() => marks[d.id] = true),
                    ),
                    const SizedBox(width: 6),
                    _Mark(
                      label: 'Não veio',
                      on: marks[d.id] == false,
                      onTap: () => setState(() => marks[d.id] = false),
                    ),
                  ] else if (d.status == DonationStatus.confirmed)
                    const StatusTag('Participou', tone: Tone.success)
                  else if (d.status == DonationStatus.absent)
                    const StatusTag('Não veio', tone: Tone.neutral),
                ],
              ),
            ),
          if (ended && enrolled.isNotEmpty) ...[
            const SizedBox(height: 14),
            SoftButton(
              label: 'Salvar presença',
              filled: true,
              expand: true,
              onTap: marks.length < enrolled.length
                  ? null
                  : () {
                      store.savePresence(g, Map.of(marks));
                      marks.clear();
                      Toast.show(context, 'Alterações salvas.');
                    },
            ),
          ],
          if (!ended) ...[
            const SizedBox(height: 12),
            LinkText('Cancelar ação', color: AppColors.erroTexto, onTap: () => _cancel(g, enrolled.length)),
          ],
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChipPill(label: label, selected: on, onTap: onTap);
  }
}
