import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/auth.dart';
import '../../data/store.dart';
import '../splash/splash_screen.dart';
import 'coupons_screen.dart';
import 'validate_screen.dart';

/// Aba atual do modo parceiro (Validar · Cupons).
final partnerTab = ValueNotifier<int>(0);

/// Modo parceiro: a empresa que dá os cupons do catálogo entra para
/// conferir o código que a pessoa mostra no balcão. Duas abas só — o
/// parceiro não cadastra nada, quem monta o catálogo é a equipe.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key, this.demo});

  /// Só o tour de desenvolvimento passa isto: um cupom já encontrado, para
  /// fotografar o resultado da busca sem o banco.
  final CouponLookup? demo;

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  @override
  void initState() {
    super.initState();
    partnerTab.value = 0;
    partnerTab.addListener(_onChange);
    store.addListener(_onChange);
    // A lista de cupons não vem no refresh geral: é só deste modo.
    store.loadPartnerCoupons();
  }

  @override
  void dispose() {
    partnerTab.removeListener(_onChange);
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// A conta do parceiro não tem modo doador: ela serve a um objetivo só, e o
  /// mapa de doações não é dela. Então a saída daqui é a saída da conta.
  Future<void> _exit() async {
    final ok = await confirmSheet(
      context,
      title: 'Sair da conta?',
      text: 'Para validar cupons de novo, basta entrar com o e-mail da empresa.',
      confirm: 'Sair da conta',
      cancel: 'Continuar',
    );
    if (ok == null || !mounted) return;
    store.setMode(AppMode.donor);
    await sair();
    if (!mounted) return;
    context.replaceAll(const SplashScreen(startAtEnd: true));
  }

  @override
  Widget build(BuildContext context) {
    final nome = store.myPartner?.name ?? 'parceiro';
    final esperando = store.partnerCoupons.fold<int>(0, (soma, c) => soma + c.pending);
    return TabShell(
      index: partnerTab.value,
      strip: ModeStrip(label: 'Modo parceiro · $nome', onExit: _exit, action: 'Sair da conta'),
      pages: [ValidateScreen(demo: widget.demo), const CouponsScreen()],
      bar: AppNavBar(
        index: partnerTab.value,
        onTap: (i) => partnerTab.value = i,
        items: [
          const NavItem(
            label: 'Validar',
            semantic: 'Validar um cupom pelo código',
            icon: PhosphorIconsRegular.receipt,
            activeIcon: PhosphorIconsFill.receipt,
          ),
          NavItem(
            label: 'Cupons',
            semantic: 'Meus cupons, $esperando para usar',
            icon: PhosphorIconsRegular.ticket,
            activeIcon: PhosphorIconsFill.ticket,
            badge: esperando,
          ),
        ],
      ),
    );
  }
}
