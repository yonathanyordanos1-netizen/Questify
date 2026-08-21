import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the Questify design v2 system.
/// Modern-Gamified: questOrange #FF6B35 on cool off-white #F7F9FC,
/// Plus Jakarta Sans, flat 24px-radius cards, 5-tab bottom nav.
class AppColors {
  AppColors._();

  // Surfaces (Material 3) — strict light/dark paper per the contrast system.
  // Light paper #FDFBF7, dark slate #0F172A (see `ink`/`inkLight`).
  static const Color canvas = Color(0xFFF8F9FA); // Cal AI off-white background
  static const Color canvasDark = Color(0xFF0F172A); // dark background
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // cards
  static const Color surfaceContainerLow = Color(0xFFF1F5F9); // tiles / pills
  static const Color surfaceContainer = Color(0xFFE8EDF3);
  static const Color surfaceContainerHigh = Color(0xFFE1E8F0);
  static const Color surfaceContainerHighest = Color(0xFFD8E1EB); // tracks

  // Legacy aliases (keep references working, map to v2 surfaces)
  static const Color glassLight = Color(0xFFFFFFFF); // card fill light
  static const Color glassDark = Color(0xFF0F172A); // card fill dark (slate)
  static const Color cardLight = Color(0xFFFFFFFF); // card fill light
  static const Color cardDark = Color(0xFF0F172A); // card fill dark
  static const Color border = Color(0xFFE0E3E6); // surface-variant divider
  static const Color borderDark = Color(0xFF2A3347);
  static const Color glassEdge = Color(0xFFE6E8EB); // hairline card border
  static const Color glassEdgeDark = Color(0xFF33405C);
  static const Color outlineVariant = Color(0xFFE1BFB5); // warm outline-variant

  /// Glassmorphic backdrop fills at ~90% opacity (0xE6) so text layered over
  /// dynamic gradient backgrounds stays 100% crisp while the backdrop still
  /// glows through. Used by every [LiquidGlassCard].
  static const Color glassBackingLight = Color(0xE6FFFFFF);
  static const Color glassBackingDark = Color(0xE60F172A);

  // Brand (v2 primary scale)
  static const Color primary = Color(0xFFFF6B35); // primary-container / questOrange
  static const Color primaryDeep = Color(0xFFAB3500); // primary (deep orange)
  static const Color primarySoft = Color(0xFFFFDBD0); // primary-fixed
  static const Color primaryFixedDim = Color(0xFFFFB59D); // light orange
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF5F1900);

  // Semantic
  static const Color success = Color(0xFF52B788);
  static const Color accent = Color(0xFF8C9AB1); // tertiary-container slate
  static const Color secondary = Color(0xFF565E74);
  static const Color secondaryContainer = Color(0xFFDAE2FD); // Intellect blue
  static const Color tertiaryContainer = Color(0xFF8C9AB1); // Discipline slate
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // League tiers
  static const Color gold = Color(0xFFFFCC00);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color platinum = Color(0xFFD9E2EC);
  static const Color diamond = Color(0xFF7ECFE6);

  // Text — high-contrast system (WCAG AA+ on both paper tones)
  // Light paper → #0F172A (slate-900); dark slate → #F8FAFC (slate-50)
  static const Color ink = Color(0xFF0F172A); // on-surface light
  static const Color inkLight = Color(0xFFF8FAFC); // on-surface dark
  static const Color muted = Color(0xFF475569); // on-surface-variant light (slate-600)
  static const Color mutedLight = Color(0xFF94A3B8); // outline light (slate-400)
  static const Color mutedLightDark = Color(0xFFCBD5E1); // outline dark (slate-300)

  // Tracks / chips
  static const Color gaugeTrack = Color(0xFFE0E3E6); // surface-container-highest
  static const Color gaugeTrackDark = Color(0xFF3A3E42);
  static const Color chip = Color(0x1A594139); // 10% on-surface-variant
  static const Color chipMuted = Color(0x0D594139);
  static const Color navPill = Color(0xE60F172A); // legacy, unused
}

class AppFonts {
  AppFonts._();

