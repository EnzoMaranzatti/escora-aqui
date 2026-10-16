import 'package:flutter/services.dart';

/// Formatting helpers in pt-BR, kept dependency-free on purpose.
abstract final class Fmt {
  static const _weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  static const _weekdaysShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  static const _months = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// R$ 1.250,00 — or R$ 1.250 when [cents] is false and the value is round.
  static String money(double v, {bool cents = true}) {
    final whole = v.truncate();
    final frac = ((v - whole) * 100).round();
    final grouped = _group(whole);
    if (!cents && frac == 0) return 'R\$ $grouped';
    return 'R\$ $grouped,${frac.toString().padLeft(2, '0')}';
  }

  static String _group(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Integer with thousand dots ("1.200").
  static String count(num n) => _group(n.round());

  /// "30/06"
  static String day(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

  /// "30/06/2026"
  static String date(DateTime d) => '${day(d)}/${d.year}';

  /// "sábado, 18/10"
  static String weekdayDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${day(d)}';

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

  /// "15 de outubro"
  static String longDay(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

  /// "outubro".
  static String month(DateTime d) => _months[d.month - 1];

  /// "9h" / "14h30"
  static String hour(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${_two(m)}';
  }

  /// "há 2 dias", "há 3 horas", "agora"
  static String ago(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inDays >= 1) return diff.inDays == 1 ? '1 dia' : '${diff.inDays} dias';
    if (diff.inHours >= 1) return diff.inHours == 1 ? '1 hora' : '${diff.inHours} horas';
    if (diff.inMinutes >= 1) return diff.inMinutes == 1 ? '1 minuto' : '${diff.inMinutes} minutos';
    return 'instantes';
  }

  /// "850 m" / "1,2 km"
  static String km(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Parses "1.250,50", "50", "50,5" into a double; null when invalid.
  static double? parseMoney(String s) {
    final t = s.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d{1,3}(\.\d{3})*(,\d{1,2})?$|^\d+(,\d{1,2})?$').hasMatch(t)) return null;
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  }

  static String digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Lowercase without accents, for search.
  static String fold(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Applies a digit pattern such as "(##) #####-####" while typing.
class MaskFormatter extends TextInputFormatter {
  MaskFormatter(this.mask, {this.altMask, this.altAt});

  final String mask;

  /// Used when the number of digits reaches [altAt] (phones with 9 digits).
  final String? altMask;
  final int? altAt;

  int get maxDigits => '#'.allMatches(altMask ?? mask).length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = Fmt.digits(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final pattern = altMask != null && altAt != null && digits.length >= altAt! ? altMask! : mask;
    final b = StringBuffer();
    var i = 0;
    for (final ch in pattern.split('')) {
      if (i >= digits.length) break;
      if (ch == '#') {
        b.write(digits[i++]);
      } else {
        b.write(ch);
      }
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static MaskFormatter phone() => MaskFormatter('(##) ####-####', altMask: '(##) #####-####', altAt: 11);
  static MaskFormatter cnpj() => MaskFormatter('##.###.###/####-##');
  static MaskFormatter cep() => MaskFormatter('#####-###');
}

/// Money typed as cents: "5" → "0,05", "5000" → "50,00".
class MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = Fmt.digits(newValue.text);
    if (digits.length > 9) digits = digits.substring(0, 9);
    if (digits.isEmpty) return const TextEditingValue();
    final v = int.parse(digits) / 100;
    final text = Fmt.money(v).replaceFirst('R\$ ', '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
