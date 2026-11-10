import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../shared/done_view.dart';

/// Os motivos de uma confirmação que não veio.
///
/// São diferentes dos de uma denúncia de propósito: quem está aqui não está
/// acusando ninguém de golpe, está sem resposta. Oferecer "suspeito de
/// golpe" como primeira opção a quem só quer saber do próprio Pix põe uma
/// palavra na boca da pessoa que ela não disse — e cai como denúncia na
/// mesa da equipe, que então trata um esquecimento como fraude.
const delayReasons = [
  'Só quero saber se chegou',
  'Tentei falar e não me responderam',
  'O telefone ou o endereço não funciona',
  'Acho que algo está errado com este ponto',
];

/// "A confirmação não veio": o caminho de quem doou quando o prazo passou.
class DelayReportScreen extends StatefulWidget {
  const DelayReportScreen({super.key, required this.donationId});

  final String donationId;

  @override
  State<DelayReportScreen> createState() => _DelayReportScreenState();
}

class _DelayReportScreenState extends State<DelayReportScreen> {
  String? _motivo;
  String _texto = '';
  bool _enviado = false;

  Donation? get _d => store.donations.where((x) => x.id == widget.donationId).firstOrNull;

  void _enviar(Donation d) {
    store.reportDelay(d, _motivo!, _texto);
    HapticFeedback.mediumImpact();
    setState(() => _enviado = true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final ponto = store.place(d.placeId).name;

    if (_enviado) {
      return DoneView(
        icon: PhosphorIconsRegular.bell,
        title: 'Recebemos seu aviso.',
        text:
            'A equipe do Escora procura a $ponto e cobra a confirmação. '
            'Se não houver resposta, o ponto sai do mapa até se explicar. '
            'Você recebe um aviso assim que algo mudar.',
        primary: 'Voltar à doação',
        onPrimary: () => Navigator.pop(context),
      );
    }

    return FlowScaffold(
      title: 'A $ponto não confirmou no prazo',
      // Dizer o que o aviso faz antes de pedir o motivo: sem isso a tela
      // parece um formulário de reclamação, e quem só quer saber do próprio
      // dinheiro desiste no meio.
      subtitle:
          'Seu Pix saiu direto para a conta da $ponto — o Escora aqui não fica com o dinheiro. '
          'O que falta é alguém de lá marcar no app que recebeu. Avise a equipe e nós cobramos por você.',
      primary: 'Enviar aviso',
      primaryIcon: null,
      onPrimary: _motivo == null ? null : () => _enviar(d),
      secondary: 'Cancelar',
      onSecondary: () => Navigator.pop(context),
      children: [
        for (final r in delayReasons) ...[
          OptionTile(title: r, selected: _motivo == r, onTap: () => setState(() => _motivo = r)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        AppTextField(
          label: 'Quer contar mais alguma coisa?',
          hint: 'Opcional',
          maxLines: 4,
          minLines: 3,
          capitalization: TextCapitalization.sentences,
          onChanged: (v) => _texto = v,
        ),
        const SizedBox(height: 14),
        NoticeBanner(
          tone: Tone.info,
          icon: PhosphorIconsRegular.info,
          text:
              'Vão junto o código da doação, a data e os ${d.waitingDays} dias de espera. '
              'Seu telefone e seu e-mail não são enviados à ${store.place(d.placeId).name}.',
        ),
      ],
    );
  }
}
