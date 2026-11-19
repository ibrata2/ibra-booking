import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../domain/logic/scheduling.dart';
import '../../services/file_helper.dart';
import '../../services/launcher_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/reminder_editor.dart';
import '../widgets/sound_picker.dart';
import 'categories_screen.dart';
import '../../core/edition.dart';
import 'staff_screen.dart';

const kIraqProvinces = [
  'بغداد',
  'البصرة',
  'نينوى',
  'أربيل',
  'النجف',
  'كربلاء',
  'بابل',
  'ديالى',
  'الأنبار',
  'ذي قار',
  'ميسان',
  'واسط',
  'القادسية',
  'المثنى',
  'صلاح الدين',
  'كركوك',
  'السليمانية',
  'دهوك',
  'حلبجة',
];

/// إضافة / تعديل / نسخ حجز.
class AppointmentFormScreen extends ConsumerStatefulWidget {
  const AppointmentFormScreen({super.key, this.appointment, this.copyFrom, this.initialDate, this.customer, this.initialStaffId});
  final Appointment? appointment;
  final Appointment? copyFrom;
  final DateTime? initialDate;
  final Customer? customer;
  final int? initialStaffId;

  @override
  ConsumerState<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _phone2 = TextEditingController();
  final _place = TextEditingController();
  final _province = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _map = TextEditingController();
  final _fee = TextEditingController();
  final _deposit = TextEditingController();
  final _notes = TextEditingController();
  final _nameFocus = FocusNode();
  final _provinceFocus = FocusNode();

  int? _categoryId;
  int? _staffId;
  int? _serviceId;
  int? _customerId;
  BookingStatus _status = BookingStatus.confirmed;
  late DateTime _date;
  late TimeOfDay _startT;
  late TimeOfDay _endT;
  double? _lat, _lng;
  RecurrenceRule _rule = const RecurrenceRule();
  ReminderConfig? _reminder;
  String? _soundKey;
  final List<(String path, String name)> _newFiles = [];
  List<Attachment> _existingFiles = [];
  bool _saving = false;

