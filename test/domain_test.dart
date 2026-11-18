import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibra_booking/core/files/zip.dart';
import 'package:ibra_booking/core/security/sha256.dart';
import 'package:ibra_booking/core/time/time_format.dart';
import 'package:ibra_booking/domain/entities/entities.dart';
import 'package:ibra_booking/domain/logic/scheduling.dart';

Appointment appt(int id, DateTime s, DateTime e, {BookingStatus status = BookingStatus.confirmed, ReminderConfig? cfg}) => Appointment(
  id: id,
  customerName: 'زبون $id',
  start: s,
  end: e,
  status: status,
  reminderOverride: cfg,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('نظام 12 ساعة', () {
    test('صباحاً ومساءً وظهراً ومنتصف الليل', () {
      expect(TimeFmt.time(DateTime(2026, 1, 1, 9, 0)), '09:00 صباحاً');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 14, 30)), '02:30 مساءً');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 18, 45)), '06:45 مساءً');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 12, 0)), '12:00 ظهراً');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 0, 0)), '12:00 منتصف الليل');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 0, 30)), '12:30 صباحاً');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 12, 15)), '12:15 مساءً');
    });
    test('الإنكليزية', () {
      expect(TimeFmt.time(DateTime(2026, 1, 1, 9, 5), ar: false), '09:05 AM');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 23, 59), ar: false), '11:59 PM');
      expect(TimeFmt.time(DateTime(2026, 1, 1, 0, 0), ar: false), '12:00 Midnight');
    });
    test('لا يظهر وقت 24 ساعة أبداً', () {
      for (var h = 0; h < 24; h++) {
        final s = TimeFmt.time(DateTime(2026, 1, 1, h, 7));
        final hour = int.parse(s.substring(0, 2));
        expect(hour >= 1 && hour <= 12, true);
      }
    });
    test('حجز بعد منتصف الليل', () {
      final r = TimeFmt.range(DateTime(2026, 1, 1, 22), DateTime(2026, 1, 2, 1));
      expect(r, '10:00 مساءً - 01:00 صباحاً (اليوم التالي)');
    });
  });

  group('التنبيهات', () {
    test('مثال المواصفات: حجزان متتاليان', () {
      final a = appt(1, DateTime(2026, 5, 1, 16), DateTime(2026, 5, 1, 18));
      final b = appt(2, DateTime(2026, 5, 1, 18, 30), DateTime(2026, 5, 1, 20));
      final plan = ReminderPlanner.plan(
        appointments: [a, b],
        defaults: ReminderConfig.defaults,
        now: DateTime(2026, 5, 1, 8),
        horizon: DateTime(2026, 6, 1),
      );
      final got = plan.map((p) => '${TimeFmt.time(p.fireAt)}|${p.type.name}|${p.appointment.id}').toList();
      expect(got, [
        '03:00 مساءً|approachStart|1',
        '04:00 مساءً|start|1',
        '05:30 مساءً|nextBooking|2',
        '05:45 مساءً|approachEnd|1',
        '06:00 مساءً|end|1',
        '06:30 مساءً|start|2',
        '07:45 مساءً|approachEnd|2',
        '08:00 مساءً|end|2',
      ]);
      expect(plan[2].during?.id, 1);
    });
    test('لا تنبيهات للحجوزات الملغاة أو الماضية', () {
      final a = appt(1, DateTime(2026, 5, 1, 16), DateTime(2026, 5, 1, 18), status: BookingStatus.cancelled);
      final b = appt(2, DateTime(2026, 4, 1, 16), DateTime(2026, 4, 1, 18));
      final plan = ReminderPlanner.plan(
        appointments: [a, b],
        defaults: ReminderConfig.defaults,
        now: DateTime(2026, 4, 30),
        horizon: DateTime(2026, 6, 1),
      );
      expect(plan.isEmpty, true);
    });
    test('أرقام الإشعارات فريدة', () {
      final list = List.generate(50, (i) => appt(i + 1, DateTime(2026, 5, 1 + i, 10), DateTime(2026, 5, 1 + i, 12)));
      final plan = ReminderPlanner.plan(appointments: list, defaults: ReminderConfig.defaults, now: DateTime(2026, 4, 1), horizon: DateTime(2027));
      final ids = plan.map((p) => p.notificationId).toSet();
      expect(ids.length, plan.length);
    });
    test('إعدادات خاصة بحجز', () {
      final a = appt(
        1,
        DateTime(2026, 5, 1, 16),
        DateTime(2026, 5, 1, 18),
        cfg: const ReminderConfig(approachStart: false, approachEnd: false, end: false),
      );
      final plan = ReminderPlanner.plan(appointments: [a], defaults: ReminderConfig.defaults, now: DateTime(2026, 4, 1), horizon: DateTime(2027));
      expect(plan.length, 1);
      expect(plan.first.type, ReminderType.start);
    });
    test('ترميز إعدادات التنبيه', () {
      const c = ReminderConfig(approachStartMin: 30, persistent: false);
      expect(ReminderConfig.tryDecode(c.encode()), c);
    });
  });

  group('التعارض', () {
    final existing = [appt(1, DateTime(2026, 5, 1, 16), DateTime(2026, 5, 1, 18))];
    test('تداخل', () {
      final c = ConflictChecker.find(start: DateTime(2026, 5, 1, 17), end: DateTime(2026, 5, 1, 19), existing: existing);
      expect(c.length, 1);
      expect(c.first.overlap, true);
    });
    test('متلاصق بدون تنقل = لا تعارض', () {
      final c = ConflictChecker.find(start: DateTime(2026, 5, 1, 18), end: DateTime(2026, 5, 1, 19), existing: existing);
      expect(c.isEmpty, true);
    });
    test('وقت تنقل غير كافٍ', () {
      final c = ConflictChecker.find(
        start: DateTime(2026, 5, 1, 18, 15),
        end: DateTime(2026, 5, 1, 19),
        existing: existing,
        travel: const Duration(minutes: 30),
      );
      expect(c.length, 1);
      expect(c.first.overlap, false);
      expect(c.first.gap, const Duration(minutes: 15));
    });
    test('تجاهل الحجز نفسه عند التعديل', () {
      final c = ConflictChecker.find(start: DateTime(2026, 5, 1, 16), end: DateTime(2026, 5, 1, 18), existing: existing, ignoreIds: {1});
      expect(c.isEmpty, true);
    });
    test('تعارض عبر منتصف الليل', () {
      final night = [appt(5, DateTime(2026, 5, 1, 22), DateTime(2026, 5, 2, 2))];
      final c = ConflictChecker.find(start: DateTime(2026, 5, 2, 1), end: DateTime(2026, 5, 2, 3), existing: night);
      expect(c.length, 1);
    });
  });

  group('التكرار', () {
    test('فاتحة ثلاثة أيام', () {
      final d = const RecurrenceRule(type: RecurrenceType.daily, count: 3).expand(DateTime(2026, 5, 30, 16));
      expect(d.map(TimeFmt.dateNum).toList(), ['2026/05/30', '2026/05/31', '2026/06/01']);
      expect(d.every((x) => x.hour == 16), true);
    });
    test('شهري يضبط نهاية الشهر', () {
      final d = const RecurrenceRule(type: RecurrenceType.monthly, count: 3).expand(DateTime(2026, 1, 31, 10));
      expect(d.map(TimeFmt.dateNum).toList(), ['2026/01/31', '2026/02/28', '2026/03/31']);
    });
    test('أيام محددة', () {
      final d = RecurrenceRule(
        type: RecurrenceType.weekdays,
        weekdays: {DateTime.friday},
        until: DateTime(2026, 5, 31),
      ).expand(DateTime(2026, 5, 1, 10));
      expect(d.length, 5);
      expect(d.every((x) => x.weekday == DateTime.friday), true);
    });
    test('فترة مخصصة', () {
      final d = RecurrenceRule(type: RecurrenceType.range, until: DateTime(2026, 5, 10)).expand(DateTime(2026, 5, 1, 19));
      expect(d.length, 10);
    });
  });

  group('الحالات', () {
    test('حالة زمنية', () {
      final a = appt(1, DateTime(2026, 5, 1, 16), DateTime(2026, 5, 1, 18));
      expect(a.effectiveStatus(DateTime(2026, 5, 1, 17)), BookingStatus.ongoing);
      expect(a.effectiveStatus(DateTime(2026, 5, 1, 19)), BookingStatus.completed);
      expect(a.effectiveStatus(DateTime(2026, 5, 1, 10)), BookingStatus.upcoming);
      expect(a.effectiveStatus(DateTime(2026, 4, 1)), BookingStatus.confirmed);
    });
  });

  group('الملفات', () {
    test('ZIP ذهاب وإياب', () {
      final data = ZipCodec.encode([ZipEntry.text('أ/ملف.txt', 'مرحبا ' * 100), ZipEntry('b.bin', List.generate(1000, (i) => i % 256))]);
      final back = ZipCodec.decode(data);
      expect(back.length, 2);
      expect(utf8.decode(back.first.data), 'مرحبا ' * 100);
      expect(back.first.name, 'أ/ملف.txt');
      expect(back[1].data.length, 1000);
    });
    test('Excel صالح', () {
      final x = XlsxWriter()
        ..addSheet('التقرير', [
          ['الاسم', 'المبلغ'],
          ['أحمد', 25000],
        ]);
      final entries = ZipCodec.decode(x.build());
      expect(entries.any((e) => e.name == 'xl/worksheets/sheet1.xml'), true);
    });
    test('SHA-256', () {
      expect(Sha256.hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(Sha256.hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });
    test('CRC32', () {
      expect(Crc32.of(utf8.encode('123456789')), 0xCBF43926);
    });
    test('المبالغ', () {
      expect(MoneyFmt.number(25000), '25,000');
      expect(MoneyFmt.number(1250000.5), '1,250,000.50');
      expect(MoneyFmt.number(-750), '-750');
    });
    test('PDF يبدأ بالترويسة', () {
      final p = PdfImageWriter()..addPage(Uint8List.fromList(List.filled(3 * 4 * 4, 200)), 4, 4);
      final b = p.build();
      expect(latin1.decode(b.sublist(0, 8)), '%PDF-1.4');
    });
  });
}
