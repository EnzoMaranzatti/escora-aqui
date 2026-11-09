import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'catalog_screen.dart';
import 'history_screen.dart';
import 'level_medal.dart';

/// Tab "Pontos" (fase 9): o saldo em destaque, os pontos do dia para pegar,
/// as sequências e as portas para o catálogo e para o extrato. Todo número
/// vem do banco.
class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.points;
        return TabPage(
          title: 'Pontos',
          onRefresh: store.refresh,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList.list(
                children: [
                  if (p == null)
                    const _HowItWorks(intro: true)
                  else ...[
                    _Hero(points: p),
                    const SizedBox(height: 10),
                    _DailyCard(points: p),
                    const SizedBox(height: 10),
                    _Streaks(points: p),
                    const SizedBox(height: 10),
                    const _CatalogCard(),
                    const SizedBox(height: 10),
                    const _HistoryCard(),
                    const SizedBox(height: 26),
                    const _HowItWorks(),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Saldo ────────────────────────────────────────────────────

/// O cartão de cima: saldo, nível e o quanto falta para o próximo. O fundo
/// muda de cor com o nível e a medalha entra grande, no canto de destaque —
/// é ela que a pessoa está perseguindo, não o ícone de apoio que era antes.
class _Hero extends StatelessWidget {
  const _Hero({required this.points});

  final PointsProfile points;

  @override
  Widget build(BuildContext context) {
    final step = points.nextStep;
    final next = points.nextLevel;
    final months = points.donationStreakMonths;
    final skin = _LevelSkin.of(points.level);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skin.gradient,
        ),
        boxShadow: [
          BoxShadow(color: skin.shadow.withValues(alpha: .26), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LevelBadge(level: points.level),
                    const SizedBox(height: 12),
                    // O saldo sobe contando até o valor. Quando os pontos do
                    // dia entram, o número anda sozinho.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: points.balance.toDouble()),
                      duration: const Duration(milliseconds: 700),
                      curve: AppMotion.smooth,
                      builder: (context, v, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Fmt.count(v.round()),
                          maxLines: 1,
                          style: AppType.display(
                            size: 46,
                            color: AppColors.white,
                          ).copyWith(fontFeatures: tabular),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      points.balance == 1 ? 'ponto para trocar' : 'pontos para trocar',
                      style: AppType.body(size: 15, color: skin.soft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // A medalha grande, com um brilho redondo atrás para ela não
              // se perder no degradê.
              SizedBox(
                height: 116,
                width: 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.white.withValues(alpha: .22),
                            AppColors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    LevelMedal(level: points.level, size: 108),
                  ],
                ),
              ),
            ],
          ),
          if (step != null && next != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: points.levelProgress),
                duration: AppMotion.slow,
                curve: AppMotion.smooth,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: AppColors.white.withValues(alpha: .25),
                  valueColor: const AlwaysStoppedAnimation(AppColors.white),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _missingLabel(step, next),
              style: AppType.body(size: 14, color: skin.soft),
            ),
          ],
          if (months > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.fire, size: 16, color: AppColors.white),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '+${(months - 1) * 10}% nos pontos · $months meses doando',
                      style: AppType.strong(size: 13.5, color: AppColors.white),
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

/// "Faltam 3 doações de R$ 10 ou mais para o Ouro", por qual das três
/// trilhas está mais perto (a regra está na migração da fase 9).
String _missingLabel(({PointsTrack track, int missing}) step, PointsLevel next) {
  final n = step.missing;
  final one = n == 1;
  final what = switch (step.track) {
    PointsTrack.donations => one ? 'doação de R\$ 10 ou mais' : 'doações de R\$ 10 ou mais',
    PointsTrack.points => one ? 'ponto' : 'pontos',
    PointsTrack.items => one ? 'item doado' : 'itens doados',
  };
  return '${one ? 'Falta' : 'Faltam'} ${Fmt.count(n)} $what para o ${next.label}';
}

/// A cor do cartão em cada nível. O degradê acompanha o metal da medalha:
/// terracota no Bronze, grafite no Prata, ouro no Ouro e petróleo no Black.
/// [soft] é o tom claro dos textos de apoio sobre esse fundo.
class _LevelSkin {
  const _LevelSkin({required this.gradient, required this.shadow, required this.soft});

  final List<Color> gradient;
  final Color shadow;
  final Color soft;

  static _LevelSkin of(PointsLevel level) => switch (level) {
    PointsLevel.bronze => const _LevelSkin(
      gradient: [AppColors.terracota500, AppColors.terracota700],
      shadow: AppColors.terracota800,
      soft: AppColors.terracota50,
    ),
    PointsLevel.prata => const _LevelSkin(
      gradient: [AppColors.cinza600, AppColors.cinza900],
      shadow: AppColors.cinza900,
      soft: AppColors.cinza100,
    ),
    PointsLevel.ouro => const _LevelSkin(
      gradient: [AppColors.ocre500, AppColors.ocre800],
      shadow: AppColors.ocre800,
      soft: AppColors.ocre50,
    ),
    PointsLevel.black => const _LevelSkin(
      gradient: [AppColors.petroleo700, AppColors.petroleo900],
      shadow: AppColors.petroleo900,
      soft: AppColors.petroleo100,
    ),
  };
}

/// O nome do nível ao lado da medalha. Sem ícone: a medalha logo à esquerda
/// já é o símbolo, e repetir deixaria o canto pesado.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final PointsLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(level.label, style: AppType.strong(size: 13.5, color: AppColors.white)),
    );
  }
}

