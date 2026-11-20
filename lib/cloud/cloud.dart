import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/edition.dart';

/// إعدادات الربط مع تطبيق الزبائن «روسم للتجميل» (نسخة المركز فقط).
/// تنكتب مرة وحدة من شاشة الربط أو تنبني مع التطبيق من GitHub Secrets.
class CloudConfig {
  final String url;
  final String anonKey;
  const CloudConfig({this.url = '', this.anonKey = ''});

  static const _builtUrl = String.fromEnvironment('CLOUD_URL');
  static const _builtKey = String.fromEnvironment('CLOUD_ANON_KEY');

  bool get valid => url.startsWith('https://') && anonKey.length > 20;

  static Future<CloudConfig> load(Database db) async {
    try {
      final r = await db.query('settings', where: 'key = ?', whereArgs: ['cloud'], limit: 1);
      if (r.isNotEmpty) {
        final j = jsonDecode(r.first['value'] as String) as Map<String, dynamic>;
        final c = CloudConfig(url: (j['url'] as String?) ?? '', anonKey: (j['key'] as String?) ?? '');
        if (c.valid) return c;
      }
    } catch (_) {}
    return const CloudConfig(url: _builtUrl, anonKey: _builtKey);
  }

  Future<void> save(Database db) => db.insert('settings', {
    'key': 'cloud',
    'value': jsonEncode({'url': url.trim(), 'key': anonKey.trim()}),
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// الموظف الحالي المسجل دخوله.
class StaffMe {
  final String userId;
  final String name;
  final bool admin;
  const StaffMe({required this.userId, required this.name, required this.admin});
}

class Cloud {
  Cloud._();
  static bool ready = false;
  static CloudConfig config = const CloudConfig();
  static bool _firebase = false;

  static SupabaseClient get db => Supabase.instance.client;
  static User? get user => ready ? db.auth.currentUser : null;

  static Future<void> init(Database localDb) async {
    if (!Edition.isCenter) return;
    config = await CloudConfig.load(localDb);
    if (!config.valid) return;
    try {
      await Supabase.initialize(url: config.url, anonKey: config.anonKey);
      ready = true;
    } catch (_) {}
    await _initFirebase();
    if (ready && user != null) unawaited(registerPush());
  }

  static Future<StaffMe?> me() async {
    final u = user;
    if (u == null) return null;
    final r = await db.from('staff_members').select().eq('user_id', u.id).eq('active', true).maybeSingle();
    if (r == null) return null;
    return StaffMe(userId: u.id, name: (r['display_name'] as String?) ?? '', admin: r['role'] == 'admin');
  }

  static Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(email: email.trim(), password: password);
    unawaited(registerPush());
  }

  /// أول مرة: حساب المدير (أول من يسجل يصير مدير تلقائياً).
  static Future<bool> signUpFirstAdmin(String email, String password, String name) async {
    final res = await db.auth.signUp(email: email.trim(), password: password);
    if (res.session == null) {
      await db.auth.signInWithPassword(email: email.trim(), password: password);
    }
    final ok = await db.rpc('claim_first_admin', params: {'p_name': name.trim()});
    unawaited(registerPush());
    return ok == true;
  }

  /// المدير يضيف موظف بحساب جديد (بدون ما يطلع من حسابه).
  static Future<void> addStaff({required String email, required String password, required String name, bool admin = false}) async {
    final temp = SupabaseClient(config.url, config.anonKey, authOptions: const AuthClientOptions(autoRefreshToken: false));
    try {
      final res = await temp.auth.signUp(email: email.trim(), password: password);
      final id = res.user?.id;
      if (id == null) throw const AuthException('signup failed');
      await db.from('staff_members').insert({'user_id': id, 'display_name': name.trim(), 'role': admin ? 'admin' : 'staff'});
    } finally {
      await temp.dispose();
    }
  }

  static Future<void> signOut() async {
    try {
      final t = _firebase ? await FirebaseMessaging.instance.getToken() : null;
      if (t != null) await db.from('device_tokens').delete().eq('token', t);
    } catch (_) {}
    await db.auth.signOut();
  }

  // ------------------------------------------------------------ الإشعارات

  static const _fbApiKey = String.fromEnvironment('FB_API_KEY');
  static const _fbSender = String.fromEnvironment('FB_SENDER_ID');
  static const _fbProject = String.fromEnvironment('FB_PROJECT_ID');
  static const _fbAndroid = String.fromEnvironment('FB_APP_ID_CENTER_ANDROID');
  static const _fbIos = String.fromEnvironment('FB_APP_ID_CENTER_IOS');

  static Future<void> _initFirebase() async {
    if (_fbApiKey.isEmpty || _fbSender.isEmpty || _fbProject.isEmpty) return;
    final appId = Platform.isIOS ? _fbIos : _fbAndroid;
    if (appId.isEmpty) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(apiKey: _fbApiKey, appId: appId, messagingSenderId: _fbSender, projectId: _fbProject),
      );
      _firebase = true;
      // قناة إشعار رسائل الزبائن
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'rs_staff_msg',
              'رسائل الزبائن',
              description: 'رسائل تطبيق روسم للتجميل',
              importance: Importance.high,
            ),
          );
    } catch (_) {}
  }

  static Future<void> registerPush() async {
    if (!_firebase || user == null) return;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      await m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      final t = await m.getToken();
      if (t != null) await db.rpc('register_token', params: {'p_token': t, 'p_kind': 'staff', 'p_platform': Platform.operatingSystem});
      m.onTokenRefresh.listen((t) => db.rpc('register_token', params: {'p_token': t, 'p_kind': 'staff', 'p_platform': Platform.operatingSystem}));
    } catch (_) {}
  }

  // ------------------------------------------------------------ أدوات

  static String publicUrl(String bucket, String path) => db.storage.from(bucket).getPublicUrl(path);

  static Future<String> upload(String bucket, File file, {String? folder}) async {
    final name = file.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '${folder == null ? '' : '$folder/'}${DateTime.now().millisecondsSinceEpoch}_$name';
    await db.storage.from(bucket).upload(path, file);
    return publicUrl(bucket, path);
  }
}
