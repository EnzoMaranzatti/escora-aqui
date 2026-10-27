import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/scaffolds.dart';

/// "Ajuda" and "Termos de uso e privacidade": plain text pages, built with
/// the same scaffold as the other flows.
class TextPage extends StatelessWidget {
  const TextPage._(this.title, this.sections);

  final String title;
  final List<(String, String)> sections;

  static const help = TextPage._('Ajuda', [
    (
      'O que é o Escora aqui',
      'Um mapa de pontos de apoio verificados perto de você: ONGs, igrejas, escolas e coletivos. '
          'Cada ponto publica metas com prazo e motivo, e você escolhe como ajudar.',
    ),
    (
      'Como funciona o Pix',
      'Você copia a chave da instituição e faz o Pix no app do seu banco. Depois, registra aqui quanto doou. '
          'A meta só avança quando a instituição confirma que recebeu. O Escora aqui não recebe dinheiro e não cobra taxa.',
    ),
    (
      'Itens e voluntariado',
      'Para itens, você combina a quantidade e o dia da entrega. Para voluntariado, se inscreve numa ação com dia e horário. '
          'A instituição confirma quando recebe os itens ou marca sua presença.',
    ),
    (
      'O que quer dizer "verificado"',
      'A equipe do Escora aqui confere cada ponto antes de ele aparecer no mapa: o CNPJ (ou a indicação de uma instituição já verificada), '
          'o endereço, a foto e a chave Pix. Os dados são revisados a cada 90 dias.',
    ),
    (
      'A instituição não encontrou minha doação',
      'Confira o comprovante em Minhas doações. Se o Pix saiu, registre de novo com o comprovante, para a instituição achar no extrato.',
    ),
    (
      'Viu algo estranho?',
      'No perfil do ponto, toque em "Denunciar". A equipe analisa e pode pausar o ponto enquanto confere.',
    ),
  ]);

  static const terms = TextPage._('Termos de uso e privacidade', [
    (
      'Projeto escolar',
      'O Escora aqui é um projeto escolar. Ele liga quem quer ajudar a pontos de apoio verificados e não movimenta dinheiro: '
          'todo Pix acontece no app do seu banco, direto para a instituição.',
    ),
    (
      'Os dados que guardamos',
      'Nome, e-mail, cidade e a posição que você escolheu, as formas de ajuda, as causas e as preferências de aviso. '
          'Celular, data de nascimento e foto de perfil só se você preencher. Também guardamos as doações que você registra, '
          'os pontos que acompanha e os comprovantes que enviar. Não pedimos CPF.',
    ),
    (
      'Quem vê o quê',
      'A instituição vê seu primeiro nome, o valor ou a quantidade que você registrou e o comprovante daquela doação. '
          'Nas avaliações, aparece só o seu primeiro nome. Seu e-mail, celular e localização não aparecem para ninguém.',
    ),
    (
      'Para que usamos',
      'Para mostrar os pontos perto de você, avisar sobre metas e confirmações e deixar a instituição conferir as doações. '
          'Não vendemos nem compartilhamos seus dados com anunciantes.',
    ),
    (
      'Seus direitos (LGPD)',
      'Você pode ver e corrigir seus dados em Perfil → Meus dados e apagar a conta em Perfil → Apagar minha conta. '
          'Ao apagar, saem seus dados e o ponto que você cadastrou. As instituições continuam com o histórico das doações, sem o seu nome.',
    ),
    (
      'Instituições',
      'Quem cadastra um ponto declara que as informações são verdadeiras e que a chave Pix está no nome da instituição '
          '(ou do responsável, quando não há CNPJ). Pontos com dados falsos são removidos do mapa.',
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      title: title,
      children: [
        for (final (i, (heading, body)) in sections.indexed) ...[
          if (i > 0) const SizedBox(height: 22),
          Text(heading, style: AppType.title().copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text(body, style: AppType.body(size: 15.5)),
        ],
      ],
    );
  }
}
