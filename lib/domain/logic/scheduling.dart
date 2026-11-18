import '../entities/appointment.dart';
import '../entities/reminder_config.dart';

/// تعارض بين حجز جديد/معدّل وحجز موجود.
class ConflictInfo {
  final Appointment other;

  /// true = تداخل زمني فعلي، false = لا يوجد وقت كافٍ للتنقل.
  final bool overlap;

  /// الفاصل المتاح بين الحجزين (عند عدم التداخل).
  final Duration gap;

  const ConflictInfo({required this.other, required this.overlap, this.gap = Duration.zero});
}

class ConflictChecker {
  ConflictChecker._();

  /// يفحص كل الحجوزات الفعّالة ويعيد المتداخلة أو القريبة جداً (أقل من مدة التنقل).
  static List<ConflictInfo> find({
    required DateTime start,
    required DateTime end,
    required Iterable<Appointment> existing,
    Set<int> ignoreIds = const {},
    Duration travel = Duration.zero,
  }) {
    final out = <ConflictInfo>[];
    for (final o in existing) {
      if (o.id != null && ignoreIds.contains(o.id)) continue;
      if (o.status.isClosed) continue;
      final overlap = start.isBefore(o.end) && o.start.isBefore(end);
      if (overlap) {
        out.add(ConflictInfo(other: o, overlap: true));
        continue;
      }
      if (travel > Duration.zero) {
        final gap = !o.end.isAfter(start) ? start.difference(o.end) : o.start.difference(end);
        if (!gap.isNegative && gap < travel) {
          out.add(ConflictInfo(other: o, overlap: false, gap: gap));
        }
      }
    }
    out.sort((a, b) => a.other.start.compareTo(b.other.start));
    return out;
  }
}

/// تنبيه مخطط له (قبل تحويله لإشعار نظام).
class PlannedReminder {
  final Appointment appointment;
  final ReminderType type;
  final DateTime fireAt;
  final bool persistent;

  /// الحجز الجاري وقت التنبيه (لتنبيه «لديك حجز آخر بعد ساعة»).
  final Appointment? during;

  const PlannedReminder({required this.appointment, required this.type, required this.fireAt, required this.persistent, this.during});

  /// رقم إشعار ثابت لكل (حجز، نوع) يمنع التكرار عند إعادة الجدولة.
  int get notificationId => NotificationIds.base(appointment.id ?? 0, type);
}

class NotificationIds {
  NotificationIds._();

  static int base(int appointmentId, ReminderType t) => (appointmentId * 8 + t.index) & 0x0FFFFFFF;

  /// إعادة الرنين في iOS (لا يدعم الرنين المستمر): 16 تكرار لكل تنبيه.
  static int repeat(int baseId, int k) => 0x10000000 + ((baseId & 0x007FFFFF) * 16 + k);

  /// التأجيل (Snooze).
  static int snooze(int baseId) => 0x30000000 + (baseId & 0x0FFFFFFF);

  static const int test = 0x7FFFFF00;
}

class ReminderPlanner {
  ReminderPlanner._();

  /// يحسب كل التنبيهات القادمة بعد [now] وحتى [horizon]، مرتبة زمنياً.
  static List<PlannedReminder> plan({
    required List<Appointment> appointments,
    required ReminderConfig defaults,
    required DateTime now,
    required DateTime horizon,
  }) {
    final active = appointments.where((a) => !a.status.isClosed && a.id != null).toList()..sort((a, b) => a.start.compareTo(b.start));
    final out = <PlannedReminder>[];

    Appointment? ongoingAt(DateTime t, Appointment except) {
      for (final b in active) {
        if (b.id == except.id) continue;
        if (b.isOngoingAt(t)) return b;
      }
      return null;
    }

    void add(Appointment a, ReminderType type, DateTime at, bool persistent, [Appointment? during]) {
      if (!at.isAfter(now) || at.isAfter(horizon)) return;
      out.add(PlannedReminder(appointment: a, type: type, fireAt: at, persistent: persistent, during: during));
    }

    for (final a in active) {
      final c = a.reminderOverride ?? defaults;
      DateTime? nextAt;
      if (c.nextBooking) {
        final t = a.start.subtract(Duration(minutes: c.nextBookingMin));
        final cur = ongoingAt(t, a);
        if (cur != null) {
          nextAt = t;
          add(a, ReminderType.nextBooking, t, c.persistent, cur);
        }
      }
      if (c.approachStart && c.approachStartMin > 0) {
        final t = a.start.subtract(Duration(minutes: c.approachStartMin));
        if (nextAt == null || t != nextAt) add(a, ReminderType.approachStart, t, c.persistent);
      }
      if (c.start) add(a, ReminderType.start, a.start, c.persistent);
      if (c.approachEnd && c.approachEndMin > 0) {
        final t = a.end.subtract(Duration(minutes: c.approachEndMin));
        if (t.isAfter(a.start)) add(a, ReminderType.approachEnd, t, c.persistent);
      }
      if (c.end) add(a, ReminderType.end, a.end, c.persistent);
    }
    out.sort((x, y) {
      final r = x.fireAt.compareTo(y.fireAt);
      return r != 0 ? r : x.type.index.compareTo(y.type.index);
    });
    return out;
  }
}
