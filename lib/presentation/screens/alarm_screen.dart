import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../services/launcher_service.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';
import '../../core/edition.dart';

/// شاشة المنبه: يستمر الرنين حتى يضغط المستخدم «استلمت».
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key, required this.payload, this.appointment});
  final AlarmPayload payload;
  final Appointment? appointment;
  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  late final SoundService _sounds = ref.read(soundServiceProvider);
  late final NotificationService _notif = ref.read(notificationServiceProvider);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ring();
  }

  Future<void> _ring() async {
    final s = ref.read(settingsProvider);
    final key = widget.appointment?.soundKey ?? s.soundFor(widget.payload.type);
    final customs = await ref.read(soundRepoProvider).all();
    final sound = await _sounds.resolve(key, customs);
    if (!_done) await _sounds.preview(sound, volume: 1, loop: true);
  }

  @override
  void dispose() {
    _done = true;
    _pulse.dispose();
    _sounds.stop();
    super.dispose();
  }

  Future<void> _ack({bool openDetails = false}) async {
    _done = true;
    await _notif.acknowledge(widget.payload);
    if (!mounted) return;
    if (openDetails && widget.appointment?.id != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: widget.appointment!.id!)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final a = widget.appointment;
    final s = ref.watch(settingsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final cat = a == null ? null : cats.where((c) => c.id == a.categoryId).firstOrNull;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final title = switch (widget.payload.type) {
      ReminderType.approachStart => context.t('rt_approachStart'),
      ReminderType.start => context.t('n_t_start'),
      ReminderType.approachEnd => context.t('rt_approachEnd'),
      ReminderType.end => context.t('n_t_end'),
      ReminderType.nextBooking => context.t('rt_nextBooking'),
    };
    final target = a == null ? null : (widget.payload.type == ReminderType.approachEnd || widget.payload.type == ReminderType.end ? a.end : a.start);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(color: Brand.red.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(-10, -6)),
                          BoxShadow(color: Brand.blue.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(10, 10)),
                        ],
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(40), child: Image.asset(Edition.logo, width: 150, height: 150)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    TimeFmt.time(now, ar: ar),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Brand.red),
                  ),
                  const SizedBox(height: 14),
                  if (a != null)
                    Glass(
                      child: Column(
                        children: [
                          Text(a.customerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          if (cat != null)
                            Text(
                              cat.name(ar),
                              style: TextStyle(color: Color(cat.color), fontWeight: FontWeight.w700),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            TimeFmt.range(a.start, a.end, ar: ar),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (a.placeName.isNotEmpty || a.fullAddress.isNotEmpty)
                            Text([a.placeName, a.fullAddress].where((e) => e.isNotEmpty).join(' — '), textAlign: TextAlign.center),
                          if (target != null && target.isAfter(now))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${context.t('remaining')}: ${TimeFmt.countdown(target.difference(now))}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.blue),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    Text(context.t('test_alarm_body'), textAlign: TextAlign.center),
                  const Spacer(),
                  if (a != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (a.phone.isNotEmpty)
                          RoundAction(
                            icon: Icons.call_rounded,
                            label: context.t('call'),
                            color: const Color(0xFF00C853),
                            onTap: () async {
                              await _ack();
                              await Launcher.call(a.phone);
                            },
                          ),
                        if (Launcher.hasLocation(a))
                          RoundAction(
                            icon: Icons.navigation_rounded,
                            label: context.t('navigate'),
                            color: Brand.blue,
                            onTap: () async {
                              await _ack();
                              await Launcher.openMap(a, app: s.mapsApp);
                            },
                          ),
                        RoundAction(
                          icon: Icons.snooze_rounded,
                          label: context.t('n_act_snooze'),
                          color: Colors.orange,
                          onTap: () async {
                            _done = true;
                            await _notif.snooze(
                              p: widget.payload,
                              appt: a,
                              settings: s,
                              cats: cats,
                              customs: await ref.read(soundRepoProvider).all(),
                            );
                            if (context.mounted) {
                              toast(context, context.t('snoozed_for', {'m': s.snoozeMinutes}));
                              Navigator.pop(context);
                            }
                          },
                        ),
                        RoundAction(
                          icon: Icons.task_alt_rounded,
                          label: context.t('n_act_done'),
                          color: const Color(0xFF7C4DFF),
                          onTap: () async {
                            await _ack();
                            await ref.read(bookingControllerProvider).setStatus(a, BookingStatus.completed);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Tajawal'),
                      ),
                      onPressed: () => _ack(openDetails: true),
                      icon: const Icon(Icons.check_circle_rounded, size: 30),
                      label: Text(context.t('n_act_ack')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
