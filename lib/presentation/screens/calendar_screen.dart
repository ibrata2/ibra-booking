import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';
import 'appointment_form_screen.dart';
import 'search_screen.dart';
import '../../core/edition.dart';

enum CalView { day, week, month, year, list }

/// التقويم: يومي، أسبوعي، شهري، سنوي، وقائمة — مع السحب والإفلات لتغيير الموعد.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalView _view = CalView.month;
  DateTime _focus = TimeFmt.dayStart(DateTime.now());
  DateTime _selected = TimeFmt.dayStart(DateTime.now());

  void _shift(int dir) => setState(() {
    switch (_view) {
      case CalView.day:
        _focus = DateTime(_focus.year, _focus.month, _focus.day + dir);
        _selected = _focus;
      case CalView.week:
        _focus = DateTime(_focus.year, _focus.month, _focus.day + 7 * dir);
      case CalView.month:
      case CalView.list:
        _focus = DateTime(_focus.year, _focus.month + dir, 1);
      case CalView.year:
        _focus = DateTime(_focus.year + dir, 1, 1);
    }
  });

  String _title(bool ar, int weekStart) => switch (_view) {
    CalView.day => TimeFmt.dateLong(_focus, ar: ar),
    CalView.week => () {
      final s = TimeFmt.weekStart(_focus, weekStart);
      final e = s.add(const Duration(days: 6));
      return '${s.day} ${TimeFmt.monthShort(s.month, ar: ar)} - ${e.day} ${TimeFmt.monthShort(e.month, ar: ar)} ${e.year}';
    }(),
    CalView.month || CalView.list => TimeFmt.monthYear(_focus, ar: ar),
    CalView.year => '${_focus.year}',
  };

  Future<void> _jump() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _focus,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: _view == CalView.year ? DatePickerMode.year : DatePickerMode.day,
    );
    if (d != null) setState(() => _focus = _selected = d);
  }

  /// نقل حجز بالسحب والإفلات مع طلب التأكيد وفحص التعارض.
  Future<void> _move(Appointment a, DateTime newStart, [int? toStaff]) async {
    final staffChanged = Edition.isCenter && toStaff != a.staffId;
    if (newStart == a.start && !staffChanged) return;
    final ar = context.ar;
    final ok = await confirmDialog(
      context,
      title: context.t('move_booking'),
      message: context.t(staffChanged ? 'move_confirm_staff' : 'move_confirm', {
        'staff': (ref.read(staffProvider).value ?? const <Staff>[]).where((x) => x.id == toStaff).firstOrNull?.name ?? context.t('unassigned'),
        'name': a.customerName,
        'date': TimeFmt.dateLong(newStart, ar: ar),
        'time': TimeFmt.range(newStart, newStart.add(a.duration), ar: ar),
      }),
      ok: context.t('move'),
    );
    if (!ok || !mounted) return;
    final ctrl = ref.read(bookingControllerProvider);
    final conflicts = await ctrl.conflicts(newStart, newStart.add(a.duration), ignoreIds: {a.id!}, staffId: Edition.isCenter ? toStaff : null);
    if (conflicts.isNotEmpty && mounted) {
      final go = await confirmDialog(
        context,
        title: context.t('conflict_title'),
        message: conflicts
            .map(
              (c) =>
                  '• ${c.other.customerName} — ${TimeFmt.range(c.other.start, c.other.end, ar: ar)}${c.overlap ? '' : ' (${context.t('travel_short', {'m': c.gap.inMinutes})})'}',
            )
            .join('\n'),
        ok: context.t('save_anyway'),
      );
      if (!go) return;
    }
    await ctrl.move(a, newStart, staffId: toStaff, changeStaff: staffChanged);
    if (mounted) toast(context, context.t('moved'));
  }

  void _open(Appointment a) => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: a.id!)));

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final settings = ref.watch(settingsProvider);
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final catMap = {for (final c in cats) c.id: c};
    final staff = (ref.watch(staffProvider).value ?? const <Staff>[]).where((x) => x.active).toList();
    final services = ref.watch(servicesProvider).value ?? const <ServiceItem>[];
    final staffFilter = Edition.isCenter ? ref.watch(staffFilterProvider) : null;
    final staffMap = {for (final x in staff) x.id: x};
    final svcMap = {for (final x in services) x.id: x};
    Color colorOf(Appointment a) {
      if (Edition.isCenter) {
        final sv = svcMap[a.serviceId];
        if (sv != null) return Color(sv.color);
        final st = staffMap[a.staffId];
        if (st != null) return Color(st.color);
      }
      return Color(catMap[a.categoryId]?.color ?? 0xFF3D7BFF);
    }

    final shown = staffFilter == null ? appts : appts.where((a) => a.staffId == staffFilter).toList();
    void add(DateTime d, int? staffId) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(initialDate: d, initialStaffId: staffId ?? staffFilter),
      ),
    );
    List<_Col> dayCols() {
      if (!Edition.isCenter || staff.isEmpty) return [_Col(day: _focus)];
      final list = staffFilter == null ? staff : staff.where((x) => x.id == staffFilter).toList();
      final cols = [for (final x in list) _Col(day: _focus, byStaff: true, staffId: x.id, title: x.name, color: Color(x.color), hours: x.hours)];
      final unassigned = appts.any((a) => a.staffId == null || !staffMap.containsKey(a.staffId)) && staffFilter == null;
      if (unassigned && appts.any((a) => (a.staffId == null || !staffMap.containsKey(a.staffId)) && _segment(a, _focus) != null)) {
        cols.add(_Col(day: _focus, byStaff: true, staffId: null, title: context.t('unassigned'), color: Colors.grey));
      }
      return cols;
    }

    Widget body = switch (_view) {
      CalView.day => _Timeline(cols: dayCols(), appts: appts, colorOf: colorOf, onOpen: _open, onMove: _move, onAdd: add),
      CalView.week => _Timeline(
        cols: [for (var i = 0; i < 7; i++) _Col(day: TimeFmt.weekStart(_focus, settings.weekStart).add(Duration(days: i)))],
        appts: shown,
        colorOf: colorOf,
        onOpen: _open,
        onMove: _move,
        onAdd: add,
      ),
      CalView.month => _MonthView(
        focus: _focus,
        selected: _selected,
        weekStart: settings.weekStart,
        appts: shown,
        cats: catMap,
        colorOf: colorOf,
        now: now,
        onSelect: (d) => setState(() => _selected = d),
        onOpen: _open,
        onMove: _move,
      ),
      CalView.year => _YearView(
        year: _focus.year,
        weekStart: settings.weekStart,
        appts: shown,
        onMonth: (m) => setState(() {
          _focus = DateTime(_focus.year, m, 1);
          _view = CalView.month;
        }),
      ),
      CalView.list => _ListView(month: _focus, appts: shown, cats: catMap, now: now, onOpen: _open),
    };

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => _shift(ar ? 1 : -1), icon: const Icon(Icons.chevron_right_rounded)),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _jump,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _title(ar, settings.weekStart),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                IconButton(onPressed: () => _shift(ar ? -1 : 1), icon: const Icon(Icons.chevron_left_rounded)),
                IconButton(
                  tooltip: context.t('today'),
                  onPressed: () => setState(() => _focus = _selected = TimeFmt.dayStart(DateTime.now())),
                  icon: const Icon(Icons.today_rounded),
                ),
                IconButton(
                  tooltip: context.t('search'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SegmentedButton<CalView>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: CalView.day, label: Text(context.t('view_day'))),
                ButtonSegment(value: CalView.week, label: Text(context.t('view_week'))),
                ButtonSegment(value: CalView.month, label: Text(context.t('view_month'))),
                ButtonSegment(value: CalView.year, label: Text(context.t('view_year'))),
                ButtonSegment(value: CalView.list, label: Text(context.t('view_list'))),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() {
                _view = s.first;
                if (_view == CalView.day) _focus = _selected;
              }),
            ),
          ),
          if (Edition.isCenter && staff.isNotEmpty) StaffFilterBar(staff: staff),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// تقسيم حجز إلى مقطع داخل يوم محدد (يدعم الحجوزات بعد منتصف الليل).
