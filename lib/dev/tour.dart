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
import '../features/institution/donation_screen.dart';
import '../features/institution/donations_inbox_screen.dart';
import '../features/institution/goal_flow.dart';
import '../features/institution/institution_shell.dart';
import '../features/institution/register/register_flow.dart';
import '../features/auth/partner_login_screen.dart';
import '../features/partner/partner_shell.dart';
import '../features/place/place_screen.dart';
import '../features/points/catalog_screen.dart';
import '../features/points/history_screen.dart';
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
    // Uma tela que não monta (dados que o banco não tem) não pode derrubar
    // o relógio: sem isto, o tour trava na tela anterior para sempre.
    try {
      _open(name);
    } catch (e, pilha) {
      debugPrint('tour: "$name" não abriu: $e\n$pilha');
    }
  }

  /// O ponto com este apelido, ou qualquer um que sirva. Os apelidos são
  /// dos dados fictícios antigos; com o banco real quase nenhum existe.
  Place _ponto(String nome) =>
      store.placeOrNull(nome) ?? store.places.firstWhere((p) => p.goals.isNotEmpty, orElse: () => store.places.first);

  /// Um ponto que tenha meta deste tipo, com a meta junto.
  (Place, Goal)? _meta(HelpType tipo) {
    for (final p in store.places) {
      for (final g in p.goals) {
        if (g.type == tipo && g.progress < 1) return (p, g);
      }
    }
    for (final p in store.places) {
      for (final g in p.goals) {
        if (g.type == tipo) return (p, g);
      }
    }
    return null;
  }

  void _open(String name) {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    // Com os dados reais do banco o ponto de demonstração não existe; as
    // telas que dependem dele caem no primeiro ponto carregado.
    final p = store.placeOrNull('casa-exemplo') ?? store.places.firstOrNull;
    if (p == null && name != 'inst' && !name.startsWith('inst-')) return;
    Widget? push;
    switch (name) {
      case 'map' || 'donations' || 'points' || 'notices' || 'profile':
        store.setMode(AppMode.donor);
        donorTab.value = ['map', 'donations', 'points', 'notices', 'profile'].indexOf(name);
        setState(() => _root = 'donor');
      case 'place':
        setState(() => _root = 'donor');
        push = PlaceScreen(placeId: p!.id);
      case 'place-empty':
        setState(() => _root = 'donor');
        final vazio = store.places.where((x) => x.goals.isEmpty).firstOrNull;
        push = PlaceScreen(placeId: (vazio ?? p!).id);
      case 'place-full':
        setState(() => _root = 'donor');
        final cheio = store.places.where((x) => x.goals.any((g) => g.progress >= 1)).firstOrNull;
        push = PlaceScreen(placeId: (cheio ?? p!).id);
      case 'pix':
        final m = _meta(HelpType.pix);
        if (m != null) push = PixScreen(placeId: m.$1.id, goalId: m.$2.id);
      case 'declare':
        final m = _meta(HelpType.pix);
        if (m != null) push = DeclareScreen(placeId: m.$1.id, goalId: m.$2.id);
      case 'items':
        final m = _meta(HelpType.itens);
        if (m != null) push = ItemsScreen(placeId: m.$1.id, goalId: m.$2.id);
      case 'volunteer':
        final m = _meta(HelpType.voluntariado);
        if (m != null) push = VolunteerScreen(placeId: m.$1.id, goalId: m.$2.id);
      case 'done':
        push = RegisteredScreen.pix(place: _ponto('santo-dumont'), amount: 50);
      case 'monthly':
        push = MonthlySetupScreen(placeId: _ponto('santo-dumont').id, suggested: 50);
      case 'monthly-pay':
        final alvo = _ponto('santo-dumont');
        final m = store.monthlyFor(alvo.id) ?? store.startMonthly(alvo, 50, 10);
        push = MonthlyPayScreen(giftId: m.id);
      case 'monthly-list':
        final outro = _ponto('lar-aurora');
        store.monthlyFor(outro.id) ?? store.startMonthly(outro, 30, 5);
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
        push = ReportScreen(placeId: p!.id);
      case 'verified':
        setState(() => _root = 'donor');
        push = PlaceScreen(placeId: p!.id);
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
          ..cnpj = '22.333.444/0001-81'
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
          ..pixKey = '22.333.444/0001-81'
          ..payee = 'Associação Cozinha Comunitária Vila Nova'
          ..accepts.addAll({HelpType.pix, HelpType.itens});
        WidgetsBinding.instance.addPostFrameCallback((_) => openRegister(nav.context));
      case 'inst' ||
          'inst-goals' ||
          'inst-inbox' ||
          'inst-done' ||
          'inst-vol' ||
          'inst-summary' ||
          'inst-point':
        store.setMode(AppMode.institution);
        setState(() => _root = 'inst');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          inboxTab.value = switch (name) {
            'inst-done' => 1,
            'inst-vol' => 2,
            'inst-summary' => 3,
            _ => 0,
          };
          institutionTab.value = switch (name) {
            'inst-goals' => 1,
            'inst-inbox' || 'inst-done' || 'inst-vol' || 'inst-summary' => 2,
            'inst-point' => 3,
            _ => 0,
          };
        });
      // Uma doação aberta: a primeira da fila, ou a mais recente se a fila
      // estiver vazia.
      case 'inst-donation' || 'inst-donation-done':
        store.setMode(AppMode.institution);
        setState(() => _root = 'inst');
        final mine = store.myPoint;
        if (mine != null) {
          final list = store.incoming(mine);
          final alvo = name == 'inst-donation'
              ? list.where((d) => d.status == DonationStatus.waiting).lastOrNull
              : list.where((d) => d.status == DonationStatus.confirmed).firstOrNull;
          if (alvo != null) push = DonationScreen(alvo.id);
        }
      case 'goal':
        setState(() => _root = 'inst');
        push = const GoalFlow();
      // Modo parceiro. Sem a fase 10 no banco não há empresa ligada à
      // conta, então o tour inventa uma só para a foto sair.
      case 'catalog':
        setState(() => _root = 'donor');
        push = const CatalogScreen();
      case 'redemptions':
        setState(() => _root = 'donor');
        push = const RedemptionsScreen();
      case 'history':
        setState(() => _root = 'donor');
        push = const PointsHistoryScreen();
      case 'partner-login':
        setState(() => _root = 'donor');
        push = const PartnerLoginScreen();
      case 'partner' || 'partner-coupons' || 'partner-found':
        _fakePartner();
        store.setMode(AppMode.partner);
        setState(() => _root = 'partner');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          partnerTab.value = name == 'partner-coupons' ? 1 : 0;
        });
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

  /// Empresa e cupons de mentira, para o modo parceiro aparecer mesmo com
  /// a fase 10 fora do banco. Não escreve nada: é só memória.
  void _fakePartner() {
    if (store.myPartner != null && store.partnerCoupons.isNotEmpty) return;
    store.myPartner ??= const Partner(id: 'demo-parceiro', name: 'Livraria Beira de Página');
    if (store.partnerCoupons.isEmpty) {
      store.partnerCoupons.addAll([
        const PartnerCoupon(
          id: 'demo-1',
          title: 'R\$ 20 de desconto em livros',
          description: 'Vale uma vez por pessoa, em qualquer livro da loja.',
          cost: 120,
          minLevel: PointsLevel.bronze,
          redeemed: 6,
          used: 3,
          stock: 14,
        ),
        const PartnerCoupon(
          id: 'demo-2',
          title: 'Café com bolo na cafeteria',
          description: 'Para quem passa a tarde lendo lá.',
          cost: 80,
          minLevel: PointsLevel.prata,
          redeemed: 4,
          used: 4,
          stock: 6,
        ),
      ]);
    }
  }

  String _root = 'donor';

  @override
  Widget build(BuildContext context) {
    return switch (_root) {
      'inst' => const InstitutionShell(),
      'team' => const TeamShell(),
      'partner' => PartnerShell(
        key: ValueKey(_current),
        demo: _current == 'partner-found'
            ? CouponLookup(
                code: 'ESC-D6611B',
                title: 'R\$ 20 de desconto em livros',
                points: 120,
                date: DateTime.now().subtract(const Duration(days: 2)),
                donorName: 'Camila',
              )
            : null,
      ),
      _ => const DonorShell(),
    };
  }
}
