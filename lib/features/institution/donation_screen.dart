import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/remote.dart' as remote;
import '../../data/store.dart';
import '../shared/help_ui.dart';

/// A doação inteira numa tela só: o valor, de quem veio, como falar com a
/// pessoa e o que ela já fez pelo ponto. Saiu da lista porque a instituição
/// precisa decidir (confirmar ou não) com tudo à vista — e, muitas vezes,
/// ligar antes de decidir.
class DonationScreen extends StatefulWidget {
  const DonationScreen(this.id, {super.key});

  /// Id da doação. A tela relê do store a cada rebuild para acompanhar a
  /// confirmação sem precisar voltar.
  final String id;

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  DonorContact? _contact;
  bool _loadingContact = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    final c = await store.donorContact(widget.id);
    if (!mounted) return;
    setState(() {
      _contact = c;
      _loadingContact = false;
    });
  }

  Donation? get _donation => store.donations.where((d) => d.id == widget.id).firstOrNull;

  String _what(Donation d, Goal? g) =>
      d.type == HelpType.pix ? Fmt.money(d.amount) : (g?.amount(d.amount) ?? Fmt.count(d.amount));

  Future<void> _confirm(Donation d, Goal? g) async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsFill.checkCircle,
      iconTone: Tone.success,
      title: 'Confirmar o recebimento de ${_what(d, g)}?',
      text: 'A meta avança e ${d.donor} recebe um aviso.',
      confirm: 'Confirmar recebimento',
      cancel: 'Voltar',
    );
    if (ok == null || !mounted) return;
    store.confirm(d);
    setState(() {});
    Toast.show(
      context,
      g == null ? 'Recebimento confirmado.' : 'Recebimento confirmado. A meta agora está em ${g.progressLabel}.',
    );
  }

  Future<void> _missing(Donation d) async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsRegular.magnifyingGlass,
      iconTone: Tone.neutral,
      title: 'Marcar como não encontrada?',
      text:
          '${d.donor} recebe um aviso para conferir o comprovante e registrar de novo, se precisar. '
          'Antes, confira o extrato a partir de ${Fmt.day(d.date)}.',
      confirm: 'Marcar como não encontrada',
      cancel: 'Voltar',
    );
    if (ok == null || !mounted) return;
    store.markNotFound(d);
    setState(() {});
  }

  void _copy(String what, String value) {
    Clipboard.setData(ClipboardData(text: value));
    Toast.show(context, '$what copiado.');
  }

  Future<void> _open(Uri uri, String erro) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) Toast.show(context, erro, icon: PhosphorIconsFill.warningCircle);
    } catch (_) {
      if (mounted) Toast.show(context, erro, icon: PhosphorIconsFill.warningCircle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final d = _donation;
        final place = store.myPoint;
        if (d == null || place == null) {
          return const FlowScaffold(
            title: 'Doação',
            children: [
              EmptyState(
                icon: PhosphorIconsRegular.tray,
                title: 'Esta doação não está mais aqui.',
                text: 'Ela pode ter sido cancelada por quem registrou.',
              ),
            ],
          );
        }
        final g = store.goal(place, d.goalId);
        final pendente = d.status == DonationStatus.waiting || d.status == DonationStatus.itemsAgreed;
        return FlowScaffold(
          background: AppColors.cinza50,
          primary: pendente ? 'Confirmar recebimento' : null,
          onPrimary: pendente ? () => _confirm(d, g) : null,
          secondary: pendente ? (d.type == HelpType.pix ? 'Não encontrei' : 'Não chegou') : null,
          onSecondary: pendente ? () => _missing(d) : null,
          children: [
            _hero(d, g),
            const SizedBox(height: 14),
            _donor(d),
            const SizedBox(height: 14),
            _details(d, g, place),
            const SizedBox(height: 14),
            _history(d),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  /// O valor grande e a situação, como no cabeçalho de um recibo.
  Widget _hero(Donation d, Goal? g) {
    final (label, tone) = switch (d.status) {
      DonationStatus.confirmed => ('Confirmada em ${Fmt.day(d.confirmedAt ?? d.date)}', Tone.success),
      DonationStatus.notFound => ('Não encontrada', Tone.neutral),
      DonationStatus.cancelled => ('Cancelada por quem registrou', Tone.neutral),
      DonationStatus.absent => ('Não compareceu', Tone.neutral),
      DonationStatus.enrolled => ('Inscrito', Tone.info),
      DonationStatus.itemsAgreed => ('Entrega combinada', Tone.alert),
      DonationStatus.waiting => ('Esperando sua confirmação', Tone.alert),
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeTag(d.type),
              const Spacer(),
              StatusTag(label, tone: tone),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _what(d, g),
            style: AppType.display(size: 34).copyWith(height: 1.05, fontFeatures: tabular),
          ),
          const SizedBox(height: 6),
          Text(
            'Registrada em ${Fmt.date(d.date)}, às ${Fmt.hour(d.date.hour * 60 + d.date.minute)}',
            style: AppType.body(size: 14),
          ),
        ],
      ),
    );
  }

  /// Quem doou e como falar com a pessoa.
  Widget _donor(Donation d) {
    final c = _contact;
    final minhas = store.donations
        .where((x) => x.placeId == d.placeId && x.donorId != null && x.donorId == d.donorId)
        .toList();
    final confirmadas = minhas.where((x) => x.status == DonationStatus.confirmed).length;
    final nome = c?.name.isNotEmpty == true ? c!.name : d.donor;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: AppColors.ocre50, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  nome.isEmpty ? '?' : nome[0].toUpperCase(),
                  style: AppType.cardTitle(size: 19, color: AppColors.ocre800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: AppType.cardTitle(size: 17, color: AppColors.cinza900)),
                    const SizedBox(height: 3),
                    Text(
                      minhas.length <= 1
                          ? 'Primeira doação para o seu ponto'
                          : '${minhas.length} doações para o seu ponto'
                                '${confirmadas > 0 ? ' · $confirmadas confirmada${confirmadas == 1 ? '' : 's'}' : ''}',
                      style: AppType.body(size: 13.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loadingContact) ...[
            const SizedBox(height: 14),
            const Hairline(),
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.petroleo600),
                ),
                const SizedBox(width: 10),
                Text('Buscando o contato…', style: AppType.body(size: 14)),
              ],
            ),
          ] else if (c == null) ...[
            const SizedBox(height: 14),
            const Hairline(),
            const SizedBox(height: 12),
            Text(
              'Não deu para mostrar o contato desta pessoa. Ela pode ter apagado a conta.',
              style: AppType.body(size: 13.5),
            ),
          ] else ...[
            const Hairline(),
            if (c.phone case final tel? when tel.isNotEmpty)
              _ContactRow(
                icon: PhosphorIconsRegular.phone,
                label: 'Telefone',
                value: tel,
                actions: [
                  _MiniAction(
                    icon: PhosphorIconsRegular.copy,
                    label: 'Copiar o telefone',
                    onTap: () => _copy('Telefone', tel),
                  ),
                  if (c.whatsapp case final w?)
                    _MiniAction(
                      icon: PhosphorIconsRegular.whatsappLogo,
                      label: 'Abrir no WhatsApp',
                      onTap: () => _open(Uri.parse('https://wa.me/$w'), 'Não deu para abrir o WhatsApp.'),
                    ),
                  _MiniAction(
                    icon: PhosphorIconsRegular.phone,
                    label: 'Ligar',
                    onTap: () => _open(Uri.parse('tel:${tel.replaceAll(RegExp(r'\D'), '')}'), 'Não deu para ligar.'),
                  ),
                ],
              ),
            if (c.email case final mail? when mail.isNotEmpty) ...[
              const Hairline(),
              _ContactRow(
                icon: PhosphorIconsRegular.envelope,
                label: 'E-mail',
                value: mail,
                actions: [
                  _MiniAction(
                    icon: PhosphorIconsRegular.copy,
                    label: 'Copiar o e-mail',
                    onTap: () => _copy('E-mail', mail),
                  ),
                  _MiniAction(
                    icon: PhosphorIconsRegular.envelope,
                    label: 'Escrever um e-mail',
                    onTap: () => _open(Uri.parse('mailto:$mail'), 'Não deu para abrir o e-mail.'),
                  ),
                ],
              ),
            ],
            if (c.place case final onde?) ...[
              const Hairline(),
              _ContactRow(icon: PhosphorIconsRegular.mapPin, label: 'Cidade', value: onde, actions: const []),
            ],
            if (c.phone == null && c.email == null) ...[
              const SizedBox(height: 12),
              Text('Esta pessoa não preencheu telefone nem e-mail no perfil.', style: AppType.body(size: 13.5)),
            ],
            const SizedBox(height: 12),
            Text(
              'Você vê este contato porque a pessoa doou para o seu ponto. Use só para falar sobre a doação.',
              style: AppType.body(size: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  /// A ficha da doação.
  Widget _details(Donation d, Goal? g, Place place) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          InfoRow(title: 'Tipo de ajuda', trailing: TypeTag(d.type)),
          const Hairline(),
          InfoRow(title: 'Meta', value: g?.headline ?? 'Doação sem meta'),
          if (d.when != null) ...[
            const Hairline(),
            InfoRow(
              title: d.type == HelpType.voluntariado ? 'Dia da ação' : 'Entrega combinada',
              value: Fmt.weekdayDay(d.when!),
            ),
          ],
          if (d.confirmedAt != null) ...[
            const Hairline(),
            InfoRow(title: 'Confirmada em', value: Fmt.date(d.confirmedAt!)),
          ],
          if (d.type == HelpType.pix) ...[
            const Hairline(),
            InfoRow(title: 'Recebido em', value: place.payee ?? place.legalName),
          ],
          if (d.receiptPath != null) ...[
            const Hairline(),
            InfoRow(
              title: 'Comprovante',
              value: 'Foto enviada por quem doou',
              action: 'Ver',
              chevron: true,
              onTap: () => _receipt(d, place),
            ),
          ],
        ],
      ),
    );
  }

  /// As outras doações da mesma pessoa para este ponto.
  Widget _history(Donation d) {
    final outras =
        store.donations
            .where(
              (x) =>
                  x.placeId == d.placeId && x.donorId != null && x.donorId == d.donorId && x.id != d.id,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    if (outras.isEmpty) return const SizedBox.shrink();
    final place = store.myPoint!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Antes desta'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, o) in outras.take(6).indexed) ...[
                if (i > 0) const Hairline(),
                InfoRow(
                  title: _what(o, store.goal(place, o.goalId)),
                  value: Fmt.date(o.date),
                  trailing: o.status == DonationStatus.confirmed
                      ? const StatusTag('Confirmada', tone: Tone.success)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _receipt(Donation d, Place place) {
    showAppSheet<void>(
      context,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comprovante', style: AppType.title().copyWith(fontSize: 22)),
          const SizedBox(height: 16),
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
}

/// Linha de contato: ícone, rótulo, valor e os botões redondos de ação.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, required this.actions});

  final IconData icon;
  final String label;
  final String value;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.cinza50, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: AppColors.cinza700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body(size: 12.5)),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label(color: AppColors.cinza900, size: 15),
                ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 6), a],
        ],
      ),
    );
  }
}

/// Botão redondo de 34px ao lado de um contato.
class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: .9,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.petroleo50,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: AppColors.petroleo700),
        ),
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