({DateTime s, DateTime e})? _segment(Appointment a, DateTime day) {
  final ds = TimeFmt.dayStart(day), de = TimeFmt.dayEnd(day);
  if (!a.start.isBefore(de) || !a.end.isAfter(ds)) return null;
  return (s: a.start.isBefore(ds) ? ds : a.start, e: a.end.isAfter(de) ? de : a.end);
}

class _DragData {
  final Appointment appt;
  const _DragData(this.appt);
}

/// عمود في عرض الخط الزمني: يوم (عرض يومي/أسبوعي) أو موظف (نسخة المركز).
class _Col {
  final DateTime day;
  final bool byStaff;
  final int? staffId;
  final String title;
  final Color? color;
  final WorkHours? hours;
  const _Col({required this.day, this.byStaff = false, this.staffId, this.title = '', this.color, this.hours});
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.cols, required this.appts, required this.colorOf, required this.onOpen, required this.onMove, required this.onAdd});
  final List<_Col> cols;
  final List<Appointment> appts;
  final Color Function(Appointment) colorOf;
  final ValueChanged<Appointment> onOpen;
  final Future<void> Function(Appointment, DateTime, int?) onMove;
  final void Function(DateTime, int?) onAdd;
  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  static const hourH = 64.0;
  static const labelW = 64.0;
  static const minColW = 118.0;
  late final ScrollController _scroll = ScrollController(initialScrollOffset: hourH * math.max(0, DateTime.now().hour - 2));

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _header(_Col c, DateTime now, bool ar) {
    if (c.byStaff) {
      final color = c.color ?? Theme.of(context).colorScheme.primary;
      return Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color.withValues(alpha: 0.18)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: color,
              child: Text(
                c.title.isEmpty ? '?' : c.title.characters.first,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }
    final d = c.day;
    return Container(
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: TimeFmt.sameDay(d, now) ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : null,
      ),
      child: Column(
        children: [
          Text(TimeFmt.weekdayShort(d.weekday, ar: ar), style: const TextStyle(fontSize: 11)),
          Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final now = DateTime.now();
    final showHeader = widget.cols.length > 1 || widget.cols.first.byStaff;
    return LayoutBuilder(
      builder: (context, box) {
        final staffMode = widget.cols.any((c) => c.byStaff);
        final need = labelW + widget.cols.length * minColW;
        final width = staffMode && need > box.maxWidth ? need : box.maxWidth;
        final content = SizedBox(
          width: width,
          height: box.maxHeight,
          child: Column(
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: labelW),
                  child: Row(children: [for (final c in widget.cols) Expanded(child: _header(c, now, ar))]),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 110),
                  child: SizedBox(
                    height: hourH * 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelW,
                          child: Column(
                            children: [
                              for (var h = 0; h < 24; h++)
                                SizedBox(
                                  height: hourH,
                                  child: Align(
                                    alignment: AlignmentDirectional.topEnd,
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(end: 6),
                                      child: Text(
                                        TimeFmt.time(DateTime(2026, 1, 1, h), ar: ar).replaceAll(':00', ''),
                                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).hintColor),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final c in widget.cols) Expanded(child: _column(c, now)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        if (width <= box.maxWidth) return content;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: content);
      },
    );
  }

  Widget _column(_Col col, DateTime now) {
    final day = col.day;
    final segs = <({Appointment a, DateTime s, DateTime e})>[];
    for (final a in widget.appts) {
      if (col.byStaff && a.staffId != col.staffId) continue;
      final g = _segment(a, day);
      if (g != null) segs.add((a: a, s: g.s, e: g.e));
    }
    segs.sort((x, y) => x.s.compareTo(y.s));
    // توزيع المتداخلة جنباً إلى جنب
    final lanes = <DateTime>[];
    final laneOf = <int>[];
    for (final s in segs) {
      var lane = lanes.indexWhere((end) => !end.isAfter(s.s));
      if (lane < 0) {
        lanes.add(s.e);
        lane = lanes.length - 1;
      } else {
        lanes[lane] = s.e;
      }
      laneOf.add(lane);
    }
    final laneCount = math.max(1, lanes.length);
    final ds = TimeFmt.dayStart(day);
    // تظليل خارج ساعات الدوام
    final off = <(int, int)>[];
    if (col.hours != null) {
      var cursor = 0;
      for (final sp in col.hours!.forDay(day.weekday)) {
        if (sp.start > cursor) off.add((cursor, sp.start));
        cursor = math.max(cursor, sp.end);
      }
      if (cursor < 1440) off.add((cursor, 1440));
    }
    final shade = Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.06);
    return LayoutBuilder(
      builder: (c, box) {
        final w = box.maxWidth;
        return Stack(
          children: [
            for (final o in off)
              Positioned(
                top: o.$1 / 60 * hourH,
                height: (o.$2 - o.$1) / 60 * hourH,
                left: 0,
                right: 0,
                child: IgnorePointer(child: ColoredBox(color: shade)),
              ),
            // خانات الإفلات (كل ربع ساعة)
            Column(
              children: [
                for (var q = 0; q < 96; q++)
                  DragTarget<_DragData>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (d) =>
                        widget.onMove(d.data.appt, ds.add(Duration(minutes: q * 15)), col.byStaff ? col.staffId : d.data.appt.staffId),
                    builder: (c, cand, _) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => widget.onAdd(ds.add(Duration(minutes: (q ~/ 2) * 30)), col.byStaff ? col.staffId : null),
                      child: Container(
                        height: hourH / 4,
                        decoration: BoxDecoration(
                          color: cand.isNotEmpty ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.25) : null,
                          border: Border(
                            top: q % 4 == 0 ? BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)) : BorderSide.none,
                            left: col.byStaff ? BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)) : BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (TimeFmt.sameDay(day, now))
              Positioned(
                top: (now.hour * 60 + now.minute) / 60 * hourH,
                left: 0,
                right: 0,
                child: Container(height: 2, color: Colors.redAccent),
              ),
            for (var i = 0; i < segs.length; i++)
              Positioned.directional(
                textDirection: Directionality.of(context),
                top: segs[i].s.difference(ds).inMinutes / 60 * hourH,
                height: math.max(22, segs[i].e.difference(segs[i].s).inMinutes / 60 * hourH - 2),
                start: laneOf[i] * (w / laneCount) + 1,
                width: w / laneCount - 2,
                child: _EventBlock(appt: segs[i].a, color: widget.colorOf(segs[i].a), onTap: () => widget.onOpen(segs[i].a)),
              ),
          ],
        );
      },
    );
  }
}

class _EventBlock extends StatelessWidget {
  const _EventBlock({required this.appt, required this.color, required this.onTap});
  final Appointment appt;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final faded = appt.status == BookingStatus.cancelled;
    Widget box({double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: faded ? 0.25 : 0.85),
          border: BorderDirectional(start: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 3)),
        ),
        child: Text(
          '${appt.customerName}\n${TimeFmt.time(appt.start, ar: ar)}',
          overflow: TextOverflow.fade,
          style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: faded ? TextDecoration.lineThrough : null),
        ),
      ),
    );
    return LongPressDraggable<_DragData>(
      data: _DragData(appt),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 140, height: 46, child: box()),
      ),
      childWhenDragging: box(opacity: 0.35),
      child: GestureDetector(onTap: onTap, child: box()),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.focus,
    required this.selected,
    required this.weekStart,
    required this.appts,
    required this.cats,
    required this.colorOf,
    required this.now,
    required this.onSelect,
    required this.onOpen,
    required this.onMove,
  });
  final DateTime focus;
  final DateTime selected;
  final int weekStart;
  final List<Appointment> appts;
  final Map<int?, EventCategory> cats;
  final Color Function(Appointment) colorOf;
  final DateTime now;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<Appointment> onOpen;
  final Future<void> Function(Appointment, DateTime) onMove;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final first = DateTime(focus.year, focus.month, 1);
    final gridStart = TimeFmt.weekStart(first, weekStart);
    final days = List.generate(42, (i) => DateTime(gridStart.year, gridStart.month, gridStart.day + i));
    List<Appointment> on(DateTime d) => appts.where((a) => _segment(a, d) != null).toList()..sort((a, b) => a.start.compareTo(b.start));
    final dayList = on(selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
      children: [
        Glass(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          TimeFmt.weekdayShort(days[i].weekday, ar: ar),
                          style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).hintColor, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var r = 0; r < 6; r++)
                Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final d = days[r * 7 + c];
                            final list = on(d);
                            final inMonth = d.month == focus.month;
                            final isSel = TimeFmt.sameDay(d, selected);
                            final isToday = TimeFmt.sameDay(d, now);
                            final primary = Theme.of(context).colorScheme.primary;
                            return DragTarget<_DragData>(
                              onAcceptWithDetails: (det) {
                                final a = det.data.appt;
                                onMove(a, DateTime(d.year, d.month, d.day, a.start.hour, a.start.minute));
                              },
                              builder: (c, cand, _) => InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => onSelect(d),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 58,
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: cand.isNotEmpty
                                        ? primary.withValues(alpha: 0.35)
                                        : isSel
                                        ? primary.withValues(alpha: 0.22)
                                        : null,
                                    border: isToday ? Border.all(color: primary, width: 1.6) : null,
                                  ),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${d.day}',
                                        style: TextStyle(
                                          fontWeight: isToday || isSel ? FontWeight.w800 : FontWeight.w500,
                                          color: inMonth ? null : Theme.of(context).hintColor.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          for (final a in list.take(4))
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(shape: BoxShape.circle, color: colorOf(a)),
                                            ),
                                        ],
                                      ),
                                      if (list.length > 4) Text('+${list.length - 4}', style: const TextStyle(fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        SectionTitle(
          TimeFmt.dateLong(selected, ar: ar),
          trailing: IconButton.filledTonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AppointmentFormScreen(initialDate: DateTime(selected.year, selected.month, selected.day, 16))),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        if (dayList.isEmpty)
          Glass(
            child: EmptyState(icon: Icons.event_busy_rounded, text: context.t('no_bookings_day')),
          )
        else ...[
          Text(context.t('drag_hint'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          for (final a in dayList)
            LongPressDraggable<_DragData>(
              data: _DragData(a),
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: colorOf(a), borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    a.customerName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              child: AppointmentTile(appt: a, category: cats[a.categoryId], now: now, onTap: () => onOpen(a)),
            ),
        ],
      ],
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({required this.year, required this.weekStart, required this.appts, required this.onMonth});
  final int year;
  final int weekStart;
  final List<Appointment> appts;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final busy = <int>{};
    for (final a in appts) {
      if (a.status == BookingStatus.cancelled) continue;
      var d = TimeFmt.dayStart(a.start);
      while (d.isBefore(a.end)) {
        if (d.year == year) busy.add(d.month * 100 + d.day);
        d = DateTime(d.year, d.month, d.day + 1);
      }
    }
    final primary = Theme.of(context).colorScheme.primary;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.92,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (c, i) {
        final m = i + 1;
        final first = DateTime(year, m, 1);
        final start = TimeFmt.weekStart(first, weekStart);
        final count = appts.where((a) => a.start.year == year && a.start.month == m && a.status != BookingStatus.cancelled).length;
        return Glass(
          padding: const EdgeInsets.all(8),
          onTap: () => onMonth(m),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      TimeFmt.month(m, ar: ar),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 7,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var k = 0; k < 42; k++)
                      Builder(
                        builder: (_) {
                          final d = DateTime(start.year, start.month, start.day + k);
                          if (d.month != m) return const SizedBox.shrink();
                          final has = busy.contains(m * 100 + d.day);
                          return Center(
                            child: Container(
                              width: 16,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: has ? BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.8)) : null,
                              child: Text('${d.day}', style: TextStyle(fontSize: 8.5, color: has ? Colors.white : null)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListView extends StatefulWidget {
  const _ListView({required this.month, required this.appts, required this.cats, required this.now, required this.onOpen});
  final DateTime month;
  final List<Appointment> appts;
  final Map<int?, EventCategory> cats;
  final DateTime now;
  final ValueChanged<Appointment> onOpen;
  @override
  State<_ListView> createState() => _ListViewState();
}

class _ListViewState extends State<_ListView> {
  BookingStatus? _status;
  int? _cat;

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final from = DateTime(widget.month.year, widget.month.month, 1);
    final to = DateTime(widget.month.year, widget.month.month + 1, 1);
    final items =
        widget.appts
            .where((a) => a.start.isBefore(to) && a.end.isAfter(from))
            .where((a) => _status == null || a.effectiveStatus(widget.now) == _status)
            .where((a) => _cat == null || a.categoryId == _cat)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final groups = <DateTime, List<Appointment>>{};
    for (final a in items) {
      groups.putIfAbsent(TimeFmt.dayStart(a.start), () => []).add(a);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(context.t('all')),
                selected: _status == null && _cat == null,
                onSelected: (_) => setState(() => _status = _cat = null),
              ),
              const SizedBox(width: 6),
              for (final s in [
                BookingStatus.upcoming,
                BookingStatus.confirmed,
                BookingStatus.pending,
                BookingStatus.completed,
                BookingStatus.cancelled,
                BookingStatus.postponed,
                BookingStatus.noShow,
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: FilterChip(
                    avatar: Icon(statusIcon(s), size: 16, color: statusColor(s)),
                    label: Text(context.t('st_${s.name}')),
                    selected: _status == s,
                    onSelected: (v) => setState(() => _status = v ? s : null),
                  ),
                ),
              for (final c in widget.cats.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: FilterChip(
                    avatar: Icon(categoryIcon(c.icon), size: 16, color: Color(c.color)),
                    label: Text(c.name(ar)),
                    selected: _cat == c.id,
                    onSelected: (v) => setState(() => _cat = v ? c.id : null),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Glass(
            child: EmptyState(icon: Icons.event_note_rounded, text: context.t('no_bookings_month')),
          ),
        for (final e in groups.entries) ...[
          SectionTitle(TimeFmt.dateLong(e.key, ar: ar), trailing: Text('${e.value.length}')),
          for (final a in e.value) AppointmentTile(appt: a, category: widget.cats[a.categoryId], now: widget.now, onTap: () => widget.onOpen(a)),
        ],
      ],
    );
  }
}
