import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'catalog_screen.dart';
import 'level_medal.dart';

/// Shown once, when the database says the person reached a new level.
///
/// The style guide vetoes confetti and loud celebrations, and the person
/// agreed to keep it that way: the moment is marked with the level's own
/// medal arriving with a fade and a short rise, in the same motion the
/// confirmations use. Nothing loops and nothing bounces.
Future<void> showLevelUp(BuildContext context, PointsLevel level) {
  return showAppSheet(context, builder: (_) => _LevelUpBody(level: level));
}

class _LevelUpBody extends StatefulWidget {
  const _LevelUpBody({required this.level});

  final PointsLevel level;

  @override
  State<_LevelUpBody> createState() => _LevelUpBodyState();
}

class _LevelUpBodyState extends State<_LevelUpBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// How many coupons this level has just opened.
  int get _unlocked => store.catalog.where((i) => i.minLevel == widget.level).length;

  @override
  Widget build(BuildContext context) {
    final n = _unlocked;
    final curva = CurvedAnimation(parent: _c, curve: AppMotion.smooth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: FadeTransition(
            opacity: curva,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .22), end: Offset.zero).animate(curva),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: AppColors.petroleo50, shape: BoxShape.circle),
                child: LevelMedal(level: widget.level, size: 96),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Você chegou ao ${widget.level.label}.',
          textAlign: TextAlign.center,
          style: AppType.title().copyWith(fontSize: 23, height: 1.25),
        ),
        const SizedBox(height: 10),
        Text(
          n == 0
              ? 'O nível fica guardado na sua conta e conta a história do que você já ajudou a fazer.'
              : n == 1
              ? 'Um cupom novo do catálogo abriu para você.'
              : '$n cupons novos do catálogo abriram para você.',
          textAlign: TextAlign.center,
          style: AppType.body(size: 15.5),
        ),
        const SizedBox(height: 22),
        if (n > 0) ...[
          PrimaryButton(
            label: 'Ver os cupons',
            onPressed: () {
              Navigator.of(context).pop();
              context.push(const CatalogScreen());
            },
          ),
          const SizedBox(height: 8),
          SoftButton(
            label: 'Deixar para depois',
            expand: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ] else
          PrimaryButton(label: 'Continuar', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
