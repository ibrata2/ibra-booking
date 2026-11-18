import 'package:flutter/material.dart';

/// ألوان الهوية: هلال أحمر/أزرق زجاجي.
class Brand {
  Brand._();
  static const red = Color(0xFFE5243B);
  static const blue = Color(0xFF2F6BFF);
  static const navy = Color(0xFF0B1026);
  static const navy2 = Color(0xFF141B3D);

  static const accents = <int>[0xFF3D7BFF, 0xFFE5243B, 0xFF7C4DFF, 0xFF00B8A9, 0xFFFF8F00, 0xFFEC407A, 0xFF43A047, 0xFFC9A84C];
}

class AppTheme {
  AppTheme._();

  static ThemeData build({required Brightness brightness, required Color accent, String fontFamily = 'tajawal'}) {
    final font = fontFamily == 'system' ? null : 'Tajawal';
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(primary: accent, secondary: Brand.red, surface: dark ? const Color(0xFF111735) : const Color(0xFFF6F8FF));
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      scaffoldBackgroundColor: dark ? const Color(0xFF0D1330) : const Color(0xFFF1F4FF),
      splashFactory: InkSparkle.splashFactory,
    );
    final radius = BorderRadius.circular(18);
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.75),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF161D42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF131A3B) : const Color(0xFFF7F9FF),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
      ),
      chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
