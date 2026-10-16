import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models.dart';
import '../shared/help_ui.dart';

/// "Lembrete da meta" at the top of the help flows.
class GoalReminder extends StatelessWidget {
  const GoalReminder({super.key, required this.text, required this.type});

  final String text;
  final HelpType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cinza200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: type.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(type.iconFill, size: 19, color: type.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppType.body(size: 14.5, color: AppColors.cinza700)),
          ),
        ],
      ),
    );
  }
}
