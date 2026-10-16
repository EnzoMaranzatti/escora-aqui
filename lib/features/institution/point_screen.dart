import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/icons.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'goal_flow.dart';
import 'register/register_flow.dart' show pixKeyError, pixKeyFormatters, pixKeyTypes;

/// Tab "Ponto": keeps the point's data up to date. Address, photo and
/// responsible go through a new review; a new Pix key pauses Pix goals.
class PointScreen extends StatelessWidget {
  const PointScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.myPoint!;
        final change = store.queue.where((s) => s.place.id == p.id && s.kind == SubmissionKind.mudanca).firstOrNull;
        Widget row(String title, String value, VoidCallback onEdit, {IconData? icon}) => InfoRow(
          icon: icon,
          title: title,
          value: value.trim().isEmpty ? '—' : value,
          action: 'Editar',
          onTap: onEdit,
        );
        return TabPage(
          title: 'Ponto',
          trailing: p.onMap
              ? LinkText('Ver no app', icon: PhosphorIconsRegular.arrowUpRight, onTap: () => previewPoint(context))
              : null,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(
                children: [
                  if (change != null) ...[
                    NoticeBanner(
                      tone: Tone.info,
                      icon: PhosphorIconsRegular.hourglassMedium,
                      title: 'Essa mudança passa por uma nova análise.',
                      text: 'Enquanto isso, o ponto continua no mapa com as informações atuais. Leva até 3 dias úteis.',
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (p.pixPaused) ...[
                    const NoticeBanner(
                      tone: Tone.alert,
                      text: 'Doações via Pix pausadas enquanto a instituição atualiza seus dados.',
                    ),
                    const SizedBox(height: 14),
                  ],
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        row(
                          'Nome no mapa',
                          p.name,
                          () => _text(context, 'Como o ponto aparece no mapa', p.name, (v) => p.name = v),
                        ),
                        const Hairline(),
                        row(
                          'O que vocês fazem',
                          p.about,
                          () => _text(
                            context,
                            'O que vocês fazem',
                            p.about,
                            (v) => p.about = v,
                            max: 280,
                            help: 'Até 280 caracteres. Aparece no perfil do ponto.',
                          ),
                        ),
                        const Hairline(),
                        row(
                          'O que distribui',
                          p.distributes ?? '',
                          () => _text(
                            context,
                            'O que vocês distribuem',
                            p.distributes ?? '',
                            (v) => p.distributes = v,
                            hint: 'Ex.: cestas básicas às sextas, das 14h às 16h',
                            help: 'Opcional. Aparece no perfil do ponto, depois das metas.',
                            optional: true,
                          ),
                        ),
                        const Hairline(),
                        row(
                          'Horários',
                          p.hours,
                          () => _text(context, 'Quando vocês recebem doações?', p.hours, (v) {
                            p.hours = v;
                            p.receiveDays = Place.daysFromText(v);
                          }, hint: 'Ex.: segunda a sexta, das 8h às 17h'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        row('Foto', p.photo == null ? 'Foto enviada' : 'Foto do local', () => _photo(context, p)),
                        const Hairline(),
                        row('Endereço', p.address, () => _address(context, p)),
                        const Hairline(),
                        row(
                          'Chave Pix',
                          p.pixKey == null ? 'Sem chave Pix' : '${p.pixKeyType}: ${p.pixKey}',
                          () => _pix(context, p),
                        ),
                        const Hairline(),
                        row('Responsável', '${p.responsible} · ${p.phone}', () => _responsible(context, p)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _text(
    BuildContext context,
    String label,
    String value,
    void Function(String) save, {
    String hint = '',
    String? help,
    int? max,
    bool optional = false,
  }) {
    return showAppSheet<void>(
      context,
      builder: (context) =>
          _EditField(label: label, value: value, hint: hint, help: help, max: max, optional: optional, onSave: save),
    );
  }

  /// "Essa mudança passa por uma nova análise."
  Future<bool> _review(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsRegular.hourglassMedium,
      title: 'Essa mudança passa por uma nova análise.',
      text: 'Enquanto isso, o ponto continua no mapa com as informações atuais. Leva até 3 dias úteis.',
      confirm: 'Enviar para análise',
      cancel: 'Cancelar',
    );
    return ok != null;
  }

  Future<void> _photo(BuildContext context, Place p) async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400);
      if (f == null || !context.mounted) return;
      if (await File(f.path).length() > 10 * 1024 * 1024) {
        if (context.mounted) {
          Toast.show(
            context,
            'A foto passou de 10 MB. Escolha outra ou reduza o tamanho.',
            icon: PhosphorIconsFill.warningCircle,
          );
        }
        return;
      }
      if (!context.mounted || !await _review(context)) return;
      store.requestChange(p, {'Foto': f.path});
    } catch (_) {}
  }

  Future<void> _address(BuildContext context, Place p) async {
    final v = await showAppSheet<String>(
      context,
      builder: (_) => _EditField(
        label: 'Rua e número',
        value: '${p.street}, ${p.number}',
        hint: '',
        returnValue: true,
        onSave: (_) {},
      ),
    );
    if (v == null || !context.mounted || !await _review(context)) return;
    store.requestChange(p, {'Endereço': '$v · ${p.neighborhood}'});
  }

  Future<void> _responsible(BuildContext context, Place p) async {
    final v = await showAppSheet<String>(
      context,
      builder: (_) =>
          _EditField(label: 'Nome completo', value: p.responsible, hint: '', returnValue: true, onSave: (_) {}),
    );
    if (v == null || !context.mounted || !await _review(context)) return;
    store.requestChange(p, {'Responsável': v});
  }

  Future<void> _pix(BuildContext context, Place p) async {
    final r = await showAppSheet<(String, String, String)>(context, builder: (_) => _PixSheet(place: p));
    if (r == null || !context.mounted) return;
    final ok = await confirmSheet(
      context,
      icon: PhosphorIconsRegular.pauseCircle,
      iconTone: Tone.alert,
      title: 'Trocar a chave Pix pausa as metas de Pix.',
      text:
          'Para proteger quem doa, a nova chave passa por análise. Até a aprovação, as metas de Pix ficam pausadas. Metas de itens e voluntariado continuam normalmente.',
      confirm: 'Trocar chave e pausar Pix',
      cancel: 'Manter chave atual',
    );
    if (ok == null) return;
    store.changePixKey(p, r.$1, r.$2, r.$3);
  }
}

class _EditField extends StatefulWidget {
  const _EditField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onSave,
    this.help,
    this.max,
    this.optional = false,
    this.returnValue = false,
  });

  final String label;
  final String value;
  final String hint;
  final String? help;
  final int? max;
  final bool optional;

  /// Pops with the text instead of saving (changes that need review).
  final bool returnValue;
  final void Function(String) onSave;

  @override
  State<_EditField> createState() => _EditFieldState();
}

class _EditFieldState extends State<_EditField> {
  late String _v = widget.value;

  @override
  Widget build(BuildContext context) {
    final ok = widget.optional || _v.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: widget.label,
          hint: widget.hint,
          help: widget.help,
          initialValue: widget.value,
          maxLength: widget.max,
          maxLines: widget.max != null ? 4 : 1,
          autofocus: true,
          capitalization: TextCapitalization.sentences,
          onChanged: (v) => setState(() => _v = v),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: widget.returnValue ? 'Continuar' : 'Salvar alterações',
          icon: null,
          onPressed: !ok || _v == widget.value
              ? null
              : () {
                  if (widget.returnValue) {
                    Navigator.pop(context, _v.trim());
                    return;
                  }
                  widget.onSave(_v.trim());
                  store.renewReview(store.myPoint!);
                  Toast.show(context, 'Alterações salvas.');
                  Navigator.pop(context);
                },
        ),
      ],
    );
  }
}

