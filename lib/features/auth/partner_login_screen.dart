import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/balanced_text.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/segment_progress.dart';
import '../../core/widgets/kit.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/reveal.dart';
import '../../core/widgets/sheets.dart';
import '../../data/auth.dart';
import '../../data/store.dart';
import '../partner/partner_shell.dart';
import 'reset_password_screen.dart';

/// Porta do parceiro (fase 10). É uma tela só de e-mail e senha, sem Google
/// e sem "criar conta": a parceria é fechada em contrato e a equipe liga a
/// conta à empresa no banco. Quem entra aqui vai direto para o balcão.
class PartnerLoginScreen extends StatefulWidget {
  const PartnerLoginScreen({super.key});

  @override
  State<PartnerLoginScreen> createState() => _PartnerLoginScreenState();
}

class _PartnerLoginScreenState extends State<PartnerLoginScreen> {
  String _email = '';
  String _password = '';
  bool _loading = false;

  bool get _valid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.trim()) && _password.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await entrar(email: _email.trim(), senha: _password);
      // O modo parceiro depende de uma consulta do carregamento geral
      // (partners.owner_id), então espera ela terminar antes de decidir.
      await store.init();
    } on AuthException catch (erro) {
      _fail(mensagemDeErro(erro));
      return;
    } on PostgrestException {
      _fail('Não deu para carregar seus dados. Confira a internet e tente de novo.');
      return;
    }
    if (!mounted) return;

    if (store.myPartner == null) {
      // Entrou, mas a conta não é de parceiro. Sai de novo para esta porta
      // continuar sendo só a do parceiro.
      await sair();
      _fail('Essa conta não é de um parceiro. Use a tela de entrar normal.');
      return;
    }

    store.setMode(AppMode.partner);
    if (!mounted) return;
    context.replaceAll(const PartnerShell());
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _loading = false);
    Toast.show(context, message, icon: PhosphorIconsFill.warningCircle, duration: const Duration(seconds: 5));
  }

  void _forgot() => context.push(ResetPasswordScreen(email: _email.trim()));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.cinza50,
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, pad.top + 72, 16, AppSpacing.bottom + pad.bottom),
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            const Reveal(
                              scaleFrom: .85,
                              child: IconBadge(
                                PhosphorIconsFill.storefront,
                                color: AppColors.white,
                                bg: AppColors.petroleo600,
                                size: 80,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Reveal(
                              delay: const Duration(milliseconds: 120),
                              child: Column(
                                children: [
                                  BalancedText('Área do parceiro.', style: AppType.display()),
                                  const SizedBox(height: 8),
                                  BalancedText(
                                    'Entre para conferir os cupons que as pessoas trocaram por pontos.',
                                    style: AppType.body(),
                                  ),
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
                            Text(
                              'Ainda não é parceiro? Fale com a equipe do Escora aqui para colocar '
                              'sua empresa no catálogo.',
                              textAlign: TextAlign.center,
                              style: AppType.body(size: 13),
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
        AppTextField(
          label: 'E-mail da empresa',
          hint: 'contato@suaempresa.com.br',
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
