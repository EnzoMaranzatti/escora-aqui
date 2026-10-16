import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/pressable.dart';

/// Field that opens a picker (date, time, list), drawn like AppTextField.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    this.error,
    this.help,
    this.icon = PhosphorIconsRegular.calendarBlank,
  });

  final String label;
  final String hint;
  final String? value;
  final VoidCallback onTap;
  final String? error;
  final String? help;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final note = error ?? help;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label(size: 14)),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: '$label, ${value ?? hint}',
          excludeSemantics: true,
          child: Pressable(
            onTap: onTap,
            scale: .99,
            child: AnimatedContainer(
              duration: AppMotion.medium,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cinza50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: error != null ? AppColors.erroBase : AppColors.cinza200,
                  width: error != null ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? hint,
                      style: AppType.body(color: value == null ? AppColors.cinza500 : AppColors.cinza900),
                    ),
                  ),
                  Icon(icon, size: 20, color: AppColors.cinza600),
                ],
              ),
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note, style: AppType.body(size: 13, color: error != null ? AppColors.erroTexto : AppColors.cinza600)),
        ],
      ],
    );
  }
}

Theme _pickerTheme(BuildContext context, Widget? child) => Theme(
  data: Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.petroleo600,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.cinza900,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.white,
      headerBackgroundColor: AppColors.petroleo600,
      headerForegroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      todayBorder: const BorderSide(color: AppColors.petroleo400),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      dialHandColor: AppColors.petroleo600,
      hourMinuteColor: AppColors.petroleo50,
    ),
  ),
  child: child!,
);

Future<DateTime?> pickDay(BuildContext context, {DateTime? initial, required DateTime first, required DateTime last}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? first,
    firstDate: first,
    lastDate: last,
    locale: const Locale('pt', 'BR'),
    builder: _pickerTheme,
  );
}

Future<TimeOfDay?> pickTime(BuildContext context, {TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0)}) {
  return showTimePicker(context: context, initialTime: initial, builder: _pickerTheme);
}
