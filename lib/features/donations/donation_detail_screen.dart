import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/receipt.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/timeline.dart';
import '../../data/store.dart';
import '../place/place_screen.dart';
import 'delay_report_screen.dart';
import 'donations_screen.dart';

/// O andamento de uma doação, numa tela só.
///
/// Antes a lista levava direto para o ponto, e quem doou não tinha onde ver
/// em que pé a própria doação estava: o cartão da lista dizia o estado numa
/// etiqueta, sem contar o caminho até ali. Aqui o comprovante responde "o que
/// eu doei" e a linha do tempo responde "e agora?".
class DonationDetailScreen extends StatelessWidget {
  const DonationDetailScreen(this.id, {super.key});

  final String id;

  Donation? get _donation => store.donations.where((d) => d.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = _donation;
        if (d == null) {
          return const FlowScaffold(
            title: 'Doação',
            background: AppColors.cinza50,
            children: [
              EmptyState(
                icon: PhosphorIconsRegular.tray,
                title: 'Esta doação não está mais aqui.',
                text: 'Ela pode ter sido cancelada.',
              ),
            ],
          );
        }
        final p = store.place(d.placeId);
        final g = store.goal(p, d.goalId);
        final avaliar = d.status == DonationStatus.confirmed && !d.rated;
        return FlowScaffold(
          background: AppColors.cinza50,
          // O rodapé do FlowScaffold só aparece quando há botão primário, e
          // sem ele "Ver o ponto" sumia em toda doação ainda não avaliável.
          primary: avaliar ? 'Avaliar ${p.name}' : 'Ver o ponto',
          onPrimary: avaliar ? () => showRateSheet(context, d) : () => context.push(PlaceScreen(placeId: p.id)),
          secondary: avaliar ? 'Ver o ponto' : null,
          onSecondary: avaliar ? () => context.push(PlaceScreen(placeId: p.id)) : null,
          children: [
            ReceiptCard(
              title: p.name,
              // O motivo da meta diz para o que a doação foi; o "R$ 1.500 até
              // 09/11" do headline brigava com o valor doado logo abaixo.
              subtitle: g?.reason,
              photo: p.image,
              badge: _estado(d),
              badgeDone: d.status == DonationStatus.confirmed,
              highlightLabel: switch (d.type) {
                HelpType.pix => 'Valor doado',
                HelpType.itens => 'Você separou',
                HelpType.voluntariado => 'Você se inscreveu para',
              },
              highlight: _quanto(d, g),
              fields: [
                ReceiptField('Registrada em', Fmt.date(d.date)),
                ReceiptField('Forma de ajuda', d.type.label),
                if (d.when != null)
                  ReceiptField(
                    d.type == HelpType.voluntariado ? 'Dia da ação' : 'Entrega combinada',
                    Fmt.date(d.when!),
                  ),
                if (d.confirmedAt != null) ReceiptField('Confirmada em', Fmt.date(d.confirmedAt!)),
              ],
              footer: _Codigo(id: d.id),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acompanhe', style: AppType.cardTitle(size: 17, color: AppColors.cinza900)),
                  const SizedBox(height: 16),
                  DonationTimeline(steps: _steps(d, p.name)),
                ],
              ),
            ),
            if (d.overdue) ...[const SizedBox(height: 14), _Atraso(d: d, place: p)],
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  /// O estado em duas palavras, para o selo do cabeçalho. É a mesma informação
  /// da linha do tempo, mas lida de relance, sem percorrer as etapas.
  String _estado(Donation d) => switch (d.status) {
    DonationStatus.confirmed => 'Confirmada',
    DonationStatus.notFound => 'Não encontrada',
    DonationStatus.cancelled => 'Cancelada',
    DonationStatus.absent => 'Faltou',
    DonationStatus.enrolled => 'Vaga garantida',
    DonationStatus.itemsAgreed => 'Entrega combinada',
    DonationStatus.waiting => 'Aguardando confirmação',
  };

  /// A legenda da barra do prazo. Antes do vencimento ela conta para baixo;
  /// depois, ela diz há quanto tempo a espera deixou de ser normal.
  String _prazo(Donation d) {
    if (d.overdue) {
      final n = -d.daysLeft;
      return 'Passou do prazo em ${Fmt.day(d.deadline)} · '
          '${n <= 0
              ? 'hoje'
              : n == 1
              ? 'há 1 dia'
              : 'há $n dias'}';
    }
    final faltam = d.daysLeft;
    if (faltam <= 0) return 'O prazo vence hoje, ${Fmt.day(d.deadline)}';
    return 'Até ${Fmt.day(d.deadline)} · ${faltam == 1 ? 'falta 1 dia' : 'faltam $faltam dias'}';
  }

