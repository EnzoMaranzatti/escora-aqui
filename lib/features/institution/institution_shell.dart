import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../shell/donor_shell.dart';
import 'dashboard_screen.dart';
import 'donations_inbox_screen.dart';
import 'goals_screen.dart';
import 'point_screen.dart';

/// Current tab of the institution mode (Painel · Metas · Doações · Ponto).
final institutionTab = ValueNotifier<int>(0);

class InstitutionShell extends StatefulWidget {
  const InstitutionShell({super.key});

  @override
  State<InstitutionShell> createState() => _InstitutionShellState();
}

class _InstitutionShellState extends State<InstitutionShell> {
  @override
  void initState() {
    super.initState();
    institutionTab.value = 0;
    institutionTab.addListener(_onChange);
    store.addListener(_onChange);
  }

  @override
  void dispose() {
    institutionTab.removeListener(_onChange);
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _exit() {
    store.setMode(AppMode.donor);
    donorTab.value = 3;
    context.replaceAll(const DonorShell());
  }

  @override
  Widget build(BuildContext context) {
    final p = store.myPoint!;
    final pending = store.pendingFor(p);
    return TabShell(
      index: institutionTab.value,
      strip: ModeStrip(label: 'Você está no modo instituição · ${p.name}', onExit: _exit),
      pages: const [DashboardScreen(), GoalsScreen(), DonationsInboxScreen(), PointScreen()],
      bar: AppNavBar(
        index: institutionTab.value,
        onTap: (i) => institutionTab.value = i,
        items: [
          const NavItem(
            label: 'Painel',
            semantic: 'Painel do ponto',
            icon: PhosphorIconsRegular.squaresFour,
            activeIcon: PhosphorIconsFill.squaresFour,
          ),
          const NavItem(
            label: 'Metas',
            semantic: 'Metas do ponto',
            icon: PhosphorIconsRegular.target,
            activeIcon: PhosphorIconsFill.target,
          ),
          NavItem(
            label: 'Doações',
            semantic: 'Doações para confirmar, $pending pendentes',
            icon: PhosphorIconsRegular.tray,
            activeIcon: PhosphorIconsFill.tray,
            badge: pending,
          ),
          const NavItem(
            label: 'Ponto',
            semantic: 'Informações do ponto',
            icon: PhosphorIconsRegular.storefront,
            activeIcon: PhosphorIconsFill.storefront,
          ),
        ],
      ),
    );
  }
}
