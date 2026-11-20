import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'cloud/cloud.dart';
import 'data/db/app_database.dart';
import 'data/repositories/sqlite_repositories.dart';
import 'presentation/providers.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';

/// IBRA BOOKING — حجوزات IBRA
/// برمجة وتطوير ابراهيم الخزرجي
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  final db = await AppDatabase.open();
  // نسخة المركز: الربط مع تطبيق الزبائن (إذا كان مُعداً)
  try {
    await Cloud.init(db.db);
  } catch (_) {}
  final settingsRepo = SqliteSettingsRepository(db.db);
  var settings = await settingsRepo.load();

  final sounds = SoundService(SqliteSoundRepository(db.db));
  try {
    await sounds.prepare();
  } catch (_) {}

  final notifications = NotificationService(logs: SqliteReminderLogRepository(db.db), sounds: sounds);
  try {
    await notifications.init(ar: settings.isArabic);
  } catch (_) {}

  // نسخة احتياطية تلقائية يومية
  if (settings.autoBackup) {
    try {
      final f = await BackupService(db.db).autoBackupIfDue(settings.lastBackupMs);
      if (f != null) {
        settings = settings.copyWith(lastBackupMs: DateTime.now().millisecondsSinceEpoch);
        await settingsRepo.save(settings);
      }
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialSettingsProvider.overrideWithValue(settings),
        notificationServiceProvider.overrideWithValue(notifications),
        soundServiceProvider.overrideWithValue(sounds),
      ],
      child: const IbraBookingApp(),
    ),
  );
}
