import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/icons.dart';
import 'core/routes.dart';
import 'core/widgets/sheets.dart';
import 'core/theme/app_colors.dart';
import 'dev/showreel.dart';
import 'dev/tour.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/partner_login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'data/auth.dart';
import 'data/store.dart';
import 'features/institution/institution_shell.dart';
import 'features/partner/partner_shell.dart';
import 'features/shell/donor_shell.dart';
import 'features/team/team_shell.dart';
import 'features/intro/intro_screen.dart';
import 'features/points/level_up_sheet.dart';
import 'features/signup/account_intro_screen.dart';
import 'features/signup/causes_screen.dart';
import 'features/signup/create_account_screen.dart';
import 'features/signup/help_type_screen.dart';
import 'features/signup/location_screen.dart';
import 'features/signup/notifications_screen.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Endereço e chave vêm do env.json: flutter run --dart-define-from-file=env.json
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
  // Quem já entrou antes abre direto no mapa, com os dados já carregados
  // (enquanto isso, o iPhone mostra a tela de abertura).
  final loggedIn = await restaurarSessao();
  if (loggedIn) await store.init().timeout(const Duration(seconds: 10), onTimeout: () {});
  // Quando o banco recusa uma ação, a mensagem aparece como aviso.
  store.errors.stream.listen(_showError);
  // Fase 9: o banco disse que a pessoa subiu de nível, ou que entraram
  // pontos com o app aberto.
  store.levelUps.stream.listen(_showLevelUp);
  store.pointsGained.stream.listen(_showPointsGained);
  // O link de "Esqueci minha senha" abre o app na tela de senha nova.
  ouvirLinkDeSenha(abrirSenhaNova: _openNewPassword, linkInvalido: _invalidResetLink);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(EscoraApp(loggedIn: loggedIn));
}

/// Lets things outside the widget tree (like the reset link) navigate.
final _navigator = GlobalKey<NavigatorState>();

void _openNewPassword() {
  final nav = _navigator.currentState;
  // The link can open the app before the first screen exists.
  if (nav == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNewPassword());
    return;
  }
  nav.push(EscoraRoute(const NewPasswordScreen()));
}

void _showError(String message) {
  final nav = _navigator.currentState;
  if (nav == null) return;
  Toast.show(
    nav.overlay!.context,
    message,
    into: nav.overlay,
    icon: PhosphorIconsFill.warningCircle,
    duration: const Duration(seconds: 5),
  );
}

/// Quando a comemoração de nível abriu pela última vez. Os dois streams
/// saem da mesma carga do banco: numa doação que sobe de nível, o nível
/// chega junto com os pontos, e aí o aviso curto só atrapalharia.
DateTime _levelUpAt = DateTime.fromMillisecondsSinceEpoch(0);

void _showLevelUp(PointsLevel level) {
  final nav = _navigator.currentState;
  if (nav == null) return;
  _levelUpAt = DateTime.now();
  showLevelUp(nav.context, level);
}

void _showPointsGained(int amount) {
  final nav = _navigator.currentState;
  if (nav == null || amount <= 0) return;
  if (DateTime.now().difference(_levelUpAt) < const Duration(seconds: 2)) return;
  Toast.show(
    nav.overlay!.context,
    '+$amount ${amount == 1 ? 'ponto' : 'pontos'}',
    into: nav.overlay,
    icon: PhosphorIconsFill.star,
  );
}

void _invalidResetLink() {
  final nav = _navigator.currentState;
  if (nav == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _invalidResetLink());
    return;
  }
  Toast.show(
    nav.overlay!.context,
    'Esse link não vale mais. Peça um novo em "Esqueci minha senha".',
    into: nav.overlay,
    icon: PhosphorIconsFill.warningCircle,
    duration: const Duration(seconds: 5),
  );
}

class EscoraApp extends StatelessWidget {
  const EscoraApp({super.key, this.loggedIn = false});

  /// There is a saved Supabase session and the profile loaded.
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      title: 'Escora aqui',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.petroleo600,
          primary: AppColors.petroleo600,
          surface: AppColors.white,
        ),
        fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.petroleo600,
          selectionColor: AppColors.petroleo200,
          selectionHandleColor: AppColors.petroleo600,
        ),
      ),
      // A route generator is what makes MaterialApp create its Navigator.
      onGenerateRoute: (_) => EscoraRoute(const SplashScreen()),
      onGenerateInitialRoutes: (_) => [for (final page in _startStack(loggedIn)) EscoraRoute(page)],
    );
  }
}

