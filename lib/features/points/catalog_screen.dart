import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';

/// "Trocar pontos": what the partners offer. Each item costs points and asks
/// for a level; the database checks both again on the way in.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  Future<void> _redeem(BuildContext context, CatalogItem item) async {
    final ok = await confirmSheet(
      context,
      title: 'Trocar ${Fmt.count(item.cost)} pontos?',
      text:
          '${item.title}, de ${item.partner.name}. Os pontos saem do seu saldo e você recebe um código para mostrar no parceiro.',
      confirm: 'Trocar pontos',
      cancel: 'Deixar para depois',
      icon: PhosphorIconsFill.gift,
    );
    if (ok == null || !context.mounted) return;
    store.redeem(item);
    Toast.show(context, 'Troca feita. Seu código está aqui em Minhas trocas.');
    context.push(const RedemptionsScreen());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.points;
        final items = store.catalog..sort((a, b) => a.cost.compareTo(b.cost));
        return FlowScaffold(
          title: 'Trocar pontos',
          subtitle: p == null
              ? null
              : '${Fmt.count(p.balance)} ${p.balance == 1 ? 'ponto' : 'pontos'} no seu saldo · ${p.level.label}',
          background: AppColors.cinza50,
          children: [
            if (items.isEmpty)
              const EmptyState(
                icon: PhosphorIconsRegular.gift,
                title: 'Nenhum cupom por aqui ainda.',
                text:
                    'Os parceiros oferecem ingressos e cupons usando o que já têm sobrando. Assim que o primeiro entrar, ele aparece nesta tela.',
              ),
            for (final item in items) ...[
              _ItemCard(item: item, points: p, onRedeem: () => _redeem(context, item)),
              const SizedBox(height: 10),
            ],
            if (store.redemptions.isNotEmpty) ...[
              const SizedBox(height: 6),
              SoftButton(
                label: 'Minhas trocas',
                icon: PhosphorIconsRegular.ticket,
                expand: true,
                onTap: () => context.push(const RedemptionsScreen()),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.points, required this.onRedeem});

  final CatalogItem item;
  final PointsProfile? points;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final p = points;
    final locked = p == null || p.level.index < item.minLevel.index;
    final missing = p == null ? item.cost : item.cost - p.balance;
    final indisponivel = item.soldOut || locked;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A foto do parceiro sangra até a borda do card. Cupom travado ou
          // esgotado fica sem cor: dá para ver o que é sem precisar ler.
          if (item.photoPath case final foto?)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColorFiltered(
                  colorFilter: indisponivel
                      ? const ColorFilter.matrix(<double>[
                          .2126, .7152, .0722, 0, 0,
                          .2126, .7152, .0722, 0, 0,
                          .2126, .7152, .0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                  child: Image.asset(
                    foto,
                    fit: BoxFit.cover,
                    // Sem a migração das fotos aplicada o caminho pode não
                    // existir: o card continua de pé, só sem imagem.
                    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.cinza100),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.photoPath == null) ...[
                      IconTile(icon: PhosphorIconsFill.ticket, size: 40),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.partner.name, style: AppType.body(size: 13.5)),
                          const SizedBox(height: 2),
                          Text(item.title, style: AppType.cardTitle(size: 16.5, color: AppColors.cinza900)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(item.description, style: AppType.body(size: 14.5)),
                ],
                const SizedBox(height: 14),
                const Hairline(),
                const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.count(item.cost)} pontos',
                      style: AppType.cardTitle(size: 15.5, color: AppColors.petroleo700),
                    ),
                    if (item.stock case final s? when s > 0 && s <= 5) ...[
                      const SizedBox(height: 3),
                      Text(s == 1 ? 'Resta 1' : 'Restam $s', style: AppType.body(size: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (item.soldOut)
                const StatusTag('Esgotado')
              else if (locked)
                StatusTag('Abre no ${item.minLevel.label}', tone: Tone.alert, icon: PhosphorIconsFill.medal)
              else if (missing > 0)
                StatusTag('Faltam ${Fmt.count(missing)} pontos')
              else
                SoftButton(label: 'Trocar', filled: true, onTap: onRedeem),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Minhas trocas": the coupons already taken, with the code to show at the
/// partner.
class RedemptionsScreen extends StatelessWidget {
  const RedemptionsScreen({super.key});

  Future<void> _copy(BuildContext context, String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      HapticFeedback.mediumImpact();
      if (context.mounted) Toast.show(context, 'Código copiado.');
    } catch (_) {
      if (context.mounted) {
        Toast.show(
          context,
          'Não conseguimos copiar. Toque e segure sobre o código para copiar.',
          icon: PhosphorIconsFill.warningCircle,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.redemptions;
        return FlowScaffold(
          title: 'Minhas trocas',
          background: AppColors.cinza50,
          children: [
            if (list.isEmpty)
              const EmptyState(
                icon: PhosphorIconsRegular.ticket,
                title: 'Você ainda não trocou pontos.',
                text: 'Quando trocar, o código do cupom fica guardado aqui.',
              ),
            for (final r in list) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.partnerName.isNotEmpty) ...[
                                Text(r.partnerName, style: AppType.body(size: 13.5)),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                r.title.isEmpty ? 'Cupom de parceiro' : r.title,
                                style: AppType.cardTitle(size: 16.5, color: AppColors.cinza900),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '−${Fmt.count(r.points)}',
                          style: AppType.cardTitle(size: 15.5, color: AppColors.cinza600).copyWith(
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Pressable(
                      onTap: () => _copy(context, r.code),
                      scale: .98,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cinza50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cinza100),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                r.code,
                                style: AppType.cardTitle(
                                  size: 18,
                                  color: AppColors.cinza900,
                                ).copyWith(fontFeatures: tabular, letterSpacing: .5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(PhosphorIconsRegular.copy, size: 20, color: AppColors.petroleo600),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mostre este código ${r.partnerName.isEmpty ? 'no parceiro' : 'em ${r.partnerName}'}. Trocado em ${Fmt.date(r.date)}.',
                      style: AppType.body(size: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
