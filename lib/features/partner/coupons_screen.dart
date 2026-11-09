import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';

/// O que esta empresa oferece no catálogo e o que já saiu dele. O parceiro
/// não edita nada aqui: quem monta o catálogo é a equipe, em contrato. A
/// tela existe para ele saber quantos cupons ainda podem bater na porta.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cupons = store.partnerCoupons;
    final trocados = cupons.fold<int>(0, (s, c) => s + c.redeemed);
    final usados = cupons.fold<int>(0, (s, c) => s + c.used);
    final esperando = trocados - usados;
    final noCatalogo = cupons.where((c) => c.active).length;

    return TabPage(
      title: 'Meus cupons',
      onRefresh: store.loadPartnerCoupons,
      subtitle: Text(
        cupons.isEmpty
            ? 'O que a sua empresa oferece no catálogo do Escora aqui.'
            : '$noCatalogo ${noCatalogo == 1 ? 'cupom no catálogo' : 'cupons no catálogo'}',
        style: AppType.body(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: cupons.isEmpty
              ? const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: PhosphorIconsRegular.ticket,
                    title: 'Nenhum cupom ainda.',
                    text: 'Quando a equipe publicar um cupom desta empresa no catálogo, ele aparece aqui.',
                  ),
                )
              : SliverList.list(
                  children: [
                    _Hero(esperando: esperando, trocados: trocados, usados: usados),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: StatTile(
                              value: '$trocados',
                              label: 'Trocados',
                              hint: 'Desde o começo',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              value: '$usados',
                              label: 'Já usados',
                              hint: 'Baixa no balcão',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SectionTitle(cupons.length == 1 ? 'O seu cupom' : 'Os seus cupons'),
                    for (final (i, c) in cupons.indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _CouponCard(c),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }
}

/// O número que o parceiro quer de relance: quantas pessoas ainda podem
/// chegar com um cupom desta empresa na mão.
class _Hero extends StatelessWidget {
  const _Hero({required this.esperando, required this.trocados, required this.usados});

  final int esperando;
  final int trocados;
  final int usados;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Esperando no balcão', style: AppType.body(size: 14)),
              const Spacer(),
              Icon(
                esperando > 0 ? PhosphorIconsFill.ticket : PhosphorIconsRegular.ticket,
                size: 20,
                color: esperando > 0 ? AppColors.petroleo600 : AppColors.cinza400,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$esperando',
            style: AppType.display(size: 34).copyWith(height: 1.05, fontFeatures: tabular),
          ),
          const SizedBox(height: 6),
          Text(
            esperando == 0
                ? trocados == 0
                      ? 'Ninguém trocou pontos por um cupom seu ainda.'
                      : 'Todos os cupons trocados já tiveram baixa.'
                : esperando == 1
                ? 'Uma pessoa ainda pode chegar com um código.'
                : 'Pessoas que ainda podem chegar com um código.',
            style: AppType.body(size: 14),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard(this.coupon);

  final PartnerCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final foto = coupon.image;
    final fora = !coupon.active;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (foto != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ColorFiltered(
                // Fora do catálogo fica cinza, como no card do doador.
                colorFilter: fora
                    ? const ColorFilter.matrix(<double>[
                        .2126, .7152, .0722, 0, 0, //
                        .2126, .7152, .0722, 0, 0, //
                        .2126, .7152, .0722, 0, 0, //
                        0, 0, 0, 1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Image(image: foto, height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(coupon.title, style: AppType.cardTitle())),
                    const SizedBox(width: 8),
                    if (fora)
                      const StatusTag('Fora do catálogo')
                    else if (coupon.soldOut)
                      const StatusTag('Esgotado', tone: Tone.alert)
                    else
                      StatusTag('${coupon.cost} pontos', tone: Tone.info),
                  ],
                ),
                if (coupon.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(coupon.description, style: AppType.body(size: 14)),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Hairline(indent: 16),
          _Conta('Trocados por pontos', '${coupon.redeemed}'),
          const Hairline(indent: 16),
          _Conta('Para usar no balcão', '${coupon.pending}', destaque: coupon.pending > 0),
          const Hairline(indent: 16),
          _Conta(
            'Estoque',
            coupon.stock == null
                ? 'Sem limite'
                : '${coupon.stock} ${coupon.stock == 1 ? 'restante' : 'restantes'}',
          ),
          if (coupon.minLevel != PointsLevel.bronze) ...[
            const Hairline(indent: 16),
            _Conta('Nível mínimo', coupon.minLevel.label),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Rótulo à esquerda, número à direita — as linhas de ficha das referências.
class _Conta extends StatelessWidget {
  const _Conta(this.label, this.value, {this.destaque = false});

  final String label;
  final String value;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InfoRow(
        title: label,
        trailing: Text(
          value,
          style: AppType.label(
            color: destaque ? AppColors.petroleo600 : AppColors.cinza900,
            size: 15,
          ).copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
        ),
      ),
    );
  }
}
