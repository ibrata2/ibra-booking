import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../services/launcher_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';
import 'appointment_form_screen.dart';
import 'notification_settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final settings = ref.watch(settingsProvider);
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final paid = ref.watch(paidTotalsProvider).value ?? const <int, double>{};
    final perm = ref.watch(permissionStatusProvider).value;
    EventCategory? cat(Appointment a) => cats.where((c) => c.id == a.categoryId).firstOrNull;

    final active = appts.where((a) => a.status != BookingStatus.cancelled).toList();
    final todayStart = TimeFmt.dayStart(now);
    final tomorrow = todayStart.add(const Duration(days: 1));
    final dayAfter = todayStart.add(const Duration(days: 2));
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    bool inRange(Appointment a, DateTime f, DateTime t) => a.start.isBefore(t) && a.end.isAfter(f);

    final today = active.where((a) => inRange(a, todayStart, tomorrow)).toList();
    final tomorrowList = active.where((a) => inRange(a, tomorrow, dayAfter)).toList();
    final monthList = active.where((a) => !a.start.isBefore(monthStart) && a.start.isBefore(nextMonth)).toList();
    final ongoing = active.where((a) => !a.status.isClosed && a.isOngoingAt(now)).toList();
    final upcoming = active.where((a) => !a.status.isClosed && a.start.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final next = upcoming.firstOrNull;
    double fees(List<Appointment> l) => l.fold(0.0, (s, a) => s + a.fee);
    double received(List<Appointment> l) => l.fold(0.0, (s, a) => s + receivedFor(a, paid));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.read(dataVersionProvider.notifier).bump(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/images/logo.png', width: 42, height: 42)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('app_name'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(
                        TimeFmt.dateLong(now, ar: ar),
                        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: context.t('add_booking'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentFormScreen())),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Glass(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Brand.red, Brand.blue]).createShader(r),
                    child: Text(
                      TimeFmt.time(now, ar: ar),
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${TimeFmt.weekday(now.weekday, ar: ar)} • ${TimeFmt.date(now, ar: ar)}',
                    style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (perm != null && !perm.allGood) ...[
              const SizedBox(height: 12),
              Glass(
                tint: Colors.orange.withValues(alpha: 0.18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_off_rounded, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.t(perm.notifications ? 'warn_exact' : 'warn_notifications'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: context.t('today'), value: today.length, color: Brand.red),
                const SizedBox(width: 10),
                _Stat(label: context.t('tomorrow'), value: tomorrowList.length, color: const Color(0xFF7C4DFF)),
                const SizedBox(width: 10),
                _Stat(label: context.t('this_month'), value: monthList.length, color: Brand.blue),
              ],
            ),
            for (final a in ongoing) ...[SectionTitle(context.t('current_booking')), _CurrentCard(appt: a, category: cat(a), now: now)],
            if (next != null) ...[SectionTitle(context.t('next_booking')), _NextCard(appt: next, category: cat(next), now: now)],
            if (settings.showFinance) ...[
              SectionTitle(context.t('earnings')),
              Row(
                children: [
                  Expanded(
                    child: _MoneyBox(title: context.t('today_fees'), fees: fees(today), received: received(today), symbol: settings.currencySymbol),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MoneyBox(
                      title: context.t('month_fees'),
                      fees: fees(monthList),
                      received: received(monthList),
                      symbol: settings.currencySymbol,
                    ),
                  ),
                ],
              ),
            ],
            SectionTitle(
              context.t('today_bookings'),
              trailing: Text('${today.length}', style: TextStyle(color: Theme.of(context).hintColor)),
            ),
            if (today.isEmpty)
              Glass(
                child: EmptyState(
                  icon: Icons.event_available_rounded,
                  text: context.t('no_bookings_today'),
                  action: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(initialDate: now))),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.t('add_booking')),
                  ),
                ),
              )
            else
              for (final a in today..sort((x, y) => x.start.compareTo(y.start)))
                AppointmentTile(
                  appt: a,
                  category: cat(a),
                  now: now,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: a.id!))),
                ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Glass(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
          ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    ),
  );
}

class _MoneyBox extends StatelessWidget {
  const _MoneyBox({required this.title, required this.fees, required this.received, required this.symbol});
  final String title;
  final double fees;
  final double received;
  final String symbol;
  @override
  Widget build(BuildContext context) => Glass(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(MoneyFmt.format(fees, symbol), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        Text(
          '${context.t('received')}: ${MoneyFmt.number(received)}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF00C853), fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CurrentCard extends ConsumerWidget {
  const _CurrentCard({required this.appt, required this.category, required this.now});
  final Appointment appt;
  final EventCategory? category;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final total = appt.duration.inSeconds;
    final elapsed = now.difference(appt.start).inSeconds.clamp(0, total);
    final progress = total == 0 ? 1.0 : elapsed / total;
    final color = Color(category?.color ?? 0xFF00C853);
    return Glass(
      tint: color.withValues(alpha: 0.16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: appt.id!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Pulse(),
              const SizedBox(width: 8),
              Text(
                context.t('st_ongoing'),
                style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                category?.name(ar) ?? '',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(appt.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (appt.placeName.isNotEmpty) Text(appt.placeName, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: color.withValues(alpha: 0.15), color: color),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${context.t('elapsed')}: ${TimeFmt.countdown(now.difference(appt.start))}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text('${context.t('ends_in')}: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                TimeFmt.countdown(appt.end.difference(now)),
                style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            TimeFmt.range(appt.start, appt.end, ar: ar),
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          _QuickActions(appt: appt),
        ],
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.appt, required this.category, required this.now});
  final Appointment appt;
  final EventCategory? category;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final color = Color(category?.color ?? 0xFF2F6BFF);
    return Glass(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: appt.id!))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(category?.icon ?? 'event'), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(appt.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              StatusChip(appt.effectiveStatus(now), dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${TimeFmt.dateLong(appt.start, ar: ar)} • ${TimeFmt.range(appt.start, appt.end, ar: ar)}',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
          if (appt.placeName.isNotEmpty || appt.fullAddress.isNotEmpty)
            Text(
              [appt.placeName, appt.fullAddress].where((e) => e.isNotEmpty).join(' — '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Text(
                  context.t('starts_in'),
                  style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  TimeFmt.countdown(appt.start.difference(now)),
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          _QuickActions(appt: appt),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.appt});
  final Appointment appt;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(settingsProvider).mapsApp;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (appt.phone.isNotEmpty)
          RoundAction(icon: Icons.call_rounded, label: context.t('call'), color: const Color(0xFF00C853), onTap: () => Launcher.call(appt.phone)),
        if (appt.phone.isNotEmpty)
          RoundAction(
            icon: Icons.chat_rounded,
            label: context.t('whatsapp'),
            color: const Color(0xFF25D366),
            onTap: () => Launcher.whatsapp(appt.phone),
          ),
        if (Launcher.hasLocation(appt))
          RoundAction(
            icon: Icons.navigation_rounded,
            label: context.t('navigate'),
            color: Brand.blue,
            onTap: () => Launcher.openMap(appt, app: maps),
          ),
      ],
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
    child: Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(color: Color(0xFF00C853), shape: BoxShape.circle),
    ),
  );
}
