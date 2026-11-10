import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Um par rótulo/valor dentro do recibo.
class ReceiptField {
  const ReceiptField(this.label, this.value, {this.wide = false});

  final String label;
  final String value;

  /// Ocupa a linha inteira em vez de metade dela.
  final bool wide;
}

/// Comprovante de uma doação, no formato de bilhete.
///
/// Quem doa por Pix fica com o comprovante do banco, que não diz nada sobre
/// para onde o dinheiro foi nem para qual meta. Este é o comprovante do outro
/// lado: o que a instituição registrou. O recorte e o picote existem para ele
/// ser reconhecido como comprovante antes de ser lido — é a forma que carrega
/// o significado, não um selo escrito "comprovante".
///
/// O cabeçalho é escuro de propósito. Um bilhete todo branco vira mais um card
/// na pilha; a faixa em petróleo com a foto do ponto é o que faz o olho parar
/// nele primeiro e saber, antes de ler, de quem é o comprovante.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.title,
    this.subtitle,
    this.photo,
    this.badge,
    this.badgeDone = false,
    required this.highlight,
    this.highlightLabel,
    required this.fields,
    this.footer,
  });

  final String title;
  final String? subtitle;

  /// Foto do ponto, no canto do cabeçalho.
  final ImageProvider? photo;

  /// Estado da doação, em uma palavra ou duas ("Aguardando confirmação").
  final String? badge;

  /// Confirmada: o selo fica claro e ganha o visto.
  final bool badgeDone;

  /// O número grande: o valor em reais, a quantidade de itens ou as horas.
  final String highlight;
  final String? highlightLabel;
  final List<ReceiptField> fields;

  /// Linha de baixo, depois do picote (o código da doação, por exemplo).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // PhysicalShape desenha a cor e a sombra no formato do próprio recorte:
    // sem isto, a sombra sai retangular e os entalhes somem contra ela.
    return PhysicalShape(
      clipper: const _TicketClipper(),
      // Sem isto o PhysicalShape só usa o recorte para a sombra: o cabeçalho
      // petróleo ia até a borda e os cantos de cima ficavam retos.
      clipBehavior: Clip.antiAlias,
      color: AppColors.white,
      elevation: 10,
      shadowColor: AppColors.cinza900.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cabecalho(title: title, subtitle: subtitle, photo: photo, badge: badge, badgeDone: badgeDone),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlightLabel != null)
                  Text(highlightLabel!, style: AppType.body(size: 12.5, color: AppColors.cinza600)),
                Text(
                  highlight,
                  style: AppType.display(size: 36).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.1,
                  ),
                ),
                if (fields.isNotEmpty) const SizedBox(height: 20),
                Wrap(
                  runSpacing: 16,
                  children: [
                    for (final f in fields)
                      SizedBox(
                        width: f.wide ? double.infinity : 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label, style: AppType.body(size: 12.5, color: AppColors.cinza600)),
                            const SizedBox(height: 1),
                            Text(f.value, style: AppType.cardTitle(size: 16, color: AppColors.cinza900)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const _Perforation(),
          if (footer != null)
            Padding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 20), child: footer)
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}

/// A faixa escura do topo: foto, nome do ponto e o estado da doação.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.title,
    required this.subtitle,
    required this.photo,
    required this.badge,
    required this.badgeDone,
  });

  final String title;
  final String? subtitle;
  final ImageProvider? photo;
  final String? badge;
  final bool badgeDone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.petroleo700,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.petroleo600,
                borderRadius: BorderRadius.circular(14),
              ),
              child: photo == null
                  ? null
                  : Image(
                      image: ResizeImage.resizeIfNeeded(140, null, photo!),
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle(size: 18, color: AppColors.white),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body(size: 13.5, color: AppColors.petroleo100).copyWith(height: 1.3),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: 10),
                    _Selo(label: badge!, done: badgeDone),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    // Sobre o fundo escuro, o contraste do estado vem do preenchimento: a
    // confirmada é sólida e clara, a pendente é só um contorno.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? AppColors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: done ? null : Border.all(color: AppColors.petroleo300, width: 1.2),
      ),
      child: Text(
        label,
        style: AppType.label(size: 12.5, color: done ? AppColors.petroleo700 : AppColors.petroleo100),
      ),
    );
  }
}

/// O picote: pontinhos entre o corpo e o canhoto, alinhados com os entalhes.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: LayoutBuilder(
        builder: (context, box) {
          const passo = 10.0;
          final n = ((box.maxWidth - 36) / passo).floor();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < n; i++)
                  Container(
                    width: 5,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.cinza300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Retângulo arredondado com dois entalhes redondos, na altura do picote.
class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  /// Distância do entalhe até a base. O bloco de baixo tem altura fixa, então
  /// o entalhe cai sempre na linha do picote.
  static const _doFundo = 57.0;
  static const _raioEntalhe = 12.0;

  @override
  Path getClip(Size size) {
    final corpo = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)));
    final y = size.height - _doFundo;
    final entalhes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: _raioEntalhe))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: _raioEntalhe));
    return Path.combine(PathOperation.difference, corpo, entalhes);
  }

  @override
  bool shouldReclip(_TicketClipper old) => false;
}
