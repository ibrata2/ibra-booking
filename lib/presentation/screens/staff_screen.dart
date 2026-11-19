import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'categories_screen.dart' show kPalette;

/// ترتيب الأيام كما في العراق: السبت أولاً.
const _weekOrder = [6, 7, 1, 2, 3, 4, 5];

String _hm(BuildContext context, int minutes) => TimeFmt.time(DateTime(2026, 1, 1).add(Duration(minutes: minutes)), ar: context.ar);

/// ملخص ساعات الدوام في سطر.
String hoursSummary(BuildContext context, WorkHours h) {
  final ar = context.ar;
  final days = _weekOrder.where(h.worksOn).toList();
  if (days.isEmpty) return context.t('no_work_days');
  final first = h.forDay(days.first);
  final range = '${_hm(context, first.first.start)} - ${_hm(context, first.last.end)}';
  return '${days.map((d) => TimeFmt.weekdayShort(d, ar: ar)).join(' ')} • $range';
}

/// إدارة الموظفين: الاسم، اللون، ساعات الدوام، الاستراحة، أيام العطل.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffProvider).value ?? const <Staff>[];
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('staff'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffEditScreen(sort: staff.length))),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(context.t('add_staff')),
      ),
      body: staff.isEmpty
          ? EmptyState(icon: Icons.badge_rounded, text: context.t('no_staff_hint'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                for (final x in staff)
                  Glass(
                    blur: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StaffEditScreen(staff: x, sort: x.sort),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(x.color),
                          child: Text(
                            x.name.isEmpty ? '?' : x.name.characters.first,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                  ),
                                  if (!x.active) ...[
                                    const SizedBox(width: 6),
                                    Text('(${context.t('inactive')})', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                  ],
                                ],
                              ),
                              if (x.role.isNotEmpty)
                                Text(
                                  x.role,
                                  style: TextStyle(color: Color(x.color), fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              Text(hoursSummary(context, x.hours), style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                              Text(
                                '${context.t('upcoming')}: ${appts.where((a) => a.staffId == x.id && a.start.isAfter(now) && !a.status.isClosed).length}',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class StaffEditScreen extends ConsumerStatefulWidget {
  const StaffEditScreen({super.key, this.staff, this.sort = 0});
  final Staff? staff;
  final int sort;
  @override
  ConsumerState<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends ConsumerState<StaffEditScreen> {
  late final _name = TextEditingController(text: widget.staff?.name);
  late final _phone = TextEditingController(text: widget.staff?.phone);
  late final _role = TextEditingController(text: widget.staff?.role);
  late int _color = widget.staff?.color ?? kPalette[(widget.sort + 4) % kPalette.length];
  late bool _active = widget.staff?.active ?? true;
  late WorkHours _hours = widget.staff?.hours ?? WorkHours.standard();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<int?> _pick(int minutes) async {
    final t = await pickTime12(context, TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, context.t('required'));
      return;
    }
    final repo = ref.read(staffRepoProvider);
    final base = widget.staff;
    final item = base == null
        ? Staff(
            name: name,
            phone: _phone.text.trim(),
            role: _role.text.trim(),
            color: _color,
            hours: _hours,
            active: _active,
            sort: widget.sort,
            createdAt: DateTime.now(),
          )
        : base.copyWith(name: name, phone: _phone.text.trim(), role: _role.text.trim(), color: _color, hours: _hours, active: _active);
    await repo.save(item);
    ref.read(dataVersionProvider.notifier).bump();
    await ref.read(bookingControllerProvider).rescheduleNotifications();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, title: context.t('delete'), message: context.t('delete_staff_msg'), danger: true, ok: context.t('delete'))) {
      return;
    }
    await ref.read(staffRepoProvider).delete(widget.staff!.id!);
    if (ref.read(staffFilterProvider) == widget.staff!.id) ref.read(staffFilterProvider.notifier).set(null);
    ref.read(dataVersionProvider.notifier).bump();
    if (mounted) Navigator.pop(context);
  }

  Widget _dayRow(int day) {
    final spans = _hours.forDay(day);
    final works = spans.isNotEmpty;
    final start = works ? spans.first.start : 600;
    final end = works ? spans.last.end : 1200;
    final hasBreak = spans.length > 1;
    final breakStart = hasBreak ? spans.first.end : 840;
    final breakEnd = hasBreak ? spans[1].start : 900;

    void setDay({bool? on, int? s, int? e, bool? brk, int? bs, int? be}) {
      final o = on ?? works;
      if (!o) {
        setState(() => _hours = _hours.withDay(day, const []));
        return;
      }
      final ss = s ?? start, ee = e ?? end;
      final b = brk ?? hasBreak;
      final bss = bs ?? breakStart, bee = be ?? breakEnd;
      final list = b && bss > ss && bee > bss && ee > bee ? [WorkSpan(ss, bss), WorkSpan(bee, ee)] : [WorkSpan(ss, ee)];
      setState(() => _hours = _hours.withDay(day, list));
    }

    Widget timeBtn(int v, ValueChanged<int> set) => OutlinedButton(
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), visualDensity: VisualDensity.compact),
      onPressed: () async {
        final r = await _pick(v);
        if (r != null) set(r);
      },
      child: Text(_hm(context, v), style: const TextStyle(fontSize: 12.5)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Switch(
                value: works,
                onChanged: (v) => setDay(on: v),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 74,
                child: Text(
                  TimeFmt.weekday(day, ar: context.ar),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!works)
                Text(context.t('day_off'), style: TextStyle(color: Theme.of(context).hintColor))
              else ...[
                timeBtn(start, (v) => setDay(s: v)),
                const Text(' – '),
                timeBtn(end, (v) => setDay(e: v)),
              ],
            ],
          ),
          if (works)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 60),
              child: Row(
                children: [
                  Checkbox(
                    value: hasBreak,
                    onChanged: (v) => setDay(brk: v ?? false),
                  ),
                  Text(context.t('break'), style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(width: 6),
                  if (hasBreak) ...[timeBtn(breakStart, (v) => setDay(bs: v)), const Text(' – '), timeBtn(breakEnd, (v) => setDay(be: v))],
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(widget.staff == null ? 'add_staff' : 'edit_staff')),
        actions: [if (widget.staff != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Color(_color),
              child: Text(
                _name.text.trim().isEmpty ? '?' : _name.text.trim().characters.first,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Glass(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: context.t('staff_name'), prefixIcon: const Icon(Icons.badge_rounded)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _role,
                  decoration: InputDecoration(labelText: context.t('staff_role'), prefixIcon: const Icon(Icons.work_outline_rounded)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: context.t('phone'), prefixIcon: const Icon(Icons.phone_rounded)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: Text(context.t('staff_active')),
                  subtitle: Text(context.t('staff_active_hint')),
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('color')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in kPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color == c ? Colors.white : Colors.transparent, width: 3),
                      boxShadow: _color == c ? [BoxShadow(color: Color(c), blurRadius: 10)] : null,
                    ),
                  ),
                ),
            ],
          ),
          SectionTitle(context.t('work_hours')),
          Glass(child: Column(children: [for (final d in _weekOrder) _dayRow(d)])),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final sat = _hours.forDay(6);
              setState(() {
                for (final d in _weekOrder) {
                  if (d != 6 && _hours.worksOn(d)) _hours = _hours.withDay(d, sat);
                }
              });
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: Text(context.t('copy_saturday')),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Text(context.t('save'))),
        ],
      ),
    );
  }
}

