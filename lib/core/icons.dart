import 'package:flutter/widgets.dart';

/// Phosphor Icons (MIT, phosphoricons.com), the library the style guide
/// asks for. Only the glyphs the app uses, drawn from the fonts in
/// assets/fonts (the phosphor_flutter package doesn't compile on this
/// Flutter version: it extends IconData, which is now final).
///
/// **Regra de peso.** O traço do Phosphor é desenhado para 24px, então em
/// tamanho pequeno o Regular fica fino demais ao lado do texto:
/// - **Bold** em ícone de até 18px encostado em texto (linha de lista,
///   chip, selo, botão, caret, link) e em ícone de até 22px sozinho dentro
///   de um quadrado ou círculo (`IconBadge`, `IconTile`, `InfoRow`,
///   `OptionTile`, `RoundIconButton`, botão de copiar, lupa do campo).
/// - **Regular** acima de 22px: vazio de tela, ícone de capa, pino do mapa
///   e estrela de nota, onde o traço fino já tem corpo.
/// - **Fill** segue valendo para estado ativo ou selecionado.

abstract final class PhosphorIconsRegular {
  static const arrowUpRight = IconData(0xe092, fontFamily: 'PhosphorRegular');
  static const arrowsClockwise = IconData(0xe094, fontFamily: 'PhosphorRegular');
  static const bank = IconData(0xe0b4, fontFamily: 'PhosphorRegular');
  static const bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const bellSimple = IconData(0xe0d0, fontFamily: 'PhosphorRegular');
  static const bellSlash = IconData(0xe0d4, fontFamily: 'PhosphorRegular');
  static const bookmarkSimple = IconData(0xe0ea, fontFamily: 'PhosphorRegular');
  static const calendarBlank = IconData(0xe10a, fontFamily: 'PhosphorRegular');
  static const calendarDots = IconData(0xe7b4, fontFamily: 'PhosphorRegular');
  static const camera = IconData(0xe10e, fontFamily: 'PhosphorRegular');
  static const car = IconData(0xe112, fontFamily: 'PhosphorRegular');
  static const caretLeft = IconData(0xe138, fontFamily: 'PhosphorRegular');
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular');
  static const chartBar = IconData(0xe150, fontFamily: 'PhosphorRegular');
  static const clipboardText = IconData(0xe198, fontFamily: 'PhosphorRegular');
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const clockCounterClockwise = IconData(0xe1a0, fontFamily: 'PhosphorRegular');
  static const coins = IconData(0xe78e, fontFamily: 'PhosphorRegular');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorRegular');
  static const envelope = IconData(0xe214, fontFamily: 'PhosphorRegular');
  static const fileText = IconData(0xe23a, fontFamily: 'PhosphorRegular');
  static const flag = IconData(0xe244, fontFamily: 'PhosphorRegular');
  static const funnelSimple = IconData(0xe268, fontFamily: 'PhosphorRegular');
  static const funnelSimpleX = IconData(0xe26a, fontFamily: 'PhosphorRegular');
  static const gift = IconData(0xe276, fontFamily: 'PhosphorRegular');
  static const handshake = IconData(0xe582, fontFamily: 'PhosphorRegular');
  static const hourglassMedium = IconData(0xe2b8, fontFamily: 'PhosphorRegular');
  static const identificationCard = IconData(0xe2c8, fontFamily: 'PhosphorRegular');
  static const image = IconData(0xe2ca, fontFamily: 'PhosphorRegular');
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
  static const lightbulb = IconData(0xe2dc, fontFamily: 'PhosphorRegular');
  static const listBullets = IconData(0xe2f2, fontFamily: 'PhosphorRegular');
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'PhosphorRegular');
  static const mapPin = IconData(0xe316, fontFamily: 'PhosphorRegular');
  static const mapPinArea = IconData(0xee3a, fontFamily: 'PhosphorRegular');
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorRegular');
  static const navigationArrow = IconData(0xeade, fontFamily: 'PhosphorRegular');
  static const package = IconData(0xe390, fontFamily: 'PhosphorRegular');
  static const paperclip = IconData(0xe39a, fontFamily: 'PhosphorRegular');
  static const path = IconData(0xe39c, fontFamily: 'PhosphorRegular');
  static const pauseCircle = IconData(0xe3a0, fontFamily: 'PhosphorRegular');
  static const pencilSimple = IconData(0xe3b4, fontFamily: 'PhosphorRegular');
  static const phone = IconData(0xe3b8, fontFamily: 'PhosphorRegular');
  static const playCircle = IconData(0xe3d2, fontFamily: 'PhosphorRegular');
  static const prohibit = IconData(0xe3de, fontFamily: 'PhosphorRegular');
  static const question = IconData(0xe3e8, fontFamily: 'PhosphorRegular');
  static const receipt = IconData(0xe3ec, fontFamily: 'PhosphorRegular');
  static const signOut = IconData(0xe42a, fontFamily: 'PhosphorRegular');
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const star = IconData(0xe46a, fontFamily: 'PhosphorRegular');
  static const stopCircle = IconData(0xe46e, fontFamily: 'PhosphorRegular');
  static const storefront = IconData(0xe470, fontFamily: 'PhosphorRegular');
  static const tag = IconData(0xe478, fontFamily: 'PhosphorRegular');
  static const target = IconData(0xe47c, fontFamily: 'PhosphorRegular');
  static const ticket = IconData(0xe490, fontFamily: 'PhosphorRegular');
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const tray = IconData(0xe4aa, fontFamily: 'PhosphorRegular');
  static const trendDown = IconData(0xe4ac, fontFamily: 'PhosphorRegular');
  static const trendUp = IconData(0xe4ae, fontFamily: 'PhosphorRegular');
  static const userCircle = IconData(0xe4c4, fontFamily: 'PhosphorRegular');
  static const usersThree = IconData(0xe68e, fontFamily: 'PhosphorRegular');
  static const whatsappLogo = IconData(0xe5d0, fontFamily: 'PhosphorRegular');
  static const wifiSlash = IconData(0xe4f2, fontFamily: 'PhosphorRegular');
  static const x = IconData(0xe4f6, fontFamily: 'PhosphorRegular');
}

