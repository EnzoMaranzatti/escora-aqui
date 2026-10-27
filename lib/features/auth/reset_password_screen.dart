import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

import '../../core/icons.dart';
import '../../core/routes.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/scaffolds.dart';
import '../../core/widgets/sheets.dart';
import '../../data/auth.dart';
import '../shell/donor_shell.dart';
import '../splash/splash_screen.dart';

/// "Esqueci minha senha". Not in Figma; same components as "Meus dados".
/// Asks for the e-mail and sends the reset link. The link opens the app on
/// [NewPasswordScreen] (see `ouvirLinkDeSenha` in main.dart).
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email = ''});

  /// Whatever was already typed on the login screen.
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late String _email = widget.email;
  bool _sent = false;
  bool _loading = false;
  bool _touched = false;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailOk => _emailRe.hasMatch(_email.trim());

  Future<void> _send({bool again = false}) async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await pedirLinkDeSenha(_email.trim());
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() => _loading = false);
      Toast.show(context, mensagemDeErro(erro), icon: PhosphorIconsFill.warningCircle);
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _sent = true;
    });
    if (again) Toast.show(context, 'Mandamos um link novo.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_sent) {
      return FlowScaffold(
        title: 'Esqueceu a senha?',
        subtitle: 'Digite o e-mail da sua conta. Vamos mandar um link para você criar uma senha nova.',
        primary: 'Enviar link',
        onPrimary: _emailOk ? _send : null,
        loading: _loading,
        children: [
          AppTextField(
            label: 'E-mail',
            hint: 'seu@email.com',
            initialValue: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            error: _touched && !_emailOk ? 'Confira o e-mail: ele precisa ter o formato nome@exemplo.com.' : null,
            onChanged: (v) => setState(() => _email = v),
            onFocusLost: () => setState(() => _touched = true),
            onSubmitted: (_) => _emailOk ? _send() : null,
          ),
        ],
      );
    }
    return FlowScaffold(
      title: 'Confira seu e-mail.',
      subtitle:
          'Se existe uma conta com ${_email.trim()}, mandamos um link para lá. '
          'Abra o e-mail neste celular e toque no link: o app abre para você criar a senha nova. '
          'Olhe também a caixa de spam.',
      primary: 'Voltar para o login',
      onPrimary: () => Navigator.of(context).pop(),
      secondary: 'Mandar outro link',
      onSecondary: _loading ? null : () => _send(again: true),
      loading: _loading,
      // Back goes to the e-mail field, to fix a typo.
      onBack: () => setState(() => _sent = false),
      children: const [],
    );
  }
}

/// Opened by the reset link. The link already signed the person in, so
/// saving the password ends on the map. Closing it signs out: the link
/// was meant for a new password, not for a way in.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  String _password = '';
  bool _touched = false;
  bool _loading = false;

  bool get _passwordOk => _password.length >= 8 && _password.contains(RegExp(r'\d'));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_passwordOk) return setState(() => _touched = true);
    setState(() => _loading = true);
    try {
      await salvarSenhaNova(_password);
    } on AuthException catch (erro) {
      _fail(mensagemDeErro(erro));
      return;
    } on PostgrestException {
      _fail('Não deu para carregar seu perfil. Confira a internet e tente de novo.');
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Toast.show(context, 'Senha nova salva.');
    context.replaceAll(const DonorShell(returning: true));
  }

  Future<void> _close() async {
    await sair();
    if (mounted) context.replaceAll(const SplashScreen(startAtEnd: true));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _loading = false);
    Toast.show(context, message, icon: PhosphorIconsFill.warningCircle);
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: 'Crie uma senha nova.',
      subtitle: 'Depois disso, você já entra com ela.',
      primary: 'Salvar nova senha',
      onPrimary: _save,
      loading: _loading,
      closeIcon: true,
      onBack: _loading ? () {} : _close,
      children: [
        AppTextField(
          label: 'Nova senha',
          hint: 'Crie uma senha',
          obscure: true,
          autofocus: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          help: 'Mínimo de 8 caracteres, com pelo menos um número.',
          error: _touched && !_passwordOk ? 'A senha precisa ter pelo menos 8 caracteres e um número.' : null,
          onChanged: (v) => setState(() => _password = v),
          onFocusLost: () => setState(() => _touched = true),
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
