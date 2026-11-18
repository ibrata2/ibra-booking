import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// كاتب/قارئ ZIP خفيف بدون حزم خارجية (للنسخ الاحتياطي وملفات Excel).
class ZipEntry {
  final String name;
  final Uint8List data;
  ZipEntry(this.name, List<int> bytes) : data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  factory ZipEntry.text(String name, String text) => ZipEntry(name, utf8.encode(text));
}

class Crc32 {
  Crc32._();
  static final List<int> _table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int of(List<int> data) {
    var c = 0xFFFFFFFF;
    for (final b in data) {
      c = _table[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

class _Out {
  final BytesBuilder b = BytesBuilder(copy: false);
  void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void bytes(List<int> v) => b.add(v);
  int get length => b.length;
}

class ZipCodec {
  ZipCodec._();

  /// [compress]: ضغط Deflate (افتراضي)، أو تخزين بدون ضغط.
  static Uint8List encode(List<ZipEntry> entries, {bool compress = true}) {
    final out = _Out();
    final central = _Out();
    const dosTime = 0;
    const dosDate = (2026 - 1980) << 9 | 1 << 5 | 1;
    for (final e in entries) {
      final name = utf8.encode(e.name);
      final crc = Crc32.of(e.data);
      var method = 0;
      List<int> payload = e.data;
      if (compress && e.data.length > 64) {
        final z = ZLibEncoder(raw: true, level: 6).convert(e.data);
        if (z.length < e.data.length) {
          payload = z;
          method = 8;
        }
      }
      final offset = out.length;
      out
        ..u32(0x04034b50)
        ..u16(20)
        ..u16(0x0800) // UTF-8 names
        ..u16(method)
        ..u16(dosTime)
        ..u16(dosDate)
        ..u32(crc)
        ..u32(payload.length)
        ..u32(e.data.length)
        ..u16(name.length)
        ..u16(0)
        ..bytes(name)
        ..bytes(payload);
      central
        ..u32(0x02014b50)
        ..u16(20)
        ..u16(20)
        ..u16(0x0800)
        ..u16(method)
        ..u16(dosTime)
        ..u16(dosDate)
        ..u32(crc)
        ..u32(payload.length)
        ..u32(e.data.length)
        ..u16(name.length)
        ..u16(0)
        ..u16(0)
        ..u16(0)
        ..u16(0)
        ..u32(0)
        ..u32(offset)
        ..bytes(name);
    }
    final cdOffset = out.length;
    final cd = central.b.takeBytes();
    out
      ..bytes(cd)
      ..u32(0x06054b50)
      ..u16(0)
      ..u16(0)
      ..u16(entries.length)
      ..u16(entries.length)
      ..u32(cd.length)
      ..u32(cdOffset)
      ..u16(0);
    return out.b.takeBytes();
  }

  static List<ZipEntry> decode(Uint8List data) {
    final bd = ByteData.sublistView(data);
    int u16(int o) => bd.getUint16(o, Endian.little);
    int u32(int o) => bd.getUint32(o, Endian.little);
    var eocd = -1;
    for (var i = data.length - 22; i >= 0 && i >= data.length - 65557; i--) {
      if (u32(i) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw const FormatException('ليس ملف ZIP صالح');
    final count = u16(eocd + 10);
    var p = u32(eocd + 16);
    final out = <ZipEntry>[];
    for (var n = 0; n < count; n++) {
      if (u32(p) != 0x02014b50) throw const FormatException('فهرس ZIP تالف');
      final method = u16(p + 10);
      final csize = u32(p + 20);
      final nameLen = u16(p + 28), extraLen = u16(p + 30), commentLen = u16(p + 32);
      final localOff = u32(p + 42);
      final name = utf8.decode(data.sublist(p + 46, p + 46 + nameLen), allowMalformed: true);
      p += 46 + nameLen + extraLen + commentLen;
      final lNameLen = u16(localOff + 26), lExtraLen = u16(localOff + 28);
      final start = localOff + 30 + lNameLen + lExtraLen;
      final raw = data.sublist(start, start + csize);
      if (name.endsWith('/')) continue;
      final bytes = switch (method) {
        0 => raw,
        8 => ZLibDecoder(raw: true).convert(raw),
        _ => throw FormatException('طريقة ضغط غير مدعومة: $method'),
      };
      out.add(ZipEntry(name, bytes));
    }
    return out;
  }
}

/// كاتب Excel (.xlsx) حقيقي بأقل حجم ممكن، يدعم النص العربي و RTL.
class XlsxWriter {
  final List<_Sheet> _sheets = [];

  void addSheet(String name, List<List<Object?>> rows, {bool rtl = true}) => _sheets.add(_Sheet(name, rows, rtl));

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String _col(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  Uint8List build() {
    final entries = <ZipEntry>[];
    final sheetsXml = StringBuffer();
    final relsXml = StringBuffer();
    final overrides = StringBuffer();
    for (var i = 0; i < _sheets.length; i++) {
      final s = _sheets[i];
      final rows = StringBuffer();
      for (var r = 0; r < s.rows.length; r++) {
        rows.write('<row r="${r + 1}">');
        final row = s.rows[r];
        for (var c = 0; c < row.length; c++) {
          final v = row[c];
          final ref = '${_col(c)}${r + 1}';
          final style = r == 0 ? ' s="1"' : '';
          if (v == null) continue;
          if (v is num) {
            rows.write('<c r="$ref"$style><v>$v</v></c>');
          } else {
            rows.write('<c r="$ref" t="inlineStr"$style><is><t xml:space="preserve">${_esc(v.toString())}</t></is></c>');
          }
        }
        rows.write('</row>');
      }
      final maxCols = s.rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
      final cols = StringBuffer('<cols>');
      for (var c = 0; c < maxCols; c++) {
        cols.write('<col min="${c + 1}" max="${c + 1}" width="22" customWidth="1"/>');
      }
      cols.write('</cols>');
      entries.add(
        ZipEntry.text(
          'xl/worksheets/sheet${i + 1}.xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
              '<sheetViews><sheetView workbookViewId="0"${s.rtl ? ' rightToLeft="1"' : ''}/></sheetViews>'
              '${maxCols > 0 ? cols : ''}<sheetData>$rows</sheetData></worksheet>',
        ),
      );
      sheetsXml.write('<sheet name="${_esc(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>');
      relsXml.write(
        '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>',
      );
      overrides.write(
        '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    final n = _sheets.length;
    relsXml.write(
      '<Relationship Id="rId${n + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    );
    entries.addAll([
      ZipEntry.text(
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            '$overrides</Types>',
      ),
      ZipEntry.text(
        '_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      ),
      ZipEntry.text(
        'xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>$sheetsXml</sheets></workbook>',
      ),
      ZipEntry.text(
        'xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">$relsXml</Relationships>',
      ),
      ZipEntry.text(
        'xl/styles.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<fonts count="2"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font></fonts>'
            '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
            '<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>'
            '<cellXfs count="2"><xf fontId="0"/><xf fontId="1" applyFont="1"/></cellXfs></styleSheet>',
      ),
    ]);
    return ZipCodec.encode(entries);
  }
}

class _Sheet {
  final String name;
  final List<List<Object?>> rows;
  final bool rtl;
  _Sheet(this.name, this.rows, this.rtl);
}

/// يكتب PDF من صور صفحات (RGB خام) — يحافظ على تشكيل العربي تماماً لأنه يرسم بمحرك Flutter.
class PdfImageWriter {
  final List<_PdfPage> _pages = [];

  /// [rgb] بايتات RGB خام بعرض [w] وارتفاع [h]. [pageW]/[pageH] بالنقاط (A4 = 595x842).
  void addPage(Uint8List rgb, int w, int h, {double pageW = 595.28, double pageH = 841.89}) => _pages.add(_PdfPage(rgb, w, h, pageW, pageH));

  Uint8List build() {
    final out = BytesBuilder(copy: false);
    final offsets = <int>[];
    void obj(String s) {
      offsets.add(out.length);
      out.add(latin1.encode(s));
    }

    void objBytes(String head, List<int> stream, String tail) {
      offsets.add(out.length);
      out.add(latin1.encode(head));
      out.add(stream);
      out.add(latin1.encode(tail));
    }

    out.add(latin1.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));
    final n = _pages.length;
    // 1: catalog, 2: pages, then per page: page, content, image
    final kids = List.generate(n, (i) => '${3 + i * 3} 0 R').join(' ');
    obj('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
    obj('2 0 obj\n<< /Type /Pages /Kids [$kids] /Count $n >>\nendobj\n');
    for (var i = 0; i < n; i++) {
      final p = _pages[i];
      final pageId = 3 + i * 3, contentId = pageId + 1, imgId = pageId + 2;
      obj(
        '$pageId 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${p.pw.toStringAsFixed(2)} ${p.ph.toStringAsFixed(2)}] '
        '/Resources << /XObject << /Im$i $imgId 0 R >> >> /Contents $contentId 0 R >>\nendobj\n',
      );
      final content = latin1.encode('q ${p.pw.toStringAsFixed(2)} 0 0 ${p.ph.toStringAsFixed(2)} 0 0 cm /Im$i Do Q\n');
      objBytes('$contentId 0 obj\n<< /Length ${content.length} >>\nstream\n', content, '\nendstream\nendobj\n');
      final z = ZLibEncoder(level: 6).convert(p.rgb);
      objBytes(
        '$imgId 0 obj\n<< /Type /XObject /Subtype /Image /Width ${p.w} /Height ${p.h} /ColorSpace /DeviceRGB '
            '/BitsPerComponent 8 /Filter /FlateDecode /Length ${z.length} >>\nstream\n',
        z,
        '\nendstream\nendobj\n',
      );
    }
    final xref = out.length;
    final sb = StringBuffer('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      sb.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    sb.write('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    out.add(latin1.encode(sb.toString()));
    return out.takeBytes();
  }
}

class _PdfPage {
  final Uint8List rgb;
  final int w, h;
  final double pw, ph;
  _PdfPage(this.rgb, this.w, this.h, this.pw, this.ph);
}
