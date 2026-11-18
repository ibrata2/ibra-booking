import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../services/export_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';

enum Period { day, week, month, year, custom }

final _expensesRangeProvider = FutureProvider.family<List<Expense>, (int, int)>((ref, r) async {
  ref.watch(dataVersionProvider);
  return ref.watch(financeRepoProvider).expensesBetween(DateTime.fromMillisecondsSinceEpoch(r.$1), DateTime.fromMillisecondsSinceEpoch(r.$2));
});

/// الحسابات المالية: الإيرادات اليومية/الأسبوعية/الشهرية/السنوية، المدفوع وغير المدفوع، مصروفات التنقل، رسوم بيانية وتصدير.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});
  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  Period _period = Period.month;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _custom;
  int _tab = 0;
  bool _exporting = false;

  (DateTime, DateTime) _range(int weekStart) {
    final a = _anchor;
    return switch (_period) {
      Period.day => (TimeFmt.dayStart(a), TimeFmt.dayEnd(a)),
      Period.week => () {
        final s = TimeFmt.weekStart(a, weekStart);
        return (s, s.add(const Duration(days: 7)));
      }(),
      Period.month => (DateTime(a.year, a.month), DateTime(a.year, a.month + 1)),
      Period.year => (DateTime(a.year), DateTime(a.year + 1)),
      Period.custom => (TimeFmt.dayStart(_custom?.start ?? a), TimeFmt.dayEnd(_custom?.end ?? a)),
    };
  }

  void _shift(int d) => setState(() {
    _anchor = switch (_period) {
      Period.day => DateTime(_anchor.year, _anchor.month, _anchor.day + d),
      Period.week => DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * d),
      Period.month => DateTime(_anchor.year, _anchor.month + d, 1),
      Period.year => DateTime(_anchor.year + d, 1, 1),
      Period.custom => _anchor,
    };
  });

  String _label(bool ar, (DateTime, DateTime) r) => switch (_period) {
    Period.day => TimeFmt.dateLong(r.$1, ar: ar),
    Period.month => TimeFmt.monthYear(r.$1, ar: ar),
    Period.year => '${r.$1.year}',
    _ => '${TimeFmt.dateNum(r.$1)} - ${TimeFmt.dateNum(r.$2.subtract(const Duration(days: 1)))}',
  };

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final settings = ref.watch(settingsProvider);
    final sym = settings.currencySymbol;
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    final paid = ref.watch(paidTotalsProvider).value ?? const <int, double>{};
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final r = _range(settings.weekStart);
    final expenses = ref.watch(_expensesRangeProvider((r.$1.millisecondsSinceEpoch, r.$2.millisecondsSinceEpoch))).value ?? const <Expense>[];
    final now = DateTime.now();

    final inPeriod = appts.where((a) => a.status != BookingStatus.cancelled && !a.start.isBefore(r.$1) && a.start.isBefore(r.$2)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final rows = [for (final a in inPeriod) ReportRow(a, cats.where((c) => c.id == a.categoryId).firstOrNull?.name(ar) ?? '', receivedFor(a, paid))];
    final summary = ReportSummary(
      count: rows.length,
      fees: rows.fold(0.0, (s, x) => s + x.appt.fee),
      received: rows.fold(0.0, (s, x) => s + x.received),
      remaining: rows.fold(0.0, (s, x) => s + x.remaining),
      expenses: expenses.fold(0.0, (s, e) => s + e.amount),
      paidCount: rows.where((x) => x.remaining <= 0).length,
    );
    final paidRows = rows.where((x) => x.remaining <= 0).toList();
    final unpaidRows = rows.where((x) => x.remaining > 0).toList();

    // بيانات الرسم البياني
    final buckets = <String>[];
    final values = <double>[];
    if (_period == Period.year) {
      for (var m = 1; m <= 12; m++) {
        buckets.add(TimeFmt.monthShort(m, ar: ar));
        values.add(rows.where((x) => x.appt.start.month == m).fold(0.0, (s, x) => s + x.appt.fee));
      }
    } else {
      final days = r.$2.difference(r.$1).inDays.clamp(1, 62);
      for (var i = 0; i < days; i++) {
        final d = DateTime(r.$1.year, r.$1.month, r.$1.day + i);
        buckets.add('${d.day}');
        values.add(rows.where((x) => TimeFmt.sameDay(x.appt.start, d)).fold(0.0, (s, x) => s + x.appt.fee));
      }
    }
    final title = '${context.t('finance_report')} — ${_label(ar, r)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('finance')),
        actions: [IconButton(tooltip: context.t('add_expense'), onPressed: () => _addExpense(context), icon: const Icon(Icons.add_card_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<Period>(
              showSelectedIcon: false,
              segments: [for (final p in Period.values) ButtonSegment(value: p, label: Text(context.t('period_${p.name}')))],
              selected: {_period},
              onSelectionChanged: (s) async {
                if (s.first == Period.custom) {
                  final res = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDateRange: _custom ?? DateTimeRange(start: DateTime(now.year, now.month), end: now),
                  );
                  if (res == null) return;
                  setState(() {
                    _custom = res;
                    _period = Period.custom;
                  });
                } else {
                  setState(() => _period = s.first);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_period != Period.custom) IconButton(onPressed: () => _shift(ar ? 1 : -1), icon: const Icon(Icons.chevron_right_rounded)),
              Expanded(
                child: Text(
                  _label(ar, r),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (_period != Period.custom) IconButton(onPressed: () => _shift(ar ? -1 : 1), icon: const Icon(Icons.chevron_left_rounded)),
            ],
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.1,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _Box(label: context.t('total_fees'), value: MoneyFmt.format(summary.fees, sym), color: Brand.blue),
              _Box(label: context.t('received'), value: MoneyFmt.format(summary.received, sym), color: const Color(0xFF00C853)),
              _Box(label: context.t('remaining'), value: MoneyFmt.format(summary.remaining, sym), color: Colors.orange),
              _Box(label: context.t('expenses'), value: MoneyFmt.format(summary.expenses, sym), color: Brand.red),
              _Box(label: context.t('net'), value: MoneyFmt.format(summary.net, sym), color: const Color(0xFF7C4DFF)),
              _Box(
                label: context.t('paid_unpaid'),
                value: '${summary.paidCount} / ${summary.count - summary.paidCount}',
                color: const Color(0xFF00ACC1),
              ),
            ],
          ),
          SectionTitle(context.t('revenue_chart')),
          Glass(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: SizedBox(
              height: 190,
              child: _BarChart(labels: buckets, values: values, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _exporting ? null : () => _export(pdf: true, title: title, rows: rows, expenses: expenses, summary: summary),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _exporting ? null : () => _export(pdf: false, title: title, rows: rows, expenses: expenses, summary: summary),
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Excel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text('${context.t('unpaid')} (${unpaidRows.length})')),
              ButtonSegment(value: 1, label: Text('${context.t('paid')} (${paidRows.length})')),
              ButtonSegment(value: 2, label: Text('${context.t('expenses')} (${expenses.length})')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 10),
          if (_tab < 2)
            for (final x in (_tab == 0 ? unpaidRows : paidRows))
              AppointmentTile(
                appt: x.appt,
                category: cats.where((c) => c.id == x.appt.categoryId).firstOrNull,
                now: now,
                showDate: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: x.appt.id!))),
                trailing: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(MoneyFmt.number(x.appt.fee), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (x.remaining > 0)
                        Text(
                          '-${MoneyFmt.number(x.remaining)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              )
          else
            for (final e in expenses)
              Glass(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(e.kind == 'travel' ? Icons.local_taxi_rounded : Icons.receipt_long_rounded, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.t('exp_${e.kind}'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${TimeFmt.date(e.date, ar: ar)}${e.note.isEmpty ? '' : ' • ${e.note}'}',
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Text(MoneyFmt.format(e.amount, sym), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () async {
                        await ref.read(financeRepoProvider).deleteExpense(e.id!);
                        ref.read(dataVersionProvider.notifier).bump();
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
          if ((_tab == 0 && unpaidRows.isEmpty) || (_tab == 1 && paidRows.isEmpty) || (_tab == 2 && expenses.isEmpty))
            EmptyState(icon: Icons.inbox_rounded, text: context.t('none')),
        ],
      ),
    );
  }

  Future<void> _export({
    required bool pdf,
    required String title,
    required List<ReportRow> rows,
    required List<Expense> expenses,
    required ReportSummary summary,
  }) async {
    setState(() => _exporting = true);
    try {
      final s = ref.read(settingsProvider);
      final f = pdf
          ? await ExportService.pdf(title: title, rows: rows, summary: summary, settings: s)
          : await ExportService.excel(title: title, rows: rows, expenses: expenses, summary: summary, settings: s);
      await ExportService.share(f, text: title);
    } catch (e) {
      if (mounted) toast(context, '${context.t('error')}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _addExpense(BuildContext context) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var kind = 'travel';
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(c.t('add_expense')),
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
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'travel', label: Text(c.t('exp_travel'))),
                  ButtonSegment(value: 'other', label: Text(c.t('exp_other'))),
                ],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(TimeFmt.date(date, ar: c.ar)),
                onTap: () async {
                  final d = await showDatePicker(context: c, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) set(() => date = d);
                },
              ),
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
      await ref.read(financeRepoProvider).addExpense(Expense(kind: kind, amount: v, date: date, note: note.text.trim()));
      ref.read(dataVersionProvider.notifier).bump();
    }
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Glass(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tint: color.withValues(alpha: 0.12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600),
        ),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    ),
  );
}

/// رسم بياني بالأعمدة (بدون مكتبات خارجية).
class _BarChart extends StatelessWidget {
  const _BarChart({required this.labels, required this.values, required this.color});
  final List<String> labels;
  final List<double> values;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: _BarPainter(labels, values, color, Theme.of(context).hintColor, Directionality.of(context)));
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.labels, this.values, this.color, this.textColor, this.dir);
  final List<String> labels;
  final List<double> values;
  final Color color;
  final Color textColor;
  final TextDirection dir;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(0, math.max);
    const bottom = 18.0, top = 16.0;
    final h = size.height - bottom - top;
    final n = values.length;
    final slot = size.width / n;
    final bw = math.max(2.0, slot * 0.62);
    final grid = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = top + h * g / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final step = n > 16 ? (n / 8).ceil() : 1;
    for (var i = 0; i < n; i++) {
      final idx = dir == TextDirection.rtl ? n - 1 - i : i;
      final v = values[idx];
      final bh = maxV == 0 ? 0.0 : h * v / maxV;
      final x = i * slot + (slot - bw) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, top + h - bh, bw, bh), const Radius.circular(4));
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: 0.35)],
          ).createShader(rect.outerRect),
      );
      if (idx % step == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[idx],
            style: TextStyle(fontSize: 9.5, color: textColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(i * slot + slot / 2 - tp.width / 2, size.height - bottom + 3));
      }
    }
    if (maxV > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: MoneyFmt.number(maxV),
          style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(2, 0));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values || old.color != color;
}
