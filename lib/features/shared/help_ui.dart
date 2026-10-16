import 'package:flutter/widgets.dart';
import '../../core/icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models.dart';

export '../map/pins.dart' show HelpTypeStyle;

/// Icon and text colors per help type (style guide: Pix = moedas,
/// itens = pacote, voluntariado = grupo de pessoas; color + icon always).
extension HelpTypeUi on HelpType {
  IconData get icon => switch (this) {
    HelpType.pix => PhosphorIconsRegular.coins,
    HelpType.itens => PhosphorIconsRegular.package,
    HelpType.voluntariado => PhosphorIconsRegular.usersThree,
  };

  IconData get iconFill => switch (this) {
    HelpType.pix => PhosphorIconsFill.coins,
    HelpType.itens => PhosphorIconsFill.package,
    HelpType.voluntariado => PhosphorIconsFill.usersThree,
  };

  /// Text on the 50 tint of the type.
  Color get ink => switch (this) {
    HelpType.pix => AppColors.petroleo800,
    HelpType.itens => AppColors.terracota700,
    HelpType.voluntariado => AppColors.ocre800,
  };

  /// Help button on the point's profile.
  String get action => switch (this) {
    HelpType.pix => 'Doar via Pix',
    HelpType.itens => 'Quero levar',
    HelpType.voluntariado => 'Quero participar',
  };
}

/// Small tag with the type's icon and name ("Itens").
class TypeTag extends StatelessWidget {
  const TypeTag(this.type, {super.key});

  final HelpType type;

  @override
  Widget build(BuildContext context) {
    final tint = switch (type) {
      HelpType.pix => AppColors.petroleo50,
      HelpType.itens => AppColors.terracota50,
      HelpType.voluntariado => AppColors.ocre50,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.iconFill, size: 13, color: type.ink),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: AppType.label(color: type.ink, size: 12.5).copyWith(height: 1.1, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
