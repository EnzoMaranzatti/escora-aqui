import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../place/place_screen.dart';
import '../shared/fields.dart';
import '../shared/help_ui.dart';

/// Goal being written across the four steps.
class _Draft {
  HelpType? type;
  String value = '';
  String item = '';
  String qty = '';
  String unit = 'unidades';
  String action = '';
  String task = '';
  DateTime? day;
  TimeOfDay? start;
  TimeOfDay? end;
  String slots = '';
  String? cause;
  DateTime? deadline;
  String reason = '';

  double get target => switch (type!) {
    HelpType.pix => Fmt.parseMoney(value) ?? 0,
    HelpType.itens => double.tryParse(qty) ?? 0,
    HelpType.voluntariado => double.tryParse(slots) ?? 0,
  };

  Goal build(Place p) {
    final when = type == HelpType.voluntariado ? day! : deadline!;
    return Goal(
      id: store.nextId('g'),
      type: type!,
      target: target,
      item: item.trim(),
      unit: unit,
      deadline: when,
      reason: _sentence(reason.trim()),
      cause: cause,
      published: p.status == PlaceStatus.active,
      action: type == HelpType.voluntariado
          ? VolunteerAction(
              name: action.trim(),
              task: task.trim(),
              day: day!,
              start: start!.hour * 60 + start!.minute,
              end: end!.hour * 60 + end!.minute,
            )
          : null,
    );
  }

  /// The card prints "Motivo: {motivo}", so the reason starts lowercase
  /// and ends with a period.
  static String _sentence(String s) {
    if (s.isEmpty) return s;
    var t = s[0].toLowerCase() + s.substring(1);
    if (!t.endsWith('.')) t = '$t.';
    return t;
  }
}

/// Criar meta, passo 1: type.
class GoalFlow extends StatefulWidget {
  const GoalFlow({super.key});

  @override
  State<GoalFlow> createState() => _GoalFlowState();
}

class _GoalFlowState extends State<GoalFlow> {
  final _d = _Draft();

