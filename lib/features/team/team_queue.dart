import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../map/escora_map.dart';

/// "Cadastros para analisar": new points, corrections and data changes.
class TeamQueueScreen extends StatefulWidget {
  const TeamQueueScreen({super.key});

  @override
  State<TeamQueueScreen> createState() => _TeamQueueScreenState();
}

class _TeamQueueScreenState extends State<TeamQueueScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.queueOf(SubmissionKind.values[_tab])..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        String count(SubmissionKind k) {
          final n = store.queueOf(k).length;
          return n == 0 ? '' : ' ($n)';
        }

        return TabPage(
          title: 'Cadastros para analisar',
          top: Segmented(
            dense: true,
            items: [
              'Novos${count(SubmissionKind.novo)}',
              'Correções${count(SubmissionKind.correcao)}',
              'Mudanças de dados${count(SubmissionKind.mudanca)}',
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          slivers: [
            if (list.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: EmptyState(
                    icon: PhosphorIconsRegular.clipboardText,
                    title: 'Nenhum cadastro na fila.',
                    text: 'Os novos aparecem aqui assim que forem enviados.',
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
                    final s = list[i];
                    final p = s.place;
                    return AppCard(
                      onTap: () => context.push(ReviewScreen(submission: s)),
                      child: Row(
                        children: [
                          IconTile(icon: PhosphorIconsFill.storefront, color: AppColors.petroleo600, size: 44),
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
                                Text(
                                  '${p.typeLabel} · ${p.neighborhood} · enviado há ${Fmt.ago(s.sentAt)}',
                                  style: AppType.body(size: 13.5),
                                ),
                                if (s.urgent) ...[
                                  const SizedBox(height: 6),
                                  const StatusTag(
                                    'Na fila há mais de 3 dias úteis',
                                    tone: Tone.alert,
                                    icon: PhosphorIconsFill.clock,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza400),
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

/// "Analisar cadastro": checklist that mirrors the donor's "O que
/// verificamos" sheet. Approve only with every item checked.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.submission});

  final Submission submission;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _checked = <String>{};
  final _map = MapController();

  Place get _p => widget.submission.place;

  List<(String, String, String?, Widget?)> get _items {
    final p = _p;
    return [
      (
        'CNPJ',
        p.cnpj != null
            ? 'Ativo na base pública · ${p.legalName}'
            : 'Sem CNPJ · indicado por ${p.indicatedBy}, aceito em ${Fmt.day(widget.submission.sentAt)}',
        'O nome e a atividade combinam com o ponto?',
        null,
      ),
      (
        'Endereço',
        '${p.address} · pino no mapa',
        'O endereço combina com o CNPJ e com a foto?',
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 120,
            child: IgnorePointer(
              child: EscoraMap(
                controller: _map,
                initialCenter: p.point,
                initialZoom: 16,
                interactive: false,
                children: [
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: p.point,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(PhosphorIconsFill.mapPin, size: 36, color: AppColors.terracota600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      (
        'Foto',
        'Foto enviada',
        'A foto mostra o local de verdade?',
        p.image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image(image: p.image!, height: 140, width: double.infinity, fit: BoxFit.cover),
              )
            : Container(
                height: 120,
                decoration: BoxDecoration(color: AppColors.cinza100, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const Icon(PhosphorIconsRegular.image, size: 36, color: AppColors.cinza400),
              ),
      ),
      if (p.pixKey != null)
        (
          'Chave Pix',
          '${p.pixKeyType}: ${p.pixKey} · favorecido: ${p.payee}',
          'O favorecido é a instituição (ou o responsável, se não há CNPJ)?',
          null,
        ),
      ('Responsável', '${p.responsible} · ${p.phone}', 'O telefone atende e é de quem cuida do ponto?', null),
    ];
  }

  Future<void> _approve() async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsFill.sealCheck,
      title: 'Aprovar ${_p.name}?',
      text:
          'O ponto aparece no mapa com o selo "Verificado em ${Fmt.day(DateTime.now())}", e o responsável recebe um aviso.',
      confirm: 'Aprovar e publicar',
      cancel: 'Voltar',
    );
    if (ok == null || !mounted) return;
    store.approve(widget.submission);
    Toast.show(context, '${_p.name} aprovado e publicado no mapa.');
    Navigator.pop(context);
  }

  Future<void> _adjust() async {
    final sent = await showAppSheet<bool>(context, builder: (_) => _AdjustSheet(submission: widget.submission));
    if (sent == true && mounted) Navigator.pop(context);
  }

  Future<void> _refuse() async {
    final r = await confirmSheet(
      context,
      title: 'Recusar ${_p.name} de vez?',
      text:
          'Use só em casos graves, como documento falso ou instituição inexistente. Para erros que dá para corrigir, peça um ajuste.',
      field: const SheetField(label: 'Motivo da recusa', required: true, help: 'Aparece para a instituição.'),
      confirm: 'Recusar cadastro',
      cancel: 'Pedir ajuste em vez disso',
      destructive: true,
      onCancel: _adjust,
    );
    if (r == null || !mounted) return;
    store.refuse(widget.submission, r);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final changes = s.kind == SubmissionKind.mudanca;
    final items = changes
        ? [
            for (final e in s.changes.entries)
              e.key == 'Foto' && photoImage(e.value) != null
                  ? (
                      'Foto',
                      'Foto nova',
                      'A foto mostra o local de verdade?',
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image(image: photoImage(e.value)!, height: 140, width: double.infinity, fit: BoxFit.cover),
                      ),
                    )
                  : (e.key, e.value, null, null),
          ]
        : _items;
    final missing = items.length - _checked.length;
    return FlowScaffold(
      title: _p.name,
      subtitle: 'Enviado por ${_p.responsible} em ${Fmt.day(s.sentAt)}',
      background: AppColors.cinza50,
      primary: 'Aprovar ponto',
      primaryIcon: null,
      onPrimary: missing == 0 ? _approve : null,
      note: missing == 0
          ? null
          : Text(
              'Confira todos os itens para aprovar. Faltam $missing.',
              style: AppType.body(size: 14).copyWith(fontFeatures: tabular),
            ),
      secondary: 'Pedir ajuste',
      onSecondary: _adjust,
      children: [
        for (final (title, shown, question, extra) in items) ...[
          _CheckItem(
            title: title,
            shown: shown,
            question: question,
            extra: extra,
            checked: _checked.contains(title),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _checked.contains(title) ? _checked.remove(title) : _checked.add(title));
            },
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        if (!changes)
          Center(
            child: LinkText('Recusar cadastro', color: AppColors.erroTexto, onTap: _refuse),
          ),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({
    required this.title,
    required this.shown,
    required this.question,
    required this.checked,
    required this.onTap,
    this.extra,
  });

  final String title;
  final String shown;
  final String? question;
  final Widget? extra;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.medium,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: checked ? AppColors.sucessoBase : AppColors.cinza100, width: checked ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: AppType.cardTitle(size: 17, color: AppColors.cinza900)),
              ),
              if (checked) const StatusTag('Conferido', tone: Tone.success, icon: PhosphorIconsFill.checkCircle),
            ],
          ),
          const SizedBox(height: 6),
          Text(shown, style: AppType.body(size: 14.5, color: AppColors.cinza800)),
          if (extra != null) ...[const SizedBox(height: 10), extra!],
          if (question != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(PhosphorIconsRegular.question, size: 16, color: AppColors.petroleo600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(question!, style: AppType.body(size: 14, color: AppColors.petroleo800)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Pressable(
            onTap: onTap,
            child: Row(
              children: [
                CheckMark(selected: checked, square: true),
                const SizedBox(width: 10),
                Text('Conferido', style: AppType.label(size: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.submission});

  final Submission submission;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _reasons = <String>{};
  String _msg = '';
  bool _tried = false;

  bool get _other => _reasons.contains(adjustReasons.last);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Qual ajuste o cadastro precisa?', style: AppType.title().copyWith(fontSize: 22, height: 1.25)),
        const SizedBox(height: 16),
        for (final r in adjustReasons) ...[
          OptionTile(
            title: r,
            multi: true,
            selected: _reasons.contains(r),
            onTap: () => setState(() => _reasons.contains(r) ? _reasons.remove(r) : _reasons.add(r)),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        AppTextField(
          label: 'Mensagem para a instituição',
          hint: "Explique o que corrigir. Opcional, exceto em 'Outro motivo'.",
          maxLines: 3,
          minLines: 2,
          capitalization: TextCapitalization.sentences,
          error: _tried && _other && _msg.trim().isEmpty ? 'Preencha este campo para continuar.' : null,
          onChanged: (v) => setState(() => _msg = v),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Enviar pedido de ajuste',
          icon: null,
          onPressed: _reasons.isEmpty
              ? null
              : () {
                  setState(() => _tried = true);
                  if (_other && _msg.trim().isEmpty) return;
                  store.askAdjust(widget.submission, _reasons.toList(), _msg);
                  Toast.show(context, 'Pedido de ajuste enviado para ${widget.submission.place.responsible}.');
                  Navigator.pop(context, true);
                },
        ),
        GhostButton(label: 'Voltar', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
