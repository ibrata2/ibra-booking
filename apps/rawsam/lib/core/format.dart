/// تنسيق التاريخ والوقت بالعربي بنظام 12 ساعة (مثل باقي تطبيقات IBRA).
class Fmt {
  Fmt._();
  static const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _months = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];

  static String time(DateTime t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final p = h == 0
        ? 'منتصف الليل'
        : h < 12
        ? 'صباحاً'
        : h == 12
        ? 'ظهراً'
        : 'مساءً';
    return '$h12:$m $p';
  }

  static String day(DateTime t) => '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}';
  static String dateTime(DateTime t) => '${day(t)} — ${time(t)}';

  static String relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'هسه';
    if (d.inMinutes < 60) return 'قبل ${d.inMinutes} دقيقة';
    if (d.inHours < 24) return 'قبل ${d.inHours} ساعة';
    if (d.inDays == 1) return 'أمس';
    if (d.inDays < 7) return 'قبل ${d.inDays} أيام';
    return day(t);
  }

  static String money(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${b.toString()} د.ع';
  }
}
