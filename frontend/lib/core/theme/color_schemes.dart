import 'package:flutter/material.dart';

const seedColor = Color(0xFF2563EB); // Primary bazowy (możesz dać AppColors.primary)

ColorScheme lightScheme = ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: Brightness.light,
  surface: const Color(0xFFF9FAFB),
);

ColorScheme darkScheme = ColorScheme.fromSeed(
  seedColor: seedColor,
  brightness: Brightness.dark,
);

/// Dodatkowe semantyczne kolory (rozszerzenie)
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Gradient brandGradient;

  const SemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.brandGradient,
  });

  @override
  SemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Gradient? brandGradient,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      brandGradient: brandGradient ?? this.brandGradient,
    );
  }

  @override
  ThemeExtension<SemanticColors> lerp(
      covariant ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      brandGradient: LinearGradient(
        colors: [
          Color.lerp(
              (brandGradient as LinearGradient).colors.first,
              (other.brandGradient as LinearGradient).colors.first,
              t)!,
          Color.lerp(
              (brandGradient as LinearGradient).colors.last,
              (other.brandGradient as LinearGradient).colors.last,
              t)!,
        ],
      ),
    );
  }

  static SemanticColors light = const SemanticColors(
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFDC2626),
    info: Color(0xFF0EA5E9),
    brandGradient: LinearGradient(
      colors: [
        Color(0xFF2563EB),
        Color(0xFF9333EA),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static SemanticColors dark = const SemanticColors(
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    info: Color(0xFF38BDF8),
    brandGradient: LinearGradient(
      colors: [
        Color(0xFF3B82F6),
        Color(0xFFA855F7),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}