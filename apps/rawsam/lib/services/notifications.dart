import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// الأصوات المميزة: لكل نوع إشعار قناة وصوت خاص (مدمجة داخل التطبيق كما تشترط أندرويد وآيفون).
class AppSounds {
  AppSounds._();
  static const post = 'rs_post';
  static const offer = 'rs_offer';
  static const gift = 'rs_gift';
  static const msg = 'rs_msg';
  static const booking = 'rs_booking';

  static const all = <String, String>{
    post: 'المنشورات الجديدة',
    offer: 'العروض',
    gift: 'الهدايا وعروض القرب',
    msg: 'رسائل المركز',
    booking: 'الحجوزات والتذكير',
  };
}

/// حدث ضغط على إشعار (يُفتح القسم المناسب).
class NotificationTap {
  final String type; // post | chat | coupon | booking | proximity
  final String? id;
  const NotificationTap(this.type, [this.id]);

  String encode() => jsonEncode({'t': type, 'i': id});
  static NotificationTap? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return NotificationTap(j['t'] as String, j['i'] as String?);
    } catch (_) {
      return null;
    }
  }
}

class LocalNotifications {
  LocalNotifications._();
  static final plugin = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<NotificationTap>.broadcast();
  static Stream<NotificationTap> get taps => _taps.stream;
  static NotificationTap? launchTap;
  static bool _ready = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  static IOSFlutterLocalNotificationsPlugin? get _ios => plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  /// [background] = true عند الاستدعاء من خلفية الجهاز (عروض القرب) — بدون تتبع الضغطات.
  static Future<void> init({bool background = false}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
    } catch (_) {}
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_rawsam'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) {
        final t = NotificationTap.decode(r.payload);
        if (t != null) _taps.add(t);
      },
    );
    if (!background) {
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch != null && launch.didNotificationLaunchApp) {
        launchTap = NotificationTap.decode(launch.notificationResponse?.payload);
      }
    }
    await _createChannels();
    if (Platform.isIOS && !background) await _installIosSounds();
    _ready = true;
  }

  static Future<void> _createChannels() async {
    final a = _android;
    if (a == null) return;
    for (final e in AppSounds.all.entries) {
      await a.createNotificationChannel(
        AndroidNotificationChannel(
          e.key,
          e.value,
          description: 'روسم للتجميل — ${e.value}',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(e.key),
        ),
      );
    }
  }

  /// آيفون يشغّل أصوات الإشعارات من Library/Sounds داخل التطبيق.
  static Future<void> _installIosSounds() async {
    try {
      final lib = await getLibraryDirectory();
      final dir = Directory('${lib.path}/Sounds');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      for (final name in AppSounds.all.keys) {
        final f = File('${dir.path}/$name.wav');
        if (f.existsSync()) continue;
        final data = await rootBundle.load('assets/sounds/$name.wav');
        await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
    } catch (_) {}
  }

  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  static Future<bool> enabled() async {
    if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? true;
    final p = await _ios?.checkPermissions();
    return p?.isEnabled ?? true;
  }

  static NotificationDetails details(String sound, {String? bigText}) => NotificationDetails(
    android: AndroidNotificationDetails(
      sound,
      AppSounds.all[sound] ?? 'روسم للتجميل',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(sound),
      styleInformation: bigText == null ? null : BigTextStyleInformation(bigText),
      color: const Color(0xFF2F6BFF),
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true, sound: '$sound.wav'),
  );

  static Future<void> show({required int id, required String title, required String body, required String sound, NotificationTap? tap}) async {
    await plugin.show(id: id, title: title, body: body, notificationDetails: details(sound, bigText: body), payload: tap?.encode());
  }

  /// تذكير الزبون بموعده: قبل ساعتين وقبل 15 دقيقة (بدون صلاحية المنبه الدقيق).
  static Future<void> scheduleBookingReminders(List<Booking> bookings) async {
    for (var i = 0; i < 40; i++) {
      await plugin.cancel(id: 9000 + i);
    }
    final now = DateTime.now();
    final upcoming = bookings.where((b) => b.upcoming && b.start.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
    var i = 0;
    for (final b in upcoming.take(20)) {
      for (final before in const [Duration(hours: 2), Duration(minutes: 15)]) {
        final at = b.start.subtract(before);
        if (at.isBefore(now)) {
          i++;
          continue;
        }
        final when = before.inHours >= 1 ? 'بعد ساعتين' : 'بعد ربع ساعة';
        await plugin.zonedSchedule(
          id: 9000 + i,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: details(AppSounds.booking),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'موعدك $when ⏰',
          body: '${b.serviceName.isEmpty ? 'موعدك' : b.serviceName} في روسم للتجميل',
          payload: NotificationTap('booking', b.id).encode(),
        );
        i++;
      }
    }
  }
}
