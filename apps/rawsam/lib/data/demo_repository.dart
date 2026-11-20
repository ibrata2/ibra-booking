import 'dart:async';
import 'dart:io';

import 'models.dart';
import 'repository.dart';

/// وضع العرض: بيانات تجريبية محلية تُستخدم إذا ما ربطنا التطبيق بقاعدة البيانات بعد.
/// تخلي التطبيق يشتغل كامل حتى تشوف كل الأقسام قبل التفعيل.
class DemoCenterRepository implements CenterRepository {
  CustomerProfile _profile = const CustomerProfile();
  final _msgs = <ChatMessage>[];
  final _msgCtrl = StreamController<List<ChatMessage>>.broadcast();
  final _unreadCtrl = StreamController<int>.broadcast();
  final _couponCtrl = StreamController<List<Coupon>>.broadcast();
  int _unread = 1;
  int _nextId = 100;
  late final List<Coupon> _coupons;

  DemoCenterRepository() {
    final now = DateTime.now();
    _msgs.add(
      ChatMessage(
        id: 1,
        sender: 'staff',
        body: 'أهلاً بيك بمركز روسم للتجميل 🌸\nاكتب شنو تحتاج ونرتبلك موعدك.',
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
    );
    _coupons = [
      Coupon(
        id: 1,
        code: 'RSM-7K2QD',
        title: 'هدية الترحيب بالتطبيق',
        discountText: 'خصم 10% على أول خدمة',
        expiresAt: now.add(const Duration(days: 14)),
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  @override
  bool get isDemo => true;

  @override
  Future<void> start() async {}

  @override
  Future<CustomerProfile> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(CustomerProfile p) async => _profile = p;

  @override
  Stream<CenterInfo> centerInfo() => Stream.value(const CenterInfo());

  @override
  Future<List<MallStep>> mallSteps() async => const [
    MallStep(id: 1, sort: 1, text: 'ادخل فرحان مول من الباب الرئيسي على شارع سبع قصور.'),
    MallStep(id: 2, sort: 2, text: 'اصعد بالسلم المتحرك للطابق الأول.'),
    MallStep(id: 3, sort: 3, text: 'لف يمين، المركز ثالث محل — روسم للتجميل. وصلت! 🌸'),
  ];

  @override
  Future<List<ServiceInfo>> services() async => const [
    ServiceInfo(id: 1, name: 'تاتو', durationMin: 120),
    ServiceInfo(id: 2, name: 'بيرسنك', durationMin: 20),
    ServiceInfo(id: 3, name: 'إزالة تاتو بالليزر', durationMin: 30),
    ServiceInfo(id: 4, name: 'إبر نضارة البشرة', durationMin: 30),
  ];

  @override
  Stream<List<Post>> posts() {
    final now = DateTime.now();
    return Stream.value([
      Post(
        id: 3,
        kind: 'offer',
        title: 'عرض نهاية الأسبوع 🎁',
        body: 'خصم 15% على جلسات إزالة التاتو بالليزر لحد يوم الخميس.',
        pinned: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 2,
        url: 'https://www.instagram.com/p/C0000000000/',
        platform: 'instagram',
        title: 'شغل جديد من المركز ✨',
        body: 'هنا يطلع منشور الانستغرام نفسه داخل التطبيق.',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Post(
        id: 1,
        title: 'أوقات الدوام',
        body: 'نستقبلكم من السبت للخميس، 10 الصبح لحد 9 بالليل.',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  @override
  Future<List<WorkItem>> works() async => const [];

  @override
  Stream<List<ChatMessage>> messages() async* {
    yield List.of(_msgs);
    yield* _msgCtrl.stream;
  }

  @override
  Stream<int> unreadCount() async* {
    yield _unread;
    yield* _unreadCtrl.stream;
  }

  void _push(ChatMessage m) {
    _msgs.add(m);
    _msgCtrl.add(List.of(_msgs));
  }

  @override
  Future<void> sendText(String text) async {
    _push(ChatMessage(id: _nextId++, sender: 'customer', body: text, createdAt: DateTime.now()));
    Timer(const Duration(seconds: 2), () {
      _push(
        ChatMessage(
          id: _nextId++,
          sender: 'staff',
          body: 'هذا وضع العرض 👋 — بعد ربط التطبيق، موظفين المركز يردون عليك هنا مباشرة.',
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  @override
  Future<void> sendImage(File file) async {
    _push(ChatMessage(id: _nextId++, sender: 'customer', kind: 'text', body: '📷 (صورة — تنرسل بعد ربط التطبيق)', createdAt: DateTime.now()));
  }

  @override
  Future<void> markRead() async {
    _unread = 0;
    _unreadCtrl.add(0);
  }

  @override
  Future<void> report(String reason) async {}

  @override
  Stream<List<Coupon>> coupons() async* {
    yield List.of(_coupons);
    yield* _couponCtrl.stream;
  }

  @override
  Stream<List<Booking>> bookings() {
    final start = DateTime.now().add(const Duration(days: 2));
    final s = DateTime(start.year, start.month, start.day, 16);
    return Stream.value([
      Booking(id: 'demo', serviceName: 'تاتو', staffName: 'روسم للتجميل', start: s, end: s.add(const Duration(hours: 2))),
    ]);
  }

  @override
  Future<Coupon?> claimProximity() async {
    final c = Coupon(
      id: _nextId++,
      code: 'RSM-NEAR${_nextId % 10}',
      title: 'مدام صرت قريب… مر علينا 🌸',
      discountText: 'خصم 10%',
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      createdAt: DateTime.now(),
    );
    _coupons.insert(0, c);
    _couponCtrl.add(List.of(_coupons));
    return c;
  }

  @override
  Future<void> registerPushToken(String token, String platform) async {}

  @override
  Future<void> deleteAccount() async {
    _profile = const CustomerProfile();
    _msgs.clear();
  }
}
