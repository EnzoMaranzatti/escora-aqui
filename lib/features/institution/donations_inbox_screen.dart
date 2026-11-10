import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../shared/help_ui.dart';
import 'donation_screen.dart';
import 'donations_stats.dart';

/// Aba de dentro de "Doações" (Fila · Recebidas · Voluntários · Resumo).
final inboxTab = ValueNotifier<int>(0);

/// Onde a instituição confere o que chegou. Confirmar é o que move a meta e
/// responde ao doador (modelo B). A lista é agrupada por mês e cada linha
/// abre a doação inteira, com o contato de quem doou.
class DonationsInboxScreen extends StatefulWidget {
  const DonationsInboxScreen({super.key});

  @override
  State<DonationsInboxScreen> createState() => _DonationsInboxScreenState();
}

class _DonationsInboxScreenState extends State<DonationsInboxScreen> {
  String _busca = '';

  /// Procura por nome de quem doou, pela meta e pelo valor digitado.
  bool _combina(Donation d, Goal? g) {
    final q = Fmt.fold(_busca.trim());
    if (q.isEmpty) return true;
    final valor = d.type == HelpType.pix ? Fmt.money(d.amount) : Fmt.count(d.amount);
    final campos = [d.donor, g?.headline ?? '', d.type.label, valor];
    return campos.any((c) => Fmt.fold(c).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, inboxTab]),
      builder: (context, _) {
        final p = store.myPoint!;
        final todas = store.incoming(p).where((d) => d.type != HelpType.voluntariado).toList();
        final fila =
            todas.where((d) => d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        final recebidas = todas
            .where((d) => d.status == DonationStatus.confirmed || d.status == DonationStatus.notFound)
            .toList();
        final tab = inboxTab.value;
        final busca = tab == 0 || tab == 1;

        return TabPage(
          title: 'Doações',
          onRefresh: store.refresh,
          subtitle: Text(
            fila.isEmpty
                ? '${recebidas.where((d) => d.status == DonationStatus.confirmed).length} confirmadas até agora'
                : '${fila.length} ${fila.length == 1 ? 'esperando você' : 'esperando você'} · '
                      '${recebidas.where((d) => d.status == DonationStatus.confirmed).length} confirmadas',
            style: AppType.body(),
          ),
          top: Column(
            children: [
              Segmented(
                items: const ['Fila', 'Recebidas', 'Voluntários', 'Resumo'],
                index: tab,
                onChanged: (i) => inboxTab.value = i,
                dense: true,
              ),
              if (busca) ...[
                const SizedBox(height: 10),
                AppSearchField(
                  hint: 'Buscar por nome, meta ou valor',
                  semantic: 'Buscar uma doação',
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ],
            ],
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverList.list(
                children: switch (tab) {
                  0 => _fila(p, fila),
                  1 => _recebidas(p, recebidas),
                  2 => [const _Volunteers()],
                  _ => [DonationsSummary(place: p)],
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _fila(Place p, List<Donation> fila) {
    if (fila.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 32),
          child: EmptyState(
            icon: PhosphorIconsRegular.tray,
            title: 'Nenhuma doação para confirmar.',
            text: 'Quando alguém registrar uma doação para o seu ponto, ela aparece aqui.',
          ),
        ),
      ];
    }
    final lista = fila.where((d) => _combina(d, store.goal(p, d.goalId))).toList();
    if (lista.isEmpty) return [_semResultado()];
    final atrasadas = lista.where((d) => d.overdue).length;
    return [
      if (atrasadas > 0)
        NoticeBanner(
          tone: Tone.alert,
          icon: PhosphorIconsRegular.hourglassMedium,
          text:
              '$atrasadas ${atrasadas == 1 ? 'doação passou' : 'doações passaram'} dos '
              '${confirmWindow.inDays} dias de prazo. Quem doou está sem resposta e pode pedir à equipe '
              'do Escora que cobre o ponto.',
        )
      else
        const NoticeBanner(
          tone: Tone.info,
          icon: PhosphorIconsRegular.lightbulb,
          text:
              'Confira o extrato do banco ou o estoque antes de confirmar. A confirmação é o que mostra ao doador '
              'que a ajuda chegou.',
        ),
      const SizedBox(height: 14),
      // A fila é curta e é onde se age: cada doação ganha um cartão com o
      // botão de confirmar no rodapé, em vez de um botão solto na linha.
      for (final (i, d) in lista.indexed) ...[
        if (i > 0) const SizedBox(height: 12),
        _QueueCard(d: d, goal: store.goal(p, d.goalId)),
      ],
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _recebidas(Place p, List<Donation> recebidas) {
    if (recebidas.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 32),
          child: EmptyState(
            icon: PhosphorIconsRegular.clockCounterClockwise,
            title: 'Nenhuma doação confirmada ainda.',
            text: 'O que você confirmar fica guardado aqui, com a data e quem doou.',
          ),
        ),
      ];
    }
    final lista = recebidas.where((d) => _combina(d, store.goal(p, d.goalId))).toList();
    if (lista.isEmpty) return [_semResultado()];
    return _agrupado(p, lista);
  }

  Widget _semResultado() => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: EmptyState(
      icon: PhosphorIconsRegular.magnifyingGlass,
      title: 'Nada encontrado.',
      text: 'Nenhuma doação combina com "${_busca.trim()}". Tente o primeiro nome de quem doou.',
    ),
  );

  /// Um cartão por mês, com as linhas separadas por fio — como nas listas
  /// do iOS. O cabeçalho do mês fica fora do cartão.
  List<Widget> _agrupado(Place p, List<Donation> lista) {
    final meses = <String, List<Donation>>{};
    for (final d in lista) {
      meses.putIfAbsent('${d.date.year}-${d.date.month}', () => []).add(d);
    }
    final agora = DateTime.now();
    final saida = <Widget>[];
    for (final e in meses.entries) {
      final primeira = e.value.first.date;
      final mesmoAno = primeira.year == agora.year;
      final titulo = '${Fmt.month(primeira)}${mesmoAno ? '' : ' de ${primeira.year}'}';
      saida.addAll([
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titulo[0].toUpperCase() + titulo.substring(1),
                  style: AppType.label(color: AppColors.cinza700, size: 13.5).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${e.value.length}', style: AppType.body(size: 13).copyWith(fontFeatures: tabular)),
            ],
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, d) in e.value.indexed) ...[
                if (i > 0) const Padding(padding: EdgeInsets.only(left: 62), child: Hairline()),
                _DonationRow(d: d, goal: store.goal(p, d.goalId)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
      ]);
    }
    return saida;
  }
}

/// Uma doação da fila: a mesma linha das Recebidas, com o botão de
/// confirmar num rodapé próprio. O botão ocupa a largura do cartão, então
/// não disputa espaço com o valor nem fica boiando ao lado do texto.
class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.d, required this.goal});

  final Donation d;
  final Goal? goal;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DonationRow(d: d, goal: goal),
          const Hairline(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SoftButton(
              label: 'Confirmar recebimento',
              icon: PhosphorIconsBold.check,
              filled: true,
              expand: true,
              height: 42,
              onTap: () => confirmarRecebimento(context, d, goal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pergunta e confirma. Fica fora das duas classes porque a fila e a tela
/// da doação chamam a mesma coisa.
Future<void> confirmarRecebimento(BuildContext context, Donation d, Goal? goal) async {
  final valor = d.type == HelpType.pix ? Fmt.money(d.amount) : (goal?.amount(d.amount) ?? Fmt.count(d.amount));
  final ok = await confirmSheet(
    context,
    icon: PhosphorIconsFill.checkCircle,
    iconTone: Tone.success,
    title: 'Confirmar o recebimento de $valor?',
    text: 'A meta avança e ${d.donor} recebe um aviso.',
    confirm: 'Confirmar recebimento',
    cancel: 'Voltar',
  );
  if (ok == null || !context.mounted) return;
  store.confirm(d);
  Toast.show(
    context,
    goal == null ? 'Recebimento confirmado.' : 'Recebimento confirmado. A meta agora está em ${goal.progressLabel}.',
  );
}

/// Uma linha da lista: inicial, quem doou, o que é, quanto, e para onde ir.
class _DonationRow extends StatelessWidget {
  const _DonationRow({required this.d, required this.goal});

  final Donation d;
  final Goal? goal;

  /// Versão curta para a coluna da direita: "R$ 150,00", "5 kits", "2 vagas".
  /// O nome do item fica no subtítulo, que tem a linha inteira.
  String get _curto {
    if (d.type == HelpType.pix) return Fmt.money(d.amount);
    final n = Fmt.count(d.amount);
    final unidade = goal?.unit;
    if (d.type == HelpType.voluntariado) return d.amount == 1 ? '1 vaga' : '$n vagas';
    if (unidade != null && unidade != 'unidades') return '$n $unidade';
    // Sem unidade ("15 cestas básicas"), fica o número e a primeira palavra
    // do item: um número solto na coluna não diz o que chegou.
    final item = goal?.item.split(' ').first;
    return item == null || item.isEmpty ? n : '$n $item';
  }

  @override
  Widget build(BuildContext context) {
    final segunda = switch (d.status) {
      DonationStatus.confirmed => 'Confirmada em ${Fmt.day(d.confirmedAt ?? d.date)}',
      DonationStatus.notFound => 'Não encontrada',
      // Antes do prazo a linha fala da meta; depois dele, do doador. Quem
      // está esperando passa a ser a informação mais importante da linha.
      _ when d.overdue => '${d.donor} espera há ${d.waitingDays} dias · prazo era ${Fmt.day(d.deadline)}',
      _ when d.when != null && d.type == HelpType.itens => '${goal?.item ?? 'Itens'} · entrega em ${Fmt.day(d.when!)}',
      _ => goal?.headline ?? 'Doação sem meta',
    };
    return Pressable(
      onTap: () => context.push(DonationScreen(d.id)),
      scale: .99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            _Avatar(name: d.donor, type: d.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          d.donor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.label(
                            color: AppColors.cinza900,
                            size: 15.5,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (d.receipt || d.receiptPath != null) ...[
                        const SizedBox(width: 6),
                        const Icon(PhosphorIconsBold.paperclip, size: 14, color: AppColors.cinza500),
                      ],
                      if (d.overdue) ...[const SizedBox(width: 6), const _Atrasada()],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    segunda,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body(size: 13, color: d.overdue ? AppColors.ocre700 : AppColors.cinza600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _curto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label(
                    color: d.status == DonationStatus.notFound ? AppColors.cinza500 : AppColors.cinza900,
                    size: 15.5,
                  ).copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
                ),
                const SizedBox(height: 2),
                Text(Fmt.day(d.date), style: AppType.body(size: 12.5).copyWith(fontFeatures: tabular)),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(PhosphorIconsBold.caretRight, size: 16, color: AppColors.cinza400),
          ],
        ),
      ),
    );
  }
}

/// Inicial de quem doou, com um selo do tipo de ajuda no canto. Cor e
/// ícone juntos, como o style guide pede.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.type});

  final String name;
  final HelpType type;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: AppColors.cinza100, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: AppType.cardTitle(size: 16, color: AppColors.cinza700),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: type.color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Icon(type.iconFill, size: 9, color: AppColors.white),
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
  /// Presença sendo marcada, por ação: id da doação → veio.
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
                    child: Pressable(
                      onTap: () => context.push(DonationScreen(d.id)),
                      scale: .99,
                      child: Text(
                        '${d.donor} · inscrito em ${Fmt.day(d.date)}',
                        style: AppType.body(size: 14.5, color: AppColors.cinza800),
                      ),
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

/// O selo de prazo vencido, na linha da fila.
class _Atrasada extends StatelessWidget {
  const _Atrasada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 2, 8, 3),
      decoration: BoxDecoration(color: AppColors.ocre50, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsBold.hourglassMedium, size: 11, color: AppColors.ocre700),
          const SizedBox(width: 4),
          Text('Passou do prazo', style: AppType.label(size: 11.5, color: AppColors.ocre700)),
        ],
      ),
    );
  }
}
