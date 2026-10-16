import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/icons.dart';

import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../donate/monthly_screen.dart';
import '../map/pins.dart';
import '../institution/institution_shell.dart';
import '../place/place_screen.dart';
import '../shell/donor_shell.dart';

/// Tab "Avisos": the same notices as the push notifications.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> with WidgetsBindingObserver {
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final s = await Permission.notification.status;
    if (mounted) setState(() => _denied = !s.isGranted);
  }

  Future<void> _enable() async {
    final s = await Permission.notification.request();
    if (s.isPermanentlyDenied || s.isDenied) await openAppSettings();
    _check();
  }

  void _open(Notice n) {
    store.markRead(n);
    if (n.forInstitution) {
      if (store.myPoint != null) {
        store.setMode(AppMode.institution);
        context.replaceAll(const InstitutionShell());
      }
      return;
    }
    switch (n.kind) {
      case NoticeKind.confirmed || NoticeKind.notFound:
        donorTab.value = 1;
      case NoticeKind.monthlyReminder:
        final m = n.placeId == null ? null : store.monthlyFor(n.placeId!);
        if (m != null) context.push(MonthlyPayScreen(giftId: m.id));
      default:
        if (n.placeId != null && store.placeOrNull(n.placeId!) != null) context.push(PlaceScreen(placeId: n.placeId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.notices;
        final unread = list.any((n) => !n.read);
        return TabPage(
          title: 'Avisos',
          top: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_denied) ...[
                NoticeBanner(
                  tone: Tone.alert,
                  icon: PhosphorIconsRegular.bellSlash,
                  text: 'Os avisos estão desligados no seu celular. Você só vê as novidades quando abrir o app.',
                  action: 'Ativar avisos',
                  onAction: _enable,
                ),
                if (unread) const SizedBox(height: 10),
              ],
              if (unread) LinkText('Marcar todos como lidos', onTap: store.markAllRead),
            ],
          ),
          slivers: [
            if (list.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 120),
                  child: Center(
                    child: EmptyState(
                      icon: PhosphorIconsRegular.bell,
                      title: 'Nenhum aviso por enquanto.',
                      text:
                          'Quando um ponto que você acompanha abrir uma meta, ou quando uma doação sua for confirmada, avisamos aqui.',
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, n) in list.indexed) ...[
                          if (i > 0) const Hairline(indent: 64),
                          _NoticeTile(n: n, onTap: () => _open(n)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.n, required this.onTap});

  final Notice n;
  final VoidCallback onTap;

  (IconData, Color) get _look => switch (n.kind) {
    NoticeKind.newGoal => (PhosphorIconsFill.flag, AppColors.terracota600),
    NoticeKind.confirmed => (PhosphorIconsFill.checkCircle, AppColors.sucessoBase),
    NoticeKind.notFound => (PhosphorIconsFill.question, AppColors.cinza600),
    NoticeKind.volunteerReminder => (PhosphorIconsFill.calendarCheck, AppColors.ocre600),
    NoticeKind.goalDone => (PhosphorIconsFill.target, AppColors.petroleo600),
    NoticeKind.monthlyReminder => (PhosphorIconsFill.arrowsClockwise, AppColors.petroleo600),
    NoticeKind.approved || NoticeKind.reactivated => (PhosphorIconsFill.sealCheck, AppColors.petroleo600),
    NoticeKind.adjust => (PhosphorIconsFill.pencilSimple, AppColors.ocre600),
    NoticeKind.refused || NoticeKind.paused => (PhosphorIconsFill.pauseCircle, AppColors.cinza600),
    NoticeKind.newDonation => (PhosphorIconsFill.storefront, AppColors.petroleo600),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _look;
    final place = n.placeId == null ? null : store.placeOrNull(n.placeId!);
    return Semantics(
      button: true,
      label: '${n.read ? '' : 'Não lido. '}${n.title}. ${n.text}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: .985,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place != null)
                PlaceThumb(place: place, size: 40, badge: (icon, color))
              else
                IconTile(icon: icon, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: AppType.label(
                              color: AppColors.cinza900,
                              size: 15,
                            ).copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700, height: 1.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('há ${Fmt.ago(n.date)}', style: AppType.body(size: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.text, style: AppType.body(size: 14)),
                    if (n.forInstitution) ...[
                      const SizedBox(height: 6),
                      const StatusTag('Modo instituição', tone: Tone.info, icon: PhosphorIconsFill.storefront),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: n.read ? 0 : 1,
                duration: AppMotion.medium,
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.terracota500, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