/// Dev shortcut: `flutter run --dart-define=START=causes` opens a screen
/// directly. Empty (default) starts at the cover, or at the map when the
/// person is logged in. The screens before it in the flow are stacked
/// underneath, so "Voltar" still works.
List<Widget> _startStack(bool loggedIn) {
  const start = String.fromEnvironment('START');
  if (start.isEmpty) {
    if (!loggedIn) return [const SplashScreen()];
    // Conta da equipe abre no painel, como no login: ela não tem modo
    // doador. Sem isto, fechar e abrir o app jogava a equipe no mapa.
    if (store.isTeam) {
      store.setMode(AppMode.team);
      return [const TeamShell()];
    }
    // Conta de parceiro abre no balcão: é a única coisa que ela faz aqui.
    if (store.myPartner != null) {
      store.setMode(AppMode.partner);
      return [const PartnerShell()];
    }
    return [const DonorShell()];
  }
  if (start == 'showreel') return const [ShowreelScreen()];
  if (start == 'tour') return const [TourScreen()];

  if (start == 'located') {
    onboarding.setPlace(
      city: 'São José do Rio Preto',
      uf: 'SP',
      position: const LatLng(-20.8197, -49.3794),
      fromGps: true,
    );
  }
  if (start == 'help-picked') {
    onboarding
      ..toggleHelp(HelpType.pix)
      ..toggleHelp(HelpType.voluntariado);
  }
  if (start == 'causes-picked') {
    for (final c in causes.take(3)) {
      onboarding.toggleCause(c);
    }
  }
  if (start == 'account-filled') {
    onboarding
      ..setPlace(city: 'São José do Rio Preto', uf: 'SP', position: const LatLng(-20.8197, -49.3794), fromGps: true)
      ..toggleHelp(HelpType.pix)
      ..toggleHelp(HelpType.voluntariado)
      ..notifications = true;
    for (final c in causes.take(4)) {
      onboarding.toggleCause(c);
    }
  }
  const cover = SplashScreen(startAtEnd: true);
  const flow = <String, Widget>{
    'intro': IntroScreen(),
    'location': LocationScreen(),
    'help': HelpTypeScreen(),
    'causes': CausesScreen(),
    'notifications': NotificationsScreen(),
    'account': AccountIntroScreen(),
    'create': CreateAccountScreen(),
  };
  final target = switch (start) {
    'verified' => 'intro',
    'goal' => 'intro',
    'located' => 'location',
    'help-picked' => 'help',
    'causes-picked' => 'causes',
    'account-filled' => 'account',
    _ => start,
  };
  if (target == 'login') return const [cover, LoginScreen()];
  if (target == 'partner-login') return const [cover, LoginScreen(), PartnerLoginScreen()];
  if (target == 'home') return const [DonorShell()];
  if (target == 'returning') return const [DonorShell()];
  // Precisam de uma conta que já entrou: com ponto (inst) ou da equipe (team).
  if (target == 'inst') {
    if (!loggedIn || store.myPoint == null) return const [DonorShell()];
    store.setMode(AppMode.institution);
    return const [InstitutionShell()];
  }
  if (target == 'team') {
    if (!loggedIn || !store.isTeam) return const [DonorShell()];
    store.setMode(AppMode.team);
    return const [TeamShell()];
  }
  // Conta ligada a uma empresa do catálogo (partners.owner_id, fase 10).
  if (target == 'partner') {
    if (!loggedIn || store.myPartner == null) return const [DonorShell()];
    store.setMode(AppMode.partner);
    return const [PartnerShell()];
  }
  if (!flow.containsKey(target)) return const [SplashScreen()];

  final keys = flow.keys.toList();
  final stack = <Widget>[cover, for (final k in keys.take(keys.indexOf(target) + 1)) flow[k]!];
  if (start == 'verified') stack.last = const IntroScreen(initialPage: 1);
  if (start == 'goal') stack.last = const IntroScreen(initialPage: 2);
  return stack;
}
