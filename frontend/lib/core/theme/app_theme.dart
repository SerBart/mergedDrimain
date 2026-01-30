import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Nowoczesna paleta - jasne kolory z głębią i stylem
  static const Color _primaryBlue = Color(0xFF0EA5E9);      // Niebieski sky
  static const Color _primaryBlueDark = Color(0xFF0284C7);  // Ciemniejszy niebieski
  static const Color _accentPurple = Color(0xFF7C3AED);     // Fioletowy akcent
  static const Color _accentPink = Color(0xFFEC4899);       // Różowy akcent
  static const Color _successGreen = Color(0xFF10B981);     // Zielony
  static const Color _warningAmber = Color(0xFFF59E0B);     // Pomarańcz
  static const Color _bgLight = Color(0xFFF8FAFC);          // Białawe tło
  static const Color _bgLighter = Color(0xFFFFFFFF);        // Białe
  static const Color _bgCard = Color(0xFFFFFFFF);           // Białe karty
  static const Color _textDark = Color(0xFF0F172A);         // Ciemny tekst
  static const Color _textMuted = Color(0xFF64748B);        // Przyćmiony tekst
  static const Color _borderLight = Color(0xFFE2E8F0);      // Jasne obramowania

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
      primary: _primaryBlue,
      secondary: _accentPurple,
      tertiary: _successGreen,
      surface: _bgCard,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      bodySmall: GoogleFonts.inter(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(color: _textDark, fontSize: 14, fontWeight: FontWeight.w400),
      bodyLarge: GoogleFonts.inter(color: _textDark, fontSize: 15, fontWeight: FontWeight.w400),
      labelSmall: GoogleFonts.inter(color: _textMuted, fontWeight: FontWeight.w500, fontSize: 12),
      labelMedium: GoogleFonts.inter(color: _textDark, fontWeight: FontWeight.w600, fontSize: 13),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: _textDark),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: _textDark),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: _textDark),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 22, color: _textDark),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 26, color: _textDark),
      headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 32, color: _textDark),
    );

    return base.copyWith(
      scaffoldBackgroundColor: _bgLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _bgCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _borderLight.withOpacity(0.6),
            width: 1,
          ),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w500, fontSize: 14),
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderLight.withOpacity(0.5), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderLight.withOpacity(0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
          elevation: 0,
          shadowColor: _primaryBlue.withOpacity(0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBlue,
          side: const BorderSide(color: _primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _borderLight.withOpacity(0.5),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _bgCard,
        selectedColor: _primaryBlue.withOpacity(0.15),
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _borderLight.withOpacity(0.6), width: 1),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_primaryBlue.withOpacity(0.08)),
        headingRowHeight: 58,
        dataRowColor: WidgetStateProperty.all(Colors.white),
        dataRowHeight: 58,
        headingTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerThickness: 1,
        columnSpacing: 28,
        horizontalMargin: 16,
        decoration: BoxDecoration(
          border: Border.all(color: _borderLight.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() => light(); // Używamy light mode dla obu
}
