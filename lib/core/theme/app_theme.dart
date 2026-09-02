import 'package:flutter/material.dart';

/// Forgo's brand: black canvas, violet accent, bold condensed type — the
/// same register as premium fitness-app dark UIs (big glowing numbers,
/// pill chips, bento-grid dashboards) rather than a generic Material dark
/// theme. There is deliberately no light theme: black is the brand, not a
/// mode.
class AppColors {
  AppColors._();

  // Canvas
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121016); // card background
  static const surfaceElevated = Color(0xFF1B1822); // raised / hero card
  static const surfaceBorder = Color(0xFF2A2732);

  // Accent — violet, with a lighter glow variant for gradients/shadows
  static const accent = Color(0xFF8B5CF6);
  static const accentBright = Color(0xFFB794F6);
  static const accentDim = Color(0xFF4C2E8C);

  // Text
  static const textPrimary = Color(0xFFF5F3F7);
  static const textSecondary = Color(0xFFA6A2AF);
  static const textMuted = Color(0xFF6F6C79);

  // Status
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFF6D28D9)],
  );
}

/// Builds a [TextStyle] against the bundled Manrope variable font
/// (`assets/fonts/Manrope-Variable.ttf`, registered per-weight in
/// pubspec.yaml) rather than fetching it from Google's font CDN at
/// runtime — one less network dependency on first launch.
TextStyle _manrope({
  required double fontSize,
  required FontWeight fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Manrope',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.background,
        primary: AppColors.accent,
        secondary: AppColors.accentBright,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
    );

    final textTheme = base.textTheme
        .apply(
          fontFamily: 'Manrope',
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineMedium: _manrope(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          headlineSmall: _manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
          titleLarge: _manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          titleMedium: _manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          bodyMedium: _manrope(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          bodySmall: _manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
          labelLarge: _manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _manrope(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: AppColors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // No Size.fromHeight here: unlike the primary ElevatedButton (always
        // stretched full-width in a Column), TextButtons are also used
        // inline inside Rows (e.g. "Already have an account? Log in"), and
        // Size.fromHeight's infinite width breaks that layout.
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentBright,
          minimumSize: const Size(0, 44),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.surfaceBorder),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentDim,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall?.copyWith(
            color: selected ? AppColors.accentBright : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accentBright : AppColors.textMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentDim,
        selectedLabelTextStyle: const TextStyle(color: AppColors.accentBright),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.textMuted),
        selectedIconTheme: const IconThemeData(color: AppColors.accentBright),
        unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceElevated,
        headerBackgroundColor: AppColors.accent,
        headerForegroundColor: Colors.white,
        todayForegroundColor: WidgetStateProperty.all(AppColors.accentBright),
      ),
    );
  }
}
