import 'dart:ui';

import 'package:flutter/material.dart';

/// هوية روسم للتجميل: كحلي داكن، أزرق زجاجي، وفضي — نفس عائلة «الحجوزات IBRA».
class Brand {
  Brand._();
  static const navy = Color(0xFF070B1C);
  static const navy2 = Color(0xFF0E1533);
  static const blue = Color(0xFF2F6BFF);
  static const sky = Color(0xFF5AA2FF);
  static const silver = Color(0xFFDCE3F0);
  static const rose = Color(0xFFFF5C8A);
  static const gold = Color(0xFFFFC857);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFE5243B);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: Brand.blue, brightness: Brightness.dark).copyWith(
      primary: Brand.blue,
      secondary: Brand.rose,
      surface: Brand.navy2,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: Brand.navy,
    );
    final radius = BorderRadius.circular(18);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Brand.sky, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w800, fontSize: 15.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF121A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0F1736),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}

/// خلفية التطبيق: كحلي مع هالتين زرقاوين ضبابيتين.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B1230), Brand.navy]),
    ),
    child: Stack(
      children: [
        const Positioned(top: -140, right: -90, child: _Orb(color: Color(0x553D7BFF), size: 340)),
        const Positioned(bottom: -160, left: -110, child: _Orb(color: Color(0x445AA2FF), size: 400)),
        Positioned.fill(child: child),
      ],
    ),
  );
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
    ),
  );
}

/// بطاقة زجاجية.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 22, this.onTap, this.margin, this.tint});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: br,
              onTap: onTap,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: br,
                  color: tint ?? Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.01)],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 58, color: Brand.sky.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 15)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// عنوان «روسم للتجميل» بالخط الكوفي.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Brand.silver, Color(0xFF9AA6BE), Colors.white],
          stops: [0, 0.45, 0.55, 1],
        ).createShader(r),
        child: Text('روسم', style: TextStyle(fontFamily: 'ReemKufi', fontSize: size, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1)),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: EdgeInsets.only(bottom: size * 0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFF1E5BFF), Color(0xFF0B3FD1)]),
            border: Border.all(color: Brand.sky.withValues(alpha: 0.7)),
          ),
          child: Text('للتجميل', style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    ],
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
