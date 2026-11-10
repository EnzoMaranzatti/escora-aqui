import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';

/// "Novo cupom": a empresa escreve o que oferece e publica no catálogo.
///
/// É uma tela só, e não um fluxo em passos como o da meta: são cinco campos
/// que cabem na vista, e dois deles já vêm preenchidos (todo mundo pode
/// trocar, sem limite de quantidade). Quem só quer publicar preenche o nome
/// e os pontos.
///
/// As regras daqui são as mesmas do banco (`partner_create_item`, fase 12).
/// O banco confere de novo — a tela só evita a viagem.
class CouponFormScreen extends StatefulWidget {
  const CouponFormScreen({super.key});

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  String _title = '';
  String _description = '';
  String _cost = '';
  String _stock = '';
  PointsLevel _level = PointsLevel.bronze;

  bool _tried = false;
  bool _saving = false;

  /// A recusa do banco (nome repetido, teto de 12 cupons): fica no fim do
  /// formulário até a pessoa mexer em algum campo.
  String? _refused;

  static const _minCost = 50;
  static const _maxCost = 5000;

  /// O nível, na língua de quem não conhece os níveis do app.
  static const _quem = {
    PointsLevel.bronze: 'Todo mundo',
    PointsLevel.prata: 'Prata ou mais',
    PointsLevel.ouro: 'Ouro ou mais',
    PointsLevel.black: 'Só Doador Black',
  };

  int? get _costValue => int.tryParse(_cost);
  int? get _stockValue => _stock.isEmpty ? null : int.tryParse(_stock);

  String? get _titleError {
    final n = _title.trim().length;
    if (n == 0) return 'Diga o que a pessoa ganha com o cupom.';
    if (n < 3) return 'Use pelo menos 3 letras.';
    return null;
  }

  String? get _costError {
    final c = _costValue;
    if (c == null) return 'Informe quantos pontos o cupom custa.';
    if (c < _minCost || c > _maxCost) return 'Escolha um valor de $_minCost a ${Fmt.count(_maxCost)} pontos.';
    if (c % 10 != 0) return 'Use um valor redondo, de 10 em 10.';
    return null;
  }

  String? get _stockError {
    if (_stock.isEmpty) return null;
    final s = _stockValue;
    if (s == null || s < 1) return 'Informe pelo menos 1, ou deixe em branco.';
    return null;
  }

  bool get _valid => _titleError == null && _costError == null && _stockError == null;

  /// Cada R$ 1 doado rende 2 pontos (regra da fase 9). Dizer o custo em
  /// reais doados é o que dá tamanho ao número para quem está digitando.
  String get _costHelp {
    final c = _costValue;
    if (c == null || _costError != null) {
      return 'De $_minCost a ${Fmt.count(_maxCost)}, de 10 em 10.';
    }
    return 'Quem doa ${Fmt.money(c / 2, cents: false)} junta esses pontos.';
  }

  void _edit(VoidCallback change) => setState(() {
    change();
    _refused = null;
  });

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final erro = await store.createCoupon(
      title: _title.trim(),
      description: _description.trim(),
      cost: _costValue!,
      minLevel: _level,
      stock: _stockValue,
    );
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _saving = false;
        _refused = erro;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    // O aviso vai no overlay da raiz, então sobrevive à volta para a lista.
    Toast.show(context, 'Cupom publicado. Ele já aparece no catálogo.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final empresa = store.myPartner?.name ?? 'Sua empresa';
    return FlowScaffold(
      title: 'Novo cupom',
      subtitle: 'Ele entra no catálogo assim que você publicar, e quem doa troca pontos por ele.',
      primary: 'Publicar cupom',
      loading: _saving,
      onPrimary: _publish,
      children: [
        AppTextField(
          label: 'O que a pessoa ganha',
          hint: 'Ex.: R\$ 20 em qualquer livro',
          maxLength: 60,
          capitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          error: _tried ? _titleError : null,
          onChanged: (v) => _edit(() => _title = v),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Como usar (opcional)',
          hint: 'Ex.: vale uma vez por pessoa, de segunda a sexta.',
          maxLines: 3,
          minLines: 2,
          maxLength: 200,
          capitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          onChanged: (v) => _edit(() => _description = v),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: AppTextField(
                label: 'Custo em pontos',
                hint: '150',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                help: _costHelp,
                error: _tried ? _costError : null,
                onChanged: (v) => _edit(() => _cost = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: AppTextField(
                label: 'Quantidade',
                hint: 'Sem limite',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                help: 'Em branco, não acaba.',
                error: _tried ? _stockError : null,
                onChanged: (v) => _edit(() => _stock = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Quem pode trocar', style: AppType.label(size: 14.5, color: AppColors.cinza800)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final nivel in PointsLevel.values)
              ChoiceChipPill(
                label: _quem[nivel]!,
                selected: _level == nivel,
                onTap: () => _edit(() => _level = nivel),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _level == PointsLevel.bronze
              ? 'Qualquer pessoa com pontos suficientes.'
              : 'Só quem já chegou ao nível ${_level.label} vê o botão de trocar.',
          style: AppType.body(size: 13.5),
        ),
        const SizedBox(height: 24),
        Text('Como aparece no catálogo', style: AppType.label(size: 14.5, color: AppColors.cinza800)),
        const SizedBox(height: 10),
        _Preview(
          empresa: empresa,
          title: _title.trim(),
          description: _description.trim(),
          cost: _costError == null ? _costValue : null,
          level: _level,
        ),
        if (_refused != null) ...[
          const SizedBox(height: 16),
          NoticeBanner(text: _refused!, tone: Tone.error),
        ],
      ],
    );
  }
}

/// O cupom do jeito que o doador vai ver, montando enquanto a pessoa
/// escreve. É o mesmo desenho do card do catálogo sem foto.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.empresa,
    required this.title,
    required this.description,
    required this.cost,
    required this.level,
  });

  final String empresa;
  final String title;
  final String description;
  final int? cost;
  final PointsLevel level;

  @override
  Widget build(BuildContext context) {
    final vazio = title.isEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cinza50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cinza200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: PhosphorIconsFill.ticket, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(empresa, style: AppType.body(size: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      vazio ? 'O nome do cupom' : title,
                      style: AppType.cardTitle(size: 16.5, color: vazio ? AppColors.cinza400 : AppColors.cinza900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: AppType.body(size: 14.5)),
          ],
          const SizedBox(height: 14),
          const Hairline(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  cost == null ? '— pontos' : '${Fmt.count(cost!)} pontos',
                  style: AppType.cardTitle(
                    size: 15.5,
                    color: cost == null ? AppColors.cinza400 : AppColors.petroleo700,
                  ).copyWith(fontFeatures: tabular),
                ),
              ),
              if (level != PointsLevel.bronze)
                StatusTag('Abre no ${level.label}', tone: Tone.alert, icon: PhosphorIconsFill.medal),
            ],
          ),
        ],
      ),
    );
  }
}
