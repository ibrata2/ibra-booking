import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'notifications.dart';
import 'push.dart';

/// إشعارات من داخل التطبيق: لما يوصل شي جديد (هدية، منشور، رد من المركز، حجز) والتطبيق شغال أو بالخلفية،
/// يطلع إشعار فوق بنفس الصوت المميز. يشتغل حتى بالآيفون بدون مفتاح APNs.
/// إذا الجهاز مسجل بإشعارات Firebase، نخليها هي ترسل حتى ما يتكرر الإشعار.
class LiveAlerts {
  LiveAlerts._();
  static SharedPreferences? _p;

  static Future<SharedPreferences> _prefs() async => _p ??= await SharedPreferences.getInstance();

  static bool get _enabled => !PushService.hasToken;

  /// يرجع العناصر الجديدة اللي ما شفناها قبل. أول مرة يحفظ الموجود بدون إشعار.
  static Future<List<T>> _fresh<T>(String key, List<T> items, String Function(T) id) async {
    final p = await _prefs();
    final seen = p.getStringList(key);
    final ids = items.map(id).toList();
    await p.setStringList(key, ids.take(300).toList());
    if (seen == null) return const [];
    final s = seen.toSet();
    return items.where((e) => !s.contains(id(e))).toList();
  }

  static Future<void> coupons(List<Coupon> list) async {
    final fresh = await _fresh('seen_coupons', list, (c) => '${c.id}');
    if (!_enabled) return;
    for (final c in fresh.where((c) => c.usable).take(3)) {
      await LocalNotifications.show(
        id: 20000 + c.id % 10000,
        title: 'وصلتك هدية من روسم للتجميل 🎁',
        body: '${c.title}${c.discountText.isEmpty ? '' : ' — ${c.discountText}'}',
        sound: AppSounds.gift,
        tap: NotificationTap('coupon', c.code),
      );
    }
  }

  static Future<void> posts(List<Post> list) async {
    final fresh = await _fresh('seen_posts', list, (p) => '${p.id}');
    if (!_enabled) return;
    for (final p in fresh.where((p) => p.notify).take(2)) {
      await LocalNotifications.show(
        id: 30000 + p.id % 10000,
        title: p.title.isNotEmpty ? p.title : (p.isOffer ? 'عرض جديد من روسم للتجميل 🎁' : 'روسم للتجميل نشرت شي جديد ✨'),
        body: p.body.isNotEmpty ? p.body : 'اضغط حتى تشوف المنشور',
        sound: p.isOffer ? AppSounds.offer : AppSounds.post,
        tap: NotificationTap('post', '${p.id}'),
      );
    }
  }

  static Future<void> messages(List<ChatMessage> list, {required bool chatOpen}) async {
    final fresh = await _fresh('seen_msgs', list.reversed.take(100).toList(), (m) => '${m.id}');
    if (!_enabled || chatOpen) return;
    for (final m in fresh.where((m) => !m.mine).take(2)) {
      await LocalNotifications.show(
        id: 40000 + m.id % 10000,
        title: m.displayName == null || m.displayName!.isEmpty ? 'روسم للتجميل' : 'روسم للتجميل · ${m.displayName}',
        body: m.kind == 'image' ? '📷 صورة' : (m.kind == 'booking' ? '📅 تم تثبيت موعدك' : m.body),
        sound: m.kind == 'booking' ? AppSounds.booking : AppSounds.msg,
        tap: const NotificationTap('chat'),
      );
    }
  }
}
