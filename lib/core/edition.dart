/// نسخة التطبيق تُحدد وقت البناء:
///   flutter build apk --dart-define=EDITION=general
///
/// - events  : «حجوزات IBRA» — للعاملين في الفواتح ومجالس العزاء والمواليد والأفراح (الملا والقارئ الحسيني).
/// - general : «الحجوزات IBRA» — نسخة عامة لأي شخص لديه عمل ومواعيد.
class Edition {
  Edition._();

  static const String id = String.fromEnvironment('EDITION', defaultValue: 'events');
  static const bool isGeneral = id == 'general';

  static const String nameAr = isGeneral ? 'الحجوزات IBRA' : 'حجوزات IBRA';
  static const String nameEn = isGeneral ? 'IBRA Bookings' : 'IBRA BOOKING';
  static const String logo = isGeneral ? 'assets/images/logo_general.png' : 'assets/images/logo.png';
  static String name(bool ar) => ar ? nameAr : nameEn;
}
