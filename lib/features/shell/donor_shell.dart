import 'package:flutter/material.dart';
import '../../core/icons.dart';

import '../../core/routes.dart';
import '../../core/widgets/scaffolds.dart';
import '../../data/store.dart';
import '../donations/donations_screen.dart';
import '../home/home_screen.dart';
import '../start/start_screen.dart';
import '../notices/notices_screen.dart';
import '../points/points_screen.dart';
import '../profile/profile_screen.dart';

/// Current donor tab. Flows that end elsewhere ("Ver minhas doações")
/// set it after popping back to the shell.
final donorTab = ValueNotifier<int>(0);

/// Tab positions in the bar below, for whoever sends the person to one.
const startTab = 0;
const mapTab = 1;
const pointsTab = 2;
const noticesTab = 3;
const profileTab = 4;

/// Closes any open flow and shows a donor tab.
void goToTab(BuildContext context, int tab) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  donorTab.value = tab;
}

/// As doações deixaram de ser uma aba: moraram cinco telas no rodapé e quem
/// doa abre essa lista uma vez por semana, não por sessão. Agora é uma tela
/// empurrada a partir do perfil — e quem vem de um fluxo ("Ver minhas
/// doações") chega nela do mesmo jeito.
void goToDonations(BuildContext context) {
  final nav = Navigator.of(context);
  nav.popUntil((r) => r.isFirst);
  donorTab.value = profileTab;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (nav.mounted) nav.push(EscoraRoute(const DonationsScreen(standalone: true)));
  });
}

/// Main screens of the donor: Início · Mapa · Pontos · Avisos · Perfil. The
/// bar hides inside task flows (they are pushed above the shell).
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
    if (donorTab.value == noticesTab) _seen = DateTime.now();
    // O mapa esconde a barra enquanto a pessoa arrasta; fora dele, ela volta.
    if (donorTab.value != mapTab) navBarAway.value = false;
    setState(() {});
  }

  void _onStore() {
    if (!mounted) return;
    if (donorTab.value == noticesTab) _seen = DateTime.now();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final badge = store.notices.where((n) => !n.read && n.date.isAfter(_seen)).length;
    return TabShell(
      index: donorTab.value,
      pages: const [StartScreen(), HomeScreen(), PointsScreen(), NoticesScreen(), ProfileScreen()],
      bar: AppNavBar(
        index: donorTab.value,
        onTap: (i) => donorTab.value = i,
        items: [
          const NavItem(
            label: 'Início',
            semantic: 'Início',
            icon: PhosphorIconsRegular.squaresFour,
            activeIcon: PhosphorIconsFill.squaresFour,
          ),
          const NavItem(
            label: 'Mapa',
            semantic: 'Mapa de pontos de apoio',
            icon: PhosphorIconsRegular.mapTrifold,
            activeIcon: PhosphorIconsFill.mapTrifold,
          ),
          const NavItem(
            label: 'Pontos',
            semantic: 'Meus pontos e cupons',
            icon: PhosphorIconsRegular.coins,
            activeIcon: PhosphorIconsFill.coins,
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
