import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'coupon_form_screen.dart';

/// O que esta empresa oferece no catálogo e o que já saiu dele: quantos
/// cupons ainda podem bater na porta, e a porta para criar outro.
///
/// Até a fase 11 o parceiro não mexia em nada aqui — quem montava o
/// catálogo era a equipe, no banco. Desde a fase 12 o cupom é da empresa:
/// ela cria ("Novo cupom") e tira do ar. Só não apaga, porque quem já
/// trocou pontos continua com o código na mão.
class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  // A tela escuta o `store` por conta própria. O shell também escuta, mas
  // ele guarda esta aba como `const CouponsScreen()`: a instância é sempre a
  // mesma, e o Flutter não reconstrói um widget idêntico. Sem o
  // `ListenableBuilder` a lista ficava com a foto do primeiro desenho — um
  // cupom recém-publicado só aparecia depois de sair e entrar no app.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final cupons = store.partnerCoupons;
    final trocados = cupons.fold<int>(0, (s, c) => s + c.redeemed);
    final usados = cupons.fold<int>(0, (s, c) => s + c.used);
    final esperando = trocados - usados;
    final noCatalogo = cupons.where((c) => c.active).length;

    return TabPage(
      title: 'Meus cupons',
      onRefresh: store.loadPartnerCoupons,
      // Criar é uma ação, não um lugar: por isso mora aqui, ao lado do
      // título, e não como terceira aba da barra de baixo.
      trailing: cupons.isEmpty
          ? null
          : SoftButton(
              label: 'Novo cupom',
              icon: PhosphorIconsBold.plus,
              filled: true,
              height: 40,
              onTap: () => context.push(const CouponFormScreen()),
            ),
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
              ? SliverToBoxAdapter(
                  child: EmptyState(
                    icon: PhosphorIconsRegular.ticket,
                    title: 'Nenhum cupom ainda.',
                    text: 'Crie o primeiro: ele entra no catálogo na hora, e quem doa troca pontos por ele.',
                    primary: 'Criar cupom',
                    onPrimary: () => context.push(const CouponFormScreen()),
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
                esperando > 0 ? PhosphorIconsFill.ticket : PhosphorIconsBold.ticket,
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
          const Hairline(indent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: fora
                ? SoftButton(
                    label: 'Voltar ao catálogo',
                    filled: true,
                    expand: true,
                    onTap: () => _mudar(context, true),
                  )
                : SoftButton(label: 'Tirar do catálogo', expand: true, onTap: () => _mudar(context, false)),
          ),
        ],
      ),
    );
  }

  /// Tirar pede confirmação, porque some da vista de quem doa; voltar não —
  /// é só desfazer.
  Future<void> _mudar(BuildContext context, bool ativo) async {
    if (!ativo) {
      final esperando = coupon.pending;
      final ok = await confirmSheet(
        context,
        title: 'Tirar do catálogo?',
        text:
            'Ninguém mais vai conseguir trocar pontos por "${coupon.title}". '
            '${esperando == 0
                ? 'Você pode voltar com ele quando quiser.'
                : esperando == 1
                ? 'A pessoa que já trocou continua com o código valendo.'
                : 'As $esperando pessoas que já trocaram continuam com o código valendo.'}',
        confirm: 'Tirar do catálogo',
        cancel: 'Manter',
      );
      if (ok == null || !context.mounted) return;
    }
    final erro = await store.setCouponActive(coupon, ativo);
    if (!context.mounted) return;
    if (erro != null) {
      Toast.show(context, erro, icon: PhosphorIconsFill.warningCircle);
      return;
    }
    HapticFeedback.selectionClick();
    Toast.show(context, ativo ? 'O cupom voltou ao catálogo.' : 'O cupom saiu do catálogo.');
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
