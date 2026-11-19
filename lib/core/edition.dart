/// نسخة التطبيق تُحدد وقت البناء:
///   flutter build apk --dart-define=EDITION=general
///
/// - events  : «حجوزات IBRA» — للعاملين في الفواتح ومجالس العزاء والمواليد والأفراح (الملا والقارئ الحسيني).
/// - general : «الحجوزات IBRA» — نسخة عامة لأي شخص لديه عمل ومواعيد.
/// - center  : «مواعيد المركز IBRA» — مثل Setmore: مراكز التجميل والعيادات بموظفين وخدمات وساعات دوام.
class Edition {
  Edition._();

  static const String id = String.fromEnvironment('EDITION', defaultValue: 'events');
  static const bool isGeneral = id == 'general';
  static const bool isCenter = id == 'center';

  /// النسخ العامة (general + center) تستخدم مصطلحات «العملاء» و«المواعيد».
  static const bool isBusiness = isGeneral || isCenter;

  static const String nameAr = isCenter ? 'مواعيد المركز IBRA' : (isGeneral ? 'الحجوزات IBRA' : 'حجوزات IBRA');
  static const String nameEn = isCenter ? 'IBRA Center' : (isGeneral ? 'IBRA Bookings' : 'IBRA BOOKING');
  static const String logo = isCenter ? 'assets/images/logo_center.png' : (isGeneral ? 'assets/images/logo_general.png' : 'assets/images/logo.png');
  static String name(bool ar) => ar ? nameAr : nameEn;
}
