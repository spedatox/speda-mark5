import 'package:flutter/material.dart';

/// JARVIS-inspired color palette from Iron Man 2 UI concepts
class JarvisColors {
  JarvisColors._();

  // Primary cyan/teal colors
  static const Color primary = Color(0xFF00D4FF);
  static const Color primaryDark = Color(0xFF0099CC);
  static const Color primaryLight = Color(0xFF66E5FF);

  // Accent colors
  static const Color accent = Color(0xFF00FF88);
  static const Color warning = Color(0xFFFF6B35);
  static const Color danger = Color(0xFFFF3366);
  static const Color success = Color(0xFF00FF88);

  // Background colors - deep dark blues
  static const Color background = Color(0xFF0A0E14);
  static const Color backgroundLight = Color(0xFF0D1117);
  static const Color surface = Color(0xFF111921);
  static const Color surfaceLight = Color(0xFF1A2332);

  // Panel colors with transparency
  static const Color panelBackground = Color(0xDD0D1520);
  static const Color panelBorder = Color(0xFF1E3A4C);
  static const Color panelHighlight = Color(0xFF00D4FF);

  // Text colors
  static const Color textPrimary = Color(0xFFE8F4F8);
  static const Color textSecondary = Color(0xFF7AA2B3);
  static const Color textMuted = Color(0xFF4A6670);

  // Glow colors for effects
  static const Color glowCyan = Color(0xFF00D4FF);
  static const Color glowTeal = Color(0xFF00A8A8);
  static const Color glowBlue = Color(0xFF0066FF);

  // Grid and line colors
  static const Color gridLine = Color(0xFF1E3040);
  static const Color gridLineBright = Color(0xFF2A4050);

  // Status colors
  static const Color online = Color(0xFF00FF88);
  static const Color offline = Color(0xFF666666);
  static const Color processing = Color(0xFF00D4FF);
}

/// JARVIS-inspired theme data
class JarvisTheme {
  JarvisTheme._();

  /// Font family for all JARVIS UI text
  static const String fontFamily = 'FSIndustrieCd';

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: JarvisColors.primary,
        secondary: JarvisColors.accent,
        surface: JarvisColors.surface,
        error: JarvisColors.danger,
        onPrimary: JarvisColors.background,
        onSecondary: JarvisColors.background,
        onSurface: JarvisColors.textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: JarvisColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: JarvisColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w600, // SemiBold
          letterSpacing: 3,
        ),
      ),
      cardTheme: CardThemeData(
        color: JarvisColors.panelBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: JarvisColors.panelBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JarvisColors.surface.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: JarvisColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: JarvisColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: JarvisColors.primary, width: 1),
        ),
        hintStyle: const TextStyle(color: JarvisColors.textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: JarvisColors.primary.withOpacity(0.2),
          foregroundColor: JarvisColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: JarvisColors.primary),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: JarvisColors.primary,
        ),
      ),
      iconTheme: const IconThemeData(
        color: JarvisColors.primary,
        size: 22,
      ),
      dividerTheme: const DividerThemeData(
        color: JarvisColors.panelBorder,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: JarvisColors.surface.withOpacity(0.95),
        selectedItemColor: JarvisColors.primary,
        unselectedItemColor: JarvisColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        // Display / hero
        displayLarge: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 57,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 2.5,
        ),
        displayMedium: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 45,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 2,
        ),
        displaySmall: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 1.2,
        ),
        // Headlines
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.primary,
          fontSize: 32,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 2,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 1.5,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 1,
        ),
        // Titles
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 1.1,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 0.6,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 0.4,
        ),
        // Body
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 0.25,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 0.2,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600, // SemiBold
          letterSpacing: 0.15,
        ),
        // Labels / buttons
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 1.4,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w800, // ExtraBold
          letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          color: JarvisColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700, // Bold
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
