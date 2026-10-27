import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// Traz o pacote do Supabase para este arquivo. Ele já está no pubspec.yaml. Sem o import, o Dart não sabe o que é Supabase.
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store.dart';

// Atalho para o cliente do supabase, que o main.dart já ligou
// Supabase.instance.client é o objeto que conversa com o seu projeto na nuvem. Ele foi configurado no main.dart, no Supabase.initialize(url, key)
final _supabase = Supabase.instance.client;

// ── Cadastro ─────────────────────────────────────────────────

// Cria a conta. O gatilho no banco cria a linha em profiles sozinho
// Falar com a internet demora. Uma função que demora devolve um Future, uma "promessa de resultado".
// <void> diz que ela não entrega valor nenhum: só avisa que terminou.
// async libera o uso de await dentro da função.
Future<void> criarConta({

  // As chaves {} deixam os parâmetros nomeados. Quem chama precisa escrever criarConta(nome: ..., email: ..., senha: ...).
  // required torna obrigatório os parâmetros
  required String nome,
  required String email,
  required String senha,
}) async {

// .auth é a parte do Supabase que cuida de contas.
// signUp envia e-mail e senha pela internet (HTTPS) para o Auth, que cria a linha em auth.users.
// await manda esperar a resposta antes de seguir. Sem ele, a função terminaria antes do Supabase responder.
  await _supabase.auth.signUp(
    email: email,
    password: senha,
    data: {'full_name': nome},
  );

  // A conta existe a partir daqui: o app passa a mostrar os dados dela.
  final primeiro = nome.split(' ').first;
  onboarding.name = primeiro;
  store
    ..fullName = nome
    ..name = primeiro
    ..email = email
    ..isTeam = false;

  // Copia as escolhas do onboarding para profiles. Se só esta parte falhar,
  // a pessoa segue para o mapa e as escolhas continuam no aparelho.
  await salvarPreferencias();
}

// ── Google ───────────────────────────────────────────────────

// Os dois Client IDs do Google Cloud vêm do env.json, como a URL do Supabase.
// Não são segredo: o segredo (Client Secret) fica só no painel do Supabase.
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

// O nonce é um número aleatório que vai (embaralhado) para o Google e volta
// dentro do token. O Supabase confere os dois: um token roubado de outro
// login não serve aqui. O pacote do Google só deixa configurar uma vez.
final _nonce = base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));
Future<void>? _googlePronto;

/// Abre a escolha de conta do Google e entra no Supabase com ela.
/// Devolve false quando a pessoa fecha a janela sem escolher.
/// [cadastro]: veio do fim do onboarding. Numa conta nova, as escolhas vão
/// para o perfil; numa conta que já existia, valem as que estão no banco.
Future<bool> entrarComGoogle({bool cadastro = false}) async {
  final google = GoogleSignIn.instance;
  _googlePronto ??= google.initialize(
    clientId: Platform.isIOS ? _googleIosClientId : null,
    serverClientId: _googleWebClientId,
    nonce: sha256.convert(utf8.encode(_nonce)).toString(),
  );
  await _googlePronto;

  // 1. O Google mostra as contas do aparelho e devolve um idToken:
  //    uma "carteirinha" assinada pelo Google dizendo quem é a pessoa.
  final GoogleSignInAccount conta;
  try {
    conta = await google.authenticate();
  } on GoogleSignInException catch (erro) {
    if (erro.code == GoogleSignInExceptionCode.canceled) return false;
    throw AuthException(erro.description ?? 'Google', code: 'google_failed');
  }
  final idToken = conta.authentication.idToken;
  if (idToken == null) throw const AuthException('Google sem idToken', code: 'google_failed');

  // 2. O Supabase confere a assinatura do Google e devolve uma sessão nossa.
  //    Na primeira vez, cria a conta, e o gatilho cria a linha em profiles
  //    (o Google manda o nome em full_name, a mesma chave do cadastro por e-mail).
  final resposta = await _supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    nonce: _nonce,
  );

  final criadaAgora = DateTime.now().difference(DateTime.parse(resposta.user!.createdAt)) < const Duration(minutes: 2);
  if (cadastro && criadaAgora) await salvarPreferencias();
  await carregarPerfil();
  return true;
}

// ── Login e sessão ───────────────────────────────────────────

/// Entra com e-mail e senha e traz o perfil do banco para o app.
Future<void> entrar({required String email, required String senha}) async {
  await _supabase.auth.signInWithPassword(email: email, password: senha);
  await carregarPerfil();
}

