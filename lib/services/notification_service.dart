import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ibra_native/ibra_native.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/l10n/tr.dart';
import '../core/time/time_format.dart';
import '../domain/entities/entities.dart';
import '../domain/logic/scheduling.dart';
import '../domain/repositories.dart';
import 'sound_service.dart';

/// حمولة الإشعار (تمر مع الضغط عليه أو على أزراره).
class AlarmPayload {
  final int appointmentId;
  final ReminderType type;
  final int baseId;
  final bool persistent;
  const AlarmPayload({required this.appointmentId, required this.type, required this.baseId, required this.persistent});

  String encode() => jsonEncode({'a': appointmentId, 't': type.name, 'n': baseId, 'p': persistent});

  static AlarmPayload? decode(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return AlarmPayload(
        appointmentId: j['a'] as int,
        type: ReminderType.parse(j['t'] as String?),
        baseId: j['n'] as int,
        persistent: j['p'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// حدث ناتج عن تفاعل المستخدم مع إشعار.
class AlarmEvent {
  final AlarmPayload payload;
  final String? action; // null = ضغط على الإشعار
  const AlarmEvent(this.payload, this.action);
}

class PermissionStatus {
  final bool notifications;
  final bool exactAlarms;
  final bool batteryUnrestricted;
  const PermissionStatus({this.notifications = true, this.exactAlarms = true, this.batteryUnrestricted = true});
  bool get allGood => notifications && exactAlarms;
}

/// نظام الإشعارات المحلي: جدولة مستقلة لكل حجز، منع التكرار، أصوات مخصصة،
/// رنين مستمر حتى الاستلام، إجراءات سريعة، واحترام حدود iOS.
class NotificationService {
  NotificationService({required this.logs, required this.sounds});
  final ReminderLogRepository logs;
  final SoundService sounds;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<AlarmEvent> _events = StreamController<AlarmEvent>.broadcast();
  Stream<AlarmEvent> get events => _events.stream;
  AlarmEvent? pendingLaunch;

  static const actAck = 'ack';
  static const actSnooze = 'snooze';
  static const actCall = 'call';
  static const actMap = 'map';
  static const actDone = 'done';
  static const iosCategory = 'ibra_alarm';

  /// iOS يسمح بـ 64 إشعاراً مجدولاً كحد أقصى.
  static int get budget => Platform.isIOS ? 60 : 400;

  /// الفاصل بين مرات إعادة الرنين حتى الاستلام.
  static const repeatEvery = Duration(minutes: 2);

  bool _ready = false;
  Future<void> _lock = Future<void>.value();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<void> init({required bool ar}) async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await refreshTimeZone();
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          iosCategory,
          actions: [
            DarwinNotificationAction.plain(actAck, Tr.t('n_act_ack', ar: ar), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(actSnooze, Tr.t('n_act_snooze', ar: ar), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(actCall, Tr.t('n_act_call', ar: ar), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(actMap, Tr.t('n_act_map', ar: ar), options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain(actDone, Tr.t('n_act_done', ar: ar), options: {DarwinNotificationActionOption.foreground}),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: const AndroidInitializationSettings('ic_stat_ibra'), iOS: darwin),
      onDidReceiveNotificationResponse: _onResponse,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch != null && launch.didNotificationLaunchApp && launch.notificationResponse != null) {
      final r = launch.notificationResponse!;
      final p = AlarmPayload.decode(r.payload);
      if (p != null) pendingLaunch = AlarmEvent(p, r.actionId);
    }
    _ready = true;
  }

  void _onResponse(NotificationResponse r) {
    final p = AlarmPayload.decode(r.payload);
    if (p == null) return;
    _events.add(AlarmEvent(p, (r.actionId == null || r.actionId!.isEmpty) ? null : r.actionId));
  }

  /// يضبط المنطقة الزمنية المحلية (يستدعى عند كل عودة للتطبيق لمعالجة تغيير الساعة/المنطقة).
  Future<bool> refreshTimeZone() async {
    final before = tz.local.name;
    String name;
    try {
      name = await IbraNative.timeZone();
    } catch (_) {
      name = 'UTC';
    }
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // البحث عن منطقة بنفس الإزاحة الحالية
      final offset = DateTime.now().timeZoneOffset.inMilliseconds;
      tz.Location? found;
      for (final l in tz.timeZoneDatabase.locations.values) {
        if (l.currentTimeZone.offset == offset) {
          found = l;
          break;
        }
      }
      tz.setLocalLocation(found ?? tz.UTC);
    }
    return before != tz.local.name;
  }

  // ---------------- الصلاحيات ----------------

  Future<PermissionStatus> status() async {
    if (Platform.isAndroid) {
      final a = _android;
      final enabled = await a?.areNotificationsEnabled() ?? true;
      final exact = await a?.canScheduleExactNotifications() ?? true;
      bool battery = true;
      try {
        battery = await IbraNative.isIgnoringBatteryOptimizations();
      } catch (_) {}
      return PermissionStatus(notifications: enabled, exactAlarms: exact, batteryUnrestricted: battery);
    }
    if (Platform.isIOS) {
      final opts = await _ios?.checkPermissions();
      return PermissionStatus(notifications: opts?.isEnabled ?? false);
    }
    return const PermissionStatus();
  }

  Future<PermissionStatus> request({bool fullScreen = true}) async {
    if (Platform.isAndroid) {
      final a = _android;
      await a?.requestNotificationsPermission();
      if (!(await a?.canScheduleExactNotifications() ?? true)) {
        await a?.requestExactAlarmsPermission();
      }
      if (fullScreen) {
        try {
          await a?.requestFullScreenIntentPermission();
        } catch (_) {}
      }
    } else if (Platform.isIOS) {
      await _ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
    return status();
  }

  Future<void> openSystemSettings() async {
    if (Platform.isAndroid) {
      await _android?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await _ios?.openAppNotificationSettings();
    }
  }

  // ---------------- الجدولة ----------------

  /// يعيد جدولة كل التنبيهات من الصفر (يلغي القديمة أولاً فلا تتكرر أبداً).
  Future<int> rescheduleAll({
    required List<Appointment> appointments,
    required AppSettings settings,
    required List<EventCategory> categories,
    required List<AlertSound> customSounds,
  }) {
    final completer = Completer<int>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await _reschedule(appointments, settings, categories, customSounds));
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<int> _reschedule(List<Appointment> appts, AppSettings settings, List<EventCategory> cats, List<AlertSound> customs) async {
    if (!_ready) return 0;
    final now = DateTime.now();
    final previous = await logs.all();
    final acked = previous.where((l) => l.acknowledged).map((l) => l.notificationId).toSet();
    final snoozes = previous.where((l) => l.type.startsWith('snooze:') && l.fireAt.isAfter(now)).toList();

    await _plugin.cancelAllPendingNotifications();

    // ننظر للخلف قليلاً لإكمال إعادة الرنين لتنبيهات لم تُستلم بعد
    final lookback = repeatEvery * (settings.iosRepeatCount + 1);
    final plan = ReminderPlanner.plan(
      appointments: appts,
      defaults: settings.reminders,
      now: now.subtract(lookback),
      horizon: now.add(const Duration(days: 45)),
    );
    final byId = {
      for (final a in appts)
        if (a.id != null) a.id!: a,
    };
    final newLogs = <ReminderLog>[];
    var used = 0;
    final exact = Platform.isAndroid ? (await _android?.canScheduleExactNotifications() ?? false) : true;

    // التأجيلات المعلقة أولاً
    for (final s in snoozes) {
      final a = byId[s.appointmentId];
      if (a == null || a.status.isClosed) continue;
      final type = ReminderType.parse(s.type.substring(7));
      await _schedule(
        id: s.notificationId,
        at: s.fireAt,
        appt: a,
        type: type,
        baseId: NotificationIds.base(a.id!, type),
        persistent: (a.reminderOverride ?? settings.reminders).persistent,
        settings: settings,
        cats: cats,
        customs: customs,
        exact: exact,
        snoozed: true,
      );
      newLogs.add(ReminderLog(appointmentId: a.id!, type: s.type, fireAt: s.fireAt, notificationId: s.notificationId));
      used++;
    }

    for (var i = 0; i < plan.length && used < budget; i++) {
      final r = plan[i];
      final baseId = r.notificationId;
      final past = !r.fireAt.isAfter(now);
      if (past && (!r.persistent || acked.contains(baseId))) continue;
      if (!past)
        await _schedule(
          id: baseId,
          at: r.fireAt,
          appt: r.appointment,
          type: r.type,
          baseId: baseId,
          persistent: r.persistent,
          settings: settings,
          cats: cats,
          customs: customs,
          exact: exact,
          during: r.during,
        );
      newLogs.add(
        ReminderLog(
          appointmentId: r.appointment.id!,
          type: r.type.name,
          fireAt: r.fireAt,
          notificationId: baseId,
          acknowledged: acked.contains(baseId),
        ),
      );
      if (!past) used++;
      // إعادة الرنين حتى الاستلام (تتوقف قبل التنبيه التالي)
      if (r.persistent && settings.iosRepeatCount > 0) {
        final nextAt = i + 1 < plan.length ? plan[i + 1].fireAt : r.fireAt.add(const Duration(days: 1));
        // الميزانية في iOS: التكرار فقط للتنبيهات الأقرب
        final allowRepeats = !Platform.isIOS || used < budget - 20;
        for (var k = 1; allowRepeats && k <= settings.iosRepeatCount && used < budget; k++) {
          final at = r.fireAt.add(repeatEvery * k);
          if (!at.isBefore(nextAt)) break;
          if (!at.isAfter(now)) continue;
          await _schedule(
            id: NotificationIds.repeat(baseId, k),
            at: at,
            appt: r.appointment,
            type: r.type,
            baseId: baseId,
            persistent: true,
            settings: settings,
            cats: cats,
            customs: customs,
            exact: exact,
            during: r.during,
            repeat: k,
          );
          used++;
        }
      }
    }
    await logs.replaceAll(newLogs);
    return used;
  }

  Future<void> _schedule({
    required int id,
    required DateTime at,
    required Appointment appt,
    required ReminderType type,
    required int baseId,
    required bool persistent,
    required AppSettings settings,
    required List<EventCategory> cats,
    required List<AlertSound> customs,
    required bool exact,
    Appointment? during,
    int repeat = 0,
    bool snoozed = false,
  }) async {
    final content = buildContent(appt: appt, type: type, at: at, settings: settings, cats: cats, during: during, repeat: repeat, snoozed: snoozed);
    final details = await _details(
      appt: appt,
      type: type,
      persistent: persistent,
      settings: settings,
      cats: cats,
      customs: customs,
      content: content,
      target: _target(appt, type),
    );
    final payload = AlarmPayload(appointmentId: appt.id!, type: type, baseId: baseId, persistent: persistent).encode();
    final mode = !exact
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : (persistent ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.exactAllowWhileIdle);
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: details,
      androidScheduleMode: mode,
      title: content.title,
      body: content.body,
      payload: payload,
    );
  }

  DateTime _target(Appointment a, ReminderType t) => switch (t) {
    ReminderType.approachStart || ReminderType.nextBooking || ReminderType.start => a.start,
    ReminderType.approachEnd || ReminderType.end => a.end,
  };

  /// نص الإشعار: اسم الزبون، نوع المناسبة، المكان، العنوان، الأوقات، المتبقي.
  NotificationContent buildContent({
    required Appointment appt,
    required ReminderType type,
    required DateTime at,
    required AppSettings settings,
    required List<EventCategory> cats,
    Appointment? during,
    int repeat = 0,
    bool snoozed = false,
  }) {
    final ar = settings.isArabic;
    String t(String k, [Map<String, Object?> a = const {}]) => Tr.t(k, ar: ar, args: a);
    final target = _target(appt, type);
    final left = TimeFmt.human(target.difference(at), ar: ar);
    final cat = cats.where((c) => c.id == appt.categoryId).firstOrNull;
    final head = switch (type) {
      ReminderType.approachStart => t('n_t_approach_start', {'left': left}),
      ReminderType.start => t('n_t_start'),
      ReminderType.approachEnd => t('n_t_approach_end', {'left': left}),
      ReminderType.end => t('n_t_end'),
      ReminderType.nextBooking => t('n_t_next', {'left': left}),
    };
    final prefix = repeat > 0 ? '🔔 ' : (snoozed ? '⏰ ' : '');
    final title = '$prefix$head — ${appt.customerName}';
    final lines = <String>[
      if (cat != null) '${t('event_type')}: ${cat.name(ar)}',
      if (appt.placeName.isNotEmpty) '${t('place')}: ${appt.placeName}',
      if (appt.fullAddress.isNotEmpty) '${t('address')}: ${appt.fullAddress}',
      '${t('time')}: ${TimeFmt.range(appt.start, appt.end, ar: ar)}',
      if (type == ReminderType.approachStart || type == ReminderType.nextBooking || type == ReminderType.approachEnd) '${t('remaining')}: $left',
      if (type == ReminderType.nextBooking && during != null) t('n_during', {'name': during.customerName}),
      if (appt.phone.isNotEmpty) '${t('phone')}: ${appt.phone}',
    ];
    return NotificationContent(title, lines.join('\n'));
  }

  String soundKeyFor(Appointment a, ReminderType t, AppSettings s) => a.soundKey ?? s.soundFor(t);

  Future<NotificationDetails> _details({
    required Appointment appt,
    required ReminderType type,
    required bool persistent,
    required AppSettings settings,
    required List<EventCategory> cats,
    required List<AlertSound> customs,
    required NotificationContent content,
    required DateTime target,
  }) async {
    final ar = settings.isArabic;
    final key = soundKeyFor(appt, type, settings);
    final sound = await sounds.resolve(key, customs);
    final cat = cats.where((c) => c.id == appt.categoryId).firstOrNull;

    AndroidNotificationSound? aSound;
    if (sound.isBuiltIn) {
      aSound = RawResourceAndroidNotificationSound(sound.resourceName);
    } else if (sound.isCustom && sound.androidUri.isNotEmpty) {
      aSound = UriAndroidNotificationSound(sound.androidUri);
    }
    final soundTag = sound.isCustom && sound.androidUri.isEmpty ? 'default' : sound.key;
    final channelId = 'ib2_${type.name}_${soundTag}_${settings.vibrate ? 'v' : 'n'}_${persistent ? 'a' : 'r'}';
    final channelName = '${Tr.t('rt_${type.name}', ar: ar)} • ${soundName(sound, ar)}${persistent ? ' • ${Tr.t('persistent_short', ar: ar)}' : ''}';
    final countdown = type == ReminderType.approachStart || type == ReminderType.nextBooking || type == ReminderType.approachEnd;

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: Tr.t('channel_desc', ar: ar),
      importance: Importance.max,
      priority: Priority.max,
      category: persistent ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      playSound: true,
      sound: aSound,
      enableVibration: settings.vibrate,
      vibrationPattern: settings.vibrate ? Int64List.fromList([0, 600, 400, 600, 400, 900]) : null,
      audioAttributesUsage: persistent ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
      additionalFlags: persistent ? Int32List.fromList([4]) : null, // FLAG_INSISTENT: يكرر الصوت
      ongoing: persistent,
      autoCancel: !persistent,
      fullScreenIntent: persistent && settings.fullScreenAlarm,
      visibility: NotificationVisibility.public,
      color: Color(cat?.color ?? 0xFF3D7BFF),
      groupKey: 'appt_${appt.id}',
      when: countdown ? target.millisecondsSinceEpoch : null,
      usesChronometer: countdown,
      chronometerCountDown: countdown,
      styleInformation: BigTextStyleInformation(content.body, contentTitle: content.title),
      ticker: content.title,
      actions: [
        if (persistent) AndroidNotificationAction(actAck, Tr.t('n_act_ack', ar: ar), showsUserInterface: true),
        AndroidNotificationAction(actSnooze, Tr.t('n_act_snooze', ar: ar), showsUserInterface: true),
        if (appt.phone.isNotEmpty) AndroidNotificationAction(actCall, Tr.t('n_act_call', ar: ar), showsUserInterface: true),
        if (appt.mapUrl.isNotEmpty || appt.lat != null || appt.fullAddress.isNotEmpty)
          AndroidNotificationAction(actMap, Tr.t('n_act_map', ar: ar), showsUserInterface: true),
        if (!persistent) AndroidNotificationAction(actDone, Tr.t('n_act_done', ar: ar), showsUserInterface: true),
      ],
    );
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      sound: sound.isSystemDefault ? null : sounds.iosSoundName(sound),
      categoryIdentifier: iosCategory,
      threadIdentifier: 'appt_${appt.id}',
      interruptionLevel: persistent ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  String soundName(AlertSound s, bool ar) {
    if (s.isSystemDefault) return Tr.t('sound_default', ar: ar);
    if (s.isBuiltIn) return Tr.t('sound_${s.key}', ar: ar);
    return s.name;
  }

  // ---------------- الاستلام / التأجيل ----------------

  /// إيقاف الرنين: يلغي الإشعار وكل مرات إعادته لهذا التنبيه.
  Future<void> acknowledge(AlarmPayload p, {int repeatCount = 16}) async {
    await _plugin.cancel(id: p.baseId);
    for (var k = 1; k <= 16; k++) {
      await _plugin.cancel(id: NotificationIds.repeat(p.baseId, k));
    }
    await _plugin.cancel(id: NotificationIds.snooze(p.baseId));
    await logs.acknowledge(p.baseId);
    await sounds.stop();
  }

  /// إيقاف كل تنبيهات حجز (عند إكماله أو إلغائه).
  Future<void> cancelForAppointment(int appointmentId) async {
    for (final t in ReminderType.values) {
      final base = NotificationIds.base(appointmentId, t);
      await _plugin.cancel(id: base);
      await _plugin.cancel(id: NotificationIds.snooze(base));
      for (var k = 1; k <= 16; k++) {
        await _plugin.cancel(id: NotificationIds.repeat(base, k));
      }
    }
  }

  Future<void> snooze({
    required AlarmPayload p,
    required Appointment appt,
    required AppSettings settings,
    required List<EventCategory> cats,
    required List<AlertSound> customs,
  }) async {
    await acknowledge(p);
    final at = DateTime.now().add(Duration(minutes: settings.snoozeMinutes));
    final id = NotificationIds.snooze(p.baseId);
    final exact = Platform.isAndroid ? (await _android?.canScheduleExactNotifications() ?? false) : true;
    await _schedule(
      id: id,
      at: at,
      appt: appt,
      type: p.type,
      baseId: p.baseId,
      persistent: p.persistent,
      settings: settings,
      cats: cats,
      customs: customs,
      exact: exact,
      snoozed: true,
    );
    final current = await logs.all();
    await logs.replaceAll([
      ...current.where((l) => l.notificationId != id),
      ReminderLog(appointmentId: appt.id!, type: 'snooze:${p.type.name}', fireAt: at, notificationId: id),
    ]);
  }

  // ---------------- الاختبار ----------------

  /// إشعار تجريبي فوري (أو بعد [delay]) بصوت ونوع محددين.
  Future<void> test({
    required AppSettings settings,
    required List<EventCategory> cats,
    required List<AlertSound> customs,
    required ReminderType type,
    String? soundKey,
    bool persistent = false,
    Duration delay = Duration.zero,
  }) async {
    final now = DateTime.now();
    final fake = Appointment(
      id: 999999,
      customerName: Tr.t('test_customer', ar: settings.isArabic),
      phone: '',
      categoryId: cats.isEmpty ? null : cats.first.id,
      placeName: Tr.t('test_place', ar: settings.isArabic),
      address: 'IBRA BOOKING',
      start: now.add(delay).add(const Duration(minutes: 60)),
      end: now.add(delay).add(const Duration(minutes: 180)),
      soundKey: soundKey,
      createdAt: now,
      updatedAt: now,
    );
    final content = buildContent(appt: fake, type: type, at: now.add(delay), settings: settings, cats: cats);
    final details = await _details(
      appt: fake,
      type: type,
      persistent: persistent,
      settings: settings,
      cats: cats,
      customs: customs,
      content: content,
      target: _target(fake, type),
    );
    final payload = AlarmPayload(appointmentId: 0, type: type, baseId: NotificationIds.test, persistent: persistent).encode();
    if (delay == Duration.zero) {
      await _plugin.show(id: NotificationIds.test, title: content.title, body: content.body, notificationDetails: details, payload: payload);
    } else {
      final exact = Platform.isAndroid ? (await _android?.canScheduleExactNotifications() ?? false) : true;
      await _plugin.zonedSchedule(
        id: NotificationIds.test,
        scheduledDate: tz.TZDateTime.from(now.add(delay), tz.local),
        notificationDetails: details,
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: content.title,
        body: content.body,
        payload: payload,
      );
    }
  }

  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;

  /// حذف قنوات أندرويد المرتبطة بصوت محذوف.
  Future<void> deleteChannelsForSound(String key) async {
    final a = _android;
    if (a == null) return;
    final chans = await a.getNotificationChannels() ?? const [];
    for (final c in chans) {
      if (c.id.contains('_${key}_')) await a.deleteNotificationChannel(channelId: c.id);
    }
  }
}

class NotificationContent {
  final String title;
  final String body;
  const NotificationContent(this.title, this.body);
}
