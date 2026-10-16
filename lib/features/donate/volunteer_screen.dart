import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import 'registered_screen.dart';

/// Voluntariado: details of an action with day and time, then enrollment.
class VolunteerScreen extends StatelessWidget {
  const VolunteerScreen({super.key, required this.placeId, required this.goalId});

  final String placeId;
  final String goalId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.place(placeId);
        final g = store.goal(p, goalId)!;
        final a = g.action!;
        final full = g.slotsLeft == 0;
        final following = store.followed.contains(p.id);
        return FlowScaffold(
          title: a.name,
          subtitle: p.name,
          primary: full ? (following ? null : 'Acompanhar este ponto') : 'Quero participar',
          primaryIcon: null,
          onPrimary: () {
            if (full) {
              store.follow(p.id);
              Toast.show(context, 'Pronto. Você vai receber um aviso quando ${p.name} abrir uma meta.');
              return;
            }
            store.enroll(p, g);
            HapticFeedback.mediumImpact();
            context.push(RegisteredScreen.volunteer(place: p, when: '${Fmt.weekdayDay(a.day)}, ${a.hours}'));
          },
          secondary: 'Voltar',
          onSecondary: () => Navigator.pop(context),
          children: [
            AppCard(
              child: Column(
                children: [
                  _Row(icon: PhosphorIconsRegular.calendarBlank, label: 'Quando', value: a.when),
                  const Hairline(indent: 32),
                  _Row(icon: PhosphorIconsRegular.mapPin, label: 'Onde', value: p.address),
                  const Hairline(indent: 32),
                  _Row(icon: PhosphorIconsRegular.handshake, label: 'O que você vai fazer', value: a.task),
                  const Hairline(indent: 32),
                  _Row(
                    icon: PhosphorIconsRegular.info,
                    label: 'Motivo',
                    value: g.reason[0].toUpperCase() + g.reason.substring(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GoalBar(value: (g.enrolled / g.target).clamp(0, 1), color: AppColors.ocre600),
                ),
                const SizedBox(width: 12),
                Text(
                  '${g.slotsLeft} de ${g.target.round()} vagas disponíveis',
                  style: AppType.label(size: 14).copyWith(fontFeatures: tabular),
                ),
              ],
            ),
            if (full) ...[
              const SizedBox(height: 18),
              NoticeBanner(
                tone: Tone.alert,
                icon: PhosphorIconsRegular.usersThree,
                title: 'As vagas desta ação acabaram.',
                text: 'Quer ser avisado quando ${p.name} abrir outra ação?',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.ocre600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.body(size: 13)),
                const SizedBox(height: 2),
                Text(value, style: AppType.label(color: AppColors.cinza900, size: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
