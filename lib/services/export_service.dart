import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/files/zip.dart';
import '../core/l10n/tr.dart';
import '../core/time/time_format.dart';
import '../domain/entities/entities.dart';
import '../core/edition.dart';

/// صف في التقرير المالي.
class ReportRow {
  final Appointment appt;
  final String category;
  final double received;
  double get remaining => (appt.fee - received).clamp(0, double.infinity).toDouble();
  const ReportRow(this.appt, this.category, this.received);
}

class ReportSummary {
  final double fees;
  final double received;
  final double remaining;
  final double expenses;
  final int count;
  final int paidCount;
  const ReportSummary({this.fees = 0, this.received = 0, this.remaining = 0, this.expenses = 0, this.count = 0, this.paidCount = 0});
  double get net => received - expenses;
}

/// تصدير التقارير إلى Excel و PDF ومشاركتها.
class ExportService {
  ExportService._();

  static Future<File> _out(String name) async {
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, name));
  }

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}_${n.hour}${n.minute}';
  }

  static Future<File> excel({
    required String title,
    required List<ReportRow> rows,
    required List<Expense> expenses,
    required ReportSummary summary,
    required AppSettings settings,
  }) async {
    final ar = settings.isArabic;
    String t(String k) => Tr.t(k, ar: ar);
    final x = XlsxWriter();
    x.addSheet(t('bookings'), [
      [
        t('date'),
        t('time'),
        t('customer'),
        t('phone'),
        t('event_type'),
        t('place'),
        t('address'),
        t('status'),
        t('fee'),
        t('received'),
        t('remaining'),
      ],
      for (final r in rows)
        [
          TimeFmt.dateNum(r.appt.start),
          TimeFmt.range(r.appt.start, r.appt.end, ar: ar),
          r.appt.customerName,
          r.appt.phone,
          r.category,
          r.appt.placeName,
          r.appt.fullAddress,
          t('st_${r.appt.effectiveStatus(DateTime.now()).name}'),
          r.appt.fee,
          r.received,
          r.remaining,
        ],
    ], rtl: ar);
    x.addSheet(t('expenses'), [
      [t('date'), t('kind'), t('amount'), t('notes')],
      for (final e in expenses) [TimeFmt.dateNum(e.date), t('exp_${e.kind}'), e.amount, e.note],
    ], rtl: ar);
    x.addSheet(t('summary'), [
      [title, ''],
      [t('bookings_count'), summary.count],
      [t('total_fees'), summary.fees],
      [t('received'), summary.received],
      [t('remaining'), summary.remaining],
      [t('expenses'), summary.expenses],
      [t('net'), summary.net],
      [t('currency'), settings.currencyCode],
    ], rtl: ar);
    final f = await _out('IBRA_BOOKING_report_${_stamp()}.xlsx');
    await f.writeAsBytes(x.build(), flush: true);
    return f;
  }

  /// يرسم التقرير بمحرك نصوص Flutter (تشكيل عربي صحيح) ثم يحوله إلى PDF.
  static Future<File> pdf({
    required String title,
    required List<ReportRow> rows,
    required ReportSummary summary,
    required AppSettings settings,
  }) async {
    final ar = settings.isArabic;
    String t(String k) => Tr.t(k, ar: ar);
    const scale = 2.0;
    const pw = 595.28, ph = 841.89;
    final w = (pw * scale).round(), h = (ph * scale).round();
    final dir = ar ? TextDirection.rtl : TextDirection.ltr;
    const margin = 36.0;
    const rowH = 30.0;
    final cols = [t('date'), t('customer'), t('event_type'), t('fee'), t('received'), t('remaining')];
    final colW = [80.0, 140.0, 105.0, 76.0, 76.0, 76.0];
    final money = (num v) => MoneyFmt.number(v);
    final writer = PdfImageWriter();

    final perFirst = ((ph - margin * 2 - 190) / rowH).floor();
    final perNext = ((ph - margin * 2 - 60) / rowH).floor();
    var index = 0;
    var page = 0;
    do {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
      c.scale(scale);
      c.drawRect(const Rect.fromLTWH(0, 0, pw, ph), Paint()..color = const Color(0xFFFFFFFF));
      var y = margin;

      void text(
        String s,
        double x,
        double yy,
        double width, {
        double size = 10,
        FontWeight weight = FontWeight.w400,
        Color color = const Color(0xFF1B1F2E),
        TextAlign align = TextAlign.start,
      }) {
        final tp = TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: size, fontWeight: weight, color: color),
          ),
          textDirection: dir,
          textAlign: align,
          maxLines: 1,
          ellipsis: '…',
        )..layout(minWidth: width, maxWidth: width);
        tp.paint(c, Offset(x, yy));
      }

      double colX(int i) {
        // في RTL يبدأ العمود الأول من اليمين
        var acc = 0.0;
        for (var k = 0; k < i; k++) {
          acc += colW[k];
        }
        return ar ? pw - margin - acc - colW[i] : margin + acc;
      }

      if (page == 0) {
        final header = Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(pw, 0), [const Color(0xFFD62839), const Color(0xFF2F6BFF)]);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(margin, y, pw - margin * 2, 64), const Radius.circular(14)), header);
        text(Edition.nameEn, margin + 16, y + 10, pw - margin * 2 - 32, size: 18, weight: FontWeight.w800, color: const Color(0xFFFFFFFF));
        text(title, margin + 16, y + 36, pw - margin * 2 - 32, size: 11, color: const Color(0xFFFFFFFF));
        y += 80;
        final boxes = [
          [t('bookings_count'), '${summary.count}'],
          [t('total_fees'), money(summary.fees)],
          [t('received'), money(summary.received)],
          [t('remaining'), money(summary.remaining)],
          [t('expenses'), money(summary.expenses)],
          [t('net'), money(summary.net)],
        ];
        final bw = (pw - margin * 2 - 10) / 3;
        for (var i = 0; i < boxes.length; i++) {
          final col = i % 3, row = i ~/ 3;
          final x = ar ? pw - margin - (col + 1) * bw - col * 5 : margin + col * (bw + 5);
          final yy = y + row * 46;
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, yy, bw, 40), const Radius.circular(10)), Paint()..color = const Color(0xFFF1F4FB));
          text(boxes[i][0], x + 10, yy + 5, bw - 20, size: 9, color: const Color(0xFF5B6275));
          text('${boxes[i][1]} ${i == 0 ? '' : settings.currencySymbol}', x + 10, yy + 19, bw - 20, size: 12, weight: FontWeight.w700);
        }
        y += 100;
      }
      // رأس الجدول
      c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(margin, y, pw - margin * 2, rowH - 4), const Radius.circular(8)),
        Paint()..color = const Color(0xFF1B1F2E),
      );
      for (var i = 0; i < cols.length; i++) {
        text(cols[i], colX(i) + 6, y + 7, colW[i] - 12, size: 9.5, weight: FontWeight.w700, color: const Color(0xFFFFFFFF));
      }
      y += rowH;
      final per = page == 0 ? perFirst : perNext;
      for (var n = 0; n < per && index < rows.length; n++, index++) {
        final r = rows[index];
        if (n.isOdd) {
          c.drawRect(Rect.fromLTWH(margin, y - 4, pw - margin * 2, rowH), Paint()..color = const Color(0xFFF7F8FC));
        }
        final vals = [TimeFmt.dateNum(r.appt.start), r.appt.customerName, r.category, money(r.appt.fee), money(r.received), money(r.remaining)];
        for (var i = 0; i < vals.length; i++) {
          text(
            vals[i],
            colX(i) + 6,
            y + 4,
            colW[i] - 12,
            size: 9.5,
            color: i == 5 && r.remaining > 0 ? const Color(0xFFD62839) : const Color(0xFF1B1F2E),
          );
        }
        y += rowH;
      }
      text(
        '${t('page')} ${page + 1} • ${TimeFmt.dateTime(DateTime.now(), ar: ar)} • ${t('dev_credit')}',
        margin,
        ph - margin + 8,
        pw - margin * 2,
        size: 8,
        color: const Color(0xFF8A90A2),
        align: TextAlign.center,
      );

      final picture = rec.endRecording();
      final img = await picture.toImage(w, h);
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      final rgba = bd!.buffer.asUint8List();
      final rgb = Uint8List(w * h * 3);
      for (var i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
        rgb[j] = rgba[i];
        rgb[j + 1] = rgba[i + 1];
        rgb[j + 2] = rgba[i + 2];
      }
      writer.addPage(rgb, w, h, pageW: pw, pageH: ph);
      page++;
    } while (index < rows.length);

    final f = await _out('IBRA_BOOKING_report_${_stamp()}.pdf');
    await f.writeAsBytes(writer.build(), flush: true);
    return f;
  }

  static Future<void> share(File f, {String? text}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: text));
  }

  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
