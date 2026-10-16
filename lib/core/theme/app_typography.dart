import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale taken from the Figma screens: DM Sans for titles and the
/// logotype, Hanken Grotesk for body, buttons and labels.
abstract final class AppType {
  static TextStyle display({Color color = AppColors.cinza900, double size = 32}) => GoogleFonts.dmSans(
    fontSize: size,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -size / 100,
    color: color,
  );

  static TextStyle title({Color color = AppColors.cinza900}) =>
      GoogleFonts.dmSans(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.24, color: color);

  static TextStyle cardTitle({Color color = AppColors.cinza800, double size = 16}) => GoogleFonts.dmSans(
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -size / 100,
    color: color,
  );

  static TextStyle body({Color color = AppColors.cinza600, double size = 16}) => GoogleFonts.hankenGrotesk(
    fontSize: size,
    height: 1.4,
    fontWeight: FontWeight.w400,
    letterSpacing: size == 16 ? 0 : -size / 100,
    color: color,
  );

  static TextStyle label({Color color = AppColors.cinza800, double size = 16}) => GoogleFonts.hankenGrotesk(
    fontSize: size,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: -size / 100,
    color: color,
  );

  static TextStyle strong({Color color = AppColors.cinza900, double size = 12}) =>
      GoogleFonts.hankenGrotesk(fontSize: size, height: 1.1, fontWeight: FontWeight.w700, color: color);

  static TextStyle logotype(double size, double tracking) => GoogleFonts.dmSans(
    fontSize: size,
    height: 1.0,
    fontWeight: FontWeight.w400,
    letterSpacing: tracking,
    color: AppColors.white,
  );
}
