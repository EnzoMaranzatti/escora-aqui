import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/step_progress.dart';
import '../../core/widgets/svg_icon.dart';
import '../auth/login_screen.dart';
import '../../data/store.dart';
import '../institution/register/register_flow.dart';
import '../shell/donor_shell.dart';
import '../map/pins.dart';

/// Step 5 of 5 — "Salve suas escolhas" (copy, passo 8). Not in Figma yet;
/// built with the same components. "Criar conta" stays disabled until the
/// form is valid. On success a check pops in place of the form, then the
/// app opens on the personalized map.
///
/// There is no backend yet: account creation and Google sign-in are
/// simulated.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.withGoogle = false, this.forInstitution = false});

  final bool withGoogle;

  /// Came from "Represento uma instituição": after the account, the point
  /// signup opens right away (donor preferences are skipped).
  final bool forInstitution;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  String _name = '';
  String _email = '';
  String _password = '';
  final _touched = <String>{};
  bool _loading = false;
  bool _done = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _nameOk => _name.trim().isNotEmpty;
  bool get _emailOk => _emailRe.hasMatch(_email.trim());
  bool get _passwordOk => _password.length >= 8 && _password.contains(RegExp(r'\d'));
  bool get _valid => _nameOk && _emailOk && _passwordOk;

  @override
  void initState() {
    super.initState();
    if (widget.withGoogle) WidgetsBinding.instance.addPostFrameCallback((_) => _googleSignIn());
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _finish(name: 'você');
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    _finish(name: _name.trim().split(' ').first);
  }

  void _finish({required String name}) {
    onboarding.name = name;
    store
      ..name = name
      ..fullName = _name.trim()
      ..email = _email.trim();
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = false;
      _done = true;
    });
    // Let the check land, then open the personalized map.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _openHome();
    });
  }

  void _openHome() {
    final nav = Navigator.of(context);
    context.replaceAll(const DonorShell());
    if (widget.forInstitution) openRegister(nav.context);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                pad.top + 6 + RoundBackButton.size + 28,
                16,
                AppSpacing.bottom + pad.bottom,
              ),
              child: Column(
                children: [
                  SwapText(_done ? 'Pronto.' : 'Crie sua conta.', style: AppType.display()),
                  const SizedBox(height: 8),
                  SwapText(
                    _done
                        ? widget.forInstitution
                              ? 'Sua conta foi criada. Agora, o ponto de apoio…'
                              : 'Sua conta foi criada. Abrindo seu mapa…'
                        : widget.forInstitution
                        ? 'Primeiro, sua conta pessoal. Logo depois você cadastra o ponto de apoio.'
                        : 'Suas escolhas já estão guardadas. Falta só isso para salvar tudo.',
                    style: AppType.body(),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child: _done
                        ? const Padding(
                            key: ValueKey('done'),
                            padding: EdgeInsets.only(top: 24),
                            child: PopIn(child: _DoneMark()),
                          )
                        : IgnorePointer(key: const ValueKey('form'), ignoring: _loading, child: _form()),
                  ),
                ],
              ),
            ),
            // White strip so the form scrolls under the bar cleanly.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppColors.white,
                padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, 8),
                child: widget.forInstitution
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedOpacity(
                          duration: AppMotion.medium,
                          opacity: _done || _loading ? 0 : 1,
                          child: RoundBackButton(
                            onTap: _done || _loading ? null : () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      )
                    : SegmentProgress(
                        count: StepProgress.steps,
                        position: StepProgress.steps - 1,
                        onBack: _done || _loading ? null : () => Navigator.of(context).maybePop(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Reveal(
      delay: const Duration(milliseconds: 200),
      child: AutofillGroup(
        child: Column(
          children: [
            GoogleButton(onTap: _googleSignIn),
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
              label: 'Nome',
              hint: 'Como podemos te chamar?',
              autofillHints: const [AutofillHints.givenName],
              textInputAction: TextInputAction.next,
              error: _touched.contains('name') && !_nameOk ? 'Digite seu nome.' : null,
              onChanged: (v) => setState(() => _name = v),
              onFocusLost: () => setState(() => _touched.add('name')),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'E-mail',
              hint: 'seu@email.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              error: _touched.contains('email') && !_emailOk
                  ? 'Confira o e-mail: ele precisa ter o formato nome@exemplo.com.'
                  : null,
              onChanged: (v) => setState(() => _email = v),
              onFocusLost: () => setState(() => _touched.add('email')),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Senha',
              hint: 'Crie uma senha',
              obscure: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              help: 'Mínimo de 8 caracteres, com pelo menos um número.',
              error: _touched.contains('password') && !_passwordOk
                  ? 'A senha precisa ter pelo menos 8 caracteres e um número.'
                  : null,
              onChanged: (v) => setState(() => _password = v),
              onFocusLost: () => setState(() => _touched.add('password')),
              onSubmitted: (_) => _valid ? _submit() : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Ao criar a conta, você concorda com os Termos de uso e a Política de privacidade.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Criar conta', loading: _loading, onPressed: _valid ? _submit : null),
            const SizedBox(height: 6),
            GhostButton(label: 'Já tem conta? Entrar', onPressed: () => context.push(const LoginScreen())),
          ],
        ),
      ),
    );
  }
}

/// Success badge shown once the account exists.
class _DoneMark extends StatelessWidget {
  const _DoneMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Pulse(color: AppColors.petroleo500, size: 140),
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.petroleo600,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.petroleo600.withValues(alpha: .3), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: const SvgIcon(Ic.checkWhite, size: 32),
        ),
      ],
    );
  }
}
