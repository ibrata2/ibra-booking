import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repository.dart';

class SupabaseCenterRepository implements CenterRepository {
  SupabaseCenterRepository({required this.platform, required this.build});
  final String platform;
  final int build;

  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;
  String? _conversationId;

  @override
  bool get isDemo => false;

  @override
  Future<void> start() async {
    if (_db.auth.currentUser == null) {
      await _db.auth.signInAnonymously();
    }
    await _ensureConversation();
  }

  Future<String?> _ensureConversation({String name = '', String phone = ''}) async {
    try {
      final id = await _db.rpc('upsert_customer', params: {'p_name': name, 'p_phone': phone, 'p_platform': platform, 'p_build': build});
      _conversationId = id as String?;
    } catch (_) {}
    return _conversationId;
  }

  @override
  Future<CustomerProfile> loadProfile() async {
    final row = await _db.from('customers').select().eq('id', _uid).maybeSingle();
    return row == null ? const CustomerProfile() : CustomerProfile.fromJson(row);
  }

  @override
  Future<void> saveProfile(CustomerProfile p) async {
    await _ensureConversation(name: p.name.trim(), phone: p.phone.trim());
    await _db
        .from('customers')
        .update({
          'name': p.name.trim(),
          'phone': p.phone.trim(),
          'neighbor_tier': p.neighborTier,
          'proximity_on': p.proximityOn,
          'promo_opt_in': p.promoOptIn,
        })
        .eq('id', _uid);
  }

  @override
  Stream<CenterInfo> centerInfo() => _db
      .from('center_settings')
      .stream(primaryKey: ['id'])
      .eq('id', 1)
      .map((rows) => rows.isEmpty ? const CenterInfo() : CenterInfo.fromJson(rows.first));

  @override
  Future<List<MallStep>> mallSteps() async {
    final rows = await _db.from('mall_steps').select().order('sort');
    return [for (final r in rows) MallStep.fromJson(r)];
  }

  @override
  Future<List<ServiceInfo>> services() async {
    final rows = await _db.from('public_services').select().eq('active', true).order('sort');
    return [for (final r in rows) ServiceInfo.fromJson(r)];
  }

  @override
  Stream<List<Post>> posts() => _db
      .from('posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(80)
      .map((rows) {
        final list = [for (final r in rows) Post.fromJson(r)]..removeWhere((p) => p.expired);
        list.sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.createdAt.compareTo(a.createdAt));
        return list;
      });

  @override
  Future<List<WorkItem>> works() async {
    final rows = await _db.from('works').select().order('sort').order('created_at', ascending: false).limit(300);
    return [for (final r in rows) WorkItem.fromJson(r)];
  }

  Future<String> _conv() async => _conversationId ?? (await _ensureConversation()) ?? (throw StateError('no conversation'));

  @override
  Stream<List<ChatMessage>> messages() async* {
    final conv = await _conv();
    yield* _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conv)
        .order('id')
        .map((rows) => [for (final r in rows) ChatMessage.fromJson(r)]);
  }

  @override
  Stream<int> unreadCount() async* {
    yield* _db
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('customer_id', _uid)
        .map((rows) => rows.isEmpty ? 0 : ((rows.first['unread_customer'] as num?)?.toInt() ?? 0));
  }

  @override
  Future<void> sendText(String text) async {
    final conv = await _conv();
    await _db.from('messages').insert({'conversation_id': conv, 'sender': 'customer', 'kind': 'text', 'body': text.trim()});
  }

  @override
  Future<void> sendImage(File file) async {
    final conv = await _conv();
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.${ext.length > 4 ? 'jpg' : ext}';
    await _db.storage.from('chat').upload(path, file);
    final url = _db.storage.from('chat').getPublicUrl(path);
    await _db.from('messages').insert({'conversation_id': conv, 'sender': 'customer', 'kind': 'image', 'image_url': url});
  }

  @override
  Future<void> markRead() async {
    try {
      await _db.rpc('mark_read_customer');
    } catch (_) {}
  }

  @override
  Future<void> report(String reason) async {
    final conv = await _conv();
    await _db.from('reports').insert({'conversation_id': conv, 'reporter': _uid, 'reason': reason});
  }

  @override
  Stream<List<Coupon>> coupons() => _db
      .from('coupons')
      .stream(primaryKey: ['id'])
      .eq('customer_id', _uid)
      .order('created_at', ascending: false)
      .map((rows) => [for (final r in rows) Coupon.fromJson(r)]);

  @override
  Stream<List<Booking>> bookings() => _db
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('customer_id', _uid)
      .order('start_at', ascending: false)
      .map((rows) => [for (final r in rows) Booking.fromJson(r)]);

  @override
  Future<Coupon?> claimProximity() async {
    final rows = await _db.rpc('claim_proximity_offer');
    if (rows is List && rows.isNotEmpty) return Coupon.fromJson(Map<String, dynamic>.from(rows.first as Map));
    return null;
  }

  @override
  Future<void> registerPushToken(String token, String platform) async {
    try {
      await _db.rpc('register_token', params: {'p_token': token, 'p_kind': 'customer', 'p_platform': platform});
    } catch (_) {}
  }

  @override
  Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account');
    await _db.auth.signOut();
    _conversationId = null;
  }
}
