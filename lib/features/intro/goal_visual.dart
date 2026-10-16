import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/svg_icon.dart';

/// Screen 6. A live goal card answers the copy's three questions (how
/// much is missing, until when, what for). It rises into place, the
/// "Ajude do seu modo" badge is stamped on its corner, then Pix
/// donations arrive one by one and push the bar up.
class GoalVisual extends StatefulWidget {
  const GoalVisual({super.key, required this.active});

  final bool active;

  @override
  State<GoalVisual> createState() => _GoalVisualState();
}

class _Gift {
  const _Gift(this.name, this.amount);

  final String name;
  final int amount;
}

const _goal = 1200;
const _start = 660;
const _gifts = [_Gift('Ana', 30), _Gift('Lucas', 50), _Gift('Marina', 20), _Gift('Pedro', 100)];

class _GoalVisualState extends State<GoalVisual> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  Timer? _loop;

  /// How many gifts have arrived so far.
  int _given = 0;

  int get _raised => _start + _gifts.take(_given).fold(0, (sum, g) => sum + g.amount);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GoalVisual old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (_enter.isDismissed) _enter.forward();
      _idle.repeat();
      _loop ??= Timer.periodic(const Duration(milliseconds: 2600), (_) => _gift());
    } else {
      _idle.stop();
      _loop?.cancel();
      _loop = null;
    }
  }

  void _gift() {
    if (!mounted || !_enter.isCompleted) return;
    // After the last gift, start over from the first amount.
    setState(() => _given = _given >= _gifts.length ? 0 : _given + 1);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed warm glow, so nothing ends in a hard edge.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.1),
              radius: .9,
              colors: [AppColors.terracota50, AppColors.white],
            ),
          ),
        ),
        const Center(child: Ring(diameter: 340)),
        const Center(child: Ring(diameter: 520)),
        // Fade into the white text panel, like the map on screen 4.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [.75, 1],
              colors: [Color(0x00FFFFFF), AppColors.white],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: top + 56, bottom: 4),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedBuilder(
                animation: Listenable.merge([_enter, _idle]),
                builder: (context, _) {
                  final e = _enter.value;
                  final card = AppMotion.smooth.transform(const Interval(0, .6).transform(e));
                  final badge = AppMotion.pop.transform(const Interval(.5, .85).transform(e));
                  final settle = Curves.easeOut.transform(const Interval(.7, 1).transform(e));
                  final wave = math.sin(_idle.value * 2 * math.pi);
                  return SizedBox(
                    width: 340,
                    height: 318,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 20,
                          top: 26,
                          width: 300,
                          child: Opacity(
                            opacity: card,
                            child: Transform.translate(
                              offset: Offset(0, 70 * (1 - card) + wave * 2.5 * settle),
                              child: Transform.scale(
                                scale: .92 + .08 * card,
                                child: _GoalCard(raised: _raised, active: e > .3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -6,
                          top: -2,
                          child: Opacity(
                            opacity: badge.clamp(0, 1),
                            child: Transform.translate(
                              offset: Offset(0, -2 * wave * settle),
                              child: Transform.rotate(
                                // Lands from a bigger tilt to Figma's 11°, then sways ±2.5°.
                                angle: (11.04 + 24 * (1 - badge) + 2.5 * wave * settle) * math.pi / 180,
                                child: Transform.scale(scale: .4 + .6 * badge, child: const _Badge()),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 40,
                          child: AnimatedSwitcher(
                            duration: AppMotion.slow,
                            switchInCurve: AppMotion.pop,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(a),
                                child: child,
                              ),
                            ),
                            child: _given == 0
                                ? const SizedBox.shrink()
                                : Center(key: ValueKey(_given), child: _GiftToast(_gifts[_given - 1])),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _money(int v) {
  final s = v.toString();
  final grouped = s.length > 3 ? '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}' : s;
  return 'R\$ $grouped';
}

/// Goal card in the same language as the map card on screen 4.
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.raised, required this.active});

  final int raised;

  /// The bar only fills once the card is in place.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.terracota600, shape: BoxShape.circle),
                child: const SvgIcon(Ic.church, size: 15, color: AppColors.white),
              ),
              const SizedBox(width: 8),
              Text('Casa Exemplo', style: AppType.label(size: 12.5, color: AppColors.cinza800)),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.sucessoBase, shape: BoxShape.circle),
                child: const SvgIcon(Ic.checkWhite, size: 9),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('40 cobertores', style: AppType.cardTitle(size: 22, color: AppColors.cinza900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.cinza50, borderRadius: BorderRadius.circular(6)),
                child: Text('até 30/06', style: AppType.strong(size: 10.5, color: AppColors.cinza700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Motivo: ',
                  style: AppType.strong(size: 12, color: AppColors.cinza800),
                ),
                const TextSpan(text: 'a frente fria aumentou o número de acolhidos.'),
              ],
            ),
            style: AppType.body(size: 12, color: AppColors.cinza600).copyWith(height: 1.35),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(end: active ? raised.toDouble() : 0),
            duration: const Duration(milliseconds: 900),
            curve: AppMotion.smooth,
            builder: (context, v, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_money(v.round()), style: AppType.cardTitle(size: 18, color: AppColors.terracota600)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        'de ${_money(_goal)}',
                        style: AppType.body(size: 12, color: AppColors.cinza500).copyWith(height: 1),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'faltam ${_money(_goal - v.round())}',
                      style: AppType.strong(size: 10.5, color: AppColors.cinza700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v / _goal,
                    minHeight: 8,
                    color: AppColors.terracota600,
                    backgroundColor: AppColors.cinza100,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.petroleo50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const SvgIcon(Ic.money, size: 16, color: AppColors.petroleo600),
                const SizedBox(width: 8),
                Text(
                  'Pix direto para a instituição, sem taxa',
                  style: AppType.label(size: 11.5, color: AppColors.petroleo700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ana enviou R$ 30 via Pix" notification under the card.
class _GiftToast extends StatelessWidget {
  const _GiftToast(this.gift);

  final _Gift gift;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .12), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.terracota100, shape: BoxShape.circle),
            child: Text(gift.name[0], style: AppType.strong(size: 12, color: AppColors.terracota700)),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: gift.name,
                  style: AppType.strong(size: 12, color: AppColors.cinza900),
                ),
                TextSpan(text: ' enviou ${_money(gift.amount)} via Pix'),
              ],
            ),
            style: AppType.body(size: 12, color: AppColors.cinza700).copyWith(height: 1),
          ),
          const SizedBox(width: 6),
          Text('agora', style: AppType.body(size: 10.5, color: AppColors.cinza400).copyWith(height: 1)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 157.3,
      height: 66.6,
      child: Stack(
        children: [
          const SvgIcon(Shapes.badge, width: 156, height: 66.6),
          Positioned(
            left: 0,
            right: 0,
            top: 11,
            child: Column(
              children: [
                Text(
                  'Ajude do seu modo',
                  textAlign: TextAlign.center,
                  style: AppType.strong(color: AppColors.white, size: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  'Envie um valor que\ncabe no seu bolso',
                  textAlign: TextAlign.center,
                  style: AppType.body(color: AppColors.white.withValues(alpha: .85), size: 10).copyWith(height: 1.05),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
