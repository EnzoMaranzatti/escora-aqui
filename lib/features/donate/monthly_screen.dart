import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/store.dart';
import '../map/pins.dart';
import 'pix_screen.dart';
import 'registered_screen.dart';

const _days = [1, 5, 10, 15, 20, 25];
const _amounts = [20.0, 30.0, 50.0, 100.0];

/// Small header naming the point a flow is about.
class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlaceThumb(place: place, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                place.name,
                style: AppType.label(color: AppColors.cinza900, size: 15.5).copyWith(fontWeight: FontWeight.w600),
              ),
              Text('${place.typeLabel} · ${place.neighborhood}', style: AppType.body(size: 13.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Start (or change) a monthly Pix to one point: amount and reminder day.
class MonthlySetupScreen extends StatefulWidget {
  const MonthlySetupScreen({super.key, required this.placeId, this.edit, this.suggested});

  final String placeId;
  final MonthlyGift? edit;

  /// Prefills the amount (e.g. the Pix the person just registered).
  final double? suggested;

  @override
  State<MonthlySetupScreen> createState() => _MonthlySetupScreenState();
}

class _MonthlySetupScreenState extends State<MonthlySetupScreen> {
  late final _amount = TextEditingController(text: _initialAmount());
  late int _day = widget.edit?.day ?? _defaultDay();
  bool _tried = false;
  bool _loading = false;

  String _initialAmount() {
    final v = widget.edit?.amount ?? widget.suggested;
    return v == null ? '' : Fmt.money(v).replaceFirst('R\$ ', '');
  }

  /// Next listed day after today, so the first reminder isn't a month away.
  static int _defaultDay() {
    final today = DateTime.now().day;
    return _days.firstWhere((d) => d > today, orElse: () => _days.first);
  }

  double? get _value => Fmt.parseMoney(_amount.text.trim());

  String? get _error {
    final v = _value;
    if (v == null || v <= 0) return 'Informe quanto você quer doar por mês.';
    if (v < 1) return 'O valor mínimo é R\$ 1,00.';
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _pickAmount(double v) {
    HapticFeedback.selectionClick();
    setState(() => _amount.text = Fmt.money(v).replaceFirst('R\$ ', ''));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _tried = true);
    if (_error != null) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final p = store.place(widget.placeId);
    final edit = widget.edit;
    if (edit != null) {
      store.updateMonthly(edit, amount: _value!, day: _day);
    } else {
      store.startMonthly(p, _value!, _day);
    }
    HapticFeedback.mediumImpact();
    final next = (edit ?? store.monthlyFor(p.id))!.nextDate;
    Toast.show(
      context,
      edit != null
          ? 'Doação mensal atualizada.'
          : 'Doação mensal ativada. O primeiro lembrete chega em ${Fmt.longDay(next)}.',
      duration: const Duration(seconds: 4),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = store.place(widget.placeId);
    final editing = widget.edit != null;
    final v = _value;
    return FlowScaffold(
      header: _PlaceHeader(place: p),
      title: editing ? 'Alterar doação mensal' : 'Doar todo mês',
      subtitle: 'No dia escolhido, a gente te avisa. Você faz o Pix no app do seu banco, com o valor já pronto.',
      primary: editing ? 'Salvar' : 'Ativar doação mensal',
      primaryIcon: null,
      loading: _loading,
      onPrimary: _save,
      children: [
        AppTextField(
          label: 'Valor por mês',
          hint: 'R\$ 0,00',
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyFormatter()],
          error: _tried ? _error : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in _amounts)
              ChoiceChipPill(label: Fmt.money(a, cents: false), selected: v == a, onTap: () => _pickAmount(a)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Dia do lembrete', style: AppType.label(size: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _days)
              ChoiceChipPill(
                label: 'Dia $d',
                selected: _day == d,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _day = d);
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        const NoticeBanner(
          tone: Tone.info,
          icon: PhosphorIconsFill.shieldCheck,
          text:
              'O Escora aqui não debita nada da sua conta. O dinheiro vai direto para a instituição, e você pode pausar ou cancelar quando quiser, em Minhas doações.',
        ),
      ],
    );
  }
}

/// This month's Pix: amount ready, key to copy, then "Já fiz o Pix".
class MonthlyPayScreen extends StatefulWidget {
  const MonthlyPayScreen({super.key, required this.giftId});

  final String giftId;

  @override
  State<MonthlyPayScreen> createState() => _MonthlyPayScreenState();
}

class _MonthlyPayScreenState extends State<MonthlyPayScreen> {

  MonthlyGift? get _gift => store.monthly.where((m) => m.id == widget.giftId).firstOrNull;

  Future<void> _paid(MonthlyGift m) async {
    final p = store.place(m.placeId);
    store.payMonthly(m);
    context.push(RegisteredScreen.pix(place: p, amount: m.amount));
  }

  @override
  Widget build(BuildContext context) {
    final m = _gift;
    if (m == null) {
      return FlowScaffold(
        title: 'Essa doação mensal foi cancelada.',
        primary: 'Voltar',
        primaryIcon: null,
        onPrimary: () => Navigator.of(context).pop(),
        children: const [],
      );
    }
    final p = store.place(m.placeId);
    final key = p.pixKey ?? '';
    final done = m.paidThisMonth;
    final month = Fmt.month(DateTime.now());
    return FlowScaffold(
      header: _PlaceHeader(place: p),
      title: 'Sua doação de $month',
      subtitle: done
          ? 'O Pix deste mês já foi registrado. O próximo lembrete chega em ${Fmt.longDay(m.nextDate)}.'
          : 'Copie a chave, faça o Pix no app do seu banco e volte aqui para registrar.',
      primary: done ? 'Voltar' : 'Copiar chave Pix',
      primaryIcon: null,
      onPrimary: done ? () => Navigator.of(context).pop() : () => copyPixKey(context, key),
      secondary: done ? null : 'Já fiz o Pix',
      onSecondary: done ? null : () => _paid(m),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cinza50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cinza100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valor', style: AppType.body(size: 14)),
              const SizedBox(height: 2),
              Text(Fmt.money(m.amount), style: AppType.display(size: 30).copyWith(fontFeatures: tabular)),
              const SizedBox(height: 14),
              const Hairline(),
              const SizedBox(height: 14),
              Text('Chave Pix (${p.pixKeyType}):', style: AppType.body(size: 14)),
              const SizedBox(height: 6),
              Pressable(
                onTap: () => copyPixKey(context, key),
                scale: .98,
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        key,
                        style: AppType.cardTitle(
                          size: 18,
                          color: AppColors.cinza900,
                        ).copyWith(height: 1.3, fontFeatures: tabular),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(PhosphorIconsRegular.copy, size: 22, color: AppColors.petroleo600),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('Confira se o nome aparece como ${p.payee ?? p.legalName}.', style: AppType.body(size: 13.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Manage sheet for one monthly gift: pay now, change, pause, cancel.
Future<void> showMonthlySheet(BuildContext context, MonthlyGift m) async {
  final p = store.place(m.placeId);
  final action = await showAppSheet<String>(
    context,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlaceHeader(place: p),
        const SizedBox(height: 16),
        Text(
          '${Fmt.money(m.amount)} todo dia ${m.day}',
          style: AppType.title().copyWith(fontSize: 22, fontFeatures: tabular),
        ),
        const SizedBox(height: 4),
        Text(
          m.paused ? 'Pausada. Você não recebe lembretes.' : 'Próximo lembrete: ${Fmt.longDay(m.nextDate)}.',
          style: AppType.body(size: 15),
        ),
        const SizedBox(height: 12),
        if (!m.paused && !m.paidThisMonth) ...[
          InfoRow(
            icon: PhosphorIconsRegular.copy,
            title: 'Fazer o Pix deste mês agora',
            chevron: true,
            onTap: () => Navigator.pop(context, 'pay'),
          ),
          const Hairline(indent: 40),
        ],
        InfoRow(
          icon: PhosphorIconsRegular.pencilSimple,
          title: 'Alterar valor ou dia',
          chevron: true,
          onTap: () => Navigator.pop(context, 'edit'),
        ),
        const Hairline(indent: 40),
        InfoRow(
          icon: m.paused ? PhosphorIconsRegular.playCircle : PhosphorIconsRegular.pauseCircle,
          title: m.paused ? 'Retomar' : 'Pausar',
          onTap: () => Navigator.pop(context, 'toggle'),
        ),
        const Hairline(indent: 40),
        InfoRow(
          icon: PhosphorIconsRegular.trash,
          title: 'Cancelar doação mensal',
          titleColor: AppColors.erroTexto,
          onTap: () => Navigator.pop(context, 'cancel'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'pay':
      context.push(MonthlyPayScreen(giftId: m.id));
    case 'edit':
      context.push(MonthlySetupScreen(placeId: m.placeId, edit: m));
    case 'toggle':
      store.toggleMonthly(m);
      HapticFeedback.lightImpact();
      Toast.show(context, m.paused ? 'Doação mensal pausada.' : 'Doação mensal retomada.');
    case 'cancel':
      final ok = await confirmSheet(
        context,
        title: 'Cancelar a doação mensal para ${p.name}?',
        text: 'Os lembretes param. As doações que você já fez continuam no seu histórico.',
        confirm: 'Cancelar doação mensal',
        cancel: 'Manter',
        destructive: true,
      );
      if (ok != null && context.mounted) {
        store.cancelMonthly(m);
        Toast.show(context, 'Doação mensal cancelada.');
      }
  }
}

/// Card on the point's page: start a monthly Pix, or see the active one.
class MonthlyCta extends StatelessWidget {
  const MonthlyCta({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final m = store.monthlyFor(place.id);
    return Pressable(
      onTap: () => m == null ? context.push(MonthlySetupScreen(placeId: place.id)) : showMonthlySheet(context, m),
      scale: .985,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.petroleo50, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const IconTile(icon: PhosphorIconsFill.arrowsClockwise, color: AppColors.petroleo600, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m == null ? 'Doe todo mês' : 'Você doa ${Fmt.money(m.amount)} todo mês',
                    style: AppType.label(
                      color: AppColors.petroleo900,
                      size: 15.5,
                    ).copyWith(fontWeight: FontWeight.w600, fontFeatures: tabular),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m == null
                        ? 'Escolha um valor e um dia. A gente te lembra todo mês.'
                        : m.paused
                        ? 'Pausada.'
                        : 'Próximo lembrete: ${Fmt.longDay(m.nextDate)}.',
                    style: AppType.body(size: 13.5, color: AppColors.petroleo800),
                  ),
                ],
              ),
            ),
            const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.petroleo600),
          ],
        ),
      ),
    );
  }
}

/// Row in "Minhas doações" for one monthly gift.
class MonthlyTile extends StatelessWidget {
  const MonthlyTile({super.key, required this.m});

  final MonthlyGift m;

  @override
  Widget build(BuildContext context) {
    final p = store.place(m.placeId);
    final (status, tone) = m.paused
        ? ('Pausada', Tone.neutral)
        : m.paidThisMonth
        ? ('Pix de ${Fmt.month(DateTime.now())} feito', Tone.success)
        : ('Ativa', Tone.info);
    return AppCard(
      onTap: () => showMonthlySheet(context, m),
      child: Row(
        children: [
          PlaceThumb(place: p, size: 42, badge: (PhosphorIconsFill.arrowsClockwise, AppColors.petroleo600)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: AppType.label(color: AppColors.cinza900, size: 15.5).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  m.paused
                      ? '${Fmt.money(m.amount)} todo dia ${m.day}'
                      : '${Fmt.money(m.amount)} todo dia ${m.day} · próximo em ${Fmt.day(m.nextDate)}',
                  style: AppType.body(size: 14).copyWith(fontFeatures: tabular),
                ),
                const SizedBox(height: 8),
                StatusTag(status, tone: tone),
              ],
            ),
          ),
          const Icon(PhosphorIconsRegular.caretRight, size: 16, color: AppColors.cinza400),
        ],
      ),
    );
  }
}
