import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'core/routes.dart';
import 'core/theme/app_colors.dart';
import 'dev/showreel.dart';
import 'dev/tour.dart';
import 'features/auth/login_screen.dart';
import 'data/store.dart';
import 'features/institution/institution_shell.dart';
import 'features/shell/donor_shell.dart';
import 'features/team/team_shell.dart';
import 'features/intro/intro_screen.dart';
import 'features/signup/account_intro_screen.dart';
import 'features/signup/causes_screen.dart';
import 'features/signup/create_account_screen.dart';
import 'features/signup/help_type_screen.dart';
import 'features/signup/location_screen.dart';
import 'features/signup/notifications_screen.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const EscoraApp());
}

class EscoraApp extends StatelessWidget {
  const EscoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      onGenerateInitialRoutes: (_) => [for (final page in _startStack()) EscoraRoute(page)],
    );
  }
}

/// Dev shortcut: `flutter run --dart-define=START=causes` opens a screen
/// directly. Empty (default) starts at the cover. The screens before it
/// in the flow are stacked underneath, so "Voltar" still works.
List<Widget> _startStack() {
  const start = String.fromEnvironment('START');
  if (start.isEmpty) return const [SplashScreen()];
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
  if (target == 'home') return const [DonorShell()];
  if (target == 'returning') return const [DonorShell(returning: true)];
  if (target == 'inst') {
    store
      ..init(returning: true)
      ..seedDemoInstitution()
      ..setMode(AppMode.institution);
    return const [InstitutionShell()];
  }
  if (target == 'team') {
    store
      ..init(returning: true)
      ..setMode(AppMode.team);
    return const [TeamShell()];
  }
  if (!flow.containsKey(target)) return const [SplashScreen()];

  final keys = flow.keys.toList();
  final stack = <Widget>[cover, for (final k in keys.take(keys.indexOf(target) + 1)) flow[k]!];
  if (start == 'verified') stack.last = const IntroScreen(initialPage: 1);
  if (start == 'goal') stack.last = const IntroScreen(initialPage: 2);
  return stack;
}
