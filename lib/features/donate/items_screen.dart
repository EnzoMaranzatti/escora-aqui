import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../shared/fields.dart';
import 'goal_reminder.dart';
import 'registered_screen.dart';

/// Levar itens: the person commits to bringing items, so the institution
/// can organize itself.
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, required this.placeId, required this.goalId});

  final String placeId;
  final String goalId;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late final Place _p = store.place(widget.placeId);
  late final Goal _g = store.goal(_p, widget.goalId)!;
  String _qty = '';
  DateTime? _date;
  bool _tried = false;

  String? get _qtyError => (int.tryParse(_qty.trim()) ?? 0) <= 0 ? 'Informe quantos você vai levar.' : null;

  String? get _dateError {
    final d = _date;
    if (d == null) return null;
    if (Fmt.dateOnly(d).isAfter(Fmt.dateOnly(_g.deadline))) {
      return 'O prazo desta meta é ${Fmt.day(_g.deadline)}. Escolha uma data até lá.';
    }
    if (!_p.receiveDays.contains(d.weekday)) {
      return 'A ${_p.name} recebe doações ${_p.hours}. Escolha um desses dias.';
    }
    return null;
  }

  Future<void> _pick() async {
    final today = Fmt.dateOnly(DateTime.now());
    final d = await pickDay(context, initial: _date, first: today, last: today.add(const Duration(days: 90)));
    if (d != null) setState(() => _date = d);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    if (_qtyError != null || _date == null || _dateError != null) return;
    final qty = double.parse(_qty.trim());
    store.registerItems(_p, _g, qty, _date!);
    HapticFeedback.mediumImpact();
    context.push(RegisteredScreen.items(place: _p, quantity: _g.amount(qty), date: _date!));
  }

  @override
  Widget build(BuildContext context) {
    final unit = _g.unit == 'unidades' ? _g.item : _g.unit;
    return FlowScaffold(
      title: 'O que você vai levar?',
      primary: 'Confirmar que vou levar',
      primaryIcon: null,
      onPrimary: _submit,
      secondary: 'Voltar',
      onSecondary: () => Navigator.pop(context),
      children: [
        GoalReminder(text: '${_g.headline}. Faltam ${_g.remaining}.', type: _g.type),
        const SizedBox(height: 22),
        AppTextField(
          label: 'Quantidade',
          hint: '0',
          help: 'Pode ser qualquer quantidade, não precisa completar a meta.',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
          error: _tried ? _qtyError : null,
          onChanged: (v) => setState(() => _qty = v),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(unit, style: AppType.body(size: 15)),
          ),
        ),
        const SizedBox(height: 18),
        PickerField(
          label: 'Quando você pretende levar?',
          hint: 'Escolha um dia',
          value: _date == null ? null : Fmt.weekdayDay(_date!),
          error: _dateError ?? (_tried && _date == null ? 'Escolha um dia' : null),
          onTap: _pick,
        ),
        const SizedBox(height: 22),
        NoticeBanner(
          tone: Tone.neutral,
          icon: PhosphorIconsRegular.mapPin,
          text: 'Entregar em: ${_p.address} · ${_p.hours}',
        ),
      ],
    );
  }
}
