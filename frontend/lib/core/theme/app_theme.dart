import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Nowoczesna, głęboka paleta kolorów - bardziej dojrzała i eleganckaa
  static const Color _primaryBlue = Color(0xFF0369A1);       // Głębszy sky blue
  static const Color _primaryBlueLighter = Color(0xFF0284C7); // Jaśniejszy wariant
  static const Color _accentIndigo = Color(0xFF4338CA);      // Indygo dla głębi
  static const Color _accentCyan = Color(0xFF06B6D4);        // Cyan dla akcenty
  static const Color _successGreen = Color(0xFF059669);      // Ciemniejszy zielony
  static const Color _warningAmber = Color(0xFFD97706);      // Ciemniejszy pomarańcz
  static const Color _errorRed = Color(0xFFDC2626);          // Czerwony
  static const Color _bgDark = Color(0xFFF1F5F9);            // Jasnoszara baza
  static const Color _bgCard = Color(0xFFFFFFFF);            // Białe karty
  static const Color _textDark = Color(0xFF0F172A);          // Bardzo ciemny tekst
  static const Color _textMuted = Color(0xFF475569);         // Przyćmiony tekst
  static const Color _borderMuted = Color(0xFFCBD5E1);       // Ciemniejsze obramowania

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
      primary: _primaryBlue,
      secondary: _accentIndigo,
      tertiary: _accentCyan,
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
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: _textDark),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: _textDark),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: _textDark, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 22, color: _textDark),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 26, color: _textDark, letterSpacing: -0.5),
      headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 32, color: _textDark, letterSpacing: -0.5),
    );

    return base.copyWith(
      scaffoldBackgroundColor: _bgDark,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: _primaryBlue.withOpacity(0.2),
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _bgCard,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _borderMuted.withOpacity(0.4),
            width: 1.2,
          ),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w600, fontSize: 14),
        hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
        prefixIconColor: _textMuted,
        suffixIconColor: _textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderMuted.withOpacity(0.4), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _borderMuted.withOpacity(0.4), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _errorRed, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _errorRed, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
          elevation: 2,
          shadowColor: _primaryBlue.withOpacity(0.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBlue,
          side: const BorderSide(color: _primaryBlue, width: 1.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: _borderMuted.withOpacity(0.3),
        thickness: 1.2,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _bgCard,
        selectedColor: _primaryBlue.withOpacity(0.12),
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w600, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderMuted.withOpacity(0.5), width: 1.2),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_primaryBlue.withOpacity(0.06)),
        headingRowHeight: 62,
        dataRowColor: WidgetStateProperty.all(_bgCard),
        dataRowHeight: 62,
        headingTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        dividerThickness: 1.2,
        columnSpacing: 32,
        horizontalMargin: 20,
        decoration: BoxDecoration(
          border: Border.all(color: _borderMuted.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData dark() => light();
}