/// Ao abrir o app: se ficou uma sessão salva no aparelho, carrega o perfil.
/// Devolve true quando a pessoa já pode ir direto para o mapa.
Future<bool> restaurarSessao() async {
  if (_supabase.auth.currentSession == null) return false;
  try {
    await carregarPerfil().timeout(const Duration(seconds: 8));
    return true;
  } on AuthException {
    // Sessão vencida ou apagada no servidor: volta para a capa.
    await sair();
    return false;
  } on PostgrestException {
    await sair();
    return false;
  } catch (_) {
    // Sem internet: mostra a capa, mas mantém a sessão para a próxima vez.
    return false;
  }
}

// ── Esqueci minha senha ──────────────────────────────────────

// No plano gratuito o texto do e-mail não pode mudar, e o padrão manda um link.
// O link passa pelo Supabase e volta para este endereço, que abre o app
// (registrado no Info.plist e no AndroidManifest; liberado em
// additional_redirect_urls no config.toml).
const _linkDeSenha = 'escoraaqui://senha-nova';

/// Parte 1: o Supabase manda o link para o e-mail.
/// Por segurança, ele responde igual mesmo quando o e-mail não tem conta:
/// assim ninguém descobre quem está cadastrado.
Future<void> pedirLinkDeSenha(String email) =>
    _supabase.auth.resetPasswordForEmail(email, redirectTo: _linkDeSenha);

/// Parte 2: quando o link abre o app, o pacote do Supabase troca o link por
/// uma sessão sozinho e avisa com o evento passwordRecovery. Esta função
/// escuta esse aviso (e o de link vencido) durante toda a vida do app.
void ouvirLinkDeSenha({required void Function() abrirSenhaNova, required void Function() linkInvalido}) {
  _supabase.auth.onAuthStateChange.listen(
    (mudanca) {
      if (mudanca.event == AuthChangeEvent.passwordRecovery) abrirSenhaNova();
    },
    onError: (Object _) => linkInvalido(),
  );
}

/// Parte 3: com a sessão do link, grava a senha nova e carrega o perfil.
Future<void> salvarSenhaNova(String senha) async {
  await _supabase.auth.updateUser(UserAttributes(password: senha));
  await carregarPerfil();
}

/// Sai da conta e limpa os dados da pessoa que estavam no app.
Future<void> sair() async {
  try {
    await _supabase.auth.signOut();
    // Esquece a conta Google escolhida: no próximo login ela pergunta de novo.
    if (_googlePronto != null) await GoogleSignIn.instance.signOut();
  } catch (_) {
    // Mesmo sem internet, a sessão salva no aparelho já foi apagada.
  }
  store
    ..name = 'você'
    ..fullName = ''
    ..email = ''
    ..userPhone = ''
    ..birthDate = null
    ..avatar = null;
  onboarding
    ..name = null
    ..city = null
    ..uf = null
    ..position = null
    ..helpTypes.clear()
    ..selectedCauses.clear();
}

// ── Perfil ───────────────────────────────────────────────────

/// Lê a linha da pessoa em profiles e preenche o app (store e onboarding).
Future<void> carregarPerfil() async {
  final usuario = _supabase.auth.currentUser!;

  // select() = SELECT; eq() = WHERE id = ...; single() = espera uma linha só.
  // A política "profiles: ver o próprio ou equipe" garante que só vem a sua.
  final perfil = await _supabase.from('profiles').select().eq('id', usuario.id).single();

  final nome = perfil['full_name'] as String;
  final primeiro = perfil['first_name'] as String;
  final nascimento = perfil['birth_date'] as String?;
  store
    ..email = usuario.email ?? ''
    ..fullName = nome
    ..name = primeiro.isEmpty ? 'você' : primeiro
    ..userPhone = perfil['phone'] as String? ?? ''
    ..birthDate = nascimento == null ? null : DateTime.parse(nascimento)
    ..notifyGoals = perfil['notify_goals'] as bool
    ..notifyConfirm = perfil['notify_confirm'] as bool
    ..notifyVolunteer = perfil['notify_volunteer'] as bool
    ..isTeam = perfil['is_team'] as bool;

  // As listas chegam como List<dynamic>; os textos voltam a ser HelpType pelo nome.
  final tipos = (perfil['help_types'] as List).cast<String>();
  final causas = (perfil['causes'] as List).cast<String>();
  onboarding
    ..name = store.name
    ..city = perfil['city'] as String?
    ..uf = perfil['uf'] as String?
    ..position = _lerPosicao(perfil['position'])
    ..helpTypes.clear()
    ..helpTypes.addAll([for (final t in HelpType.values) if (tipos.contains(t.name)) t])
    ..selectedCauses.clear()
    ..selectedCauses.addAll(causas);
}