  String _quanto(Donation d, Goal? g) => switch (d.type) {
    HelpType.pix => Fmt.money(d.amount),
    HelpType.itens => g?.amount(d.amount) ?? Fmt.count(d.amount),
    HelpType.voluntariado =>
      g?.action == null ? 'uma ação' : '${Fmt.hour(g!.action!.start)} às ${Fmt.hour(g.action!.end)}',
  };

  /// As etapas mudam com a forma de ajuda: o Pix é conferido no extrato, os
  /// itens são combinados e entregues, e o voluntariado tem dia marcado.
  List<TimelineStep> _steps(Donation d, String ponto) {
    final atrasada = d.overdue;
    final registro = TimelineStep(
      title: switch (d.type) {
        HelpType.pix => 'Você registrou o Pix',
        HelpType.itens => 'Você registrou a doação',
        HelpType.voluntariado => 'Você se inscreveu',
      },
      detail: Fmt.date(d.date),
      state: TrackState.done,
    );

    if (d.status == DonationStatus.notFound) {
      return [
        registro,
        TimelineStep(
          title: 'A $ponto não encontrou esta doação',
          detail: 'Confira o comprovante e registre de novo, se precisar.',
          state: TrackState.current,
        ),
      ];
    }

    final confirmada = d.status == DonationStatus.confirmed;

    if (d.type == HelpType.voluntariado) {
      final inscrito = d.status == DonationStatus.enrolled || confirmada;
      return [
        registro,
        TimelineStep(
          title: 'A $ponto confirmou sua vaga',
          detail: inscrito ? 'Vaga garantida.' : 'A $ponto tem 3 dias para responder.',
          state: inscrito ? TrackState.done : TrackState.current,
          alert: atrasada,
          progress: inscrito ? null : d.waitProgress,
          note: inscrito ? null : _prazo(d),
        ),
        TimelineStep(
          title: 'Dia da ação',
          detail: d.when == null ? null : Fmt.date(d.when!),
          state: confirmada ? TrackState.done : (inscrito ? TrackState.current : TrackState.future),
        ),
      ];
    }

    if (d.type == HelpType.itens) {
      final combinada = d.status == DonationStatus.itemsAgreed || confirmada;
      return [
        registro,
        TimelineStep(
          title: 'Entrega combinada',
          detail: d.when != null
              ? 'Levar até ${Fmt.date(d.when!)}.'
              : atrasada
              ? 'Ninguém de lá respondeu ainda.'
              : 'A $ponto entra em contato em até 3 dias.',
          state: combinada ? TrackState.done : TrackState.current,
          alert: atrasada && d.when == null,
          progress: combinada || d.when != null ? null : d.waitProgress,
          note: combinada || d.when != null ? null : _prazo(d),
        ),
        TimelineStep(
          title: 'A $ponto confirmou o recebimento',
          detail: confirmada && d.confirmedAt != null ? Fmt.date(d.confirmedAt!) : 'Depois da entrega.',
          state: confirmada ? TrackState.done : TrackState.future,
        ),
      ];
    }

    return [
      registro,
      TimelineStep(
        title: 'A $ponto confere o extrato',
        detail: confirmada
            ? 'Conferido.'
            : atrasada
            ? 'O prazo combinado é de 3 dias e já passou.'
            : 'A $ponto tem 3 dias para conferir.',
        state: confirmada ? TrackState.done : TrackState.current,
        alert: atrasada,
        progress: confirmada ? null : d.waitProgress,
        note: confirmada ? null : _prazo(d),
      ),
      TimelineStep(
        title: 'Doação confirmada',
        detail: confirmada && d.confirmedAt != null ? Fmt.date(d.confirmedAt!) : 'Avisamos você quando acontecer.',
        state: confirmada ? TrackState.done : TrackState.future,
      ),
    ];
  }
}

/// O código fica no canhoto do recibo, como numa passagem: é o que a pessoa
/// lê para a instituição no telefone quando algo não bate.
class _Codigo extends StatelessWidget {
  const _Codigo({required this.id});

  final String id;

