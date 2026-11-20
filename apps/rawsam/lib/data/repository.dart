import 'dart:io';

import 'models.dart';

/// كل ما يحتاجه تطبيق الزبون من المركز. نسختان: سحابية (Supabase) وتجريبية (وضع العرض).
abstract class CenterRepository {
  bool get isDemo;

  /// تسجيل دخول تلقائي (حساب مجهول) — لا يحتاج كلمة سر.
  Future<void> start();

  Future<CustomerProfile> loadProfile();
  Future<void> saveProfile(CustomerProfile p);

  Stream<CenterInfo> centerInfo();
  Future<List<MallStep>> mallSteps();
  Future<List<ServiceInfo>> services();

  Stream<List<Post>> posts();
  Future<List<WorkItem>> works();

  Stream<List<ChatMessage>> messages();
  Stream<int> unreadCount();
  Future<void> sendText(String text);
  Future<void> sendImage(File file);
  Future<void> markRead();
  Future<void> report(String reason);

  Stream<List<Coupon>> coupons();
  Stream<List<Booking>> bookings();

  /// عرض القرب: يُطلب بعد دخول دائرة المركز. يعيد الكوبون الجديد أو null.
  Future<Coupon?> claimProximity();

  Future<void> registerPushToken(String token, String platform);
  Future<void> deleteAccount();
}
