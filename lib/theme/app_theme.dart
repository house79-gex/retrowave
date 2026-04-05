import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette allineata alla preview HTML RetroWave.
abstract class AppColors {
  static const Color bg = Color(0xFF0A0B0E);
  static const Color s1 = Color(0xFF111318);
  static const Color s2 = Color(0xFF181B22);
  static const Color s3 = Color(0xFF1E2229);
  static const Color border = Color(0xFF252A35);
  static const Color border2 = Color(0xFF2E3440);
  static const Color acc = Color(0xFFF5C518);
  static const Color acc2 = Color(0xFFFF6B35);
  static const Color purple = Color(0xFF7C6FF7);
  static const Color text = Color(0xFFECEEF2);
  static const Color muted = Color(0xFF5A6072);
  static const Color muted2 = Color(0xFF7A8399);
  static const Color green = Color(0xFF22D3A0);
  static const Color red = Color(0xFFFF5F5F);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.dark(
        surface: AppColors.s1,
        primary: AppColors.acc,
        secondary: AppColors.acc2,
        tertiary: AppColors.purple,
        onSurface: AppColors.text,
        onPrimary: AppColors.bg,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.s1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.s2,
        contentTextStyle: GoogleFonts.syne(color: AppColors.text),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }

  static TextStyle mono(double size, {Color? color, FontWeight? weight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color ?? AppColors.muted2,
      fontWeight: weight ?? FontWeight.w400,
    );
  }
}
