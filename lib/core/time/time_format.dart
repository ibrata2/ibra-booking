/// تنسيق الوقت والتاريخ — نظام 12 ساعة حصراً لكل ما يُعرض للمستخدم.
/// لا يعتمد على أي حزمة، فيعمل في الواجهات والإشعارات والتقارير بنفس الشكل.
class TimeFmt {
  TimeFmt._();

  static const _monthsAr = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];
  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _monthsShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  // DateTime.weekday: 1=الإثنين .. 7=الأحد
  static const _daysAr = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _daysShortAr = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
  static const _daysShortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _2(int v) => v.toString().padLeft(2, '0');

  /// 09:00 صباحاً — 02:30 مساءً — 12:00 ظهراً — 12:00 منتصف الليل
  static String time(DateTime t, {bool ar = true}) {
    final h = t.hour, m = t.minute;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final hm = '${_2(h12)}:${_2(m)}';
    if (h == 0 && m == 0) return ar ? '$hm منتصف الليل' : '$hm Midnight';
    if (h == 12 && m == 0) return ar ? '$hm ظهراً' : '$hm Noon';
    final suffix = h < 12 ? (ar ? 'صباحاً' : 'AM') : (ar ? 'مساءً' : 'PM');
    return '$hm $suffix';
  }

  /// نطاق زمني: 04:00 مساءً - 06:00 مساءً (مع اليوم التالي إن تجاوز منتصف الليل)
  static String range(DateTime s, DateTime e, {bool ar = true}) {
    final crosses = !sameDay(s, e);
    final endTxt = time(e, ar: ar) + (crosses ? (ar ? ' (اليوم التالي)' : ' (next day)') : '');
    return '${time(s, ar: ar)} - $endTxt';
  }

  static String month(int m, {bool ar = true}) => ar ? _monthsAr[m - 1] : _monthsEn[m - 1];
  static String monthShort(int m, {bool ar = true}) => ar ? _monthsAr[m - 1] : _monthsShortEn[m - 1];
  static String weekday(int wd, {bool ar = true}) => ar ? _daysAr[wd - 1] : _daysEn[wd - 1];
  static String weekdayShort(int wd, {bool ar = true}) => ar ? _daysShortAr[wd - 1] : _daysShortEn[wd - 1];

  /// الأربعاء 18 تشرين الثاني 2026
  static String dateLong(DateTime d, {bool ar = true}) => '${weekday(d.weekday, ar: ar)} ${d.day} ${month(d.month, ar: ar)} ${d.year}';

  /// 18 تشرين الثاني 2026
  static String date(DateTime d, {bool ar = true}) => '${d.day} ${month(d.month, ar: ar)} ${d.year}';

  /// 2026/11/18
  static String dateNum(DateTime d) => '${d.year}/${_2(d.month)}/${_2(d.day)}';

  static String monthYear(DateTime d, {bool ar = true}) => '${month(d.month, ar: ar)} ${d.year}';

  /// تاريخ ووقت كامل: الأربعاء 18 تشرين الثاني 2026 - 04:00 مساءً
  static String dateTime(DateTime d, {bool ar = true}) => '${dateLong(d, ar: ar)} - ${time(d, ar: ar)}';

  /// عداد تنازلي: 02:15:09
  static String countdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 99 ? '${h ~/ 24}d ${_2(h % 24)}:${_2(m)}' : '${_2(h)}:${_2(m)}:${_2(s)}';
  }

  /// مدة مقروءة: «ساعة و 15 دقيقة» / «1h 15m»
  static String human(Duration d, {bool ar = true}) {
    if (d.isNegative) d = -d;
    final days = d.inDays, h = d.inHours % 24, m = d.inMinutes % 60;
    final parts = <String>[];
    if (ar) {
      if (days > 0)
        parts.add(
          days == 1
              ? 'يوم'
              : days == 2
              ? 'يومين'
              : '$days أيام',
        );
      if (h > 0)
        parts.add(
          h == 1
              ? 'ساعة'
              : h == 2
              ? 'ساعتين'
              : '$h ساعات',
        );
      if (m > 0 || parts.isEmpty)
        parts.add(
          m == 1
              ? 'دقيقة'
              : m == 2
              ? 'دقيقتين'
              : '$m دقيقة',
        );
      return parts.join(' و ');
    }
    if (days > 0) parts.add('${days}d');
    if (h > 0) parts.add('${h}h');
    if (m > 0 || parts.isEmpty) parts.add('${m}m');
    return parts.join(' ');
  }

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime dayEnd(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  /// بداية الأسبوع حسب الإعداد (6=السبت، 7=الأحد، 1=الإثنين).
  static DateTime weekStart(DateTime d, int firstWeekday) {
    final diff = (d.weekday - firstWeekday + 7) % 7;
    return DateTime(d.year, d.month, d.day - diff);
  }
}

/// تنسيق المبالغ: 25,000 د.ع
class MoneyFmt {
  MoneyFmt._();

  static String number(num v) {
    final neg = v < 0;
    final fixed = v.abs();
    final hasFraction = (fixed - fixed.truncate()).abs() > 0.001;
    final intPart = fixed.truncate().toString();
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    if (hasFraction) buf.write('.${((fixed - fixed.truncate()) * 100).round().toString().padLeft(2, '0')}');
    return '${neg ? '-' : ''}$buf';
  }

  static String format(num v, String symbol) => '${number(v)} $symbol';
}
