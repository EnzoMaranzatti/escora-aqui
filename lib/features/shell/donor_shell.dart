import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../donations/donations_screen.dart';
import '../home/home_screen.dart';
import '../notices/notices_screen.dart';
import '../profile/profile_screen.dart';

/// Current donor tab. Flows that end elsewhere ("Ver minhas doações")
/// set it after popping back to the shell.
final donorTab = ValueNotifier<int>(0);

/// Closes any open flow and shows a donor tab.
void goToTab(BuildContext context, int tab) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  donorTab.value = tab;
}

/// Main screens of the donor: Mapa · Doações · Avisos · Perfil. The bar
/// hides inside task flows (they are pushed above the shell).
class DonorShell extends StatefulWidget {
  const DonorShell({super.key});

  @override
  State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> {
  /// Badge counts notices that arrived after the tab was last opened.
  DateTime _seen = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    store.init();
    donorTab.addListener(_onTab);
    store.addListener(_onStore);
  }

  @override
  void dispose() {
    donorTab.removeListener(_onTab);
    store.removeListener(_onStore);
    super.dispose();
  }

  void _onTab() {
    if (donorTab.value == 2) _seen = DateTime.now();
    setState(() {});
  }

  void _onStore() {
    if (!mounted) return;
    if (donorTab.value == 2) _seen = DateTime.now();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final badge = store.notices.where((n) => !n.read && n.date.isAfter(_seen)).length;
    return TabShell(
      index: donorTab.value,
      pages: const [HomeScreen(), DonationsScreen(), NoticesScreen(), ProfileScreen()],
      bar: AppNavBar(
        index: donorTab.value,
        onTap: (i) => donorTab.value = i,
        items: [
          const NavItem(
            label: 'Mapa',
            semantic: 'Mapa de pontos de apoio',
            icon: PhosphorIconsRegular.mapTrifold,
            activeIcon: PhosphorIconsFill.mapTrifold,
          ),
          const NavItem(
            label: 'Doações',
            semantic: 'Minhas doações',
            icon: PhosphorIconsRegular.receipt,
            activeIcon: PhosphorIconsFill.receipt,
          ),
          NavItem(
            label: 'Avisos',
            semantic: 'Avisos, $badge não lidos',
            icon: PhosphorIconsRegular.bell,
            activeIcon: PhosphorIconsFill.bell,
            badge: badge,
          ),
          const NavItem(
            label: 'Perfil',
            semantic: 'Meu perfil',
            icon: PhosphorIconsRegular.userCircle,
            activeIcon: PhosphorIconsFill.userCircle,
          ),
        ],
      ),
    );
  }
}
