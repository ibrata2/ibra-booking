import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/booking_controller.dart';
import 'core/l10n/tr.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/entities.dart';
import 'presentation/providers.dart';
import 'presentation/screens/alarm_screen.dart';
import 'presentation/screens/appointment_details_screen.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/lock_screen.dart';
import 'presentation/widgets/common.dart';
import 'services/launcher_service.dart';
import 'services/notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class IbraBookingApp extends ConsumerStatefulWidget {
  const IbraBookingApp({super.key});
  @override
  ConsumerState<IbraBookingApp> createState() => _IbraBookingAppState();
}

class _IbraBookingAppState extends ConsumerState<IbraBookingApp> with WidgetsBindingObserver {
  StreamSubscription<AlarmEvent>? _sub;
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(settingsProvider).hasPin;
    final notif = ref.read(notificationServiceProvider);
    _sub = notif.events.listen(_handle);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // أول تشغيل: طلب صلاحيات الإشعارات والمنبهات الدقيقة
      final s = ref.read(settingsProvider);
      if (!s.onboarded) {
        try {
          await notif.request(fullScreen: s.fullScreenAlarm);
        } catch (_) {}
        await ref.read(settingsProvider.notifier).set(s.copyWith(onboarded: true));
        ref.read(bookingControllerProvider).refresh();
      }
      await ref.read(bookingControllerProvider).rescheduleNotifications();
      final launch = notif.pendingLaunch;
      notif.pendingLaunch = null;
      if (launch != null) _handle(launch);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final s = ref.read(settingsProvider);
      if (s.hasPin && _pausedAt != null && DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        setState(() => _locked = true);
      }
      _pausedAt = null;
      // معالجة تغيير الساعة/المنطقة الزمنية وإعادة تعبئة التنبيهات
      await ref.read(notificationServiceProvider).refreshTimeZone();
      await ref.read(bookingControllerProvider).rescheduleNotifications();
      ref.read(bookingControllerProvider).refresh();
    }
  }

  Future<void> _handle(AlarmEvent e) async {
    final nav = navigatorKey.currentState;
    final ctx = navigatorKey.currentContext;
    if (nav == null || ctx == null) return;
    final notif = ref.read(notificationServiceProvider);
    final p = e.payload;
    if (p.appointmentId == 0) {
      // إشعار تجريبي
      if (e.action == null && p.persistent) {
        nav.push(MaterialPageRoute(builder: (_) => AlarmScreen(payload: p)));
      } else {
        await notif.acknowledge(p);
      }
      return;
    }
    final appt = await ref.read(appointmentRepoProvider).byId(p.appointmentId);
    if (appt == null) {
      await notif.acknowledge(p);
      return;
    }
    final settings = ref.read(settingsProvider);
    switch (e.action) {
      case NotificationService.actAck:
        await notif.acknowledge(p);
        nav.push(MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: appt.id!)));
        if (ctx.mounted) toast(ctx, Tr.t('alarm_acked', ar: settings.isArabic));
      case NotificationService.actSnooze:
        await notif.snooze(
          p: p,
          appt: appt,
          settings: settings,
          cats: await ref.read(categoryRepoProvider).all(),
          customs: await ref.read(soundRepoProvider).all(),
        );
        if (ctx.mounted) toast(ctx, Tr.t('snoozed_for', ar: settings.isArabic, args: {'m': settings.snoozeMinutes}));
      case NotificationService.actCall:
        await notif.acknowledge(p);
        if (appt.phone.isNotEmpty) await Launcher.call(appt.phone);
      case NotificationService.actMap:
        await notif.acknowledge(p);
        await Launcher.openMap(appt, app: settings.mapsApp);
      case NotificationService.actDone:
        await notif.acknowledge(p);
        await ref.read(bookingControllerProvider).setStatus(appt, BookingStatus.completed);
        if (ctx.mounted) toast(ctx, Tr.t('marked_done', ar: settings.isArabic));
      default:
        if (p.persistent) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => AlarmScreen(payload: p, appointment: appt),
            ),
          );
        } else {
          await notif.acknowledge(p);
          nav.push(MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: appt.id!)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final accent = Color(s.accent);
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'IBRA BOOKING',
      onGenerateTitle: (c) => c.t('app_name'),
      locale: Locale(s.language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: switch (s.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: AppTheme.build(brightness: Brightness.light, accent: accent, fontFamily: s.fontFamily),
      darkTheme: AppTheme.build(brightness: Brightness.dark, accent: accent, fontFamily: s.fontFamily),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(alwaysUse24HourFormat: false, textScaler: TextScaler.linear(s.fontScale)),
          child: Stack(
            children: [
              ?child,
              if (_locked) Positioned.fill(child: LockScreen(onUnlocked: () => setState(() => _locked = false))),
            ],
          ),
        );
      },
      home: const HomeShell(),
    );
  }
}
