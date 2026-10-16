import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../shell/donor_shell.dart';
import 'team_points.dart';
import 'team_queue.dart';
import 'team_reports.dart';

/// Team panel (Cadastros · Denúncias · Pontos), inside the app.
class TeamShell extends StatefulWidget {
  const TeamShell({super.key});

  @override
  State<TeamShell> createState() => _TeamShellState();
}

class _TeamShellState extends State<TeamShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _exit() {
    store.setMode(AppMode.donor);
    donorTab.value = 3;
    context.replaceAll(const DonorShell());
  }

  @override
  Widget build(BuildContext context) {
    final queue = store.queue.length;
    final reports = store.openReports.length;
    return TabShell(
      index: _tab,
      strip: ModeStrip(label: 'Painel da equipe', icon: PhosphorIconsFill.shieldCheck, onExit: _exit),
      pages: const [TeamQueueScreen(), TeamReportsScreen(), TeamPointsScreen()],
      bar: AppNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          NavItem(
            label: 'Cadastros',
            semantic: 'Cadastros para analisar, $queue na fila',
            icon: PhosphorIconsRegular.clipboardText,
            activeIcon: PhosphorIconsFill.clipboardText,
            badge: queue,
          ),
          NavItem(
            label: 'Denúncias',
            semantic: 'Denúncias abertas, $reports',
            icon: PhosphorIconsRegular.flag,
            activeIcon: PhosphorIconsFill.flag,
            badge: reports,
          ),
          const NavItem(
            label: 'Pontos',
            semantic: 'Todos os pontos',
            icon: PhosphorIconsRegular.mapPinArea,
            activeIcon: PhosphorIconsFill.mapPinArea,
          ),
        ],
      ),
    );
  }
}
