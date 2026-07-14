import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens d’espacement DUSOL (échelle 4).
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Rayons cohérents avec le web (style.css).
class AppRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get hero => BorderRadius.circular(22);
  static BorderRadius get sheet => BorderRadius.circular(xl);
}

/// Durées / courbes — 2–3 motifs max, réutilisés.
class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 480);
  static const Curve easeOut = Cubic(0.22, 1, 0.36, 1);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1);
}

/// Thème DUSOL — émeraude profond · or champagne · Cormorant + Outfit.
class AppTheme {
  static const Color emerald950 = Color(0xFF061A10);
  static const Color emerald900 = Color(0xFF0D2818);
  static const Color emerald800 = Color(0xFF134E2A);
  static const Color emerald700 = Color(0xFF1B6B3A);
  static const Color emerald600 = Color(0xFF2D8A52);
  static const Color emerald400 = Color(0xFF5CC98A);
  static const Color gold300 = Color(0xFFE8D5A3);
  static const Color gold400 = Color(0xFFD4B872);
  static const Color gold500 = Color(0xFFC9A962);
  static const Color cream = Color(0xFFFAF8F3);
  static const Color cream2 = Color(0xFFF3EFE6);
  static const Color sand = Color(0xFFE8E2D4);

  static const Color primary = emerald900;
  static const Color accent = gold500;
  static const Color surface = Color(0xFF1A3D2E);
  static const Color card = Color(0xFF243D32);

  /// Noms pour TextStyle(fontFamily:) — résolus via GoogleFonts.
  static const String fontDisplay = 'Cormorant Garamond';
  static const String fontUi = 'Outfit';

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emerald900, emerald950, Color(0xFF1A2F24)],
  );

  static const LinearGradient ambientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A2418), emerald950],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: 0.2,
      );

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.35,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.outfit(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextTheme _textTheme(Brightness brightness) {
    final on =
        brightness == Brightness.dark ? const Color(0xFFF5F7F4) : const Color(0xFF0F1419);
    final muted =
        brightness == Brightness.dark ? const Color(0xB3F5F7F4) : const Color(0x990F1419);
    final displayColor =
        brightness == Brightness.dark ? gold300 : emerald900;

    final base = GoogleFonts.outfitTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return base.copyWith(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: displayColor,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: displayColor,
        height: 1.15,
      ),
      displaySmall: GoogleFonts.cormorantGaramond(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: displayColor,
        height: 1.2,
      ),
      headlineLarge: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: displayColor,
      ),
      headlineSmall: GoogleFonts.cormorantGaramond(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: on,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: on,
        letterSpacing: 0.15,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: on,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: on,
      ),
      bodyLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: on),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: on),
      bodySmall: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: muted),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: on,
        letterSpacing: 0.3,
      ),
      labelMedium: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
      labelSmall: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: muted,
        letterSpacing: 0.4,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: gold500,
      onPrimary: emerald950,
      primaryContainer: emerald800,
      onPrimaryContainer: gold300,
      secondary: emerald400,
      onSecondary: emerald950,
      secondaryContainer: emerald800,
      onSecondaryContainer: cream,
      tertiary: gold400,
      onTertiary: emerald950,
      error: const Color(0xFFFF8A80),
      onError: emerald950,
      surface: surface,
      onSurface: const Color(0xFFF5F7F4),
      surfaceContainerHighest: card,
      outline: const Color(0x33FFFFFF),
      outlineVariant: const Color(0x22FFFFFF),
    );
    final textTheme = _textTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: emerald950,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: gold300,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium?.copyWith(color: gold300),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold500,
          foregroundColor: emerald950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(color: emerald950),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold300,
          side: const BorderSide(color: Color(0x66C9A962)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold300),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold500,
        foregroundColor: emerald950,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E332A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 4),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 4),
          borderSide: const BorderSide(color: gold500, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xB3FFFFFF)),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0x66FFFFFF)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x22FFFFFF),
        selectedColor: const Color(0x44C9A962),
        labelStyle: textTheme.labelMedium!.copyWith(color: cream),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: gold500.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? gold300 : const Color(0x99FFFFFF),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? gold300 : const Color(0x99FFFFFF),
            size: 22,
          );
        }),
        height: 72,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: gold500,
        circularTrackColor: Color(0x33C9A962),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: gold300,
        unselectedLabelColor: const Color(0x99FFFFFF),
        indicatorColor: gold500,
        labelStyle: textTheme.labelLarge,
        dividerColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 4)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x22FFFFFF), space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: gold300),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: gold300,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: gold500, textColor: emerald950),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.light(
      primary: emerald900,
      onPrimary: Colors.white,
      primaryContainer: sand,
      onPrimaryContainer: emerald900,
      secondary: emerald600,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD8EEDF),
      onSecondaryContainer: emerald900,
      tertiary: gold500,
      onTertiary: emerald950,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: cream,
      onSurface: const Color(0xFF0F1419),
      surfaceContainerHighest: Colors.white,
      outline: const Color(0x220D2818),
      outlineVariant: const Color(0x140D2818),
    );
    final textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: cream,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFECE7DC),
        foregroundColor: emerald900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium?.copyWith(color: emerald900),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: Color(0x140D2818)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald800,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emerald900,
          side: const BorderSide(color: Color(0x66C9A962)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: emerald800,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 4)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 4),
          borderSide: const BorderSide(color: emerald600, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cream2,
        selectedColor: const Color(0x332D8A52),
        labelStyle: textTheme.labelMedium!.copyWith(color: emerald900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFECE7DC),
        indicatorColor: gold500.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? emerald900 : const Color(0x990F1419),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? emerald900 : const Color(0x990F1419),
            size: 22,
          );
        }),
        height: 72,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: emerald600,
        circularTrackColor: Color(0x332D8A52),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: emerald900,
        unselectedLabelColor: const Color(0x990F1419),
        indicatorColor: gold500,
        labelStyle: textTheme.labelLarge,
        dividerColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: emerald900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 4)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: emerald900),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: emerald800,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: gold500, textColor: emerald950),
    );
  }
}