  static final TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.2,
    color: AppColors.ink,
  );

  static final TextStyle headline = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );

  static final TextStyle title = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static final TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.ink,
  );

  static final TextStyle label = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.ink,
  );

  /// Legacy helper used by the onboarding wizard.
  static TextStyle bold({
    required double size,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: color,
      letterSpacing: letterSpacing ?? -0.5,
    );
  }

  static const List<String> categoryNames = ['Fitness', 'Intellect', 'Discipline'];
  static const List<Color> categoryColors = [
    AppColors.primary,
    AppColors.secondaryContainer,
    AppColors.tertiaryContainer,
  ];

  static Color categoryColor(int index) {
    if (index < 0 || index >= categoryColors.length) return AppColors.primary;
    return categoryColors[index];
  }

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.2,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.8,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class AppSpacing {
  AppSpacing._();

  // Radius tokens
  static const double radiusCard = 24; // cards
  static const double radiusSoft = 16; // buttons / bubbles
  static const double radiusSm = 10; // chips / icon tiles
  static const double radiusPill = 100; // full round
  static const double radiusSheet = 28; // top sheets

  // Shadow tokens (v2) — single shadows, wrap in `[...]` at use sites
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x0D0F172A), // 5% slate
    offset: Offset(0, 4),
    blurRadius: 20,
    spreadRadius: 0,
  );
  static const BoxShadow shadowStrong = BoxShadow(
    color: Color(0x140F172A), // 8% slate
    offset: Offset(0, 8),
    blurRadius: 30,
    spreadRadius: 0,
  );
  /// Default card shadow (single layer).
  static const BoxShadow glassShadow = shadow;

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

ThemeData buildAppTheme({
  required Brightness brightness,
  Color? primary,
  double? accentScale,
}) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark ? _darkScheme() : _lightScheme();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
    fontFamily: 'Plus Jakarta Sans',
    textTheme: AppFonts.apply(ThemeData(brightness: brightness).textTheme),
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.inkLight : AppColors.ink,
        size: 24,
      ),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.primary : AppColors.primaryDeep,
        letterSpacing: -0.5,
      ),
      toolbarHeight: 64,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primary.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.primary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColors.glassDark : AppColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.borderDark : AppColors.border,
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return isDark ? AppColors.mutedLightDark : AppColors.mutedLight;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primarySoft;
        return isDark ? AppColors.glassEdgeDark : AppColors.surfaceContainerHigh;
      }),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: isDark ? AppColors.gaugeTrackDark : AppColors.gaugeTrack,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.glassDark : AppColors.surfaceContainerLow,
      hintStyle: TextStyle(color: isDark ? AppColors.mutedLightDark : AppColors.mutedLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
      side: BorderSide(color: AppColors.mutedLight, width: 1.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

ColorScheme _lightScheme() => const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: Color(0xFF5C647A),
      tertiary: Color(0xFF515F74),
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: Color(0xFF243245),
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF93000A),
      surface: AppColors.surfaceContainerLowest,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      outline: AppColors.mutedLight,
      outlineVariant: AppColors.outlineVariant,
      shadow: Color(0x0F0F172A),
      scrim: Color(0xFF191C1E),
      inverseSurface: Color(0xFF2D3133),
      onInverseSurface: Color(0xFFEFF1F4),
    );

ColorScheme _darkScheme() => const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: Color(0xFF832600),
      onPrimaryContainer: Color(0xFFFFDBD0),
      secondary: Color(0xFFC7CEE6),
      onSecondary: Color(0xFF303750),
      secondaryContainer: Color(0xFF3E4759),
      onSecondaryContainer: Color(0xFFDAE2FD),
      tertiary: Color(0xFFB9C7DF),
      onTertiary: Color(0xFF23304A),
      tertiaryContainer: Color(0xFF39455E),
      onTertiaryContainer: Color(0xFFD5E3FC),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF8C1D18),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.glassDark,
      onSurface: AppColors.inkLight,
      onSurfaceVariant: Color(0xFFC9C3BE),
      surfaceContainerLowest: Color(0xFF17191C),
      surfaceContainerLow: Color(0xFF1E2124),
      surfaceContainer: Color(0xFF23262A),
      surfaceContainerHigh: Color(0xFF2A2E33),
      surfaceContainerHighest: Color(0xFF35393E),
      outline: Color(0xFF8D7168),
      outlineVariant: Color(0xFF55443C),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFEFF1F4),
      onInverseSurface: Color(0xFF2D3133),
    );

class AppTheme {
  AppTheme._();

  static ThemeData light() => buildAppTheme(brightness: Brightness.light);

  static ThemeData dark() => buildAppTheme(brightness: Brightness.dark);

  static Brightness of(BuildContext context) => Theme.of(context).brightness;
}
