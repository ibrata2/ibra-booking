import 'package:flutter/services.dart';

/// واجهة Dart للتكاملات الأصلية (Android Kotlin / iOS Swift).
class IbraNative {
  IbraNative._();
  static const MethodChannel _ch = MethodChannel('com.ibraprogram/ibra_native');

  /// معرّف المنطقة الزمنية للجهاز (مثل Asia/Baghdad).
  static Future<String> timeZone() async => (await _ch.invokeMethod<String>('timeZone')) ?? 'UTC';

  /// يحوّل أي ملف صوتي مدعوم (MP3/WAV/M4A/AAC) إلى WAV PCM 16-bit مع القص.
  /// يعيد مدة الناتج بالملي ثانية.
  static Future<int> decodeToWav({required String input, required String output, int startMs = 0, int endMs = 0, int maxMs = 29000}) async {
    final r = await _ch.invokeMethod<int>('decodeToWav', {'input': input, 'output': output, 'startMs': startMs, 'endMs': endMs, 'maxMs': maxMs});
    return r ?? 0;
  }

  /// مدة ملف صوتي بالملي ثانية.
  static Future<int> durationMs(String path) async => (await _ch.invokeMethod<int>('durationMs', {'path': path})) ?? 0;

  /// أندرويد: يسجل الصوت في مكتبة أصوات الإشعارات ويعيد content:// URI صالح لقنوات الإشعارات.
  static Future<String?> registerAndroidSound(String path, String title) => _ch.invokeMethod<String>('registerSound', {'path': path, 'title': title});

  static Future<void> unregisterAndroidSound(String uri) => _ch.invokeMethod<void>('unregisterSound', {'uri': uri});

  /// معاينة صوت داخل التطبيق.
  static Future<void> play(String path, {double volume = 1, int startMs = 0, int endMs = 0, bool loop = false}) =>
      _ch.invokeMethod<void>('play', {'path': path, 'volume': volume, 'startMs': startMs, 'endMs': endMs, 'loop': loop});

  static Future<void> stop() => _ch.invokeMethod<void>('stop');

  /// أندرويد: هل التطبيق مستثنى من تحسين البطارية؟ (iOS دائماً true)
  static Future<bool> isIgnoringBatteryOptimizations() async => (await _ch.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ?? true;

  /// أندرويد: يفتح صفحة إعدادات تحسين البطارية.
  static Future<void> openBatterySettings() => _ch.invokeMethod<void>('openBatterySettings');
}
