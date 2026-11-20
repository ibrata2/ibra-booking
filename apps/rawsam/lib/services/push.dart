import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/config.dart';
import '../data/repository.dart';
import 'notifications.dart';

/// إشعارات المركز عبر Firebase: المنشورات والعروض (لكل الزبائن) والرسائل والحجوزات والهدايا (لك وحدك).
class PushService {
  PushService._();
  static bool _ready = false;
  static final _taps = StreamController<NotificationTap>.broadcast();
  static Stream<NotificationTap> get taps => _taps.stream;
  static NotificationTap? launchTap;

  static Future<void> initFirebase() async {
    if (!AppConfig.hasFirebase || _ready) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConfig.fbApiKey,
          appId: Platform.isIOS ? AppConfig.fbAppIdIos : AppConfig.fbAppIdAndroid,
          messagingSenderId: AppConfig.fbSenderId,
          projectId: AppConfig.fbProjectId,
        ),
      );
      _ready = true;
    } catch (_) {}
  }

  static NotificationTap _tapOf(RemoteMessage m) {
    final t = (m.data['type'] as String?) ?? 'post';
    return NotificationTap(t, (m.data['id'] ?? m.data['code']) as String?);
  }

  /// يربط الجهاز بالمركز بعد موافقة الزبون على الإشعارات.
  static Future<void> attach(CenterRepository repo, {required bool promos}) async {
    if (!_ready) return;
    final m = FirebaseMessaging.instance;
    try {
      await m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((msg) {
        // أندرويد لا يعرض إشعار Firebase والتطبيق مفتوح — نعرضه بنفس الصوت المميز
        if (!Platform.isAndroid) return;
        final n = msg.notification;
        if (n == null) return;
        final ch = n.android?.channelId;
        LocalNotifications.show(
          id: msg.hashCode & 0x7fffffff,
          title: n.title ?? AppConfig.centerName,
          body: n.body ?? '',
          sound: AppSounds.all.containsKey(ch) ? ch! : AppSounds.post,
          tap: _tapOf(msg),
        );
      });
      FirebaseMessaging.onMessageOpenedApp.listen((msg) => _taps.add(_tapOf(msg)));
      final initial = await m.getInitialMessage();
      if (initial != null) launchTap = _tapOf(initial);

      if (Platform.isIOS) {
        // آيفون يحتاج رمز APNs قبل رمز Firebase
        for (var i = 0; i < 5 && await m.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      final token = await m.getToken();
      if (token != null) await repo.registerPushToken(token, Platform.operatingSystem);
      m.onTokenRefresh.listen((t) => repo.registerPushToken(t, Platform.operatingSystem));
      await setPromos(promos);
    } catch (_) {}
  }

  /// الزبون يقدر يطفي إشعارات العروض والمنشورات من الإعدادات (رسائل المركز وحجوزاته تبقى).
  static Future<void> setPromos(bool on) async {
    if (!_ready) return;
    try {
      if (on) {
        await FirebaseMessaging.instance.subscribeToTopic(AppConfig.customersTopic);
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(AppConfig.customersTopic);
      }
    } catch (_) {}
  }
}
