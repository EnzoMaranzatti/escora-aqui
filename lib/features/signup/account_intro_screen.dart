import 'package:flutter/material.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/ripple_backdrop.dart';
import '../../core/widgets/svg_icon.dart';
import '../map/pins.dart';
import '../onboarding/onboarding_state.dart';
import 'create_account_screen.dart';
import 'step_scaffold.dart';

/// Step 5 of 5, entry. Closes the flow by handing back what the person
/// picked (city, ways to help, causes, alerts) in one summary card, each
/// line ticking in, then asks for the account that will keep it all.
class AccountIntroScreen extends StatelessWidget {
  const AccountIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      step: 5,
      centered: true,
      backdrop: const RippleBackdrop(),
      hero: const _Summary(),
      title: 'Salve suas escolhas.',
      subtitle: 'Crie sua conta para guardar sua cidade, suas causas e seus avisos.',
      primaryLabel: 'Criar conta',
      onPrimary: () => context.push(const CreateAccountScreen()),
      footer: GhostButton(
        label: 'Continuar com Google',
        icon: Ic.google,
        iconSize: 16,
        onPressed: () => context.push(const CreateAccountScreen(withGoogle: true)),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final city = onboarding.city;
    final causes = onboarding.selectedCauses.toList();
    final rows = [
      (Ic.mapPin, 'Cidade', city == null ? null : [onboarding.uf == null ? city : '$city, ${onboarding.uf}']),
      (
        Ic.handsHeart,
        'Como ajudar',
        onboarding.helpTypes.isEmpty ? null : [for (final t in onboarding.helpTypes) t.label],
      ),
      (
        Ic.starOutline,
        'Causas',
        causes.isEmpty ? null : [...causes.take(2), if (causes.length > 2) '+${causes.length - 2}'],
      ),
      (Ic.bell, 'Avisos de metas novas', onboarding.notifications ? ['Ativados'] : null),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cinza100),
        boxShadow: [
          BoxShadow(color: AppColors.cinza900.withValues(alpha: .08), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          for (final (i, (icon, label, values)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.cinza50),
            Reveal(
              delay: Duration(milliseconds: 200 + 140 * i),
              child: _Row(
                icon: icon,
                label: label,
                values: values,
                delay: Duration(milliseconds: 420 + 140 * i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One choice: icon, label, the picked values as chips, and a check that
/// pops in when something was chosen ("escolha depois" otherwise).
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.values, required this.delay});

  final String icon;
  final String label;
  final List<String>? values;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final done = values != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.petroleo50 : AppColors.cinza50,
              borderRadius: BorderRadius.circular(11),
            ),
            child: SvgIcon(icon, size: 18, color: done ? AppColors.petroleo600 : AppColors.cinza400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body(size: 12, color: AppColors.cinza500).copyWith(height: 1.2)),
                const SizedBox(height: 4),
                if (values case final v?)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final value in v)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.cinza50, borderRadius: BorderRadius.circular(6)),
                          child: Text(value, style: AppType.label(size: 12.5, color: AppColors.cinza800)),
                        ),
                    ],
                  )
                else
                  Text(
                    'Você escolhe depois',
                    style: AppType.label(size: 13, color: AppColors.cinza400).copyWith(height: 1.3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            PopIn(
              delay: delay,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.petroleo600, shape: BoxShape.circle),
                child: const SvgIcon(Ic.checkWhite, size: 12),
              ),
            )
          else
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cinza200, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
