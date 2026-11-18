/// أنواع التكرار.
enum RecurrenceType {
  none,
  daily, // يومياً (مثل فاتحة لثلاثة أيام)
  weekly,
  monthly,
  yearly,
  weekdays, // أيام محددة من الأسبوع
  range; // كل يوم ضمن فترة مخصصة (من تاريخ إلى تاريخ)

  static RecurrenceType parse(String? v) => RecurrenceType.values.firstWhere((e) => e.name == v, orElse: () => RecurrenceType.none);
}

class RecurrenceRule {
  final int? id;
  final RecurrenceType type;
  final int interval; // كل كم (يوم/أسبوع/شهر/سنة)
  final Set<int> weekdays; // 1=الإثنين ... 7=الأحد (حسب DateTime.weekday)
  final int? count; // عدد المرات
  final DateTime? until; // آخر تاريخ (شامل)

  const RecurrenceRule({this.id, this.type = RecurrenceType.none, this.interval = 1, this.weekdays = const {}, this.count, this.until});

  static const int maxOccurrences = 366;

  bool get isNone => type == RecurrenceType.none;

  RecurrenceRule copyWith({
    int? id,
    RecurrenceType? type,
    int? interval,
    Set<int>? weekdays,
    int? count,
    bool clearCount = false,
    DateTime? until,
    bool clearUntil = false,
  }) => RecurrenceRule(
    id: id ?? this.id,
    type: type ?? this.type,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    count: clearCount ? null : (count ?? this.count),
    until: clearUntil ? null : (until ?? this.until),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'type': type.name,
    'interval': interval,
    'weekdays': (weekdays.toList()..sort()).join(','),
    'count': count,
    'until_ms': until?.millisecondsSinceEpoch,
  };

  factory RecurrenceRule.fromMap(Map<String, Object?> m) => RecurrenceRule(
    id: m['id'] as int?,
    type: RecurrenceType.parse(m['type'] as String?),
    interval: (m['interval'] as int?) ?? 1,
    weekdays: ((m['weekdays'] as String?) ?? '').split(',').where((e) => e.isNotEmpty).map(int.parse).toSet(),
    count: m['count'] as int?,
    until: m['until_ms'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['until_ms'] as int),
  );

  /// يولد تواريخ بداية كل تكرار (بنفس وقت اليوم) ابتداءً من [first].
  List<DateTime> expand(DateTime first) {
    if (type == RecurrenceType.none) return [first];
    final step = interval < 1 ? 1 : interval;
    final limit = count ?? maxOccurrences;
    final untilDay = until == null ? null : DateTime(until!.year, until!.month, until!.day, 23, 59, 59);
    final out = <DateTime>[];
    bool canAdd(DateTime d) => untilDay == null || !d.isAfter(untilDay);

    DateTime at(int y, int m, int d) {
      // يضبط اليوم لآخر يوم في الشهر إن لزم (31 → 30/28)
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, d > last ? last : d, first.hour, first.minute);
    }

    switch (type) {
      case RecurrenceType.daily:
      case RecurrenceType.range:
        for (var i = 0; out.length < limit; i++) {
          final d = DateTime(first.year, first.month, first.day + i * (type == RecurrenceType.range ? 1 : step), first.hour, first.minute);
          if (!canAdd(d)) break;
          out.add(d);
          if (untilDay == null && count == null && out.length >= 30) break;
        }
      case RecurrenceType.weekly:
        for (var i = 0; out.length < limit; i++) {
          final d = DateTime(first.year, first.month, first.day + i * 7 * step, first.hour, first.minute);
          if (!canAdd(d)) break;
          out.add(d);
          if (untilDay == null && count == null && out.length >= 52) break;
        }
      case RecurrenceType.monthly:
        for (var i = 0; out.length < limit; i++) {
          final d = at(first.year, first.month + i * step, first.day);
          if (!canAdd(d)) break;
          out.add(d);
          if (untilDay == null && count == null && out.length >= 24) break;
        }
      case RecurrenceType.yearly:
        for (var i = 0; out.length < limit; i++) {
          final d = at(first.year + i * step, first.month, first.day);
          if (!canAdd(d)) break;
          out.add(d);
          if (untilDay == null && count == null && out.length >= 10) break;
        }
      case RecurrenceType.weekdays:
        final days = weekdays.isEmpty ? {first.weekday} : weekdays;
        for (var i = 0; out.length < limit && i < 3660; i++) {
          final d = DateTime(first.year, first.month, first.day + i, first.hour, first.minute);
          if (!canAdd(d)) break;
          if (days.contains(d.weekday)) out.add(d);
          if (untilDay == null && count == null && out.length >= 52) break;
        }
      case RecurrenceType.none:
        out.add(first);
    }
    if (out.isEmpty) out.add(first);
    return out;
  }
}
