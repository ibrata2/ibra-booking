import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/demo_repository.dart';
import 'data/repository.dart';
import 'data/supabase_repository.dart';
import 'services/media.dart';
import 'services/notifications.dart';
import 'services/push.dart';
import 'state.dart';

/// روسم للتجميل — تطبيق الزبائن
/// برمجة وتطوير ابراهيم الخزرجي
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
  );

  try {
    await LocalNotifications.init();
  } catch (_) {}
  await PushService.initFirebase();

  CenterRepository repo = DemoCenterRepository();
  if (AppConfig.hasCloud) {
    try {
      // لا يحتاج إنترنت هنا — الاتصال وتسجيل الدخول يصيران بشاشة البداية مع إعادة المحاولة
      await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
      repo = SupabaseCenterRepository(platform: Platform.operatingSystem, build: await Updater.currentBuild());
    } catch (_) {}
  }

  runApp(ProviderScope(overrides: [repoProvider.overrideWithValue(repo)], child: const RawsamApp()));
}
