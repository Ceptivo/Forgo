import 'package:flutter/material.dart';

/// Forgo's brand: clean white/light-gray canvas, bold black UI elements
/// (pill buttons, floating nav dock, big numbers), and a single mint-green
/// accent — the same register as premium light-mode product dashboards
/// and onboarding flows (Outfit type, generous rounding, black pills).
class AppColors {
  AppColors._();

  // Canvas
  static const background = Color(0xFFF6F6F6);
  static const surface = Color(0xFFFFFFFF); // card background
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceBorder = Color(0xFFEBEBEB);
  static const surfaceMuted = Color(0xFFF1F1F1); // input fill, ticks

  // Black — the UI's primary "ink" color: pill buttons, nav dock, headlines
  static const ink = Color(0xFF000000);
  static const inkSoft = Color(0xFF1A1A1A);

  // Accent — mint green
  static const accent = Color(0xFF76FB91);
  // ~4.1:1 against `background` — darker than a pure brand green so link/
  // icon text stays legible, not just decorative.
  static const accentDeep = Color(0xFF178A3D);
  static const accentDim = Color(0xFFE3FDE9); // faint fill/tint

  // Text — both grays are picked for ≥4.5:1 contrast against `background`
  // (WCAG AA for normal-size text). The old values (#8A8A8A / #BFBFBF)
  // read as faint/washed-out on the off-white canvas; these keep the same
  // hierarchy (secondary darker than muted) while staying readable.
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF5C5C5C);
  static const textMuted = Color(0xFF6A6A6A);

  // Status
  static const success = accentDeep;
  static const danger = Color(0xFFE5484D);
  static const warning = Color(0xFFF5A623);

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB9FEC7), accent],
  );
}

/// Builds a [TextStyle] against the bundled Outfit variable font
/// (`assets/fonts/Outfit-Variable.ttf`, registered per-weight in
/// pubspec.yaml) rather than fetching it from Google's font CDN at
/// runtime — one less network dependency on first launch.
TextStyle _outfit({
  required double fontSize,
  required FontWeight fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Outfit',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        surface: AppColors.background,
        primary: AppColors.ink,
        secondary: AppColors.accentDeep,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
        onPrimary: Colors.white,
      ),
    );

    final textTheme = base.textTheme
        .apply(
          fontFamily: 'Outfit',
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          headlineMedium: _outfit(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          headlineSmall: _outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
          titleLarge: _outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: _outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          bodySmall: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
          labelLarge: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
        // Material 3 default: the app bar tints/darkens once content has
        // scrolled underneath it. Forgo's app bars sit flush with the
        // page background, so that tint just reads as an unwanted grey
        // flash rather than a deliberate elevation change.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: _outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.ink, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        // No Size.fromHeight here: unlike the primary ElevatedButton (always
        // stretched full-width in a Column), TextButtons are also used
        // inline inside Rows (e.g. "Already have an account? Log in"), and
        // Size.fromHeight's infinite width breaks that layout.
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentDeep,
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
        backgroundColor: AppColors.ink,
        indicatorColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall?.copyWith(
            color: selected ? AppColors.ink : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.ink : Colors.white70,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentDim,
        selectedLabelTextStyle: const TextStyle(color: AppColors.accentDeep),
        unselectedLabelTextStyle: const TextStyle(color: AppColors.textMuted),
        selectedIconTheme: const IconThemeData(color: AppColors.accentDeep),
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
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: Colors.white,
        todayForegroundColor: WidgetStateProperty.all(AppColors.accentDeep),
      ),
    );
  }
}
