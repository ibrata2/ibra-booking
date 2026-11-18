import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';

/// خلفية التطبيق: تدرج داكن/فاتح مع هالتين حمراء وزرقاء ضبابيتين (روح الهلال).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF0E1433), Brand.navy] : const [Color(0xFFF3F6FF), Color(0xFFE9EEFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Orb(color: Brand.red.withValues(alpha: dark ? 0.35 : 0.18), size: 320),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Orb(color: Brand.blue.withValues(alpha: dark ? 0.40 : 0.20), size: 380),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// بطاقة زجاجية (Glassmorphism).
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.tint,
    this.onTap,
    this.onLongPress,
    this.blur = 16,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    final fill = tint ?? (dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.62));
    final surface = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: br,
            color: fill,
            border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.9), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: dark ? 0.08 : 0.35),
                Colors.white.withValues(alpha: dark ? 0.01 : 0.10),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: br,
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              )
            : surface,
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
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
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
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// أيقونات التصنيفات القابلة للاختيار.
const Map<String, IconData> kCategoryIcons = {
  'mosque': Icons.mosque_rounded,
  'heart': Icons.favorite_rounded,
  'baby': Icons.child_friendly_rounded,
  'ring': Icons.diamond_rounded,
  'book': Icons.menu_book_rounded,
  'star': Icons.star_rounded,
  'event': Icons.event_rounded,
  'music': Icons.music_note_rounded,
  'mic': Icons.mic_rounded,
  'cake': Icons.cake_rounded,
  'group': Icons.groups_rounded,
  'home': Icons.home_rounded,
  'flower': Icons.local_florist_rounded,
  'candle': Icons.light_rounded,
  'school': Icons.school_rounded,
  'celebration': Icons.celebration_rounded,
};

IconData categoryIcon(String key) => kCategoryIcons[key] ?? Icons.event_rounded;

Color statusColor(BookingStatus s) => switch (s) {
  BookingStatus.confirmed => const Color(0xFF2F6BFF),
  BookingStatus.pending => const Color(0xFFFFA000),
  BookingStatus.upcoming => const Color(0xFF00ACC1),
  BookingStatus.ongoing => const Color(0xFF00C853),
  BookingStatus.completed => const Color(0xFF78909C),
  BookingStatus.cancelled => const Color(0xFFE53935),
  BookingStatus.postponed => const Color(0xFF8E24AA),
  BookingStatus.noShow => const Color(0xFF6D4C41),
};

IconData statusIcon(BookingStatus s) => switch (s) {
  BookingStatus.confirmed => Icons.verified_rounded,
  BookingStatus.pending => Icons.hourglass_top_rounded,
  BookingStatus.upcoming => Icons.upcoming_rounded,
  BookingStatus.ongoing => Icons.play_circle_fill_rounded,
  BookingStatus.completed => Icons.check_circle_rounded,
  BookingStatus.cancelled => Icons.cancel_rounded,
  BookingStatus.postponed => Icons.update_rounded,
  BookingStatus.noShow => Icons.person_off_rounded,
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});
  final BookingStatus status;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: dense ? 13 : 15, color: c),
          const SizedBox(width: 4),
          Text(
            context.t('st_${status.name}'),
            style: TextStyle(color: c, fontSize: dense ? 11 : 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// بطاقة حجز مختصرة في القوائم.
class AppointmentTile extends StatelessWidget {
  const AppointmentTile({super.key, required this.appt, required this.category, required this.now, this.onTap, this.showDate = false, this.trailing});

  final Appointment appt;
  final EventCategory? category;
  final DateTime now;
  final VoidCallback? onTap;
  final bool showDate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final color = Color(category?.color ?? 0xFF9E9E9E);
    final st = appt.effectiveStatus(now);
    return Glass(
      onTap: onTap,
      blur: 0,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(categoryIcon(category?.icon ?? 'event'), color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appt.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                      ),
                    ),
                    StatusChip(st, dense: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${showDate ? '${TimeFmt.date(appt.start, ar: ar)} • ' : ''}${TimeFmt.range(appt.start, appt.end, ar: ar)}',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                ),
                if (appt.placeName.isNotEmpty || category != null)
                  Text(
                    [category?.name(ar), appt.placeName].where((e) => e != null && e.isNotEmpty).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// زر دائري زجاجي صغير.
class RoundAction extends StatelessWidget {
  const RoundAction({super.key, required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: 0.15),
                border: Border.all(color: c.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: c),
            ),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String? ok, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t('cancel'))),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok ?? c.t('ok')),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// منتقي وقت بنظام 12 ساعة حصراً (AM/PM مترجمة).
Future<TimeOfDay?> pickTime12(BuildContext context, TimeOfDay initial) => showTimePicker(
  context: context,
  initialTime: initial,
  builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: false), child: child!),
);

String formatTod(BuildContext context, TimeOfDay t) => TimeFmt.time(DateTime(2026, 1, 1, t.hour, t.minute), ar: context.ar);
