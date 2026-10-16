import 'package:flutter/painting.dart';

/// Brand palette from style-guide.md (scales 50–900) plus the few extra
/// tones the Figma screens use.
abstract final class AppColors {
  // Petróleo (primária)
  static const petroleo50 = Color(0xFFEEF6F6);
  static const petroleo100 = Color(0xFFD5E9EA);
  static const petroleo200 = Color(0xFFABD2D4);
  static const petroleo300 = Color(0xFF7BB5B9);
  static const petroleo400 = Color(0xFF4C9499);
  static const petroleo500 = Color(0xFF2B777D);
  static const petroleo600 = Color(0xFF1F6268);
  static const petroleo700 = Color(0xFF194F54);
  static const petroleo800 = Color(0xFF143E42);
  static const petroleo900 = Color(0xFF0E2D30);

  // Terracota (acento)
  static const terracota50 = Color(0xFFFBF1EC);
  static const terracota100 = Color(0xFFF5DCD0);
  static const terracota200 = Color(0xFFEBB9A2);
  static const terracota300 = Color(0xFFDE9273);
  static const terracota400 = Color(0xFFCF6E4B);
  static const terracota500 = Color(0xFFB95634);
  static const terracota600 = Color(0xFF9C4529);
  static const terracota700 = Color(0xFF7D3722);
  static const terracota800 = Color(0xFF5F2A1B);

  // Ocre (apoio)
  static const ocre50 = Color(0xFFFBF5E6);
  static const ocre100 = Color(0xFFF5E6C2);
  static const ocre200 = Color(0xFFEBCD8A);
  static const ocre300 = Color(0xFFDFB25A);
  static const ocre400 = Color(0xFFCF9836);
  static const ocre500 = Color(0xFFB07D22);
  static const ocre600 = Color(0xFF8F641B);
  static const ocre700 = Color(0xFF704E16);
  static const ocre800 = Color(0xFF533A12);

  // Cinza morno
  static const cinza50 = Color(0xFFF8F6F3);
  static const cinza100 = Color(0xFFEFECE7);
  static const cinza200 = Color(0xFFE2DDD6);
  static const cinza300 = Color(0xFFCBC4BA);
  static const cinza400 = Color(0xFFA69E93);
  static const cinza500 = Color(0xFF82796E);
  static const cinza600 = Color(0xFF655D54);
  static const cinza700 = Color(0xFF4D4740);
  static const cinza800 = Color(0xFF36312C);
  static const cinza900 = Color(0xFF221F1B);

  // Semânticas
  static const sucessoTexto = Color(0xFF24633C);
  static const sucessoFundo = Color(0xFFEAF4EC);
  static const sucessoBase = Color(0xFF2F7A4B);
  static const erroTexto = Color(0xFFA3231B);
  static const erroFundo = Color(0xFFFCECEA);
  static const erroBase = Color(0xFFB3261E);

  // Figma extras
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1D1D1D);
  static const pillBorder = Color(0xFFDEDEDE);
  static const sheetBorder = Color(0xFFEBEBEB);
  static const cardBorder = Color(0xFFE5E5E5);
  static const sunshine = Color(0xFFFFC33C);
  static const tooltip = Color(0xFF000000);
}
