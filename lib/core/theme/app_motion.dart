import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// O guia de estilo pedia 150–250ms, ease-out e **sem bounce**. A decisão de
/// 10/11/2026 foi outra: o app ganha o movimento de mola do iOS, com um
/// exagero pequeno no fim. A diferença entre "sem bounce" e "bounce de
/// desenho animado" é o tamanho do exagero — aqui ele fica entre 3% e 9%, o
/// bastante para a interface parecer ter peso, pouco para virar brinquedo.
///
/// Regra de uso: [spring] em tudo que **move, cresce ou aparece**; [smooth]
/// em tudo que interpola **cor, opacidade ou largura de texto**, onde passar
/// do alvo e voltar fica visível como um tremor.
abstract final class AppMotion {
  /// Ease-out à moda da Apple: arranca rápido e pousa devagar, sem passar do
  /// alvo. É o token seguro para cor e opacidade.
  static const smooth = Cubic(0.32, 0.72, 0, 1);

  /// Mola calma: passa ~4% do alvo e volta. O movimento padrão de quem toca,
  /// abre e empurra coisas na tela.
  static const spring = Cubic(0.22, 1.12, 0.36, 1);

  /// Symmetric ease for elements that travel across the screen.
  static const glide = Cubic(0.65, 0, 0.35, 1);

  /// Mola solta: passa ~9%. Para o que nasce na tela — pino no mapa, selo,
  /// a pílula da barra de navegação.
  static const pop = Cubic(0.34, 1.46, 0.64, 1);

  /// Toque: o encolher é imediato, só a volta tem mola.
  static const fast = Duration(milliseconds: 140);

  /// O movimento comum de um elemento que reage ao dedo.
  static const medium = Duration(milliseconds: 340);

  /// Entradas e saídas de blocos inteiros.
  static const slow = Duration(milliseconds: 560);
  static const page = Duration(milliseconds: 620);
}
