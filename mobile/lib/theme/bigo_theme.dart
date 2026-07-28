import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Neon Night Live palette — charcoal stage + electric cyan + coral heat.
/// Kept as [BigoColors] so existing imports keep working while the look
/// moves away from the old purple “AI dark” theme.
abstract final class BigoColors {
  static const primary = Color(0xFF00E5C8);
  static const primaryDeep = Color(0xFF00B39A);
  static const accent = Color(0xFF5B8CFF);
  static const hot = Color(0xFFFF4D6A);
  static const teal = Color(0xFF00E5C8);

  static const bg = Color(0xFF070A0F);
  static const bgElevated = Color(0xFF0E141C);
  static const bgCard = Color(0xFF121A24);
  static const surface = Color(0xFF1A2433);

  static const textPrimary = Color(0xFFF4F7FB);
  static const textSecondary = Color(0x99F4F7FB);

  static const appGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0B1220),
      Color(0xFF070A0F),
      Color(0xFF05070B),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4D6A), Color(0xFFFF7A45)],
  );

  static const liveGradient = LinearGradient(
    colors: [Color(0xFFFF4D6A), Color(0xFFFF2D55)],
  );
}

ThemeData buildBigoTheme() {
  final display = GoogleFonts.spaceGroteskTextTheme();
  final body = GoogleFonts.dmSansTextTheme();

  const scheme = ColorScheme.dark(
    primary: BigoColors.primary,
    onPrimary: Color(0xFF041411),
    secondary: BigoColors.accent,
    onSecondary: Colors.white,
    tertiary: BigoColors.hot,
    surface: BigoColors.bgElevated,
    onSurface: BigoColors.textPrimary,
    error: BigoColors.hot,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: BigoColors.bg,
    canvasColor: BigoColors.bg,
    dividerColor: Colors.white12,
    textTheme: body
        .apply(
          bodyColor: BigoColors.textPrimary,
          displayColor: BigoColors.textPrimary,
        )
        .copyWith(
          displayLarge: display.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: BigoColors.textPrimary,
          ),
          displayMedium: display.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: BigoColors.textPrimary,
          ),
          headlineLarge: display.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: BigoColors.textPrimary,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: BigoColors.textPrimary,
          ),
          titleLarge: display.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: BigoColors.textPrimary,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: BigoColors.textPrimary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      centerTitle: true,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        color: BigoColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: BigoColors.bgElevated,
      selectedItemColor: BigoColors.primary,
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BigoColors.hot,
      foregroundColor: Colors.white,
      elevation: 6,
    ),
    cardTheme: CardThemeData(
      color: BigoColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: BigoColors.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BigoColors.primary,
        foregroundColor: const Color(0xFF041411),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BigoColors.surface,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BigoColors.primary,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      textColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: Colors.white12),
  );
}
