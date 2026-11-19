import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../domain/logic/scheduling.dart';
import '../../services/export_service.dart';
import '../../services/file_helper.dart';
import '../../services/launcher_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/sound_picker.dart';
import 'appointment_form_screen.dart';
import '../../core/edition.dart';

final _paymentsProvider = FutureProvider.family<List<Payment>, int>((ref, id) async {
  ref.watch(dataVersionProvider);
  return ref.watch(financeRepoProvider).paymentsFor(id);
});
final _expensesProvider = FutureProvider.family<List<Expense>, int>((ref, id) async {
  ref.watch(dataVersionProvider);
  return ref.watch(financeRepoProvider).expensesFor(id);
});
final _attachmentsProvider = FutureProvider.family<List<Attachment>, int>((ref, id) async {
  ref.watch(dataVersionProvider);
  return ref.watch(attachmentRepoProvider).forAppointment(id);
});
final _ruleProvider = FutureProvider.family<RecurrenceRule?, int>((ref, id) async => ref.watch(appointmentRepoProvider).rule(id));

class AppointmentDetailsScreen extends ConsumerWidget {
  const AppointmentDetailsScreen({super.key, required this.appointmentId});
  final int appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final list = ref.watch(appointmentsProvider);
    final appt = list.value?.where((a) => a.id == appointmentId).firstOrNull;
    if (appt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: list.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off_rounded, text: context.t('not_found')),
      );
    }
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final settings = ref.watch(settingsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final customs = ref.watch(customSoundsProvider).value ?? const <AlertSound>[];
    final cat = cats.where((c) => c.id == appt.categoryId).firstOrNull;
    final color = Color(cat?.color ?? 0xFF3D7BFF);
    final st = appt.effectiveStatus(now);
    final ctrl = ref.read(bookingControllerProvider);

    String shareText() => [
      '📅 ${cat?.name(ar) ?? ''} — ${appt.customerName}',
      '🗓 ${TimeFmt.dateLong(appt.start, ar: ar)}',
      '⏰ ${TimeFmt.range(appt.start, appt.end, ar: ar)}',
      if (appt.placeName.isNotEmpty) '🏛 ${appt.placeName}',
      if (appt.fullAddress.isNotEmpty) '📍 ${appt.fullAddress}',
      if (Launcher.hasLocation(appt)) '🗺 ${Launcher.shareLink(appt)}',
    ].join('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('booking_details')),
        actions: [
          IconButton(
            tooltip: context.t('edit'),
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(appointment: appt))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'copy':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(copyFrom: appt)));
                case 'share':
                  await ExportService.shareText(shareText());
                case 'delete':
                  await _delete(context, ref, appt);
              }
            },
            itemBuilder: (c) => [
              PopupMenuItem(
                value: 'copy',
                child: ListTile(leading: const Icon(Icons.copy_rounded), title: Text(c.t('copy_booking'))),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(leading: const Icon(Icons.share_rounded), title: Text(c.t('share'))),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: Text(c.t('delete'), style: const TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Glass(
            tint: color.withValues(alpha: 0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: color),
                      child: Icon(categoryIcon(cat?.icon ?? 'event'), color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appt.customerName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                          Text(
                            cat?.name(ar) ?? '',
                            style: TextStyle(color: color, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    InkWell(onTap: () => _changeStatus(context, ref, appt), child: StatusChip(st)),
                  ],
                ),
                const SizedBox(height: 14),
                if (Edition.isCenter) ...[
                  if (staffOf(ref, appt) case final st?)
                    _InfoRow(icon: Icons.badge_rounded, text: '${context.t('staff_member')}: ${st.name}', color: Color(st.color)),
                  if (serviceOf(ref, appt) case final sv?) _InfoRow(icon: Icons.spa_rounded, text: '${context.t('service')}: ${sv.name}', bold: true),
                ],
                _InfoRow(
                  icon: Icons.event_rounded,
                  text: TimeFmt.dateLong(appt.start, ar: ar),
                ),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  text: TimeFmt.range(appt.start, appt.end, ar: ar),
                ),
                _InfoRow(
                  icon: Icons.timelapse_rounded,
                  text: '${context.t('duration')}: ${TimeFmt.human(appt.duration, ar: ar)}',
                ),
                if (st == BookingStatus.ongoing)
                  _InfoRow(
                    icon: Icons.hourglass_bottom_rounded,
                    text: '${context.t('ends_in')}: ${TimeFmt.countdown(appt.end.difference(now))}',
                    color: color,
                  )
                else if (appt.start.isAfter(now) && !appt.status.isClosed)
                  _InfoRow(
                    icon: Icons.hourglass_top_rounded,
                    text: '${context.t('starts_in')}: ${TimeFmt.countdown(appt.start.difference(now))}',
                    color: color,
                  ),
                if (appt.recurrenceId != null)
                  Consumer(
                    builder: (c, r, _) {
                      final rule = r.watch(_ruleProvider(appt.recurrenceId!)).value;
                      return _InfoRow(icon: Icons.repeat_rounded, text: rule == null ? context.t('recurring') : context.t('rec_${rule.type.name}'));
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Glass(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (appt.phone.isNotEmpty)
                  RoundAction(
                    icon: Icons.call_rounded,
                    label: context.t('call'),
                    color: const Color(0xFF00C853),
                    onTap: () => Launcher.call(appt.phone),
                  ),
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
                    onTap: () => Launcher.openMap(appt, app: settings.mapsApp),
                  ),
                RoundAction(icon: Icons.share_rounded, label: context.t('share'), onTap: () => ExportService.shareText(shareText())),
              ],
            ),
          ),
          if (appt.phone.isNotEmpty || appt.phone2.isNotEmpty) ...[
            SectionTitle(context.t('contact')),
            Glass(
              child: Column(
                children: [
                  if (appt.phone.isNotEmpty) _PhoneRow(phone: appt.phone),
                  if (appt.phone2.isNotEmpty) _PhoneRow(phone: appt.phone2),
                ],
              ),
            ),
          ],
          if (appt.placeName.isNotEmpty || appt.fullAddress.isNotEmpty || appt.mapUrl.isNotEmpty || appt.lat != null) ...[
            SectionTitle(context.t('location')),
            Glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appt.placeName.isNotEmpty) _InfoRow(icon: Icons.location_city_rounded, text: appt.placeName, bold: true),
                  if (appt.province.isNotEmpty || appt.area.isNotEmpty)
                    _InfoRow(icon: Icons.map_rounded, text: [appt.province, appt.area].where((e) => e.isNotEmpty).join(' - ')),
                  if (appt.address.isNotEmpty) _InfoRow(icon: Icons.home_work_rounded, text: appt.address),
                  if (appt.landmark.isNotEmpty) _InfoRow(icon: Icons.flag_rounded, text: '${context.t('landmark')}: ${appt.landmark}'),
                  if (appt.lat != null) _InfoRow(icon: Icons.gps_fixed_rounded, text: '${appt.lat}, ${appt.lng}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => Launcher.openMap(appt, app: settings.mapsApp),
                        icon: const Icon(Icons.navigation_rounded),
                        label: Text(context.t('start_navigation')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Launcher.openMap(appt, app: settings.mapsApp == 'google' ? 'apple' : 'google', navigate: false),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(settings.mapsApp == 'google' ? context.t('apple_maps') : context.t('google_maps')),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ExportService.shareText('${appt.placeName}\n${appt.fullAddress}\n${Launcher.shareLink(appt)}'),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(context.t('share_location')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(context.t('travel_time_hint'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ],
          if (settings.showFinance) _FinanceSection(appt: appt),
          if (appt.notes.isNotEmpty) ...[
            SectionTitle(context.t('notes')),
            Glass(
              child: SizedBox(width: double.infinity, child: SelectableText(appt.notes)),
            ),
          ],
          _AttachmentsSection(appt: appt),
          SectionTitle(context.t('reminders')),
          Glass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.reminderOverride == null ? context.t('default_reminders') : context.t('custom_reminders'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ..._plannedFor(appt, ref, now).map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(context.t('rt_${p.type.name}'))),
                        Text(
                          '${TimeFmt.time(p.fireAt, ar: ar)}${TimeFmt.sameDay(p.fireAt, appt.start) ? '' : ' • ${TimeFmt.dateNum(p.fireAt)}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_plannedFor(appt, ref, now).isEmpty)
                  Text(context.t('no_upcoming_reminders'), style: TextStyle(color: Theme.of(context).hintColor)),
                const Divider(),
                _InfoRow(icon: Icons.music_note_rounded, text: '${context.t('booking_sound')}: ${soundLabel(context, appt.soundKey, customs)}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!appt.status.isClosed)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
                    onPressed: () => ctrl.setStatus(appt, BookingStatus.completed),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(context.t('mark_completed')),
                  ),
                ),
              if (!appt.status.isClosed) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _changeStatus(context, ref, appt),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(context.t('change_status')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PlannedReminder> _plannedFor(Appointment appt, WidgetRef ref, DateTime now) {
    final all = ref.read(appointmentsProvider).value ?? const <Appointment>[];
    final near = all
        .where((a) => a.end.isAfter(appt.start.subtract(const Duration(days: 1))) && a.start.isBefore(appt.end.add(const Duration(days: 1))))
        .toList();
    return ReminderPlanner.plan(
      appointments: near,
      defaults: ref.read(settingsProvider).reminders,
      now: now,
      horizon: now.add(const Duration(days: 400)),
    ).where((p) => p.appointment.id == appt.id).toList();
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref, Appointment appt) async {
    final s = await showModalBottomSheet<BookingStatus>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in [
              BookingStatus.confirmed,
              BookingStatus.pending,
              BookingStatus.completed,
              BookingStatus.postponed,
              BookingStatus.cancelled,
              BookingStatus.noShow,
            ])
              ListTile(
                leading: Icon(statusIcon(s), color: statusColor(s)),
                title: Text(c.t('st_${s.name}')),
                trailing: appt.status == s ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(c, s),
              ),
          ],
        ),
      ),
    );
    if (s != null) await ref.read(bookingControllerProvider).setStatus(appt, s);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Appointment appt) async {
    final ctrl = ref.read(bookingControllerProvider);
    if (appt.recurrenceId != null) {
      final r = await showDialog<int>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.t('delete_booking')),
          content: Text(c.t('delete_series_msg')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t('cancel'))),
            OutlinedButton(onPressed: () => Navigator.pop(c, 1), child: Text(c.t('this_only'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(c, 2),
              child: Text(c.t('all_series')),
            ),
          ],
        ),
      );
      if (r == null) return;
      await ctrl.delete(appt, series: r == 2);
    } else {
      if (!await confirmDialog(
        context,
        title: context.t('delete_booking'),
        message: context.t('delete_confirm'),
        danger: true,
        ok: context.t('delete'),
      ))
        return;
      await ctrl.delete(appt);
    }
    if (context.mounted) {
      toast(context, context.t('deleted'));
      Navigator.pop(context);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color, this.bold = false});
  final IconData icon;
  final String text;
  final Color? color;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color ?? Theme.of(context).hintColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontWeight: bold || color != null ? FontWeight.w700 : FontWeight.w500, color: color),
          ),
        ),
      ],
    ),
  );
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone});
  final String phone;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.phone_rounded, size: 19),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          phone,
          textDirection: TextDirection.ltr,
          textAlign: context.ar ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        onPressed: () => Launcher.call(phone),
        icon: const Icon(Icons.call_rounded, color: Color(0xFF00C853)),
      ),
      IconButton(
        onPressed: () => Launcher.whatsapp(phone),
        icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
      ),
      IconButton(onPressed: () => Launcher.sms(phone), icon: const Icon(Icons.sms_rounded)),
    ],
  );
}