  bool get _editing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final src = widget.appointment ?? widget.copyFrom;
    final now = DateTime.now();
    if (src != null) {
      _name.text = src.customerName;
      _phone.text = src.phone;
      _phone2.text = src.phone2;
      _place.text = src.placeName;
      _province.text = src.province;
      _area.text = src.area;
      _address.text = src.address;
      _landmark.text = src.landmark;
      _map.text = src.mapUrl;
      _lat = src.lat;
      _lng = src.lng;
      _fee.text = src.fee == 0 ? '' : MoneyFmt.number(src.fee).replaceAll(',', '');
      _deposit.text = src.deposit == 0 ? '' : MoneyFmt.number(src.deposit).replaceAll(',', '');
      _notes.text = src.notes;
      _categoryId = src.categoryId;
      _staffId = src.staffId;
      _serviceId = src.serviceId;
      _customerId = src.customerId;
      _status = src.status;
      _reminder = src.reminderOverride;
      _soundKey = src.soundKey;
      _date = TimeFmt.dayStart(widget.copyFrom != null ? (widget.initialDate ?? src.start) : src.start);
      _startT = TimeOfDay.fromDateTime(src.start);
      _endT = TimeOfDay.fromDateTime(src.end);
      if (widget.appointment?.id != null) {
        ref.read(attachmentRepoProvider).forAppointment(widget.appointment!.id!).then((v) {
          if (mounted) setState(() => _existingFiles = v);
        });
      }
    } else {
      final base = widget.initialDate ?? now;
      _date = TimeFmt.dayStart(base);
      _staffId = widget.initialStaffId;
      final h = widget.initialDate != null && widget.initialDate!.hour > 0 ? widget.initialDate!.hour : (now.hour + 1).clamp(0, 22);
      _startT = TimeOfDay(hour: h, minute: 0);
      _endT = TimeOfDay(hour: (h + 2) % 24, minute: 0);
      if (widget.customer != null) {
        _name.text = widget.customer!.name;
        _phone.text = widget.customer!.phone;
        _phone2.text = widget.customer!.phone2;
        _address.text = widget.customer!.address;
        _customerId = widget.customer!.id;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _phone2, _place, _province, _area, _address, _landmark, _map, _fee, _deposit, _notes]) {
      c.dispose();
    }
    _nameFocus.dispose();
    _provinceFocus.dispose();
    super.dispose();
  }

  DateTime get _start => DateTime(_date.year, _date.month, _date.day, _startT.hour, _startT.minute);
  DateTime get _end {
    var e = DateTime(_date.year, _date.month, _date.day, _endT.hour, _endT.minute);
    // ينتهي بعد منتصف الليل
    if (!e.isAfter(_start)) e = e.add(const Duration(days: 1));
    return e;
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').replaceAll('٬', '').trim()) ?? 0;

  Appointment _build() {
    final now = DateTime.now();
    final base = widget.appointment;
    return Appointment(
      id: base?.id,
      customerId: _customerId,
      customerName: _name.text.trim(),
      phone: _phone.text.trim(),
      phone2: _phone2.text.trim(),
      categoryId: _categoryId,
      staffId: _staffId,
      serviceId: _serviceId,
      placeName: _place.text.trim(),
      province: _province.text.trim(),
      area: _area.text.trim(),
      address: _address.text.trim(),
      landmark: _landmark.text.trim(),
      mapUrl: _map.text.trim(),
      lat: _lat,
      lng: _lng,
      start: _start,
      end: _end,
      fee: _num(_fee),
      deposit: _num(_deposit),
      notes: _notes.text.trim(),
      status: _status,
      recurrenceId: base?.recurrenceId,
      reminderOverride: _reminder,
      soundKey: _soundKey,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final a = _build();
    final ctrl = ref.read(bookingControllerProvider);
    if (Edition.isCenter) {
      final staff = (ref.read(staffProvider).value ?? const <Staff>[]).where((x) => x.active).toList();
      if (staff.isNotEmpty && _staffId == null) {
        toast(context, context.t('staff_required'));
        return;
      }
      final st = staff.where((x) => x.id == _staffId).firstOrNull;
      if (st != null && !st.hours.covers(a.start, a.end)) {
        final go = await confirmDialog(
          context,
          title: context.t('outside_hours_title'),
          message: context.t('outside_hours_msg', {'name': st.name}),
          ok: context.t('save_anyway'),
        );
        if (!go || !mounted) return;
      }
    }
    setState(() => _saving = true);
    try {
      // فحص التعارض لكل تكرار جديد أو للحجز نفسه
      final starts = !_editing && !_rule.isNone ? _rule.expand(a.start) : [a.start];
      final found = <ConflictInfo>[];
      for (final s in starts.take(60)) {
        found.addAll(await ctrl.conflicts(s, s.add(a.duration), ignoreIds: {if (a.id != null) a.id!}, staffId: _staffId));
      }
      if (found.isNotEmpty && mounted) {
        final go = await _conflictDialog(found);
        if (go != true) {
          setState(() => _saving = false);
          return;
        }
      }
      var series = false;
      if (_editing && a.recurrenceId != null && mounted) {
        final r = await showDialog<int>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(c.t('recurring_edit_title')),
            content: Text(c.t('recurring_edit_msg')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t('cancel'))),
              OutlinedButton(onPressed: () => Navigator.pop(c, 1), child: Text(c.t('this_only'))),
              FilledButton(onPressed: () => Navigator.pop(c, 2), child: Text(c.t('all_series'))),
            ],
          ),
        );
        if (r == null) {
          setState(() => _saving = false);
          return;
        }
        series = r == 2;
      }
      final id = await ctrl.save(a, rule: _editing ? null : _rule, applyToSeries: series);
      final attRepo = ref.read(attachmentRepoProvider);
      for (final f in _newFiles) {
        await attRepo.add(Attachment(appointmentId: id, filePath: f.$1, name: f.$2, createdAt: DateTime.now()));
      }
      if (mounted) {
        toast(context, context.t(_editing ? 'saved' : 'booking_added'));
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) toast(context, '${context.t('error')}: $e');
      setState(() => _saving = false);
    }
  }

  Future<bool?> _conflictDialog(List<ConflictInfo> list) {
    final ar = context.ar;
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: Text(c.t('conflict_title')),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(c.t('conflict_msg')),
              const SizedBox(height: 10),
              for (final x in list.take(8))
                Card(
                  child: ListTile(
                    leading: Icon(x.overlap ? Icons.call_merge_rounded : Icons.directions_car_rounded, color: x.overlap ? Colors.red : Colors.orange),
                    title: Text(x.other.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${TimeFmt.date(x.other.start, ar: ar)}\n${TimeFmt.range(x.other.start, x.other.end, ar: ar)}\n'
                      '${x.overlap ? c.t('overlap') : c.t('travel_short', {'m': x.gap.inMinutes})}'
                      '${x.other.placeName.isEmpty ? '' : '\n${x.other.placeName}'}',
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: Text(c.t('cancel'))),
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t('change_time'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.t('save_anyway')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  void _setDuration(int minutes) {
    final e = _start.add(Duration(minutes: minutes));
    setState(() => _endT = TimeOfDay(hour: e.hour, minute: e.minute));
  }

  Future<void> _pasteMap() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = data?.text?.trim() ?? '';
    if (txt.isEmpty) return;
    _map.text = txt;
    _parseMap(txt);
  }

  void _parseMap(String v) {
    final c = Launcher.parseCoords(v);
    setState(() {
      if (c != null) {
        _lat = c.$1;
        _lng = c.$2;
      }
    });
  }

  /// اختيار خدمة: يضبط المدة والسعر تلقائياً.
  void _pickService(ServiceItem sv) {
    final prevPrice = (ref.read(servicesProvider).value ?? const <ServiceItem>[]).where((x) => x.id == _serviceId).firstOrNull?.price;
    setState(() {
      _serviceId = sv.id;
      final e = _start.add(Duration(minutes: sv.durationMin));
      _endT = TimeOfDay(hour: e.hour, minute: e.minute);
      if (_fee.text.trim().isEmpty || (prevPrice != null && _num(_fee) == prevPrice)) {
        _fee.text = sv.price == 0 ? '' : MoneyFmt.number(sv.price).replaceAll(',', '');
      }
      final staff = (ref.read(staffProvider).value ?? const <Staff>[]).where((x) => x.active && sv.offeredBy(x.id)).toList();
      if (_staffId != null && !sv.offeredBy(_staffId)) _staffId = null;
      if (_staffId == null && staff.length == 1) _staffId = staff.first.id;
    });
  }

  List<Widget> _centerSection(BuildContext context) {
    final services = (ref.watch(servicesProvider).value ?? const <ServiceItem>[]).where((x) => x.active || x.id == _serviceId).toList();
    final allStaff = (ref.watch(staffProvider).value ?? const <Staff>[]).where((x) => x.active || x.id == _staffId).toList();
    final sv = services.where((x) => x.id == _serviceId).firstOrNull;
    final staff = sv == null ? allStaff : allStaff.where((x) => sv.offeredBy(x.id) || x.id == _staffId).toList();
    final sym = ref.watch(settingsProvider).currencySymbol;
    return [
      SectionTitle(
        context.t('service'),
        trailing: TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen())),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(context.t('manage')),
        ),
      ),
      if (services.isEmpty)
        Text(context.t('no_services_hint'), style: TextStyle(color: Theme.of(context).hintColor))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final x in services)
              ChoiceChip(
                selected: _serviceId == x.id,
                onSelected: (_) => _pickService(x),
                avatar: CircleAvatar(backgroundColor: Color(x.color), radius: 7),
                label: Text(
                  '${x.name} • ${TimeFmt.human(Duration(minutes: x.durationMin), ar: context.ar)}${x.price > 0 ? ' • ${MoneyFmt.format(x.price, sym)}' : ''}',
                ),
                selectedColor: Color(x.color).withValues(alpha: 0.25),
              ),
          ],
        ),
      SectionTitle(
        context.t('staff_member'),
        trailing: TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen())),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(context.t('manage')),
        ),
      ),
      if (allStaff.isEmpty)
        Text(context.t('no_staff_hint'), style: TextStyle(color: Theme.of(context).hintColor))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final x in staff)
              ChoiceChip(
                selected: _staffId == x.id,
                onSelected: (_) => setState(() => _staffId = x.id),
                avatar: CircleAvatar(
                  backgroundColor: Color(x.color),
                  child: Text(x.name.isEmpty ? '?' : x.name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                label: Text(x.role.isEmpty ? x.name : '${x.name} — ${x.role}'),
                selectedColor: Color(x.color).withValues(alpha: 0.25),
              ),
          ],
        ),
    ];
  }

  /// الأوقات الفارغة للموظف المختار ضمن دوامه (مثل Setmore).
  Widget _slots(BuildContext context) {
    final staff = (ref.watch(staffProvider).value ?? const <Staff>[]).where((x) => x.id == _staffId).firstOrNull;
    if (staff == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(context.t('pick_staff_for_slots'), style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final dayEnd = _date.add(const Duration(days: 1));
    final bookings = appts.where((a) => a.staffId == staff.id && a.start.isBefore(dayEnd) && a.end.isAfter(_date));
    final dur = _end.difference(_start).inMinutes;
    final slots = SlotFinder.free(
      hours: staff.hours,
      day: _date,
      durationMin: dur <= 0 ? 30 : dur,
      staffBookings: bookings,
      stepMin: 15,
      now: DateTime.now(),
      ignoreIds: {if (widget.appointment?.id != null) widget.appointment!.id!},
    );
    final ar = context.ar;
    final spans = staff.hours.forDay(_date.weekday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Icon(Icons.access_time_filled_rounded, size: 18, color: Color(staff.color)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${context.t('available_times')} — ${staff.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          spans.isEmpty
              ? context.t('day_off')
              : '${context.t('work_hours')}: ${spans.map((sp) => '${TimeFmt.time(_date.add(Duration(minutes: sp.start)), ar: ar)} - ${TimeFmt.time(_date.add(Duration(minutes: sp.end)), ar: ar)}').join(' ، ')}',
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 8),
        if (slots.isEmpty)
          Text(
            context.t('no_slots'),
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sl in slots)
                ChoiceChip(
                  selected: sl == _start,
                  label: Text(TimeFmt.time(sl, ar: ar)),
                  onSelected: (_) => setState(() {
                    final d = _end.difference(_start);
                    _startT = TimeOfDay(hour: sl.hour, minute: sl.minute);
                    final e = sl.add(d);
                    _endT = TimeOfDay(hour: e.hour, minute: e.minute);
                  }),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final settings = ref.watch(settingsProvider);
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final customers = ref.watch(customersProvider).value ?? const <Customer>[];
    final remaining = (_num(_fee) - _num(_deposit)).clamp(0, double.infinity);
    final crosses = !TimeFmt.sameDay(_start, _end);
    final title = _editing ? context.t('edit_booking') : (widget.copyFrom != null ? context.t('copy_booking') : context.t('new_booking'));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            SectionTitle(context.t('customer')),
            Glass(
              child: Column(
                children: [
                  RawAutocomplete<Customer>(
                    textEditingController: _name,
                    focusNode: _nameFocus,
                    optionsBuilder: (v) {
                      final q = v.text.trim();
                      if (q.isEmpty) return const Iterable<Customer>.empty();
                      return customers.where((c) => c.name.contains(q) || c.phone.contains(q)).take(8);
                    },
                    displayStringForOption: (c) => c.name,
                    onSelected: (c) {
                      _phone.text = c.phone;
                      if (_phone2.text.isEmpty) _phone2.text = c.phone2;
                      if (_address.text.isEmpty) _address.text = c.address;
                      setState(() => _customerId = c.id);
                    },
                    fieldViewBuilder: (c, ctrl, focus, submit) => TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: context.t('customer_name'), prefixIcon: const Icon(Icons.person_rounded)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? context.t('required') : null,
                    ),
                    optionsViewBuilder: (c, onSel, options) => Align(
                      alignment: ar ? Alignment.topRight : Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260, maxWidth: 360),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final o in options)
                                ListTile(
                                  leading: const Icon(Icons.person_outline_rounded),
                                  title: Text(o.name),
                                  subtitle: o.phone.isEmpty ? null : Text(o.phone, textDirection: TextDirection.ltr),
                                  onTap: () => onSel(o),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: context.t('phone'), prefixIcon: const Icon(Icons.phone_rounded)),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phone2,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: context.t('phone2'), prefixIcon: const Icon(Icons.phone_forwarded_rounded)),
                  ),
                ],
              ),
            ),
            if (Edition.isCenter)
              ..._centerSection(context)
            else ...[
              SectionTitle(
                context.t('event_type'),
                trailing: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.t('manage')),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                      avatar: Icon(categoryIcon(c.icon), size: 18, color: Color(c.color)),
                      label: Text(c.name(ar)),
                      selectedColor: Color(c.color).withValues(alpha: 0.25),
                      side: BorderSide(color: Color(c.color).withValues(alpha: 0.6)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final s in [BookingStatus.confirmed, BookingStatus.pending, BookingStatus.postponed, BookingStatus.cancelled])
                  if (_editing || s == BookingStatus.confirmed || s == BookingStatus.pending)
                    ChoiceChip(
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                      avatar: Icon(statusIcon(s), size: 16, color: statusColor(s)),
                      label: Text(context.t('st_${s.name}')),
                    ),
              ],
            ),
            SectionTitle(context.t('date_time')),
            Glass(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded),
                    title: Text(context.t('event_date')),
                    subtitle: Text(
                      TimeFmt.dateLong(_date, ar: ar),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: _pickDate,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeBox(
                          label: context.t('start_time'),
                          value: formatTod(context, _startT),
                          onTap: () async {
                            final t = await pickTime12(context, _startT);
                            if (t != null) {
                              final dur = _end.difference(_start);
                              setState(() {
                                _startT = t;
                                final e = _start.add(dur);
                                _endT = TimeOfDay(hour: e.hour, minute: e.minute);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeBox(
                          label: context.t('end_time'),
                          value: formatTod(context, _endT) + (crosses ? '\n${context.t('next_day')}' : ''),
                          onTap: () async {
                            final t = await pickTime12(context, _endT);
                            if (t != null) setState(() => _endT = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${context.t('duration')}: ${TimeFmt.human(_end.difference(_start), ar: ar)}',
                        style: TextStyle(color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in [30, 60, 90, 120, 180, 240])
                        ActionChip(
                          label: Text(TimeFmt.human(Duration(minutes: m), ar: ar)),
                          onPressed: () => _setDuration(m),
                        ),
                    ],
                  ),
                  if (Edition.isCenter) _slots(context),
                ],
              ),
            ),
            if (!_editing) ...[
              SectionTitle(context.t('repeat')),
              Glass(
                child: _RecurrenceEditor(rule: _rule, start: _start, onChanged: (r) => setState(() => _rule = r)),
              ),
            ],
            if (!Edition.isCenter) ...[
              SectionTitle(context.t('location')),
              Glass(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _place,
                      decoration: InputDecoration(labelText: context.t('place_name'), prefixIcon: const Icon(Icons.location_city_rounded)),
                    ),
                    const SizedBox(height: 10),
                    RawAutocomplete<String>(
                      textEditingController: _province,
                      focusNode: _provinceFocus,
                      optionsBuilder: (v) => kIraqProvinces.where((p) => p.contains(v.text.trim())),
                      fieldViewBuilder: (c, ctrl, focus, submit) => TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        decoration: InputDecoration(labelText: context.t('province'), prefixIcon: const Icon(Icons.map_rounded)),
                      ),
                      optionsViewBuilder: (c, onSel, options) => Align(
                        alignment: ar ? Alignment.topRight : Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 260),
                            child: ListView(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              children: [for (final o in options) ListTile(title: Text(o), onTap: () => onSel(o))],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _area,
                      decoration: InputDecoration(labelText: context.t('area'), prefixIcon: const Icon(Icons.holiday_village_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: context.t('address_detail'), prefixIcon: const Icon(Icons.home_work_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _landmark,
                      decoration: InputDecoration(labelText: context.t('landmark'), prefixIcon: const Icon(Icons.flag_rounded)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _map,
                      textDirection: TextDirection.ltr,
                      onChanged: _parseMap,
                      decoration: InputDecoration(
                        labelText: context.t('map_link'),
                        prefixIcon: const Icon(Icons.pin_drop_rounded),
                        suffixIcon: IconButton(tooltip: context.t('paste'), icon: const Icon(Icons.content_paste_rounded), onPressed: _pasteMap),
                      ),
                    ),
                    if (_lat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, size: 18, color: Color(0xFF00C853)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Launcher.openMap(_build(), app: settings.mapsApp, navigate: false),
                              child: Text(context.t('preview')),
                            ),
                            IconButton(onPressed: () => setState(() => _lat = _lng = null), icon: const Icon(Icons.close_rounded)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (settings.showFinance) ...[
              SectionTitle(context.t('payment')),
              Glass(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fee,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: context.t('fee'), suffixText: settings.currencySymbol),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _deposit,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: context.t('deposit'), suffixText: settings.currencySymbol),
                            validator: (v) => _num(_deposit) > _num(_fee) && _num(_fee) > 0 ? context.t('deposit_too_big') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('${context.t('remaining')}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          MoneyFmt.format(remaining, settings.currencySymbol),
                          style: TextStyle(fontWeight: FontWeight.w800, color: remaining > 0 ? Colors.orange : const Color(0xFF00C853)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SectionTitle(context.t('notes')),
            Glass(
              child: TextFormField(
                controller: _notes,
                maxLines: 4,
                minLines: 2,
                decoration: InputDecoration(hintText: context.t('notes_hint')),
              ),
            ),
            SectionTitle(
              context.t('attachments'),
              trailing: TextButton.icon(
                onPressed: () async {
                  final f = await FileHelper.pickAttachments();
                  setState(() => _newFiles.addAll(f));
                },
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(context.t('add')),
              ),
            ),
            if (_existingFiles.isEmpty && _newFiles.isEmpty)
              Text(context.t('no_attachments'), style: TextStyle(color: Theme.of(context).hintColor))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _existingFiles)
                    _FileThumb(
                      path: a.filePath,
                      name: a.name,
                      onRemove: () async {
                        await ref.read(attachmentRepoProvider).delete(a.id!);
                        setState(() => _existingFiles.remove(a));
                      },
                    ),
                  for (final f in _newFiles) _FileThumb(path: f.$1, name: f.$2, onRemove: () => setState(() => _newFiles.remove(f))),
                ],
              ),
            SectionTitle(context.t('reminders')),
            Glass(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _reminder == null,
                    title: Text(context.t('use_default_reminders')),
                    onChanged: (v) => setState(() => _reminder = v ? null : settings.reminders),
                  ),
                  if (_reminder != null) ReminderEditor(config: _reminder!, onChanged: (c) => setState(() => _reminder = c)),
                  const Divider(),
                  SoundPickerTile(
                    title: context.t('booking_sound'),
                    value: _soundKey,
                    allowInherit: true,
                    onChanged: (k) => setState(() => _soundKey = k),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(context.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _FileThumb extends StatelessWidget {
  const _FileThumb({required this.path, required this.name, required this.onRemove});
  final String path;
  final String name;
  final VoidCallback onRemove;
  bool get _isImage => RegExp(r'\.(jpe?g|png|webp|gif|heic)$', caseSensitive: false).hasMatch(path);
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: 92,
        height: 92,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)),
        child: _isImage
            ? Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_rounded))
            : Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.insert_drive_file_rounded),
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5), textAlign: TextAlign.center),
                  ],
                ),
              ),
      ),
      PositionedDirectional(
        top: 2,
        end: 2,
        child: InkWell(
          onTap: onRemove,
          child: const CircleAvatar(
            radius: 12,
            backgroundColor: Colors.black54,
            child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ),
        ),
      ),
    ],
  );
}

