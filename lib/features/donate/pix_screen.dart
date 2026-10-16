import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'goal_reminder.dart';
import 'registered_screen.dart';

/// Copies the key and tells where to paste it.
Future<void> copyPixKey(BuildContext context, String key) async {
  try {
    await Clipboard.setData(ClipboardData(text: key));
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      Toast.show(
        context,
        'Chave copiada. Cole no app do seu banco e volte aqui para registrar a doação.',
        duration: const Duration(seconds: 4),
      );
    }
  } catch (_) {
    if (context.mounted) {
      Toast.show(
        context,
        'Não conseguimos copiar a chave. Toque e segure sobre ela para copiar manualmente.',
        icon: PhosphorIconsFill.warningCircle,
      );
    }
  }
}

/// Doar via Pix, passo 1: the key, and the fact that the money goes
/// straight to the institution (the payment happens in the bank's app).
class PixScreen extends StatelessWidget {
  const PixScreen({super.key, required this.placeId, required this.goalId});

  final String placeId;
  final String goalId;

  @override
  Widget build(BuildContext context) {
    final p = store.place(placeId);
    final g = store.goal(p, goalId)!;
    final key = p.pixKey ?? '';
    return FlowScaffold(
      title: 'Doe via Pix para ${p.name}',
      primary: 'Copiar chave Pix',
      primaryIcon: null,
      onPrimary: () => copyPixKey(context, key),
      secondary: 'Já fiz o Pix',
      onSecondary: () => context.push(DeclareScreen(placeId: placeId, goalId: goalId)),
      children: [
        GoalReminder(text: '${g.headline}. Motivo: ${g.reason}', type: g.type),
        const SizedBox(height: 16),
        const NoticeBanner(
          tone: Tone.info,
          icon: PhosphorIconsFill.shieldCheck,
          text: 'O dinheiro vai direto para a instituição. O Escora aqui não recebe o valor e não cobra taxa.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cinza50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cinza100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chave Pix (${p.pixKeyType}):', style: AppType.body(size: 14)),
              const SizedBox(height: 6),
              Pressable(
                onTap: () => copyPixKey(context, key),
                scale: .98,
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        key,
                        style: AppType.cardTitle(
                          size: 19,
                          color: AppColors.cinza900,
                        ).copyWith(height: 1.3, fontFeatures: tabular),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(PhosphorIconsRegular.copy, size: 22, color: AppColors.petroleo600),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Hairline(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(PhosphorIconsRegular.bank, size: 18, color: AppColors.cinza700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Confira no seu banco se o nome aparece como:', style: AppType.body(size: 14)),
                        const SizedBox(height: 4),
                        Text(
                          p.payee ?? p.legalName,
                          style: AppType.label(
                            color: AppColors.cinza900,
                            size: 15.5,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Doar via Pix, passo 2: the donor tells how much they sent. The goal
/// only moves when the institution confirms it (modelo B).
class DeclareScreen extends StatefulWidget {
  const DeclareScreen({super.key, required this.placeId, required this.goalId});

  final String placeId;
  final String goalId;

  @override
  State<DeclareScreen> createState() => _DeclareScreenState();
}

class _DeclareScreenState extends State<DeclareScreen> {
  String _value = '';
  bool _tried = false;
  bool _loading = false;
  XFile? _receipt;

  String? get _error {
    final t = _value.trim();
    if (t.isEmpty) return 'Informe o valor que você doou.';
    final v = Fmt.parseMoney(t);
    if (v == null) return 'Use apenas números, por exemplo 50,00.';
    if (v <= 0) return 'Informe o valor que você doou.';
    return null;
  }

  Future<void> _attach() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (f != null) setState(() => _receipt = f);
    } catch (_) {
      // Permission denied or picker closed.
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    if (_error != null) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    final p = store.place(widget.placeId);
    final g = store.goal(p, widget.goalId)!;
    final amount = Fmt.parseMoney(_value.trim())!;
    store.registerPix(p, g, amount, receipt: _receipt != null);
    context.push(RegisteredScreen.pix(place: p, amount: amount));
  }

  @override
  Widget build(BuildContext context) {
    final p = store.place(widget.placeId);
    return FlowScaffold(
      title: 'Quanto você doou?',
      subtitle: 'A ${p.name} vai conferir o recebimento. Quando ela confirmar, a meta avança.',
      primary: 'Registrar doação',
      primaryIcon: null,
      loading: _loading,
      note: _loading ? Text('Registrando sua doação…', style: AppType.body(size: 14)) : null,
      onPrimary: _submit,
      secondary: 'Voltar',
      onSecondary: () => Navigator.pop(context),
      children: [
        AppTextField(
          label: 'Valor doado',
          hint: 'R\$ 0,00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R$ ]'))],
          autofocus: true,
          error: _tried ? _error : null,
          onChanged: (v) => setState(() => _value = v),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 22),
        Text('Comprovante', style: AppType.label(size: 14)),
        const SizedBox(height: 6),
        if (_receipt == null)
          SoftButton(
            label: 'Anexar comprovante',
            icon: PhosphorIconsRegular.paperclip,
            expand: true,
            height: 50,
            onTap: _attach,
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cinza50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cinza200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_receipt!.path), width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                const Icon(PhosphorIconsFill.checkCircle, size: 18, color: AppColors.sucessoBase),
                const SizedBox(width: 6),
                Expanded(child: Text('Comprovante', style: AppType.label(size: 15))),
                IconButton(
                  tooltip: 'Remover comprovante',
                  onPressed: () => setState(() => _receipt = null),
                  icon: const Icon(PhosphorIconsRegular.x, size: 18, color: AppColors.cinza600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text('Opcional. Ajuda a instituição a encontrar sua doação mais rápido.', style: AppType.body(size: 13)),
      ],
    );
  }
}
