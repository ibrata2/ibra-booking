import 'dart:convert';

import '../../core/edition.dart';

/// أنواع التنبيهات. الترتيب ثابت لأنه يدخل في حساب رقم الإشعار.
enum ReminderType {
  approachStart, // اقتراب بداية الحجز
  start, // بداية الحجز
  approachEnd, // اقتراب نهاية الحجز
  end, // انتهاء الحجز
  nextBooking; // اقتراب الحجز التالي (أثناء حجز جارٍ)

  static ReminderType parse(String? v) => ReminderType.values.firstWhere((e) => e.name == v, orElse: () => ReminderType.start);
}

/// إعدادات تنبيهات حجز (أو الافتراضية لكل الحجوزات).
class ReminderConfig {
  final bool approachStart;
  final int approachStartMin;
  final bool start;
  final bool approachEnd;
  final int approachEndMin;
  final bool end;
  final bool nextBooking;
  final int nextBookingMin;

  /// التنبيه يبقى يرن حتى يفتح المستخدم التطبيق ويضغط «استلمت».
  final bool persistent;

  const ReminderConfig({
    this.approachStart = true,
    this.approachStartMin = 60,
    this.start = true,
    this.approachEnd = true,
    this.approachEndMin = 15,
    this.end = true,
    this.nextBooking = true,
    this.nextBookingMin = 60,
    this.persistent = true,
  });

  /// نسخة المركز: تذكير قبل الموعد بـ 15 دقيقة وعند البداية.
  static const defaults = Edition.isCenter
      ? ReminderConfig(approachStartMin: 15, approachEnd: false, end: false, nextBooking: false)
      : ReminderConfig();

  bool isEnabled(ReminderType t) => switch (t) {
    ReminderType.approachStart => approachStart,
    ReminderType.start => start,
    ReminderType.approachEnd => approachEnd,
    ReminderType.end => end,
    ReminderType.nextBooking => nextBooking,
  };

  ReminderConfig copyWith({
    bool? approachStart,
    int? approachStartMin,
    bool? start,
    bool? approachEnd,
    int? approachEndMin,
    bool? end,
    bool? nextBooking,
    int? nextBookingMin,
    bool? persistent,
  }) => ReminderConfig(
    approachStart: approachStart ?? this.approachStart,
    approachStartMin: approachStartMin ?? this.approachStartMin,
    start: start ?? this.start,
    approachEnd: approachEnd ?? this.approachEnd,
    approachEndMin: approachEndMin ?? this.approachEndMin,
    end: end ?? this.end,
    nextBooking: nextBooking ?? this.nextBooking,
    nextBookingMin: nextBookingMin ?? this.nextBookingMin,
    persistent: persistent ?? this.persistent,
  );

  Map<String, Object?> toJson() => {
    'as': approachStart,
    'asm': approachStartMin,
    's': start,
    'ae': approachEnd,
    'aem': approachEndMin,
    'e': end,
    'n': nextBooking,
    'nm': nextBookingMin,
    'p': persistent,
  };

  factory ReminderConfig.fromJson(Map<String, Object?> j) {
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    int i(String k, int d) => j[k] is num ? (j[k] as num).toInt() : d;
    return ReminderConfig(
      approachStart: b('as', true),
      approachStartMin: i('asm', 60),
      start: b('s', true),
      approachEnd: b('ae', true),
      approachEndMin: i('aem', 15),
      end: b('e', true),
      nextBooking: b('n', true),
      nextBookingMin: i('nm', 60),
      persistent: b('p', true),
    );
  }

  String encode() => jsonEncode(toJson());

  static ReminderConfig? tryDecode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      if (v is Map<String, Object?>) return ReminderConfig.fromJson(v);
    } catch (_) {}
    return null;
  }

  @override
  bool operator ==(Object other) => other is ReminderConfig && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