class _RecurrenceEditor extends StatelessWidget {
  const _RecurrenceEditor({required this.rule, required this.start, required this.onChanged});
  final RecurrenceRule rule;
  final DateTime start;
  final ValueChanged<RecurrenceRule> onChanged;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final occ = rule.isNone ? 1 : rule.expand(start).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RecurrenceType>(
          initialValue: rule.type,
          decoration: InputDecoration(labelText: context.t('repeat_type'), prefixIcon: const Icon(Icons.repeat_rounded)),
          items: [for (final t in RecurrenceType.values) DropdownMenuItem(value: t, child: Text(context.t('rec_${t.name}')))],
          onChanged: (t) {
            if (t == null) return;
            onChanged(
              rule.copyWith(
                type: t,
                count: t == RecurrenceType.daily ? 3 : (t == RecurrenceType.none || t == RecurrenceType.range ? null : 4),
                clearCount: t == RecurrenceType.none || t == RecurrenceType.range,
                until: t == RecurrenceType.range ? start.add(const Duration(days: 9)) : null,
                clearUntil: t != RecurrenceType.range,
                weekdays: t == RecurrenceType.weekdays ? {start.weekday} : const {},
              ),
            );
          },
        ),
        if (!rule.isNone) ...[
          const SizedBox(height: 10),
          if (rule.type == RecurrenceType.weekdays)
            Wrap(
              spacing: 6,
              children: [
                for (final d in [6, 7, 1, 2, 3, 4, 5])
                  FilterChip(
                    label: Text(TimeFmt.weekday(d, ar: ar)),
                    selected: rule.weekdays.contains(d),
                    onSelected: (v) {
                      final s = {...rule.weekdays};
                      v ? s.add(d) : s.remove(d);
                      onChanged(rule.copyWith(weekdays: s));
                    },
                  ),
              ],
            ),
          if (rule.type != RecurrenceType.range) ...[
            if (rule.type != RecurrenceType.weekdays && rule.type != RecurrenceType.daily)
              Row(
                children: [
                  Text(context.t('every')),
                  IconButton(
                    onPressed: rule.interval > 1 ? () => onChanged(rule.copyWith(interval: rule.interval - 1)) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${rule.interval}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  IconButton(
                    onPressed: () => onChanged(rule.copyWith(interval: rule.interval + 1)),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Text(context.t('unit_${rule.type.name}')),
                ],
              ),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(context.t('by_count'))),
                ButtonSegment(value: false, label: Text(context.t('until_date'))),
              ],
              selected: {rule.until == null},
              onSelectionChanged: (s) => s.first
                  ? onChanged(rule.copyWith(count: 3, clearUntil: true))
                  : onChanged(rule.copyWith(clearCount: true, until: start.add(const Duration(days: 30)))),
            ),
            const SizedBox(height: 6),
          ],
          if (rule.until == null && rule.type != RecurrenceType.range)
            Row(
              children: [
                Text(context.t('times_count')),
                IconButton(
                  onPressed: (rule.count ?? 1) > 1 ? () => onChanged(rule.copyWith(count: (rule.count ?? 2) - 1)) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${rule.count ?? 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                IconButton(
                  onPressed: (rule.count ?? 1) < RecurrenceRule.maxOccurrences ? () => onChanged(rule.copyWith(count: (rule.count ?? 1) + 1)) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_rounded),
              title: Text(context.t('until_date')),
              subtitle: Text(TimeFmt.dateLong(rule.until ?? start, ar: ar)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: rule.until ?? start,
                  firstDate: TimeFmt.dayStart(start),
                  lastDate: DateTime(2100),
                );
                if (d != null) onChanged(rule.copyWith(until: d));
              },
            ),
          Text(
            context.t('occurrences', {'n': occ}),
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}