// ── Pontos do dia ────────────────────────────────────────────

/// Os pontos de hoje, para a pessoa pegar com o dedo. Antes isso acontecia
/// sozinho quando o app abria e ninguém via — agora a semana inteira fica à
/// vista e o dia de hoje tem um botão.
class _DailyCard extends StatefulWidget {
  const _DailyCard({required this.points});

  final PointsProfile points;

  @override
  State<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<_DailyCard> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    final won = await store.claimDailyPoints();
    if (!mounted) return;
    setState(() => _busy = false);
    if (won <= 0) return;
    HapticFeedback.mediumImpact();
    Toast.show(context, '+${Fmt.count(won)} ${won == 1 ? 'ponto' : 'pontos'} de hoje. Até amanhã!');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.points;
    final done = p.claimedToday;
    final today = DateTime.now().weekday;
    final claimed = p.weekdaysClaimed;
    final value = PointsProfile.dailyValue();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.calendarCheck, size: 19, color: AppColors.petroleo600),
              const SizedBox(width: 8),
              Expanded(child: Text('Pontos de hoje', style: AppType.cardTitle(size: 16))),
              if (done)
                Text(
                  'pego ✓',
                  style: AppType.strong(size: 13, color: AppColors.petroleo600),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: _DayPip(
                    weekday: d,
                    value: PointsProfile.dailyValue(
                      DateTime.now().add(Duration(days: d - today)),
                    ),
                    done: claimed.contains(d),
                    isToday: d == today,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (done)
            Text(
              'Você já pegou os pontos de hoje. Volte amanhã: o fim de semana vale mais, e um mês inteiro sem falhar rende 40 pontos de bônus.',
              style: AppType.body(size: 13.5),
            )
          else
            SoftButton(
              label: _busy ? 'Pegando…' : 'Pegar $value ${value == 1 ? 'ponto' : 'pontos'} de hoje',
              icon: _busy ? null : PhosphorIconsFill.star,
              filled: true,
              expand: true,
              onTap: _busy ? null : _claim,
            ),
        ],
      ),
    );
  }
}

/// Um dia da semana na tirinha: a inicial em cima e, embaixo, o quanto vale
/// ou o certinho de quem já pegou.
class _DayPip extends StatelessWidget {
  const _DayPip({required this.weekday, required this.value, required this.done, required this.isToday});

  final int weekday;
  final int value;
  final bool done;
  final bool isToday;

  static const _labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? AppColors.petroleo600
        : isToday
        ? AppColors.ocre100
        : AppColors.cinza100;
    final fg = done
        ? AppColors.white
        : isToday
        ? AppColors.ocre700
        : AppColors.cinza500;
    return Semantics(
      label: '${_labels[weekday - 1]}: ${done ? 'pontos já pegos' : '$value pontos'}',
      child: Column(
        children: [
          Text(
            _labels[weekday - 1],
            style: AppType.body(size: 11.5, color: isToday ? AppColors.cinza900 : AppColors.cinza500),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: AppMotion.medium,
            curve: AppMotion.smooth,
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: isToday && !done ? Border.all(color: AppColors.ocre400, width: 1.5) : null,
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(PhosphorIconsBold.check, size: 15, color: AppColors.white)
                : Text('$value', style: AppType.strong(size: 13.5, color: fg)),
          ),
        ],
      ),
    );
  }
}

// ── Sequências, catálogo e extrato ───────────────────────────

