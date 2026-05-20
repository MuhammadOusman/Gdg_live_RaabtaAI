import 'package:flutter/material.dart';

class RaabtaTheme {
  static const Color pitchBlack = Color(0xFF000000);
  static const Color charcoal = Color(0xFF0F1115);
  static const Color electricBlue = Color(0xFF4A90E2);
  static const Color emeraldGreen = Color(0xFF2ECC71);
  static const Color softGold = Color(0xFFF1C40F);
  static const Color signalRed = Color(0xFFE74C3C);
  static const Color glassWhite = Color(0x0FFFFFFF);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: electricBlue,
      brightness: Brightness.dark,
      primary: electricBlue,
      secondary: emeraldGreen,
      tertiary: softGold,
      surface: charcoal,
      onSurface: Colors.white,
      error: signalRed,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pitchBlack,
      canvasColor: pitchBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: charcoal.withValues(alpha: 0.78),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: charcoal.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: charcoal,
        labelStyle: const TextStyle(color: Colors.white70),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ).copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          height: 1.35,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          height: 1.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: charcoal.withValues(alpha: 0.72),
        elevation: 0,
        indicatorColor: electricBlue.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? electricBlue : Colors.white60,
            size: 20,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.46)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: electricBlue, width: 1.2),
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: charcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
