import 'dart:convert';

import 'reminder_config.dart';

/// كل إعدادات التطبيق (تخزن كـ JSON في جدول settings).
class AppSettings {
  final String language; // ar | en
  final String themeMode; // system | light | dark
  final int accent; // اللون الأساسي
  final double fontScale;
  final String fontFamily; // tajawal | system
  final String currencyCode;
  final String currencySymbol;
  final int weekStart; // 6=السبت 7=الأحد 1=الإثنين
  final int travelMinutes;
  final bool showFinance;
  final ReminderConfig reminders;
  final Map<String, String> soundByType; // ReminderType.name -> sound key
  final bool vibrate;
  final double previewVolume;
  final int snoozeMinutes;
  final bool fullScreenAlarm;
  final int iosRepeatCount; // عدد مرات إعادة الرنين في iOS حتى الاستلام
  final String mapsApp; // google | apple
  final String pinHash;
  final bool biometric;
  final bool autoBackup;
  final int lastBackupMs;
  final bool onboarded;

  const AppSettings({
    this.language = 'ar',
    this.themeMode = 'system',
    this.accent = 0xFF3D7BFF,
    this.fontScale = 1.0,
    this.fontFamily = 'tajawal',
    this.currencyCode = 'IQD',
    this.currencySymbol = 'د.ع',
    this.weekStart = 6,
    this.travelMinutes = 30,
    this.showFinance = true,
    this.reminders = ReminderConfig.defaults,
    this.soundByType = const {},
    this.vibrate = true,
    this.previewVolume = 0.8,
    this.snoozeMinutes = 10,
    this.fullScreenAlarm = true,
    this.iosRepeatCount = 6,
    this.mapsApp = 'google',
    this.pinHash = '',
    this.biometric = false,
    this.autoBackup = true,
    this.lastBackupMs = 0,
    this.onboarded = false,
  });

  bool get isArabic => language == 'ar';
  bool get hasPin => pinHash.isNotEmpty;

  String soundFor(ReminderType t) => soundByType[t.name] ?? 'app_chime';

  AppSettings copyWith({
    String? language,
    String? themeMode,
    int? accent,
    double? fontScale,
    String? fontFamily,
    String? currencyCode,
    String? currencySymbol,
    int? weekStart,
    int? travelMinutes,
    bool? showFinance,
    ReminderConfig? reminders,
    Map<String, String>? soundByType,
    bool? vibrate,
    double? previewVolume,
    int? snoozeMinutes,
    bool? fullScreenAlarm,
    int? iosRepeatCount,
    String? mapsApp,
    String? pinHash,
    bool? biometric,
    bool? autoBackup,
    int? lastBackupMs,
    bool? onboarded,
  }) => AppSettings(
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    fontScale: fontScale ?? this.fontScale,
    fontFamily: fontFamily ?? this.fontFamily,
    currencyCode: currencyCode ?? this.currencyCode,
    currencySymbol: currencySymbol ?? this.currencySymbol,
    weekStart: weekStart ?? this.weekStart,
    travelMinutes: travelMinutes ?? this.travelMinutes,
    showFinance: showFinance ?? this.showFinance,
    reminders: reminders ?? this.reminders,
    soundByType: soundByType ?? this.soundByType,
    vibrate: vibrate ?? this.vibrate,
    previewVolume: previewVolume ?? this.previewVolume,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    fullScreenAlarm: fullScreenAlarm ?? this.fullScreenAlarm,
    iosRepeatCount: iosRepeatCount ?? this.iosRepeatCount,
    mapsApp: mapsApp ?? this.mapsApp,
    pinHash: pinHash ?? this.pinHash,
    biometric: biometric ?? this.biometric,
    autoBackup: autoBackup ?? this.autoBackup,
    lastBackupMs: lastBackupMs ?? this.lastBackupMs,
    onboarded: onboarded ?? this.onboarded,
  );

  Map<String, Object?> toJson() => {
    'language': language,
    'themeMode': themeMode,
    'accent': accent,
    'fontScale': fontScale,
    'fontFamily': fontFamily,
    'currencyCode': currencyCode,
    'currencySymbol': currencySymbol,
    'weekStart': weekStart,
    'travelMinutes': travelMinutes,
    'showFinance': showFinance,
    'reminders': reminders.toJson(),
    'soundByType': soundByType,
    'vibrate': vibrate,
    'previewVolume': previewVolume,
    'snoozeMinutes': snoozeMinutes,
    'fullScreenAlarm': fullScreenAlarm,
    'iosRepeatCount': iosRepeatCount,
    'mapsApp': mapsApp,
    'pinHash': pinHash,
    'biometric': biometric,
    'autoBackup': autoBackup,
    'lastBackupMs': lastBackupMs,
    'onboarded': onboarded,
  };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    T v<T>(String k, T def) => j[k] is T ? j[k] as T : def;
    double dbl(String k, double def) => j[k] is num ? (j[k] as num).toDouble() : def;
    int i(String k, int def) => j[k] is num ? (j[k] as num).toInt() : def;
    final sounds = <String, String>{};
    final raw = j['soundByType'];
    if (raw is Map) {
      raw.forEach((k, val) {
        if (k is String && val is String) sounds[k] = val;
      });
    }
    final rem = j['reminders'];
    return AppSettings(
      language: v('language', d.language),
      themeMode: v('themeMode', d.themeMode),
      accent: i('accent', d.accent),
      fontScale: dbl('fontScale', d.fontScale),
      fontFamily: v('fontFamily', d.fontFamily),
      currencyCode: v('currencyCode', d.currencyCode),
      currencySymbol: v('currencySymbol', d.currencySymbol),
      weekStart: i('weekStart', d.weekStart),
      travelMinutes: i('travelMinutes', d.travelMinutes),
      showFinance: v('showFinance', d.showFinance),
      reminders: rem is Map<String, Object?> ? ReminderConfig.fromJson(rem) : d.reminders,
      soundByType: sounds,
      vibrate: v('vibrate', d.vibrate),
      previewVolume: dbl('previewVolume', d.previewVolume),
      snoozeMinutes: i('snoozeMinutes', d.snoozeMinutes),
      fullScreenAlarm: v('fullScreenAlarm', d.fullScreenAlarm),
      iosRepeatCount: i('iosRepeatCount', d.iosRepeatCount),
      mapsApp: v('mapsApp', d.mapsApp),
      pinHash: v('pinHash', d.pinHash),
      biometric: v('biometric', d.biometric),
      autoBackup: v('autoBackup', d.autoBackup),
      lastBackupMs: i('lastBackupMs', d.lastBackupMs),
      onboarded: v('onboarded', d.onboarded),
    );
  }

  String encode() => jsonEncode(toJson());

  static AppSettings decode(String? s) {
    if (s == null || s.isEmpty) return const AppSettings();
    try {
      final j = jsonDecode(s);
      if (j is Map<String, Object?>) return AppSettings.fromJson(j);
    } catch (_) {}
    return const AppSettings();
  }
}
