import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../shared/fields.dart';
import '../shared/help_ui.dart';
import 'goal_flow.dart';

/// Tab "Metas": open, finished and closed goals of the point.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.myPoint!;
        final open = p.goals.where((g) => g.status == GoalStatus.open || g.status == GoalStatus.expired).toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final done = p.goals.where((g) => g.status == GoalStatus.done).toList();
        final closed = p.goals.where((g) => g.status == GoalStatus.closed).toList();
        final list = [open, done, closed][_tab];
        final empty = ['Nenhuma meta aberta.', 'Nenhuma meta concluída ainda.', 'Nenhuma meta encerrada.'][_tab];
        return TabPage(
          title: 'Metas',
          trailing: SoftButton(
            label: 'Criar meta',
            icon: PhosphorIconsBold.plus,
            filled: true,
            height: 40,
            onTap: () => context.push(const GoalFlow()),
          ),
          top: Segmented(
            items: const ['Abertas', 'Concluídas', 'Encerradas'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          slivers: [
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: EmptyState(
                    compact: true,
                    icon: PhosphorIconsRegular.target,
                    title: empty,
                    primary: _tab == 0 ? 'Criar meta' : null,
                    onPrimary: () => context.push(const GoalFlow()),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = list[i];
                    if (g.status == GoalStatus.expired) return ExpiredGoalCard(goal: g);
                    return _GoalTile(goal: g);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final Goal goal;

  Future<void> _close(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: 'Encerrar a meta "${goal.headline}"?',
      text: 'Ela sai do mapa e não recebe mais doações. As doações já confirmadas continuam no histórico.',
      confirm: 'Encerrar meta',
      cancel: 'Manter meta',
      destructive: true,
    );
    if (ok != null) store.closeGoal(goal);
  }

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final open = g.status == GoalStatus.open;
    final volunteer = g.type == HelpType.voluntariado;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeTag(g.type),
              const SizedBox(width: 8),
              if (!g.published) const StatusTag('Salva', tone: Tone.neutral),
              const Spacer(),
              if (g.status == GoalStatus.done)
                StatusTag('Meta concluída em ${Fmt.day(g.doneAt ?? g.deadline)}', tone: Tone.success),
              if (g.status == GoalStatus.closed)
                StatusTag('Encerrada em ${Fmt.day(g.doneAt ?? g.deadline)}', tone: Tone.neutral),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            volunteer ? '${g.action!.name} · ${g.action!.when}' : g.headline,
            style: AppType.cardTitle(size: 18, color: AppColors.cinza900).copyWith(height: 1.25, fontFeatures: tabular),
          ),
          const SizedBox(height: 4),
          Text('Motivo: ${g.reason}', style: AppType.body(size: 14.5)),
          const SizedBox(height: 12),
          GoalBar(value: volunteer ? (g.enrolled / g.target).clamp(0, 1) : g.progress, color: g.type.color),
          const SizedBox(height: 6),
          Text(
            volunteer ? '${g.enrolled} de ${g.target.round()} vagas preenchidas' : g.progressLabel,
            style: AppType.body(size: 13.5).copyWith(fontFeatures: tabular),
          ),
          if (open) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SoftButton(
                    label: 'Editar',
                    icon: PhosphorIconsRegular.pencilSimple,
                    expand: true,
                    onTap: () => showEditGoal(context, g),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton(
                    label: 'Encerrar',
                    icon: PhosphorIconsRegular.stopCircle,
                    expand: true,
                    onTap: () => _close(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _goalName(Goal g) => switch (g.type) {
  HelpType.pix => g.quantity,
  HelpType.itens => g.item,
  HelpType.voluntariado => g.action?.name ?? 'voluntários',
};

/// "Prazo encerrado": give more time or close.
class ExpiredGoalCard extends StatelessWidget {
  const ExpiredGoalCard({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return AppCard(
      color: AppColors.ocre50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.hourglassLow, size: 20, color: AppColors.ocre700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'O prazo da meta de ${_goalName(g)} terminou.',
                  style: AppType.cardTitle(size: 17, color: AppColors.ocre800).copyWith(height: 1.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vocês arrecadaram ${g.progressLabel}. Quer dar mais tempo ou encerrar?',
            style: AppType.body(size: 14.5, color: AppColors.ocre800).copyWith(fontFeatures: tabular),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SoftButton(
                  label: 'Dar mais tempo',
                  filled: true,
                  expand: true,
                  onTap: () async {
                    final today = Fmt.dateOnly(DateTime.now());
                    final d = await pickDay(
                      context,
                      first: today.add(const Duration(days: 1)),
                      last: today.add(const Duration(days: 180)),
                    );
                    if (d != null) store.extendGoal(g, d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftButton(label: 'Encerrar meta', expand: true, onTap: () => store.closeGoal(g)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Meta concluída" notice for the institution.
class DoneGoalCard extends StatelessWidget {
  const DoneGoalCard({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return AppCard(
      color: AppColors.sucessoFundo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.checkCircle, size: 20, color: AppColors.sucessoBase),
              const SizedBox(width: 8),
              Text('Meta concluída.', style: AppType.cardTitle(size: 17, color: AppColors.sucessoTexto)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${g.quantity} arrecadados, com a ajuda de ${g.helpers} ${g.helpers == 1 ? 'pessoa' : 'pessoas'}. Quem doou recebe um aviso.',
            style: AppType.body(size: 14.5, color: AppColors.sucessoTexto),
          ),
          const SizedBox(height: 14),
          SoftButton(
            label: 'Criar nova meta',
            filled: true,
            color: AppColors.sucessoBase,
            onTap: () {
              store.markGoalSeen(g);
              context.push(const GoalFlow());
            },
          ),
        ],
      ),
    );
  }
}

/// Edit a goal. After the first confirmed donation only the deadline and
/// the reason can change: the value is locked.
Future<void> showEditGoal(BuildContext context, Goal g) =>
    showAppSheet<void>(context, builder: (_) => _EditGoal(goal: g));

class _EditGoal extends StatefulWidget {
  const _EditGoal({required this.goal});

  final Goal goal;

  @override
  State<_EditGoal> createState() => _EditGoalState();
}

class _EditGoalState extends State<_EditGoal> {
  late String _value = Fmt.count(widget.goal.target).replaceAll('.', '');
  late DateTime _deadline = widget.goal.deadline;
  late String _reason = widget.goal.reason;
  bool _tried = false;

  String? get _reasonError => _reason.trim().length < 20
      ? 'Conte o motivo com pelo menos 20 caracteres. É ele que ajuda o doador a decidir.'
      : null;

  String? get _valueError => (double.tryParse(_value.replaceAll(',', '.')) ?? 0) <= 0
      ? switch (widget.goal.type) {
          HelpType.pix => 'Informe o valor da meta.',
          HelpType.itens => 'Informe quantos vocês precisam.',
          HelpType.voluntariado => 'Informe quantos voluntários vocês precisam.',
        }
      : null;

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final locked = g.valueLocked;
    final label = switch (g.type) {
      HelpType.pix => 'Valor da meta',
      HelpType.itens => 'Quantidade',
      HelpType.voluntariado => 'Vagas',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Editar meta', style: AppType.title().copyWith(fontSize: 22)),
        const SizedBox(height: 18),
        AppTextField(
          label: label,
          hint: g.type == HelpType.pix ? 'R\$ 0,00' : '0',
          initialValue: _value,
          enabled: !locked,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
          help: locked ? 'Esta meta já recebeu doações, então o valor não pode mais ser alterado.' : null,
          error: _tried && !locked ? _valueError : null,
          onChanged: (v) => setState(() => _value = v),
        ),
        const SizedBox(height: 16),
        PickerField(
          label: 'Até quando?',
          hint: 'Escolha um dia',
          value: Fmt.weekdayDay(_deadline),
          onTap: () async {
            final today = Fmt.dateOnly(DateTime.now());
            final d = await pickDay(
              context,
              initial: _deadline.isAfter(today) ? _deadline : null,
              first: today.add(const Duration(days: 1)),
              last: today.add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _deadline = d);
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Motivo',
          hint: 'Ex.: a frente fria aumentou o número de acolhidos.',
          initialValue: _reason,
          maxLines: 3,
          minLines: 2,
          maxLength: 160,
          capitalization: TextCapitalization.sentences,
          help:
              'Seja específico: o que mudou, quem será atendido ou o que vai ser comprado. Entre 20 e 160 caracteres.',
          error: _tried ? _reasonError : null,
          onChanged: (v) => setState(() => _reason = v),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Salvar alterações',
          icon: null,
          onPressed: () {
            setState(() => _tried = true);
            if (_reasonError != null || (!locked && _valueError != null)) return;
            if (!locked) g.target = double.parse(_value.replaceAll(',', '.'));
            g.deadline = _deadline;
            if (g.action != null) g.action!.day = _deadline;
            g.reason = _reason.trim();
            store.touch();
            Toast.show(context, 'Alterações salvas.');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
