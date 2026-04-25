import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette RetroWave — toni piu morbidi e contrasto leggibile.
abstract class AppColors {
  static const Color bg = Color(0xFF07080C);
  static const Color bgGradientEnd = Color(0xFF0E1018);
  static const Color s1 = Color(0xFF12151C);
  static const Color s2 = Color(0xFF1A1E28);
  static const Color s3 = Color(0xFF222833);
  static const Color border = Color(0xFF2A3140);
  static const Color border2 = Color(0xFF343B4D);
  static const Color acc = Color(0xFFF0C84C);
  static const Color accSoft = Color(0x33F0C84C);
  static const Color acc2 = Color(0xFFFF7A5C);
  static const Color purple = Color(0xFF9B8CFF);
  static const Color cyan = Color(0xFF5CE1E6);
  static const Color text = Color(0xFFF2F4F8);
  static const Color muted = Color(0xFF6B7289);
  static const Color muted2 = Color(0xFF8B93A8);
  static const Color green = Color(0xFF34D399);
  static const Color red = Color(0xFFFF6B6B);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.dark(
        surface: AppColors.s1,
        surfaceContainerHighest: AppColors.s2,
        primary: AppColors.acc,
        secondary: AppColors.acc2,
        tertiary: AppColors.cyan,
        onSurface: AppColors.text,
        onPrimary: AppColors.bg,
        outline: AppColors.border,
      ),
    );

    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: jakarta.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.s1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.s2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.text),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xE812151C),
        indicatorColor: AppColors.accSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.acc : AppColors.muted,
          );
        }),
      ),
    );
  }

  static TextStyle mono(double size, {Color? color, FontWeight? weight}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      color: color ?? AppColors.muted2,
      fontWeight: weight ?? FontWeight.w400,
    );
  }

  /// Titolo schermata (Syne, impatto retro).
  static TextStyle displayTitle({double size = 28, Color? accent}) {
    return GoogleFonts.syne(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.05,
      color: accent ?? AppColors.text,
    );
  }
}