class _Streaks extends StatelessWidget {
  const _Streaks({required this.points});

  final PointsProfile points;

  @override
  Widget build(BuildContext context) {
    final months = points.donationStreakMonths;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: PhosphorIconsFill.fire,
            value: '${points.loginStreakDays}',
            title: points.loginStreakDays == 1 ? 'dia seguido aqui' : 'dias seguidos aqui',
            note: 'Pegue os pontos todo dia para não perder',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: PhosphorIconsFill.calendarCheck,
            value: '$months',
            title: months == 1 ? 'mês doando' : 'meses doando',
            note: months > 1 ? '+${(months - 1) * 10}% nos pontos' : 'Doe todo mês e os pontos rendem mais',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.title, required this.note});

  final IconData icon;
  final String value;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.petroleo600),
          const SizedBox(height: 10),
          Text(value, style: AppType.display(size: 26)),
          const SizedBox(height: 1),
          Text(title, style: AppType.label(size: 14, color: AppColors.cinza700)),
          const SizedBox(height: 6),
          Text(note, style: AppType.body(size: 13)),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard();

  @override
  Widget build(BuildContext context) {
    final items = store.catalog;
    final mine = store.redemptions;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          InfoRow(
            icon: PhosphorIconsRegular.gift,
            title: 'Trocar pontos',
            value: items.isEmpty
                ? 'Nenhum cupom de parceiro por enquanto'
                : items.length == 1
                ? '1 cupom de parceiro'
                : '${items.length} cupons de parceiros',
            chevron: true,
            onTap: () => context.push(const CatalogScreen()),
          ),
          if (mine.isNotEmpty) ...[
            const Hairline(indent: 48),
            InfoRow(
              icon: PhosphorIconsRegular.ticket,
              title: 'Minhas trocas',
              value: mine.length == 1 ? '1 cupom' : '${mine.length} cupons',
              chevron: true,
              onTap: () => context.push(const RedemptionsScreen()),
            ),
          ],
        ],
      ),
    );
  }
}

/// O extrato saiu daqui: a lista inteira empurrava o resto da tela para
/// baixo. Agora é uma linha que leva para a tela própria.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context) {
    final n = store.pointsEntries.length;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InfoRow(
        icon: PhosphorIconsRegular.receipt,
        title: 'Extrato de pontos',
        value: n == 0
            ? 'Nada por aqui ainda'
            : n == 1
            ? '1 lançamento'
            : '${Fmt.count(n)} lançamentos',
        chevron: true,
        onTap: () => context.push(const PointsHistoryScreen()),
      ),
    );
  }
}

/// As regras, nas palavras da pessoa. Também é a primeira coisa que a aba
/// mostra para quem nunca ganhou um ponto.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({this.intro = false});

  final bool intro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (intro) ...[
          const SizedBox(height: 8),
          const EmptyState(
            icon: PhosphorIconsRegular.coins,
            title: 'Seus pontos começam na primeira doação.',
            text:
                'Cada ajuda que a instituição confirma rende pontos, e os pontos viram cupons de parceiros. Abrir o app todo dia também conta.',
          ),
          const SizedBox(height: 18),
        ] else
          const SectionTitle('Como ganhar pontos'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: const [
              InfoRow(
                icon: PhosphorIconsRegular.coins,
                title: 'Doar em dinheiro',
                value: 'R\$ 1 doado = 2 pontos',
              ),
              Hairline(indent: 48),
              InfoRow(
                icon: PhosphorIconsRegular.package,
                title: 'Doar itens',
                value: 'Cada item entregue = 2 pontos',
              ),
              Hairline(indent: 48),
              InfoRow(
                icon: PhosphorIconsRegular.calendarDots,
                title: 'Pegar os pontos do dia',
                value: '2 pontos de segunda a sexta, 4 no sábado, 6 no domingo',
              ),
              Hairline(indent: 48),
              InfoRow(
                icon: PhosphorIconsRegular.star,
                title: 'Um mês inteiro sem falhar',
                value: 'Pegar os pontos todos os dias do mês rende 40 de bônus',
              ),
              Hairline(indent: 48),
              InfoRow(
                icon: PhosphorIconsRegular.target,
                title: 'Doar todo mês',
                value: 'Cada mês seguido rende 10% a mais nos pontos da doação',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Os pontos entram quando a instituição confirma que recebeu. Eles não viram dinheiro: o app não movimenta valor.',
          style: AppType.body(size: 13.5),
        ),
      ],
    );
  }
}
