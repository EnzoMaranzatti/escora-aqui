import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/routes.dart';
import '../data/store.dart';
import '../features/donate/items_screen.dart';
import '../features/donate/monthly_screen.dart';
import '../features/donate/pix_screen.dart';
import '../features/donate/registered_screen.dart';
import '../features/donate/volunteer_screen.dart';
import '../features/institution/donations_inbox_screen.dart';
import '../features/institution/goal_flow.dart';
import '../features/institution/institution_shell.dart';
import '../features/institution/register/register_flow.dart';
import '../features/place/place_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/place/report_screen.dart';
import '../features/shell/donor_shell.dart';
import '../features/team/team_queue.dart';
import '../features/team/team_shell.dart';

/// Dev only (`--dart-define=START=tour --dart-define=TOUR_FILE=/path`):
/// shows the screen whose name is written in TOUR_FILE, so screenshots of
/// every screen can be taken from the Mac without tapping.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  static const _file = String.fromEnvironment('TOUR_FILE');
  Timer? _timer;
  String _current = '';

  @override
  void initState() {
    super.initState();
    store.init();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    String name;
    try {
      name = File(_file).readAsStringSync().trim();
    } catch (_) {
      return;
    }
    if (name == _current || name.isEmpty) return;
    _current = name;
    _open(name);
  }

  void _open(String name) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    final p = store.place('casa-exemplo');
    Widget? push;
    switch (name) {
      case 'map' || 'donations' || 'notices' || 'profile':
        store.setMode(AppMode.donor);
        donorTab.value = ['map', 'donations', 'notices', 'profile'].indexOf(name);
        setState(() => _root = 'donor');
      case 'place':
        setState(() => _root = 'donor');
        push = PlaceScreen(placeId: p.id);
      case 'place-empty':
        setState(() => _root = 'donor');
        push = const PlaceScreen(placeId: 'vila-nova');
      case 'place-full':
        setState(() => _root = 'donor');
        push = const PlaceScreen(placeId: 'semear');
      case 'pix':
        push = PixScreen(placeId: 'santo-dumont', goalId: 'g3');
      case 'declare':
        push = DeclareScreen(placeId: 'santo-dumont', goalId: 'g3');
      case 'items':
        push = ItemsScreen(placeId: p.id, goalId: 'g1');
      case 'volunteer':
        push = const VolunteerScreen(placeId: 'liberal', goalId: 'g4');
      case 'done':
        push = RegisteredScreen.pix(place: store.place('santo-dumont'), amount: 50);
      case 'monthly':
        push = MonthlySetupScreen(placeId: 'santo-dumont', suggested: 50);
      case 'monthly-pay':
        final m = store.monthlyFor('santo-dumont') ?? store.startMonthly(store.place('santo-dumont'), 50, 10);
        push = MonthlyPayScreen(giftId: m.id);
      case 'monthly-list':
        store.monthlyFor('lar-aurora') ?? store.startMonthly(store.place('lar-aurora'), 30, 5);
        store.setMode(AppMode.donor);
        donorTab.value = 1;
        setState(() => _root = 'donor');
      case 'edit-profile':
        push = const EditProfileScreen();
      case 'map-list':
        store.setMode(AppMode.donor);
        donorTab.value = 0;
        setState(() => _root = 'donor');
      case 'report':
        push = ReportScreen(placeId: p.id);
      case 'verified':
        setState(() => _root = 'donor');
        push = PlaceScreen(placeId: p.id);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) showVerifiedSheet(nav.context, p);
        });
      case 'register':
        store.draft = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => openRegister(nav.context));
      case final s when s.startsWith('reg'):
        store.startDraft()
          ..step = int.parse(s.substring(3))
          ..responsible = 'Enzo Silva'
          ..phone = '(17) 99812-3344'
          ..phoneVerified = true
          ..hasCnpj = true
          ..cnpj = '22.333.444/0001-55'
          ..legalName = 'Associação Cozinha Comunitária Vila Nova'
          ..cnpjStatus = 'ativa'
          ..cnpjConfirmed = true
          ..name = 'Cozinha Comunitária Vila Nova'
          ..type = 'Associação'
          ..about = 'Servimos almoço para 60 famílias do bairro, de segunda a sexta.'
          ..street = 'Rua Bahia'
          ..number = '512'
          ..neighborhood = 'Vila Nova'
          ..hours = 'segunda a sexta, das 8h às 17h'
          ..pixKey = '22.333.444/0001-55'
          ..payee = 'Associação Cozinha Comunitária Vila Nova'
          ..accepts.addAll({HelpType.pix, HelpType.itens});
        WidgetsBinding.instance.addPostFrameCallback((_) => openRegister(nav.context));
      case 'inst' || 'inst-goals' || 'inst-inbox' || 'inst-vol' || 'inst-point':
        store.setMode(AppMode.institution);
        setState(() => _root = 'inst');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          inboxTab.value = name == 'inst-vol' ? 2 : 0;
          institutionTab.value = switch (name) {
            'inst-goals' => 1,
            'inst-inbox' || 'inst-vol' => 2,
            'inst-point' => 3,
            _ => 0,
          };
        });
      case 'goal':
        setState(() => _root = 'inst');
        push = const GoalFlow();
      case 'team' || 'team-review':
        store.setMode(AppMode.team);
        setState(() => _root = 'team');
        if (name == 'team-review') push = ReviewScreen(submission: store.queue.first);
    }
    if (push != null) {
      final page = push;
      WidgetsBinding.instance.addPostFrameCallback((_) => nav.context.push(page));
    }
  }

  String _root = 'donor';

  @override
  Widget build(BuildContext context) {
    return switch (_root) {
      'inst' => const InstitutionShell(),
      'team' => const TeamShell(),
      _ => const DonorShell(),
    };
  }
}