  @override
  Widget build(BuildContext context) {
    final p = store.myPoint!;
    final options = [
      if (p.pixKey != null && !p.pixPaused) (HelpType.pix, 'Dinheiro (Pix)', 'para comprar, pagar ou consertar algo.'),
      (HelpType.itens, 'Itens', 'alimentos, roupas, materiais e outros.'),
      (HelpType.voluntariado, 'Voluntários', 'pessoas para uma ação com dia e hora.'),
    ];
    return FlowScaffold(
      step: 1,
      steps: 4,
      title: 'Que tipo de ajuda vocês precisam?',
      primary: 'Continuar',
      onPrimary: _d.type == null ? null : () => context.push(_Details(d: _d)),
      children: [
        for (final (t, title, desc) in options) ...[
          OptionTile(
            title: title,
            subtitle: desc[0].toUpperCase() + desc.substring(1),
            icon: t.icon,
            iconColor: t.color,
            selected: _d.type == t,
            onTap: () => setState(() => _d.type = t),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ── Passo 2 — Detalhes ──────────────────────────────────────
class _Details extends StatefulWidget {
  const _Details({required this.d});

  final _Draft d;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  _Draft get d => widget.d;
  bool _tried = false;

  Map<String, String?> get _errors => {
    'value': d.type == HelpType.pix && d.target <= 0 ? 'Informe o valor da meta.' : null,
    'item': d.type == HelpType.itens && d.item.trim().isEmpty ? 'Preencha este campo para continuar.' : null,
    'qty': d.type == HelpType.itens && d.target <= 0 ? 'Informe quantos vocês precisam.' : null,
    'action': d.type == HelpType.voluntariado && d.action.trim().isEmpty ? 'Preencha este campo para continuar.' : null,
    'task': d.type == HelpType.voluntariado && d.task.trim().isEmpty ? 'Preencha este campo para continuar.' : null,
    'day': d.type == HelpType.voluntariado && (d.day == null || d.start == null || d.end == null)
        ? 'Escolha o dia e o horário.'
        : null,
    'slots': d.type == HelpType.voluntariado && d.target <= 0 ? 'Informe quantos voluntários vocês precisam.' : null,
    'cause': d.cause == null ? 'Escolha uma causa.' : null,
    'deadline': d.type != HelpType.voluntariado && d.deadline == null ? 'Escolha uma data a partir de amanhã.' : null,
  };

  String? _e(String k) => _tried ? _errors[k] : null;

  Future<void> _pickDeadline() async {
    final today = Fmt.dateOnly(DateTime.now());
    final r = await pickDay(
      context,
      initial: d.deadline,
      first: today.add(const Duration(days: 1)),
      last: today.add(const Duration(days: 365)),
    );
    if (r != null) setState(() => d.deadline = r);
  }

  Future<void> _pickSchedule() async {
    final today = Fmt.dateOnly(DateTime.now());
    final day = await pickDay(
      context,
      initial: d.day,
      first: today.add(const Duration(days: 1)),
      last: today.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return;
    final start = await pickTime(context, initial: d.start ?? const TimeOfDay(hour: 9, minute: 0));
    if (start == null || !mounted) return;
    final end = await pickTime(
      context,
      initial: d.end ?? TimeOfDay(hour: (start.hour + 3).clamp(0, 23), minute: start.minute),
    );
    if (end == null) return;
    setState(() {
      d.day = day;
      d.start = start;
      d.end = end;
    });
  }

  String? get _schedule {
    if (d.day == null || d.start == null || d.end == null) return null;
    final s = d.start!.hour * 60 + d.start!.minute;
    final e = d.end!.hour * 60 + d.end!.minute;
    return '${Fmt.weekdayDay(d.day!)}, das ${Fmt.hour(s)} às ${Fmt.hour(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (d.type!) {
      HelpType.pix => 'Quanto vocês precisam?',
      HelpType.itens => 'O que vocês precisam?',
      HelpType.voluntariado => 'Qual é a ação?',
    };
    return FlowScaffold(
      step: 2,
      steps: 4,
      title: title,
      primary: 'Continuar',
      onPrimary: () {
        FocusScope.of(context).unfocus();
        setState(() => _tried = true);
        if (_errors.values.any((e) => e != null)) return;
        context.push(_Reason(d: d));
      },
      children: [
        ...switch (d.type!) {
          HelpType.pix => [
            AppTextField(
              label: 'Valor da meta',
              hint: 'R\$ 0,00',
              initialValue: d.value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              error: _e('value'),
              onChanged: (v) => setState(() => d.value = v),
            ),
          ],
          HelpType.itens => [
            AppTextField(
              label: 'Item',
              hint: 'Ex.: cobertores',
              initialValue: d.item,
              error: _e('item'),
              onChanged: (v) => setState(() => d.item = v),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Quantidade',
              hint: '0',
              initialValue: d.qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              error: _e('qty'),
              onChanged: (v) => setState(() => d.qty = v),
            ),
            const SizedBox(height: 16),
            Text('Unidade', style: AppType.label(size: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final u in itemUnits)
                  ChoiceChipPill(label: u, selected: d.unit == u, onTap: () => setState(() => d.unit = u)),
              ],
            ),
          ],
          HelpType.voluntariado => [
            AppTextField(
              label: 'Nome da ação',
              hint: 'Ex.: separar doações',
              initialValue: d.action,
              capitalization: TextCapitalization.sentences,
              error: _e('action'),
              onChanged: (v) => setState(() => d.action = v),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'O que os voluntários vão fazer',
              hint: '',
              initialValue: d.task,
              maxLines: 3,
              minLines: 2,
              capitalization: TextCapitalization.sentences,
              error: _e('task'),
              onChanged: (v) => setState(() => d.task = v),
            ),
            const SizedBox(height: 16),
            PickerField(
              label: 'Dia e horário',
              hint: 'Escolha um dia',
              value: _schedule,
              error: _e('day'),
              onTap: _pickSchedule,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Vagas',
              hint: '0',
              initialValue: d.slots,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              error: _e('slots'),
              onChanged: (v) => setState(() => d.slots = v),
            ),
          ],
        },
        const SizedBox(height: 22),
        Text('Qual causa esta meta atende?', style: AppType.label(size: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in causes)
              ChoiceChipPill(label: c, selected: d.cause == c, onTap: () => setState(() => d.cause = c)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _e('cause') ?? 'Quem acompanha essa causa perto de vocês recebe um aviso.',
          style: AppType.body(size: 13, color: _e('cause') != null ? AppColors.erroTexto : AppColors.cinza600),
        ),
        if (d.type != HelpType.voluntariado) ...[
          const SizedBox(height: 22),
          PickerField(
            label: 'Até quando?',
            hint: 'Escolha um dia',
            value: d.deadline == null ? null : Fmt.weekdayDay(d.deadline!),
            help: 'Escolha uma data real. Metas sem urgência podem ter prazo mais longo.',
            error: _e('deadline'),
            onTap: _pickDeadline,
          ),
        ],
      ],
    );
  }
}

// ── Passo 3 — Motivo ────────────────────────────────────────
class _Reason extends StatefulWidget {
  const _Reason({required this.d});

  final _Draft d;

  @override
  State<_Reason> createState() => _ReasonState();
}

class _ReasonState extends State<_Reason> {
  bool _tried = false;

  bool get _ok => widget.d.reason.trim().length >= 20;

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      step: 3,
      steps: 4,
      title: 'Por que vocês precisam disso agora?',
      subtitle: 'O motivo aparece para todos, junto da meta. Quem doa quer entender para que serve.',
      primary: 'Ver como fica',
      onPrimary: () {
        FocusScope.of(context).unfocus();
        setState(() => _tried = true);
        if (_ok) context.push(_Preview(d: widget.d));
      },
      children: [
        AppTextField(
          label: 'Motivo',
          hint: 'Ex.: a frente fria aumentou o número de acolhidos.',
          initialValue: widget.d.reason,
          maxLines: 4,
          minLines: 3,
          maxLength: 160,
          autofocus: true,
          capitalization: TextCapitalization.sentences,
          help:
              'Seja específico: o que mudou, quem será atendido ou o que vai ser comprado. Entre 20 e 160 caracteres.',
          error: _tried && !_ok
              ? 'Conte o motivo com pelo menos 20 caracteres. É ele que ajuda o doador a decidir.'
              : null,
          onChanged: (v) => setState(() => widget.d.reason = v),
        ),
      ],
    );
  }
}

// ── Passo 4 — Prévia ────────────────────────────────────────
class _Preview extends StatelessWidget {
  const _Preview({required this.d});

  final _Draft d;

  @override
  Widget build(BuildContext context) {
    final p = store.myPoint!;
    final goal = d.build(p);
    final live = p.status == PlaceStatus.active;
    return FlowScaffold(
      step: 4,
      steps: 4,
      title: 'Assim a meta aparece no app',
      background: AppColors.cinza50,
      primary: live ? 'Publicar meta' : 'Salvar meta',
      primaryIcon: null,
      onPrimary: () {
        store.addGoal(p, goal);
        HapticFeedback.mediumImpact();
        if (live) {
          Toast.show(
            context,
            'Meta publicada. Quem acompanha ${goal.cause} perto de vocês vai receber um aviso.',
            duration: const Duration(seconds: 4),
          );
        }
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
      secondary: 'Editar',
      onSecondary: () {
        var n = 0;
        Navigator.of(context).popUntil((_) => n++ == 2);
      },
      children: [
        IgnorePointer(
          child: GoalCard(place: p, goal: goal),
        ),
        if (!live) ...[
          const SizedBox(height: 14),
          const NoticeBanner(
            tone: Tone.info,
            icon: PhosphorIconsRegular.hourglassMedium,
            text: 'A meta fica salva e aparece no mapa quando o ponto for aprovado.',
          ),
        ],
      ],
    );
  }
}

/// Opens the public profile as donors see it.
void previewPoint(BuildContext context) => context.push(PlaceScreen(placeId: store.myPoint!.id, preview: true));
