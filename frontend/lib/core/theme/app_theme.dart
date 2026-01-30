import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Jasna, nowoczesna paleta kolorów - tylko jasne odcienie
  static const Color _primaryBlue = Color(0xFF2563EB);      // Jasny niebieski
  static const Color _accentOrange = Color(0xFFF97316);    // Jasny pomarańcz
  static const Color _successGreen = Color(0xFF16A34A);    // Jasny zielony
  static const Color _warningAmber = Color(0xFFEAB308);    // Jasny bursztyn
  static const Color _bgLight = Color(0xFFFAFAFA);         // Białawe tło
  static const Color _bgCard = Color(0xFFFFFFFF);          // Białe karty
  static const Color _textDark = Color(0xFF1F2937);        // Ciemny tekst
  static const Color _textMuted = Color(0xFF6B7280);       // Przyćmiony tekst
  static const Color _borderLight = Color(0xFFE5E7EB);     // Jasne obramowania

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
      primary: _primaryBlue,
      secondary: _accentOrange,
      surface: _bgCard,
      tertiary: _successGreen,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      bodySmall: GoogleFonts.inter(color: _textMuted, fontSize: 13),
      bodyMedium: GoogleFonts.inter(color: _textDark, fontSize: 14),
      bodyLarge: GoogleFonts.inter(color: _textDark, fontSize: 15),
      labelSmall: GoogleFonts.inter(color: _textMuted, fontWeight: FontWeight.w500, fontSize: 12),
      labelMedium: GoogleFonts.inter(color: _textDark, fontWeight: FontWeight.w600, fontSize: 13),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: _textDark),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: _textDark),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: _textDark),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 22, color: _textDark),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 26, color: _textDark),
      headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 32, color: _textDark),
    );

    return base.copyWith(
      scaffoldBackgroundColor: _bgLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
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
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderLight, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _bgCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: _textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBlue,
          side: const BorderSide(color: _primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _borderLight,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _bgCard,
        selectedColor: _primaryBlue,
        labelStyle: const TextStyle(color: _textDark, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _borderLight, width: 1),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F4F6)),
        headingRowHeight: 56,
        dataRowColor: WidgetStateProperty.all(Colors.white),
        dataRowHeight: 56,
        headingTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dataTextStyle: GoogleFonts.inter(
          color: _textDark,
          fontSize: 13,
        ),
        dividerThickness: 1,
        columnSpacing: 24,
        horizontalMargin: 16,
      ),
    );
  }

  static ThemeData dark() {
    // W ciemnym trybie też używamy jasnych, ciepłych kolorów gdzie to możliwe
    final scheme = ColorScheme.fromSeed(
      seedColor: _primaryBlue,
      brightness: Brightness.light,
      primary: _primaryBlue,
      secondary: _accentOrange,
      surface: _bgCard,
      tertiary: _successGreen,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
    );

    // Dla dark mode - używamy tego samego light theme
    // Jeśli chcesz wprowadzić dark mode, możemy to zmienić później
    return light();
  }
}
