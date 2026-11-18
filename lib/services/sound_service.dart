import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ibra_native/ibra_native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/entities/entities.dart';
import '../domain/repositories.dart';

/// إدارة أصوات التنبيه: المدمجة + المستوردة + المسجلة من الميكروفون.
class SoundService {
  SoundService(this.repo);
  final SoundRepository repo;

  static const builtinKeys = ['app_chime', 'app_bell', 'app_soft', 'app_alert', 'app_digital'];

  /// الحد الأقصى لمدة صوت الإشعار (قيود iOS أقل من 30 ثانية).
  static const maxMs = 29000;

  Directory? _support;

  Future<Directory> soundsDir() async {
    _support ??= await getApplicationSupportDirectory();
    final d = Directory(p.join(_support!.path, 'sounds'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory?> _iosLibrarySounds() async {
    if (!Platform.isIOS) return null;
    final lib = await getLibraryDirectory();
    final d = Directory(p.join(lib.path, 'Sounds'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  AlertSound builtin(String key) => AlertSound(key: key, name: key, filePath: '', createdAt: DateTime(2026));

  static final systemDefault = AlertSound(key: 'default', name: 'default', createdAt: DateTime(2026));

  /// يجهز الأصوات المدمجة على القرص (للمعاينة) وينسخ الأصوات إلى Library/Sounds في iOS.
  Future<void> prepare() async {
    final dir = await soundsDir();
    final builtinDir = Directory(p.join(dir.path, 'builtin'))..createSync(recursive: true);
    final ios = await _iosLibrarySounds();
    for (final k in builtinKeys) {
      final name = '${k.replaceFirst('app_', 'ib_')}.wav';
      final f = File(p.join(builtinDir.path, name));
      if (!f.existsSync()) {
        final data = await rootBundle.load('assets/sounds/$name');
        await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      if (ios != null) {
        final t = File(p.join(ios.path, name));
        if (!t.existsSync()) await f.copy(t.path);
      }
    }
    if (ios != null) {
      for (final s in await repo.all()) {
        final t = File(p.join(ios.path, iosSoundName(s)));
        if (!t.existsSync() && File(s.filePath).existsSync()) await File(s.filePath).copy(t.path);
      }
    }
  }

  /// الأصوات المتاحة: افتراضي النظام + المدمجة + المخصصة.
  Future<List<AlertSound>> available() async => [systemDefault, for (final k in builtinKeys) builtin(k), ...await repo.all()];

  Future<AlertSound> resolve(String key, List<AlertSound> customs) async {
    if (key == 'default') return systemDefault;
    if (key.startsWith('app_')) return builtin(key);
    for (final s in customs) {
      if (s.key == key) return s;
    }
    return builtin('app_chime');
  }

  /// مسار ملف قابل للتشغيل للمعاينة.
  Future<String?> playablePath(AlertSound s) async {
    if (s.isSystemDefault) {
      final dir = await soundsDir();
      return p.join(dir.path, 'builtin', 'ib_chime.wav');
    }
    if (s.isBuiltIn) {
      final dir = await soundsDir();
      return p.join(dir.path, 'builtin', '${s.resourceName}.wav');
    }
    return File(s.filePath).existsSync() ? s.filePath : null;
  }

  Future<void> preview(AlertSound s, {double volume = 0.8, bool loop = false}) async {
    final path = await playablePath(s);
    if (path == null) return;
    await IbraNative.play(path, volume: volume, loop: loop);
  }

  Future<void> stop() => IbraNative.stop();

  /// اسم الملف في Library/Sounds لـ iOS.
  String iosSoundName(AlertSound s) => s.isBuiltIn ? '${s.resourceName}.wav' : 'ibc_${s.id}.wav';

  /// استيراد ملف صوتي (MP3/WAV/M4A/AAC) مع القص والتحويل إلى WAV متوافق.
  Future<AlertSound> import({required String sourcePath, required String name, int startMs = 0, int endMs = 0}) async {
    final dir = await soundsDir();
    final tmp = p.join(dir.path, 'tmp_${DateTime.now().microsecondsSinceEpoch}.wav');
    final duration = await IbraNative.decodeToWav(input: sourcePath, output: tmp, startMs: startMs, endMs: endMs, maxMs: maxMs);
    if (duration <= 0) {
      try {
        File(tmp).deleteSync();
      } catch (_) {}
      throw const FormatException('empty');
    }
    final id = await repo.save(AlertSound(key: 'c0', name: name, filePath: tmp, durationMs: duration, createdAt: DateTime.now()));
    final finalPath = p.join(dir.path, 'custom_$id.wav');
    await File(tmp).rename(finalPath);
    var sound = AlertSound(id: id, key: 'c$id', name: name, filePath: finalPath, durationMs: duration, createdAt: DateTime.now());
    if (Platform.isAndroid) {
      final uri = await IbraNative.registerAndroidSound(finalPath, name);
      sound = sound.copyWith(androidUri: uri ?? '');
    }
    final ios = await _iosLibrarySounds();
    if (ios != null) await File(finalPath).copy(p.join(ios.path, iosSoundName(sound)));
    await repo.save(sound);
    return sound;
  }

  Future<void> rename(AlertSound s, String name) => repo.save(s.copyWith(name: name));

  Future<void> delete(AlertSound s) async {
    if (s.id == null) return;
    if (s.androidUri.isNotEmpty) {
      try {
        await IbraNative.unregisterAndroidSound(s.androidUri);
      } catch (_) {}
    }
    try {
      File(s.filePath).deleteSync();
    } catch (_) {}
    final ios = await _iosLibrarySounds();
    if (ios != null) {
      try {
        File(p.join(ios.path, iosSoundName(s))).deleteSync();
      } catch (_) {}
    }
    await repo.delete(s.id!);
  }

  /// بعد استعادة نسخة احتياطية: إعادة تسجيل الأصوات المخصصة لدى النظام.
  Future<void> reRegisterAll() async {
    final dir = await soundsDir();
    for (final s in await repo.all()) {
      final path = p.join(dir.path, 'custom_${s.id}.wav');
      if (!File(path).existsSync()) continue;
      var upd = AlertSound(id: s.id, key: s.key, name: s.name, filePath: path, durationMs: s.durationMs, createdAt: s.createdAt);
      if (Platform.isAndroid) {
        final uri = await IbraNative.registerAndroidSound(path, s.name);
        upd = upd.copyWith(androidUri: uri ?? '');
      }
      await repo.save(upd);
    }
    await prepare();
  }
}
