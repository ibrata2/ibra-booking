import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

/// اختيار الملفات ونسخها لمساحة التطبيق (يعمل مع مسارات الملفات و content:// على أندرويد).
class FileHelper {
  FileHelper._();

  static String _safe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static Future<File> _copy(PlatformFile f, String destPath) async {
    final dest = File(destPath);
    final path = f.path;
    if (path != null && File(path).existsSync()) {
      return File(path).copy(dest.path);
    }
    return dest.writeAsBytes(await f.xFile.readAsBytes(), flush: true);
  }

  /// يختار ملفاً واحداً وينسخه للمجلد المؤقت ويعيد مساره.
  static Future<(String path, String name)?> pickOne({FileType type = FileType.any, List<String>? extensions}) async {
    final f = await FilePicker.pickFile(type: extensions == null ? type : FileType.custom, allowedExtensions: extensions);
    if (f == null) return null;
    final tmp = await getTemporaryDirectory();
    final out = await _copy(f, p.join(tmp.path, '${DateTime.now().microsecondsSinceEpoch}_${_safe(f.name)}'));
    return (out.path, f.name);
  }

  /// يختار مرفقات (صور/ملفات) وينسخها لمجلد المرفقات الدائم.
  static Future<List<(String path, String name)>> pickAttachments({bool imagesOnly = false}) async {
    final files = await FilePicker.pickFiles(type: imagesOnly ? FileType.image : FileType.any);
    final dir = await BackupService.attachmentsDir();
    final out = <(String, String)>[];
    for (final f in files) {
      final copied = await _copy(f, p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}_${_safe(f.name)}'));
      out.add((copied.path, f.name));
    }
    return out;
  }
}