class _FinanceSection extends ConsumerWidget {
  const _FinanceSection({required this.appt});
  final Appointment appt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final settings = ref.watch(settingsProvider);
    final payments = ref.watch(_paymentsProvider(appt.id!)).value ?? const <Payment>[];
    final expenses = ref.watch(_expensesProvider(appt.id!)).value ?? const <Expense>[];
    final received = appt.deposit + payments.fold(0.0, (s, p) => s + p.amount);
    final remaining = (appt.fee - received).clamp(0, double.infinity);
    final sym = settings.currencySymbol;
    Widget line(String a, String b, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(a)),
          Text(
            b,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(context.t('payment')),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(context.t('fee'), MoneyFmt.format(appt.fee, sym)),
              line(context.t('deposit'), MoneyFmt.format(appt.deposit, sym)),
              for (final p in payments)
                Row(
                  children: [
                    const Icon(Icons.payments_rounded, size: 16, color: Color(0xFF00C853)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${TimeFmt.date(p.date, ar: ar)}${p.note.isEmpty ? '' : ' • ${p.note}'}', style: const TextStyle(fontSize: 13)),
                    ),
                    Text(MoneyFmt.number(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await ref.read(financeRepoProvider).deletePayment(p.id!);
                        ref.read(dataVersionProvider.notifier).bump();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              const Divider(),
              line(context.t('received'), MoneyFmt.format(received, sym), color: const Color(0xFF00C853)),
              line(context.t('remaining'), MoneyFmt.format(remaining, sym), color: remaining > 0 ? Colors.orange : null),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _addMoney(context, ref, payment: true, suggested: remaining.toDouble()),
                    icon: const Icon(Icons.add_card_rounded),
                    label: Text(context.t('add_payment')),
                  ),
                  if (remaining > 0)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(financeRepoProvider)
                            .addPayment(
                              Payment(appointmentId: appt.id!, amount: remaining.toDouble(), date: DateTime.now(), note: context.t('full_payment')),
                            );
                        ref.read(dataVersionProvider.notifier).bump();
                      },
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(context.t('mark_paid')),
                    ),
                ],
              ),
            ],
          ),
        ),
        SectionTitle(
          context.t('travel_expenses'),
          trailing: TextButton.icon(
            onPressed: () => _addMoney(context, ref, payment: false),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.t('add')),
          ),
        ),
        if (expenses.isEmpty)
          Text(context.t('no_expenses'), style: TextStyle(color: Theme.of(context).hintColor))
        else
          Glass(
            child: Column(
              children: [
                for (final e in expenses)
                  Row(
                    children: [
                      const Icon(Icons.local_taxi_rounded, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${context.t('exp_${e.kind}')}${e.note.isEmpty ? '' : ' • ${e.note}'}')),
                      Text(MoneyFmt.format(e.amount, sym), style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await ref.read(financeRepoProvider).deleteExpense(e.id!);
                          ref.read(dataVersionProvider.notifier).bump();
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _addMoney(BuildContext context, WidgetRef ref, {required bool payment, double suggested = 0}) async {
    final amount = TextEditingController(text: suggested > 0 ? MoneyFmt.number(suggested).replaceAll(',', '') : '');
    final note = TextEditingController();
    var kind = 'travel';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(c.t(payment ? 'add_payment' : 'add_expense')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: c.t('amount')),
              ),
              const SizedBox(height: 10),
              if (!payment)
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'travel', label: Text(c.t('exp_travel'))),
                    ButtonSegment(value: 'other', label: Text(c.t('exp_other'))),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => set(() => kind = s.first),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: InputDecoration(labelText: c.t('notes')),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.t('save'))),
          ],
        ),
      ),
    );
    final v = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
    if (ok == true && v > 0) {
      final repo = ref.read(financeRepoProvider);
      if (payment) {
        await repo.addPayment(Payment(appointmentId: appt.id!, amount: v, date: DateTime.now(), note: note.text.trim()));
      } else {
        await repo.addExpense(Expense(appointmentId: appt.id, kind: kind, amount: v, date: appt.start, note: note.text.trim()));
      }
      ref.read(dataVersionProvider.notifier).bump();
    }
  }
}