abstract final class PhosphorIconsFill {
  static const arrowsClockwise = IconData(0xe094, fontFamily: 'PhosphorFill');
  static const bell = IconData(0xe0ce, fontFamily: 'PhosphorFill');
  static const buildings = IconData(0xe102, fontFamily: 'PhosphorFill');
  static const calendarCheck = IconData(0xe712, fontFamily: 'PhosphorFill');
  static const chatCircleText = IconData(0xe16e, fontFamily: 'PhosphorFill');
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorFill');
  static const clipboardText = IconData(0xe198, fontFamily: 'PhosphorFill');
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorFill');
  static const coins = IconData(0xe78e, fontFamily: 'PhosphorFill');
  static const crown = IconData(0xe614, fontFamily: 'PhosphorFill');
  static const fire = IconData(0xe242, fontFamily: 'PhosphorFill');
  static const flag = IconData(0xe244, fontFamily: 'PhosphorFill');
  static const gift = IconData(0xe276, fontFamily: 'PhosphorFill');
  static const hourglassLow = IconData(0xe2b6, fontFamily: 'PhosphorFill');
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorFill');
  static const mapPin = IconData(0xe316, fontFamily: 'PhosphorFill');
  static const mapPinArea = IconData(0xee3a, fontFamily: 'PhosphorFill');
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorFill');
  static const medal = IconData(0xe320, fontFamily: 'PhosphorFill');
  static const navigationArrow = IconData(0xeade, fontFamily: 'PhosphorFill');
  static const package = IconData(0xe390, fontFamily: 'PhosphorFill');
  static const pauseCircle = IconData(0xe3a0, fontFamily: 'PhosphorFill');
  static const pencilSimple = IconData(0xe3b4, fontFamily: 'PhosphorFill');
  static const question = IconData(0xe3e8, fontFamily: 'PhosphorFill');
  static const receipt = IconData(0xe3ec, fontFamily: 'PhosphorFill');
  static const sealCheck = IconData(0xe606, fontFamily: 'PhosphorFill');
  static const shieldCheck = IconData(0xe40c, fontFamily: 'PhosphorFill');
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorFill');
  static const star = IconData(0xe46a, fontFamily: 'PhosphorFill');
  static const storefront = IconData(0xe470, fontFamily: 'PhosphorFill');
  static const target = IconData(0xe47c, fontFamily: 'PhosphorFill');
  static const ticket = IconData(0xe490, fontFamily: 'PhosphorFill');
  static const tray = IconData(0xe4aa, fontFamily: 'PhosphorFill');
  static const userCircle = IconData(0xe4c4, fontFamily: 'PhosphorFill');
  static const usersThree = IconData(0xe68e, fontFamily: 'PhosphorFill');
  static const warning = IconData(0xe4e0, fontFamily: 'PhosphorFill');
  static const warningCircle = IconData(0xe4e2, fontFamily: 'PhosphorFill');
  static const xCircle = IconData(0xe4f8, fontFamily: 'PhosphorFill');
}

