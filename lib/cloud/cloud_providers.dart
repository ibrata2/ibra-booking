import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud.dart';

typedef CRow = Map<String, dynamic>;

/// يتغير بعد تسجيل الدخول/الخروج حتى يعاد تحميل بيانات الموظف.
class CloudSession extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final cloudSessionProvider = NotifierProvider<CloudSession, int>(CloudSession.new);

final staffMeProvider = FutureProvider<StaffMe?>((ref) async {
  ref.watch(cloudSessionProvider);
  if (!Cloud.ready) return null;
  return Cloud.me();
});

final conversationsProvider = StreamProvider<List<CRow>>((ref) {
  ref.watch(cloudSessionProvider);
  return Cloud.db.from('conversations').stream(primaryKey: ['id']).order('last_message_at', ascending: false).limit(300);
});

/// الزبائن حسب رقمهم (للأسماء والأرقام بالمحادثات).
final cloudCustomersProvider = StreamProvider<Map<String, CRow>>((ref) {
  ref.watch(cloudSessionProvider);
  return Cloud.db.from('customers').stream(primaryKey: ['id']).map((rows) => {for (final r in rows) r['id'] as String: r});
});

final staffNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.from('staff_members').select('user_id, display_name');
  return {for (final r in rows) r['user_id'] as String: (r['display_name'] as String?) ?? ''};
});

final chatMessagesProvider = StreamProvider.family<List<CRow>, String>((ref, conv) {
  return Cloud.db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', conv).order('id');
});

final cloudPostsProvider = StreamProvider<List<CRow>>((ref) {
  ref.watch(cloudSessionProvider);
  return Cloud.db.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(100);
});

final cloudSettingsProvider = StreamProvider<CRow>((ref) {
  ref.watch(cloudSessionProvider);
  return Cloud.db.from('center_settings').stream(primaryKey: ['id']).eq('id', 1).map((r) => r.isEmpty ? <String, dynamic>{} : r.first);
});

final offersProvider = FutureProvider<List<CRow>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.from('offers').select().order('created_at', ascending: false);
  return List<CRow>.from(rows);
});

final offerStatsProvider = FutureProvider<Map<int, (int, int)>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.rpc('offer_stats');
  return {
    for (final r in (rows as List))
      ((r as Map)['offer_id'] as num).toInt(): (((r['sent'] as num?) ?? 0).toInt(), ((r['used'] as num?) ?? 0).toInt()),
  };
});

final cloudWorksProvider = FutureProvider<List<CRow>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.from('works').select().order('created_at', ascending: false).limit(500);
  return List<CRow>.from(rows);
});

final mallStepsAdminProvider = FutureProvider<List<CRow>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.from('mall_steps').select().order('sort');
  return List<CRow>.from(rows);
});

final staffMembersProvider = FutureProvider<List<CRow>>((ref) async {
  ref.watch(cloudSessionProvider);
  final rows = await Cloud.db.from('staff_members').select().order('created_at');
  return List<CRow>.from(rows);
});

/// مجموع الرسائل غير المقروءة (لشارة القائمة).
final unreadStaffProvider = Provider<int>((ref) {
  if (!Cloud.ready || Cloud.user == null) return 0;
  final list = ref.watch(conversationsProvider).value ?? const [];
  return list.fold<int>(0, (s, r) => s + ((r['unread_staff'] as num?)?.toInt() ?? 0));
});

const kNotifSounds = <String, String>{
  'rs_post': 'منشور جديد ✨',
  'rs_offer': 'عرض 🎁',
  'rs_gift': 'هدية / جرس',
  'rs_msg': 'رسالة',
  'rs_booking': 'حجز',
};

const kWorkCategories = <String, String>{'tattoo': 'تاتو', 'piercing': 'بيرسنك', 'laser': 'ليزر', 'skin': 'بشرة وإبر', 'other': 'أخرى'};

const kNeighborTiers = <String, String>{'building': 'نفس البناية', 'near': 'قريب (أقل من كيلو)', 'area': 'نفس المنطقة'};
