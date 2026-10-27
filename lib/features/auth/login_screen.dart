import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/decor.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/ripple_backdrop.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/sheets.dart';
import '../../data/auth.dart';
import '../shell/donor_shell.dart';
import '../intro/intro_screen.dart';
import 'reset_password_screen.dart';

/// "Já tenho um cadastro". Not designed in Figma yet; uses the same
/// components. Signs in with Supabase (lib/data/auth.dart).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _email = '';
  String _password = '';
  bool _loading = false;

  bool get _valid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.trim()) && _password.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await entrar(email: _email.trim(), senha: _password);
    } on AuthException catch (erro) {
      _fail(mensagemDeErro(erro));
      return;
    } on PostgrestException {
      _fail('Não deu para carregar seu perfil. Confira a internet e tente de novo.');
      return;
    }
    if (!mounted) return;
    context.replaceAll(const DonorShell());
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _loading = false);
    Toast.show(context, message, icon: PhosphorIconsFill.warningCircle);
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    final bool signedIn;
    try {
      signedIn = await entrarComGoogle();
    } on AuthException catch (erro) {
      _fail(mensagemDeErro(erro));
      return;
    } on PostgrestException {
      _fail('Não deu para carregar seu perfil. Confira a internet e tente de novo.');
      return;
    }
    if (!mounted) return;
    if (!signedIn) return setState(() => _loading = false);
    context.replaceAll(const DonorShell());
  }

  void _forgot() => context.push(ResetPasswordScreen(email: _email.trim()));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            // Same quiet backdrop as the end of signup, centered on the clover.
            const Positioned.fill(child: RepaintBoundary(child: RippleBackdrop(focusY: .19, scale: .62))),
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, pad.top + 56, 16, AppSpacing.bottom + pad.bottom),
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            const Reveal(scaleFrom: .8, child: _Clover()),
                            const SizedBox(height: 24),
                            Reveal(
                              delay: const Duration(milliseconds: 120),
                              child: Column(
                                children: [
                                  BalancedText('Que bom te ver de novo.', style: AppType.display()),
                                  const SizedBox(height: 8),
                                  BalancedText('Entre para ver os pontos que você acompanha.', style: AppType.body()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Reveal(
                              delay: const Duration(milliseconds: 220),
                              child: IgnorePointer(ignoring: _loading, child: _form()),
                            ),
                            const Spacer(),
                            const SizedBox(height: 16),
                            GhostButton(
                              label: 'Ainda não tem conta? Começar',
                              onPressed: () => context.replaceAll(const IntroScreen()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: pad.top + 6,
              left: 16,
              child: RoundBackButton(onTap: () => Navigator.of(context).maybePop()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      children: [
        GoogleButton(onTap: _google),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.cinza200)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: AppType.body(size: 14)),
            ),
            const Expanded(child: Divider(color: AppColors.cinza200)),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'E-mail',
          hint: 'seu@email.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          onChanged: (v) => setState(() => _email = v),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Senha',
          hint: 'Sua senha',
          obscure: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onChanged: (v) => setState(() => _password = v),
          onSubmitted: (_) => _valid ? _submit() : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Pressable(
            onTap: _forgot,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
              child: Text('Esqueci minha senha', style: AppType.label(size: 14, color: AppColors.petroleo600)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Entrar', loading: _loading, onPressed: _valid ? _submit : null),
      ],
    );
  }
}

/// Brand clover on a white disc, breathing gently.
class _Clover extends StatefulWidget {
  const _Clover();

  @override
  State<_Clover> createState() => _CloverState();
}

class _CloverState extends State<_Clover> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.rotate(
        angle: .06 * math.sin(_c.value * 2 * math.pi),
        child: Transform.scale(scale: 1 + .03 * math.sin(_c.value * 4 * math.pi), child: child),
      ),
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.petroleo600.withValues(alpha: .12), blurRadius: 28, offset: const Offset(0, 10)),
          ],
        ),
        child: const BrandLogo(size: 54, color: AppColors.petroleo500),
      ),
    );
  }
}