class _PixSheet extends StatefulWidget {
  const _PixSheet({required this.place});

  final Place place;

  @override
  State<_PixSheet> createState() => _PixSheetState();
}

class _PixSheetState extends State<_PixSheet> {
  late String _type = widget.place.pixKeyType ?? 'CNPJ';
  String _key = '';
  late String _payee = widget.place.payee ?? '';
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final err = pixKeyError(_type, _key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Chave Pix', style: AppType.title().copyWith(fontSize: 22)),
        const SizedBox(height: 16),
        Text('Tipo de chave Pix', style: AppType.label(size: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in pixKeyTypes)
              ChoiceChipPill(
                label: t,
                selected: _type == t,
                onTap: () => setState(() {
                  _type = t;
                  _key = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          key: ValueKey(_type),
          label: 'Chave Pix',
          hint: '',
          inputFormatters: pixKeyFormatters(_type),
          keyboardType: _type == 'E-mail'
              ? TextInputType.emailAddress
              : (_type == 'Chave aleatória' ? TextInputType.text : TextInputType.number),
          error: _tried ? err : null,
          onChanged: (v) => setState(() => _key = v),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Nome que aparece no banco ao fazer o Pix',
          hint: '',
          initialValue: _payee,
          help:
              'O doador vai conferir esse nome antes de pagar. Ele precisa ser o da instituição (ou do responsável, se não houver CNPJ).',
          onChanged: (v) => setState(() => _payee = v),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Continuar',
          icon: null,
          onPressed: () {
            setState(() => _tried = true);
            if (err != null || _payee.trim().isEmpty) return;
            Navigator.pop(context, (_type, _key.trim(), _payee.trim()));
          },
        ),
      ],
    );
  }
}