/// Copia as escolhas da pessoa (cidade, ajudas, causas, avisos) para profiles.
/// Erros ficam quietos: as escolhas continuam no aparelho.
Future<void> salvarPreferencias() async {
  final usuario = _supabase.auth.currentUser;
  if (usuario == null) return;
  final posicao = onboarding.position;
  try {
    await _supabase.from('profiles').update({
      'city': onboarding.city,
      'uf': onboarding.uf,
      if (posicao != null) 'position': 'POINT(${posicao.longitude} ${posicao.latitude})',
      'help_types': [for (final tipo in onboarding.helpTypes) tipo.name],
      'causes': onboarding.selectedCauses.toList(),
      'notify_goals': store.notifyGoals,
      'notify_confirm': store.notifyConfirm,
      'notify_volunteer': store.notifyVolunteer,
    }).eq('id', usuario.id);
  } on PostgrestException {
    // Fica para a próxima mudança, que manda tudo de novo.
  }
}

/// "Meus dados": nome, celular e nascimento vão para profiles.
/// Um e-mail novo só vale depois que a pessoa clica no link que o Supabase manda.
/// Devolve true quando o e-mail ficou esperando essa confirmação.
Future<bool> salvarDados({
  required String nomeCompleto,
  required String email,
  required String celular,
  required DateTime? nascimento,
}) async {
  final usuario = _supabase.auth.currentUser;
  if (usuario == null) return false; // modo demonstração, sem conta
  await _supabase.from('profiles').update({
    'full_name': nomeCompleto,
    'first_name': nomeCompleto.split(' ').first,
    'phone': celular.isEmpty ? null : celular,
    'birth_date': nascimento?.toIso8601String().substring(0, 10),
  }).eq('id', usuario.id);

  if (email == usuario.email) return false;
  await _supabase.auth.updateUser(UserAttributes(email: email));
  return true;
}

/// A coluna position volta do banco em hexadecimal (EWKB):
/// 1 byte de ordem, 4 de tipo, 4 do SRID (4326) e depois longitude e latitude.
LatLng? _lerPosicao(Object? valor) {
  if (valor is! String || valor.length < 42) return null;
  final bytes = Uint8List.fromList([
    for (var i = 0; i < valor.length; i += 2) int.parse(valor.substring(i, i + 2), radix: 16),
  ]);
  final dados = ByteData.sublistView(bytes);
  final ordem = bytes[0] == 1 ? Endian.little : Endian.big;
  final temSrid = dados.getUint32(1, ordem) & 0x20000000 != 0;
  final inicio = temSrid ? 9 : 5;
  return LatLng(dados.getFloat64(inicio + 8, ordem), dados.getFloat64(inicio, ordem));
}

// ── Erros ────────────────────────────────────────────────────

/// Traduz o erro do Supabase para uma frase em português.
/// String mensagemDeErro(AuthException erro): recebe o erro e devolve um texto (String).
/// AuthException é o "tipo" de erro que o Auth do Supabase lança.
String mensagemDeErro(AuthException erro) {

  //  um código fixo em inglês que o Supabase manda.
  // switch compara o código com cada opção e devolve o texto da que bater.
  return switch (erro.code) {
    'user_already_exists' => 'Já existe uma conta com esse e-mail. Tente entrar.',
    'email_exists' => 'Esse e-mail já está em outra conta.',
    'invalid_credentials' => 'E-mail ou senha não conferem.',
    'otp_expired' => 'Esse link não vale mais. Peça um novo em "Esqueci minha senha".',
    'same_password' => 'A senha nova precisa ser diferente da anterior.',
    'weak_password' => 'A senha precisa ter pelo menos 8 caracteres e um número.',
    'email_address_invalid' => 'Confira o e-mail: ele precisa ter o formato nome@exemplo.com.',
    'over_request_rate_limit' || 'over_email_send_rate_limit' =>
      'Muitas tentativas seguidas. Espere um minuto e tente de novo.',
    _ => 'Não deu para continuar agora. Confira a internet e tente de novo.',
  };
}
