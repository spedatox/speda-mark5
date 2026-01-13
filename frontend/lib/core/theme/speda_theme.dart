import 'package:flutter/material.dart';

/// Ultra-minimal 2026 design system for Speda
/// Philosophy: Apple-level simplicity with subtle tech hints

class SpedaColors {
  SpedaColors._();

  // Core backgrounds - deep, rich blacks
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF121216);
  static const Color surfaceLight = Color(0xFF1A1A1F);
  static const Color surfaceElevated = Color(0xFF222228);

  // Primary accent - refined cyan
  static const Color primary = Color(0xFF00C8FF);
  static const Color primaryMuted = Color(0xFF0099CC);
  static const Color primarySubtle = Color(0xFF003344);

  // Semantic colors
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFCC00);
  static const Color error = Color(0xFFFF3B30);

  // Text hierarchy
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF48484A);

  // Borders & dividers
  static const Color border = Color(0xFF2C2C2E);
  static const Color borderSubtle = Color(0xFF1C1C1E);

  // User message accent (warm contrast)
  static const Color userAccent = Color(0xFF0A84FF);
}

/// Minimal design tokens
class SpedaSpacing {
  SpedaSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class SpedaRadius {
  SpedaRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 100;
}

/// Typography - clean, modern
class SpedaTypography {
  SpedaTypography._();

  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    color: SpedaColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: SpedaColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: SpedaColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: SpedaColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: SpedaColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: SpedaColors.textTertiary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: SpedaColors.textSecondary,
  );
}

/// Main theme
class SpedaTheme {
  SpedaTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: SpedaTypography.fontFamily,

      // Colors
      colorScheme: const ColorScheme.dark(
        primary: SpedaColors.primary,
        secondary: SpedaColors.userAccent,
        surface: SpedaColors.surface,
        error: SpedaColors.error,
        onPrimary: SpedaColors.background,
        onSecondary: Colors.white,
        onSurface: SpedaColors.textPrimary,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: SpedaColors.background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SpedaColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: SpedaTypography.title,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SpedaColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpedaRadius.xl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpedaRadius.xl),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SpedaRadius.xl),
          borderSide: const BorderSide(color: SpedaColors.primary, width: 1),
        ),
        hintStyle: SpedaTypography.body.copyWith(color: SpedaColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SpedaSpacing.lg,
          vertical: SpedaSpacing.md,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: SpedaColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SpedaRadius.lg),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SpedaColors.primary,
          foregroundColor: SpedaColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: SpedaSpacing.lg,
            vertical: SpedaSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SpedaRadius.xl),
          ),
          textStyle: SpedaTypography.label.copyWith(
            fontWeight: FontWeight.w600,
            color: SpedaColors.background,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: SpedaColors.primary,
          textStyle: SpedaTypography.label,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: SpedaColors.textSecondary,
        size: 22,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: SpedaColors.border,
        thickness: 0.5,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpedaColors.surface,
        selectedItemColor: SpedaColors.primary,
        unselectedItemColor: SpedaColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: SpedaTypography.displayLarge,
        headlineMedium: SpedaTypography.heading,
        titleLarge: SpedaTypography.title,
        bodyLarge: SpedaTypography.body,
        bodyMedium: SpedaTypography.bodySmall,
        labelLarge: SpedaTypography.label,
        bodySmall: SpedaTypography.caption,
      ),
    );
  }
}

/// Minimal reusable widgets
class SpedaWidgets {
  SpedaWidgets._();

  /// Simple status dot
  static Widget statusDot({bool isOnline = true, double size = 8}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? SpedaColors.success : SpedaColors.textTertiary,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Subtle divider
  static Widget divider({double indent = 0}) {
    return Container(
      height: 0.5,
      margin: EdgeInsets.symmetric(horizontal: indent),
      color: SpedaColors.borderSubtle,
    );
  }

  /// Action chip/pill button
  static Widget actionPill({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SpedaSpacing.md,
          vertical: SpedaSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isActive ? SpedaColors.primarySubtle : SpedaColors.surfaceLight,
          borderRadius: BorderRadius.circular(SpedaRadius.full),
          border: Border.all(
            color: isActive ? SpedaColors.primary.withOpacity(0.3) : SpedaColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive ? SpedaColors.primary : SpedaColors.textSecondary,
              ),
              const SizedBox(width: SpedaSpacing.xs + 2),
            ],
            Text(
              label,
              style: SpedaTypography.label.copyWith(
                color: isActive ? SpedaColors.primary : SpedaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
