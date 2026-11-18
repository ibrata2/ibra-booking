import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';

/// محرر أوقات التنبيهات (لحجز محدد أو لكل الحجوزات).
class ReminderEditor extends StatelessWidget {
  const ReminderEditor({super.key, required this.config, required this.onChanged});
  final ReminderConfig config;
  final ValueChanged<ReminderConfig> onChanged;

  static const _minutes = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 1440];

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    Widget minutesPicker(int value, ValueChanged<int> set) => DropdownButton<int>(
      value: _minutes.contains(value) ? value : null,
      hint: Text(TimeFmt.human(Duration(minutes: value), ar: ar)),
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(16),
      items: [
        for (final m in _minutes)
          DropdownMenuItem(
            value: m,
            child: Text(TimeFmt.human(Duration(minutes: m), ar: ar)),
          ),
      ],
      onChanged: (v) => v == null ? null : set(v),
    );

    Widget row(bool on, String label, ValueChanged<bool> toggle, {int? minutes, ValueChanged<int>? setMinutes, String? hint}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Switch(value: on, onChanged: toggle),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (hint != null) Text(hint, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ),
          ),
          if (minutes != null && setMinutes != null && on) minutesPicker(minutes, setMinutes),
        ],
      ),
    );

    return Column(
      children: [
        row(
          config.approachStart,
          context.t('rt_approachStart'),
          (v) => onChanged(config.copyWith(approachStart: v)),
          minutes: config.approachStartMin,
          setMinutes: (m) => onChanged(config.copyWith(approachStartMin: m)),
          hint: context.t('before_start'),
        ),
        row(config.start, context.t('rt_start'), (v) => onChanged(config.copyWith(start: v))),
        row(
          config.approachEnd,
          context.t('rt_approachEnd'),
          (v) => onChanged(config.copyWith(approachEnd: v)),
          minutes: config.approachEndMin,
          setMinutes: (m) => onChanged(config.copyWith(approachEndMin: m)),
          hint: context.t('before_end'),
        ),
        row(config.end, context.t('rt_end'), (v) => onChanged(config.copyWith(end: v))),
        row(
          config.nextBooking,
          context.t('rt_nextBooking'),
          (v) => onChanged(config.copyWith(nextBooking: v)),
          minutes: config.nextBookingMin,
          setMinutes: (m) => onChanged(config.copyWith(nextBookingMin: m)),
          hint: context.t('next_hint'),
        ),
        const Divider(),
        row(config.persistent, context.t('persistent'), (v) => onChanged(config.copyWith(persistent: v)), hint: context.t('persistent_hint')),
      ],
    );
  }
}
