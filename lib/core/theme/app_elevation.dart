import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sombras do sistema.
///
/// O guia de estilo dizia "card sobre o fundo do app: sem sombra, borda de 1px
/// em cinza 200". Na tela, borda cinza em tudo é justamente o que dá ao app a
/// cara de modelo pronto: a borda desenha a caixa, e o olho passa a ver uma
/// grade de caixas em vez de uma hierarquia.
///
/// Aqui a separação vem da luz, não do traço. Cada nível tem **duas** camadas:
/// uma curta, quase colada no objeto, que dá o contato com a superfície, e uma
/// longa e muito clara, que dá a altura. É o que as referências de 10/11/2026
/// fazem, e é o que diferencia um card que flutua de um card carimbado.
///
/// A cor é sempre cinza 900 com opacidade baixa — nunca preto puro, que
/// esverdeia o cinza morno da marca.
abstract final class AppElevation {
  static const _tinta = AppColors.cinza900;

  /// Card comum sobre o fundo do app. Substitui a borda de 1px.
  static List<BoxShadow> get card => [
    BoxShadow(color: _tinta.withValues(alpha: .04), blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: _tinta.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 8)),
  ];

  /// Card que precisa se destacar dos outros cards da mesma tela, e card
  /// flutuante sobre o mapa.
  static List<BoxShadow> get raised => [
    BoxShadow(color: _tinta.withValues(alpha: .05), blurRadius: 3, offset: const Offset(0, 1)),
    BoxShadow(color: _tinta.withValues(alpha: .09), blurRadius: 28, offset: const Offset(0, 12)),
  ];

  /// Bottom sheets, diálogos e a barra de navegação.
  static List<BoxShadow> get overlay => [
    BoxShadow(color: _tinta.withValues(alpha: .06), blurRadius: 4, offset: const Offset(0, 2)),
    BoxShadow(color: _tinta.withValues(alpha: .18), blurRadius: 40, offset: const Offset(0, 16)),
  ];
}
