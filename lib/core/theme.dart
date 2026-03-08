import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const darkBg = Color(0xFF0A0B0F);
  static const darkSurface = Color(0xFF12141A);
  static const darkSurfaceAlt = Color(0xFF1A1D26);
  static const darkBorder = Color(0xFF252836);
  static const darkCard = Color(0xFF15171F);
  static const darkSidebar = Color(0xFF0E1016);
  static const darkText = Color(0xFFF0F2FF);
  static const darkTextSub = Color(0xFF8B8FA8);
  static const darkTextMuted = Color(0xFF4A4E67);

  static const lightBg = Color(0xFFF4F5FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEEF0FF);
  static const lightBorder = Color(0xFFE2E5F0);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF0D0F1E);
  static const lightTextSub = Color(0xFF5A5E78);
  static const lightTextMuted = Color(0xFF9EA3BB);

  static const accent = Color(0xFF6C63FF);
  static const accentAlt = Color(0xFFFF6584);
  static const accentGreen = Color(0xFF00D4A1);
  static const accentAmber = Color(0xFFFFB347);
  static const accentOrange = Color(0xFFFF8A65);
  static const codeBg = Color(0xFF0D0F15);
  static const codeText = Color(0xFFA8B2D8);
}

class AppTheme {
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    bg: AppColors.darkBg,
    surface: AppColors.darkSurface,
    surfaceAlt: AppColors.darkSurfaceAlt,
    border: AppColors.darkBorder,
    primary: AppColors.darkText,
    secondary: AppColors.darkTextSub,
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surfaceAlt: AppColors.lightSurfaceAlt,
    border: AppColors.lightBorder,
    primary: AppColors.lightText,
    secondary: AppColors.lightTextSub,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
    required Color primary,
    required Color secondary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        secondary: AppColors.accentAlt,
        onSecondary: Colors.white,
        error: AppColors.accentAlt,
        onError: Colors.white,
        surface: surface,
        onSurface: primary,
      ),
      cardColor: surface,
      dividerColor: border,
      textTheme: _textTheme(primary, secondary),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: secondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color p, Color s) => TextTheme(
    displayLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.w800, color: p),
    displayMedium: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: p),
    displaySmall: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: p),
    headlineLarge: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: p),
    headlineMedium: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: p),
    headlineSmall: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: p),
    titleLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: p),
    titleMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: p),
    titleSmall: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: p),
    bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: p),
    bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: s),
    bodySmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: s),
    labelLarge: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: p),
    labelMedium: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: s),
    labelSmall: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, color: s),
  );
}