  String get _curto => id.replaceAll('-', '').substring(0, 8).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Código da doação', style: AppType.body(size: 12.5, color: AppColors.cinza600)),
            const SizedBox(height: 1),
            Text(
              _curto,
              style: AppType.cardTitle(
                size: 16,
                color: AppColors.cinza900,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()], letterSpacing: 1.2),
            ),
          ],
        ),
        Pressable(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _curto));
            HapticFeedback.selectionClick();
            Toast.show(context, 'Código copiado.', icon: PhosphorIconsFill.checkCircle);
          },
          scale: .94,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(PhosphorIconsBold.copy, size: 20, color: AppColors.petroleo600),
          ),
        ),
      ],
    );
  }
}

/// O que fazer quando a instituição não conferiu no prazo.
///
/// O Pix é direto: o dinheiro já está na conta de lá, e o que falta é só
/// alguém marcar no app. Dizer isso tira o medo de golpe; os dois botões
/// tiram a sensação de que não há o que fazer.
class _Atraso extends StatelessWidget {
  const _Atraso({required this.d, required this.place});

  final Donation d;
  final Place place;

  int get dias => d.waitingDays;

  /// Quando a pessoa já avisou a equipe, nesta sessão.
  DateTime? get _avisado => store.nudged[d.id];

  String get _codigo => d.id.replaceAll('-', '').substring(0, 8).toUpperCase();

  String get _texto => switch (d.type) {
    HelpType.pix =>
      'O valor saiu da sua conta direto para a ${place.name} — o Escora aqui '
          'não fica com o dinheiro em momento nenhum. O que falta é alguém de '
          'lá conferir o extrato e marcar a doação como recebida.',
    HelpType.itens =>
      'A ${place.name} ainda não combinou a entrega com você. Vale chamar '
          'antes de separar as coisas, para não levar em dia fechado.',
    HelpType.voluntariado =>
      'A ${place.name} ainda não confirmou sua vaga. Vale chamar antes de se '
          'programar para o dia.',
  };

  /// WhatsApp quer o número com o país na frente.
  String? get _zap {
    final digits = place.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    return digits.length <= 11 ? '55$digits' : digits;
  }

  Future<void> _open(BuildContext context, Uri uri, String erro) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) Toast.show(context, erro, icon: PhosphorIconsFill.warningCircle);
    } catch (_) {
      if (context.mounted) Toast.show(context, erro, icon: PhosphorIconsFill.warningCircle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zap = _zap;
    final avisado = _avisado;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                PhosphorIconsRegular.hourglassMedium,
                size: 38,
                color: AppColors.ocre700,
                bg: AppColors.ocre50,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A confirmação passou do prazo',
                      style: AppType.cardTitle(size: 16, color: AppColors.cinza900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dias dias de espera · o prazo é de ${confirmWindow.inDays}.',
                      style: AppType.body(size: 13, color: AppColors.ocre700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_texto, style: AppType.body(size: 14).copyWith(height: 1.45)),
          const SizedBox(height: 14),
          if (avisado != null)
            // Depois de avisar, o botão sai e fica o recibo do aviso. Um
            // botão que continua ali depois de apertado faz a pessoa apertar
            // de novo, e cada toque vira um chamado novo na mesa da equipe.
            _Avisado(em: avisado)
          else
            SoftButton(
              label: 'Avisar o Escora sobre a demora',
              icon: PhosphorIconsRegular.bell,
              filled: true,
              expand: true,
              onTap: () => context.push(DelayReportScreen(donationId: d.id)),
            ),
          if (zap != null) ...[
            const SizedBox(height: 8),
            SoftButton(
              label: 'Falar direto com a ${place.name}',
              icon: PhosphorIconsRegular.whatsappLogo,
              expand: true,
              onTap: () => _open(
                context,
                Uri.parse(
                  'https://wa.me/$zap?text=${Uri.encodeComponent('Oi! Fiz uma doação pelo Escora aqui '
                  '(código $_codigo) e ela ainda está aguardando confirmação.')}',
                ),
                'Não deu para abrir o WhatsApp.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// O recibo do aviso, no lugar do botão.
class _Avisado extends StatelessWidget {
  const _Avisado({required this.em});

  final DateTime em;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: AppColors.petroleo50, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsFill.checkCircle, size: 19, color: AppColors.petroleo600),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Você avisou a equipe em ${Fmt.day(em)}. Ela procura a instituição e '
              'manda um aviso para você quando houver resposta.',
              style: AppType.body(size: 13.5, color: AppColors.petroleo700).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
