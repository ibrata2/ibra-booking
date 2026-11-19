import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ibra_native/ibra_native.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/sound_picker.dart';
import '../../core/edition.dart';

/// إعدادات التنبيهات + الصلاحيات + صفحة اختبار التنبيهات والأصوات.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  ReminderType _testType = ReminderType.approachStart;
  String? _testSound;
  bool _testPersistent = true;
  int? _pending;

  @override
  void initState() {
    super.initState();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final n = await ref.read(notificationServiceProvider).pendingCount();
    if (mounted) setState(() => _pending = n);
  }

  Future<void> _save(AppSettings s) async {
    await ref.read(settingsProvider.notifier).set(s);
    await ref.read(bookingControllerProvider).rescheduleNotifications();
    await _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final perm = ref.watch(permissionStatusProvider);
    final notif = ref.read(notificationServiceProvider);

    Widget permRow(bool ok, String label, VoidCallback fix) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? const Color(0xFF00C853) : Colors.orange),
      title: Text(label),
      trailing: ok ? null : TextButton(onPressed: fix, child: Text(context.t('fix'))),
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.t('notif_settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SectionTitle(context.t('permissions')),
          Glass(
            child: perm.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (p) => Column(
                children: [
                  if (!p.notifications)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        context.t('notif_disabled_warning'),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
                      ),
                    ),
                  permRow(p.notifications, context.t('perm_notifications'), () async {
                    await notif.request(fullScreen: s.fullScreenAlarm);
                    ref.read(dataVersionProvider.notifier).bump();
                  }),
                  if (Platform.isAndroid)
                    permRow(p.exactAlarms, context.t('perm_exact'), () async {
                      await notif.request(fullScreen: s.fullScreenAlarm);
                      ref.read(dataVersionProvider.notifier).bump();
                    }),
                  if (Platform.isAndroid)
                    permRow(p.batteryUnrestricted, context.t('perm_battery'), () async {
                      await IbraNative.openBatterySettings();
                    }),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await notif.request(fullScreen: s.fullScreenAlarm);
                            ref.read(dataVersionProvider.notifier).bump();
                          },
                          icon: const Icon(Icons.verified_user_rounded),
                          label: Text(context.t('request_permissions')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: notif.openSystemSettings,
                          icon: const Icon(Icons.settings_rounded),
                          label: Text(context.t('system_settings')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(context.t('silent_note'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ),
          SectionTitle(context.t('default_reminders')),
          Glass(
            child: ReminderEditor(
              config: s.reminders,
              onChanged: (c) => _save(s.copyWith(reminders: c)),
            ),
          ),
          if (Edition.isCenter) ...[
            SectionTitle(context.t('notify_for')),
            Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: s.notifyStaffId,
                    decoration: InputDecoration(labelText: context.t('notify_for'), prefixIcon: const Icon(Icons.badge_rounded)),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(context.t('all_staff'))),
                      for (final st in ref.watch(staffProvider).value ?? const <Staff>[]) DropdownMenuItem(value: st.id, child: Text(st.name)),
                    ],
                    onChanged: (v) => _save(s.copyWith(notifyStaffId: v ?? 0)),
                  ),
                  const SizedBox(height: 6),
                  Text(context.t('notify_for_hint'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ],
          SectionTitle(context.t('alarm_behavior')),
          Glass(
            child: Column(
              children: [
                if (Platform.isAndroid)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.fullScreenAlarm,
                    title: Text(context.t('full_screen_alarm')),
                    subtitle: Text(context.t('full_screen_alarm_hint')),
                    onChanged: (v) async {
                      if (v) await notif.request(fullScreen: true);
                      await _save(s.copyWith(fullScreenAlarm: v));
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('repeat_until_ack')),
                  subtitle: Text(context.t('repeat_until_ack_hint', {'n': s.iosRepeatCount})),
                  trailing: DropdownButton<int>(
                    value: s.iosRepeatCount,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final n in [0, 2, 4, 6, 8, 10, 15]) DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) => v == null ? null : _save(s.copyWith(iosRepeatCount: v)),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('snooze_minutes')),
                  trailing: DropdownButton<int>(
                    value: s.snoozeMinutes,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final n in [5, 10, 15, 20, 30, 60]) DropdownMenuItem(value: n, child: Text('$n ${context.t('min_short')}')),
                    ],
                    onChanged: (v) => v == null ? null : _save(s.copyWith(snoozeMinutes: v)),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('test_alerts')),
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ReminderType>(
                  initialValue: _testType,
                  decoration: InputDecoration(labelText: context.t('alert_type')),
                  items: [for (final t in ReminderType.values) DropdownMenuItem(value: t, child: Text(context.t('rt_${t.name}')))],
                  onChanged: (v) => setState(() => _testType = v ?? _testType),
                ),
                SoundPickerTile(title: context.t('sound'), value: _testSound, allowInherit: true, onChanged: (k) => setState(() => _testSound = k)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _testPersistent,
                  title: Text(context.t('persistent')),
                  onChanged: (v) => setState(() => _testPersistent = v),
                ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _test(Duration.zero),
                        icon: const Icon(Icons.notifications_rounded),
                        label: Text(context.t('test_now')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _test(const Duration(seconds: 10)),
                        icon: const Icon(Icons.timer_10_rounded),
                        label: Text(context.t('test_10s')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(context.t('test_close_hint'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: Text('${context.t('scheduled_count')}: ${_pending ?? '…'}')),
                    TextButton.icon(
                      onPressed: () async {
                        final n = await ref.read(bookingControllerProvider).rescheduleNotifications();
                        await _refreshPending();
                        if (context.mounted) toast(context, context.t('rescheduled_n', {'n': n}));
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.t('reschedule')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _test(Duration delay) async {
    final s = ref.read(settingsProvider);
    final notif = ref.read(notificationServiceProvider);
    final st = await notif.status();
    if (!st.notifications) {
      await notif.request(fullScreen: s.fullScreenAlarm);
    }
    await notif.test(
      settings: s,
      cats: await ref.read(categoryRepoProvider).all(),
      customs: await ref.read(soundRepoProvider).all(),
      type: _testType,
      soundKey: _testSound,
      persistent: _testPersistent,
      delay: delay,
    );
    if (mounted && delay > Duration.zero) toast(context, context.t('test_scheduled'));
  }
}