class _AttachmentsSection extends ConsumerWidget {
  const _AttachmentsSection({required this.appt});
  final Appointment appt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(_attachmentsProvider(appt.id!)).value ?? const <Attachment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          context.t('attachments'),
          trailing: TextButton.icon(
            onPressed: () async {
              final picked = await FileHelper.pickAttachments();
              for (final f in picked) {
                await ref
                    .read(attachmentRepoProvider)
                    .add(Attachment(appointmentId: appt.id!, filePath: f.$1, name: f.$2, createdAt: DateTime.now()));
              }
              ref.read(dataVersionProvider.notifier).bump();
            },
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: Text(context.t('add')),
          ),
        ),
        if (files.isEmpty)
          Text(context.t('no_attachments'), style: TextStyle(color: Theme.of(context).hintColor))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in files)
                GestureDetector(
                  onTap: () {
                    if (f.isImage) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => _ImageViewer(path: f.filePath)));
                    } else {
                      ExportService.share(File(f.filePath));
                    }
                  },
                  onLongPress: () async {
                    if (await confirmDialog(context, title: context.t('delete'), message: f.name, danger: true)) {
                      await ref.read(attachmentRepoProvider).delete(f.id!);
                      try {
                        File(f.filePath).deleteSync();
                      } catch (_) {}
                      ref.read(dataVersionProvider.notifier).bump();
                    }
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    child: f.isImage
                        ? Image.file(File(f.filePath), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded))
                        : Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file_rounded),
                                Text(
                                  f.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      foregroundColor: Colors.white,
      actions: [IconButton(onPressed: () => ExportService.share(File(path)), icon: const Icon(Icons.share_rounded))],
    ),
    body: InteractiveViewer(maxScale: 6, child: Center(child: Image.file(File(path)))),
  );
}

Staff? staffOf(WidgetRef ref, Appointment a) => (ref.watch(staffProvider).value ?? const <Staff>[]).where((x) => x.id == a.staffId).firstOrNull;
ServiceItem? serviceOf(WidgetRef ref, Appointment a) =>
    (ref.watch(servicesProvider).value ?? const <ServiceItem>[]).where((x) => x.id == a.serviceId).firstOrNull;
