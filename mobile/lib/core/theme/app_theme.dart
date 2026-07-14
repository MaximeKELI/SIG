import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thème DUSOL — émeraude profond · or champagne (parité web).
class AppTheme {
  static const Color emerald950 = Color(0xFF061A10);
  static const Color emerald900 = Color(0xFF0D2818);
  static const Color emerald800 = Color(0xFF134E2A);
  static const Color emerald600 = Color(0xFF2D8A52);
  static const Color gold300 = Color(0xFFE8D5A3);
  static const Color gold500 = Color(0xFFC9A962);
  static const Color cream = Color(0xFFFAF8F3);
  static const Color cream2 = Color(0xFFF3EFE6);

  static const Color primary = emerald900;
  static const Color accent = gold500;
  static const Color surface = Color(0xFF1A3D2E);
  static const Color card = Color(0xFF243D32);

  static const String fontDisplay = 'serif';
  static const String fontUi = 'sans-serif';

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontUi,
    );
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: gold500,
        secondary: Color(0xFF5CC98A),
        surface: surface,
        onPrimary: emerald950,
        onSurface: Color(0xFFF5F7F4),
        outline: Color(0x33FFFFFF),
      ),
      scaffoldBackgroundColor: emerald950,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: gold300,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: gold300,
          letterSpacing: 0.3,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x22FFFFFF)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold500,
          foregroundColor: emerald950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold300,
          side: const BorderSide(color: Color(0x66C9A962)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E332A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x33FFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold500, width: 1.4),
        ),
        labelStyle: const TextStyle(color: Color(0xB3FFFFFF)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x22FFFFFF),
        selectedColor: const Color(0x44C9A962),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: gold500.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
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
        height: 68,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x22FFFFFF), space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontUi,
    );
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: emerald900,
        secondary: emerald600,
        surface: cream,
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F1419),
        outline: Color(0x220D2818),
      ),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFECE7DC),
        foregroundColor: emerald900,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontDisplay,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: emerald900,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x140D2818)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald800,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: emerald600, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cream2,
        selectedColor: const Color(0x332D8A52),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: emerald900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFECE7DC),
        indicatorColor: gold500.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        height: 68,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: emerald900,
        contentTextStyle: const TextStyle(color: cream),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
