import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/files/zip.dart';
import '../data/db/app_database.dart';

/// النسخ الاحتياطي والاستعادة: البيانات كـ JSON + الأصوات المخصصة + المرفقات في ملف واحد.
class BackupService {
  BackupService(this.db);
  final Database db;

  static const tables = [
    'customers',
    'categories',
    'staff',
    'services',
    'recurring_appointments',
    'custom_sounds',
    'appointments',
    'payments',
    'expenses',
    'attachments',
    'settings',
  ];

  static Future<Directory> attachmentsDir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'attachments'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<Directory> backupsDir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'backups'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<Directory> soundsDir() async {
    final d = Directory(p.join((await getApplicationSupportDirectory()).path, 'sounds'));
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// ينشئ ملف النسخة الاحتياطية ويعيد مساره.
  Future<File> create({Directory? into, String? fileName}) async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final t in tables) {
      data[t] = await db.query(t);
    }
    // مسارات نسبية للملفات
    final entries = <ZipEntry>[];
    final sDir = await soundsDir();
    for (final row in data['custom_sounds']!) {
      final f = File(row['file_path'] as String? ?? '');
      final name = 'custom_${row['id']}.wav';
      final file = f.existsSync() ? f : File(p.join(sDir.path, name));
      if (file.existsSync()) entries.add(ZipEntry('files/sounds/$name', await file.readAsBytes()));
    }
    for (final row in data['attachments']!) {
      final f = File(row['file_path'] as String? ?? '');
      if (f.existsSync()) entries.add(ZipEntry('files/attachments/${p.basename(f.path)}', await f.readAsBytes()));
    }
    final manifest = {
      'app': 'IBRA BOOKING',
      'schema': AppDatabase.version,
      'created': DateTime.now().toIso8601String(),
      'counts': {for (final e in data.entries) e.key: e.value.length},
    };
    entries.insert(0, ZipEntry.text('manifest.json', jsonEncode(manifest)));
    entries.insert(1, ZipEntry.text('data.json', jsonEncode(data)));
    final bytes = ZipCodec.encode(entries);
    final dir = into ?? await getTemporaryDirectory();
    final now = DateTime.now();
    final name = fileName ?? 'IBRA_BOOKING_${now.year}${_2(now.month)}${_2(now.day)}_${_2(now.hour)}${_2(now.minute)}.ibrabackup';
    final out = File(p.join(dir.path, name));
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  static String _2(int v) => v.toString().padLeft(2, '0');

  /// نسخة تلقائية يومية داخل التطبيق (تحفظ آخر 7 نسخ).
  Future<File?> autoBackupIfDue(int lastMs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastMs < const Duration(hours: 24).inMilliseconds) return null;
    final dir = await backupsDir();
    final f = await create(into: dir, fileName: 'auto_${DateTime.now().millisecondsSinceEpoch}.ibrabackup');
    final all = dir.listSync().whereType<File>().where((e) => e.path.endsWith('.ibrabackup')).toList()..sort((a, b) => b.path.compareTo(a.path));
    for (final old in all.skip(7)) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    return f;
  }

  Future<List<File>> autoBackups() async {
    final dir = await backupsDir();
    return dir.listSync().whereType<File>().where((e) => e.path.endsWith('.ibrabackup')).toList()..sort((a, b) => b.path.compareTo(a.path));
  }

  /// يتحقق من الملف ويعيد ملخصه قبل الاستعادة.
  Map<String, Object?> inspect(Uint8List bytes) {
    final entries = ZipCodec.decode(bytes);
    final m = entries.where((e) => e.name == 'manifest.json').firstOrNull;
    if (m == null || !entries.any((e) => e.name == 'data.json')) {
      throw const FormatException('invalid');
    }
    final j = jsonDecode(utf8.decode(m.data)) as Map<String, Object?>;
    if (j['app'] != 'IBRA BOOKING') throw const FormatException('invalid');
    return j;
  }

  /// يستبدل كل البيانات الحالية بمحتوى النسخة.
  Future<void> restore(Uint8List bytes) async {
    final entries = ZipCodec.decode(bytes);
    final dataEntry = entries.firstWhere((e) => e.name == 'data.json');
    final data = (jsonDecode(utf8.decode(dataEntry.data)) as Map<String, dynamic>);
    final sDir = await soundsDir();
    final aDir = await attachmentsDir();
    // الملفات أولاً
    for (final e in entries) {
      if (e.name.startsWith('files/sounds/')) {
        await File(p.join(sDir.path, p.basename(e.name))).writeAsBytes(e.data, flush: true);
      } else if (e.name.startsWith('files/attachments/')) {
        await File(p.join(aDir.path, p.basename(e.name))).writeAsBytes(e.data, flush: true);
      }
    }
    await db.transaction((txn) async {
      for (final t in tables.reversed) {
        await txn.delete(t);
      }
      for (final t in tables) {
        final rows = (data[t] as List?) ?? const [];
        for (final r in rows) {
          final row = Map<String, Object?>.from(r as Map);
          if (t == 'custom_sounds') {
            row['file_path'] = p.join(sDir.path, 'custom_${row['id']}.wav');
            row['android_uri'] = '';
          } else if (t == 'attachments') {
            row['file_path'] = p.join(aDir.path, p.basename((row['file_path'] as String?) ?? ''));
          }
          await txn.insert(t, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await txn.delete('reminders');
    });
  }
}
