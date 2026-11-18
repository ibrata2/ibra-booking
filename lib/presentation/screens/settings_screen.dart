import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'notification_settings_screen.dart';
import 'sounds_screen.dart';

const kCurrencies = <(String, String, String)>[
  ('IQD', 'د.ع', 'IQD'),
  ('USD', r'$', r'$'),
  ('EUR', '€', '€'),
  ('SAR', 'ر.س', 'SAR'),
  ('AED', 'د.إ', 'AED'),
  ('KWD', 'د.ك', 'KWD'),
  ('JOD', 'د.أ', 'JOD'),
  ('TRY', '₺', '₺'),
  ('IRR', 'ریال', 'IRR'),
  ('GBP', '£', '£'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final s = ref.watch(settingsProvider);
    Future<void> set(AppSettings v, {bool reschedule = false}) async {
      await ref.read(settingsProvider.notifier).set(v);
      if (reschedule) await ref.read(bookingControllerProvider).rescheduleNotifications();
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SectionTitle(context.t('language')),
          Glass(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ar', label: Text('العربية')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {s.language},
              onSelectionChanged: (v) => set(s.copyWith(language: v.first), reschedule: true),
            ),
          ),
          SectionTitle(context.t('appearance')),
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system', icon: const Icon(Icons.brightness_auto_rounded), label: Text(context.t('theme_auto'))),
                    ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode_rounded), label: Text(context.t('theme_light'))),
                    ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode_rounded), label: Text(context.t('theme_dark'))),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => set(s.copyWith(themeMode: v.first)),
                ),
                const SizedBox(height: 14),
                Text(context.t('app_color'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in Brand.accents)
                      GestureDetector(
                        onTap: () => set(s.copyWith(accent: c)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(c),
                            border: Border.all(color: s.accent == c ? Colors.white : Colors.transparent, width: 3),
                            boxShadow: s.accent == c ? [BoxShadow(color: Color(c), blurRadius: 12)] : null,
                          ),
                          child: s.accent == c ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'tajawal', label: Text(context.t('font_tajawal'))),
                    ButtonSegment(value: 'system', label: Text(context.t('font_system'))),
                  ],
                  selected: {s.fontFamily},
                  onSelectionChanged: (v) => set(s.copyWith(fontFamily: v.first)),
                ),
                const SizedBox(height: 10),
                Text('${context.t('font_size')}: ${(s.fontScale * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: s.fontScale,
                  min: 0.85,
                  max: 1.35,
                  divisions: 10,
                  onChanged: (v) => set(s.copyWith(fontScale: double.parse(v.toStringAsFixed(2)))),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('bookings_settings')),
          Glass(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_car_rounded),
                  title: Text(context.t('travel_time')),
                  subtitle: Text(context.t('travel_time_hint2')),
                  trailing: DropdownButton<int>(
                    value: s.travelMinutes,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in [0, 10, 15, 20, 30, 45, 60, 90, 120])
                        DropdownMenuItem(
                          value: m,
                          child: Text(m == 0 ? context.t('none') : TimeFmt.human(Duration(minutes: m), ar: ar)),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : set(s.copyWith(travelMinutes: v)),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_view_week_rounded),
                  title: Text(context.t('week_start')),
                  trailing: DropdownButton<int>(
                    value: s.weekStart,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final d in [6, 7, 1])
                        DropdownMenuItem(
                          value: d,
                          child: Text(TimeFmt.weekday(d, ar: ar)),
                        ),
                    ],
                    onChanged: (v) => v == null ? null : set(s.copyWith(weekStart: v)),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_rounded),
                  title: Text(context.t('maps_app')),
                  trailing: DropdownButton<String>(
                    value: s.mapsApp,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'google', child: Text(context.t('google_maps'))),
                      DropdownMenuItem(value: 'apple', child: Text(context.t('apple_maps'))),
                    ],
                    onChanged: (v) => v == null ? null : set(s.copyWith(mapsApp: v)),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_rounded),
                  title: Text(context.t('categories')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('finance')),
          Glass(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.visibility_rounded),
                  value: s.showFinance,
                  title: Text(context.t('show_finance')),
                  onChanged: (v) => set(s.copyWith(showFinance: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_rounded),
                  title: Text(context.t('currency')),
                  trailing: DropdownButton<String>(
                    value: kCurrencies.any((c) => c.$1 == s.currencyCode) ? s.currencyCode : null,
                    hint: Text(s.currencyCode),
                    underline: const SizedBox.shrink(),
                    items: [for (final c in kCurrencies) DropdownMenuItem(value: c.$1, child: Text('${c.$1} (${ar ? c.$2 : c.$3})'))],
                    onChanged: (v) {
                      final c = kCurrencies.firstWhere((e) => e.$1 == v);
                      set(s.copyWith(currencyCode: c.$1, currencySymbol: ar ? c.$2 : c.$3));
                    },
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('notifications')),
          Glass(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: Text(context.t('notif_settings')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.library_music_rounded),
                  title: Text(context.t('sounds')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('IBRA BOOKING • v1.0.0', style: TextStyle(color: Theme.of(context).hintColor)),
          ),
        ],
      ),
    );
  }
}
