import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';

/// Tela do balcão: a pessoa mostra "ESC-A1B2C3", o parceiro digita e vê se
/// o cupom é de verdade, de quem é e se ainda vale. Dar baixa é um segundo
/// toque de propósito — conferir e usar são decisões diferentes.
class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key, this.demo});

  /// Resultado já pronto, usado só pelo tour de desenvolvimento.
  final CouponLookup? demo;

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  final _field = TextEditingController();
  CouponLookup? _found;
  String? _error;
  bool _loading = false;

  /// Virou baixa agora, nesta tela (e não numa visita anterior).
  bool _justUsed = false;

  @override
  void initState() {
    super.initState();
    final d = widget.demo;
    if (d != null) {
      _found = d;
      _field.text = d.code;
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  String get _code => _field.text.trim().toUpperCase();

  /// O banco gera sempre "ESC-" + 6 caracteres. Só procura quando o código
  /// está inteiro: meia busca só devolve "não encontrado" e assusta.
  bool get _valid => RegExp(r'^ESC-[A-Z0-9]{6}$').hasMatch(_code);

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _found = null;
      _error = null;
      _justUsed = false;
    });
    final r = await store.findCoupon(_code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _found = r.coupon;
      _error = r.error;
    });
    if (r.coupon == null) HapticFeedback.heavyImpact();
  }

  Future<void> _use() async {
    final c = _found;
    if (c == null) return;
    setState(() => _loading = true);
    final r = await store.useCoupon(c);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.coupon != null) {
        _found = r.coupon;
        _justUsed = true;
      } else {
        _error = r.error;
      }
    });
    if (r.coupon != null) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      // O banco recusou (outro caixa deu baixa primeiro): relê o estado real.
      await _search();
    }
  }

  void _clear() {
    _field.clear();
    setState(() {
      _found = null;
      _error = null;
      _justUsed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Validar cupom',
      subtitle: Text(
        'Digite o código que a pessoa mostrou. Confira o nome antes de dar baixa.',
        style: AppType.body(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverList.list(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Código do cupom',
                      hint: 'ESC-A1B2C3',
                      help: 'O "ESC-" entra sozinho. Digite as seis letras e números.',
                      controller: _field,
                      capitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.search,
                      inputFormatters: const [_CouponFormatter()],
                      enabled: !_loading,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _valid ? _search() : null,
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'Procurar',
                      loading: _loading && _found == null,
                      onPressed: _valid && !_loading ? _search : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: AppMotion.fast,
                switchInCurve: AppMotion.smooth,
                child: _result(),
              ),
              // Enquanto não há nada para mostrar, a tela ensina o balcão.
              // Quem atende muda, e o passo que se esquece é conferir o nome.
              if (_found == null && _error == null) ...[
                const SizedBox(height: 10),
                const SectionTitle('Como funciona'),
                const _Steps(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _result() {
    if (_error != null) {
      return _Panel(
        key: const ValueKey('erro'),
        tone: Tone.error,
        icon: PhosphorIconsFill.xCircle,
        title: _error!,
        text: 'Confira as letras e os números com a pessoa e procure de novo.',
        onClear: _clear,
      );
    }
    final c = _found;
    if (c == null) {
      return const SizedBox.shrink(key: ValueKey('vazio'));
    }
    if (_justUsed) {
      return _Panel(
        key: const ValueKey('baixa'),
        tone: Tone.success,
        icon: PhosphorIconsFill.checkCircle,
        title: 'Cupom usado.',
        text: '${c.title} · ${c.donorName}. Baixa registrada agora, '
            '${Fmt.day(c.usedAt!)} às ${_hour(c.usedAt!)}.',
        onClear: _clear,
      );
    }
    if (c.used) {
      return _Panel(
        key: const ValueKey('usado'),
        tone: Tone.alert,
        icon: PhosphorIconsRegular.clockCounterClockwise,
        title: 'Esse cupom já foi usado.',
        text: 'Baixa em ${Fmt.date(c.usedAt!)} às ${_hour(c.usedAt!)}. '
            'Cada cupom vale uma vez só.',
        onClear: _clear,
      );
    }
    return _ValidCard(coupon: c, loading: _loading, onUse: _use, onClear: _clear);
  }
}

/// O cupom vale. Quem confere no balcão olha primeiro o nome da pessoa,
/// então é ele que vem grande; o resto é ficha.
class _ValidCard extends StatelessWidget {
  const _ValidCard({required this.coupon, required this.loading, required this.onUse, required this.onClear});

  final CouponLookup coupon;
  final bool loading;
  final VoidCallback onUse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const ValueKey('vale'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Tone.success.bg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    coupon.donorName.isEmpty ? '?' : coupon.donorName[0].toUpperCase(),
                    style: AppType.cardTitle(size: 20, color: Tone.success.fg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.donorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle(size: 20),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(PhosphorIconsFill.sealCheck, size: 15, color: Tone.success.fg),
                          const SizedBox(width: 5),
                          Text(
                            'Cupom válido',
                            style: AppType.label(color: Tone.success.fg, size: 13.5)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Hairline(indent: 16),
          _Linha('O que é', coupon.title),
          const Hairline(indent: 16),
          _Linha('Código', coupon.code),
          const Hairline(indent: 16),
          _Linha('Trocado em', Fmt.date(coupon.date)),
          const Hairline(indent: 16),
          _Linha('Custou', '${coupon.points} pontos'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                PrimaryButton(label: 'Dar baixa', loading: loading, onPressed: loading ? null : onUse),
                const SizedBox(height: 6),
                Center(child: LinkText('Procurar outro', onTap: onClear)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rótulo à esquerda, valor à direita.
class _Linha extends StatelessWidget {
  const _Linha(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InfoRow(
        title: label,
        trailing: Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: AppType.label(color: AppColors.cinza900, size: 15)
                .copyWith(fontWeight: FontWeight.w600, fontFeatures: tabular),
          ),
        ),
      ),
    );
  }
}

/// Resultado em uma frase: não achou, já usado, ou baixa feita.
class _Panel extends StatelessWidget {
  const _Panel({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.text,
    required this.onClear,
  });

  final Tone tone;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: tone.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: tone.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.cardTitle(color: tone.fg)),
                    const SizedBox(height: 4),
                    Text(text, style: AppType.body(size: 14, color: tone.fg)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: LinkText('Procurar outro', onTap: onClear)),
        ],
      ),
    );
  }
}

/// "14h30" a partir de um horário (o Fmt.hour do app recebe minutos do dia).
String _hour(DateTime d) => Fmt.hour(d.hour * 60 + d.minute);

/// Escreve o código por quem digita: tudo em maiúscula, sem nada que não
/// seja letra ou número, e com o "ESC-" na frente. Colar "esc-a1b2c3" ou
/// digitar só "a1b2c3" dá no mesmo.
class _CouponFormatter extends TextInputFormatter {
  const _CouponFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antes, TextEditingValue agora) {
    var s = agora.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (s.startsWith('ESC')) s = s.substring(3);
    if (s.length > 6) s = s.substring(0, 6);
    final t = s.isEmpty ? '' : 'ESC-$s';
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Os três passos do balcão, numerados.
class _Steps extends StatelessWidget {
  const _Steps();

  static const _passos = [
    ('A pessoa mostra o código', 'Ele aparece no celular dela, em "Meus cupons".'),
    ('Você confere o nome', 'O app diz de quem é o cupom e o que ele vale.'),
    ('Dá baixa', 'Cada cupom vale uma vez só. Depois da baixa ele não volta.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          for (final (i, (titulo, texto)) in _passos.indexed) ...[
            if (i > 0) const Hairline(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: AppColors.cinza100, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: AppType.label(color: AppColors.cinza700, size: 13.5)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: AppType.label(color: AppColors.cinza900, size: 15)),
                        const SizedBox(height: 2),
                        Text(texto, style: AppType.body(size: 13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