/// إدارة الخدمات: الاسم، المدة، السعر، اللون، ومن يقدمها.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider).value ?? const <ServiceItem>[];
    final staff = ref.watch(staffProvider).value ?? const <Staff>[];
    final sym = ref.watch(settingsProvider).currencySymbol;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('services'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null, services.length),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('add_service')),
      ),
      body: services.isEmpty
          ? EmptyState(icon: Icons.design_services_rounded, text: context.t('no_services_hint'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                for (final x in services)
                  Glass(
                    blur: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    onTap: () => _edit(context, ref, x, x.sort),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: Color(x.color), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.spa_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(x.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                '${TimeFmt.human(Duration(minutes: x.durationMin), ar: context.ar)}'
                                '${x.price > 0 ? ' • ${MoneyFmt.format(x.price, sym)}' : ''}',
                                style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5),
                              ),
                              Text(
                                x.staffIds.isEmpty
                                    ? context.t('all_staff')
                                    : staff.where((s) => x.staffIds.contains(s.id)).map((s) => s.name).join('، '),
                                style: TextStyle(color: Color(x.color), fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static const _durations = [10, 15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240];

  Future<void> _edit(BuildContext context, WidgetRef ref, ServiceItem? sv, int sort) async {
    final name = TextEditingController(text: sv?.name);
    final price = TextEditingController(text: sv == null || sv.price == 0 ? '' : MoneyFmt.number(sv.price).replaceAll(',', ''));
    var duration = sv?.durationMin ?? 30;
    var color = sv?.color ?? kPalette[(sort + 3) % kPalette.length];
    var staffIds = {...?sv?.staffIds};
    final staff = (ref.read(staffProvider).value ?? const <Staff>[]).where((x) => x.active).toList();
    final sym = ref.read(settingsProvider).currencySymbol;
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.t(sv == null ? 'add_service' : 'edit_service'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: ctx.t('service_name')),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _durations.contains(duration) ? duration : null,
                        decoration: InputDecoration(labelText: ctx.t('duration')),
                        items: [
                          for (final m in _durations)
                            DropdownMenuItem(
                              value: m,
                              child: Text(TimeFmt.human(Duration(minutes: m), ar: ctx.ar)),
                            ),
                        ],
                        onChanged: (v) => set(() => duration = v ?? duration),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: ctx.t('price'), suffixText: sym),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(ctx.t('color'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kPalette)
                      GestureDetector(
                        onTap: () => set(() => color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(ctx.t('offered_by'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(label: Text(ctx.t('all_staff')), selected: staffIds.isEmpty, onSelected: (_) => set(() => staffIds = {})),
                    for (final x in staff)
                      FilterChip(
                        label: Text(x.name),
                        selected: staffIds.contains(x.id),
                        onSelected: (v) => set(() => v ? staffIds.add(x.id!) : staffIds.remove(x.id)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (sv != null)
                      TextButton.icon(
                        onPressed: () => Navigator.pop(ctx, 'delete'),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        label: Text(ctx.t('delete'), style: const TextStyle(color: Colors.red)),
                      ),
                    const Spacer(),
                    FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(ctx.t('save'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final repo = ref.read(serviceRepoProvider);
    if (r == 'delete' && sv != null) {
      await repo.delete(sv.id!);
    } else if (r == 'save' && name.text.trim().isNotEmpty) {
      final p = double.tryParse(price.text.replaceAll(',', '').trim()) ?? 0;
      final item = sv == null
          ? ServiceItem(name: name.text.trim(), durationMin: duration, price: p, color: color, staffIds: staffIds, sort: sort)
          : sv.copyWith(name: name.text.trim(), durationMin: duration, price: p, color: color, staffIds: staffIds);
      await repo.save(item);
    } else {
      return;
    }
    ref.read(dataVersionProvider.notifier).bump();
  }
}