abstract final class PhosphorIconsBold {
  static const arrowsClockwise = IconData(0xe094, fontFamily: 'PhosphorBold');
  static const arrowUpRight = IconData(0xe092, fontFamily: 'PhosphorBold');
  static const bank = IconData(0xe0b4, fontFamily: 'PhosphorBold');
  static const bell = IconData(0xe0ce, fontFamily: 'PhosphorBold');
  static const bellSimple = IconData(0xe0d0, fontFamily: 'PhosphorBold');
  static const bellSlash = IconData(0xe0d4, fontFamily: 'PhosphorBold');
  static const bookmarkSimple = IconData(0xe0ea, fontFamily: 'PhosphorBold');
  static const calendarBlank = IconData(0xe10a, fontFamily: 'PhosphorBold');
  static const calendarDots = IconData(0xe7b4, fontFamily: 'PhosphorBold');
  static const camera = IconData(0xe10e, fontFamily: 'PhosphorBold');
  static const car = IconData(0xe112, fontFamily: 'PhosphorBold');
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorBold');
  static const caretLeft = IconData(0xe138, fontFamily: 'PhosphorBold');
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorBold');
  static const chartBar = IconData(0xe150, fontFamily: 'PhosphorBold');
  static const check = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const clipboardText = IconData(0xe198, fontFamily: 'PhosphorBold');
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorBold');
  static const clockCounterClockwise = IconData(0xe1a0, fontFamily: 'PhosphorBold');
  static const coins = IconData(0xe78e, fontFamily: 'PhosphorBold');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorBold');
  static const envelope = IconData(0xe214, fontFamily: 'PhosphorBold');
  static const fileText = IconData(0xe23a, fontFamily: 'PhosphorBold');
  static const flag = IconData(0xe244, fontFamily: 'PhosphorBold');
  static const funnelSimple = IconData(0xe268, fontFamily: 'PhosphorBold');
  static const funnelSimpleX = IconData(0xe26a, fontFamily: 'PhosphorBold');
  static const gift = IconData(0xe276, fontFamily: 'PhosphorBold');
  static const handshake = IconData(0xe582, fontFamily: 'PhosphorBold');
  static const hourglassMedium = IconData(0xe2b8, fontFamily: 'PhosphorBold');
  static const identificationCard = IconData(0xe2c8, fontFamily: 'PhosphorBold');
  static const image = IconData(0xe2ca, fontFamily: 'PhosphorBold');
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorBold');
  static const lightbulb = IconData(0xe2dc, fontFamily: 'PhosphorBold');
  static const listBullets = IconData(0xe2f2, fontFamily: 'PhosphorBold');
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'PhosphorBold');
  static const mapPin = IconData(0xe316, fontFamily: 'PhosphorBold');
  static const mapPinArea = IconData(0xee3a, fontFamily: 'PhosphorBold');
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorBold');
  static const minus = IconData(0xe32a, fontFamily: 'PhosphorBold');
  static const navigationArrow = IconData(0xeade, fontFamily: 'PhosphorBold');
  static const package = IconData(0xe390, fontFamily: 'PhosphorBold');
  static const paperclip = IconData(0xe39a, fontFamily: 'PhosphorBold');
  static const path = IconData(0xe39c, fontFamily: 'PhosphorBold');
  static const pauseCircle = IconData(0xe3a0, fontFamily: 'PhosphorBold');
  static const pencilSimple = IconData(0xe3b4, fontFamily: 'PhosphorBold');
  static const phone = IconData(0xe3b8, fontFamily: 'PhosphorBold');
  static const playCircle = IconData(0xe3d2, fontFamily: 'PhosphorBold');
  static const plus = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const prohibit = IconData(0xe3de, fontFamily: 'PhosphorBold');
  static const question = IconData(0xe3e8, fontFamily: 'PhosphorBold');
  static const receipt = IconData(0xe3ec, fontFamily: 'PhosphorBold');
  static const signOut = IconData(0xe42a, fontFamily: 'PhosphorBold');
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorBold');
  static const star = IconData(0xe46a, fontFamily: 'PhosphorBold');
  static const stopCircle = IconData(0xe46e, fontFamily: 'PhosphorBold');
  static const storefront = IconData(0xe470, fontFamily: 'PhosphorBold');
  static const tag = IconData(0xe478, fontFamily: 'PhosphorBold');
  static const target = IconData(0xe47c, fontFamily: 'PhosphorBold');
  static const ticket = IconData(0xe490, fontFamily: 'PhosphorBold');
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorBold');
  static const tray = IconData(0xe4aa, fontFamily: 'PhosphorBold');
  static const trendDown = IconData(0xe4ac, fontFamily: 'PhosphorBold');
  static const trendUp = IconData(0xe4ae, fontFamily: 'PhosphorBold');
  static const userCircle = IconData(0xe4c4, fontFamily: 'PhosphorBold');
  static const usersThree = IconData(0xe68e, fontFamily: 'PhosphorBold');
  static const whatsappLogo = IconData(0xe5d0, fontFamily: 'PhosphorBold');
  static const wifiSlash = IconData(0xe4f2, fontFamily: 'PhosphorBold');
  static const x = IconData(0xe4f6, fontFamily: 'PhosphorBold');
}

/// Os três pesos do Phosphor usam os mesmos codepoints: só muda a fonte.
/// Serve para pedir outro peso de um glifo recebido por parâmetro, quando
/// o tamanho só é conhecido dentro do componente (ver `kit.dart`).
extension PhosphorWeight on IconData {
  // ignore: non_const_argument_for_const_parameter
  IconData get bold => IconData(codePoint, fontFamily: 'PhosphorBold');
  // ignore: non_const_argument_for_const_parameter
  IconData get fill => IconData(codePoint, fontFamily: 'PhosphorFill');
}
