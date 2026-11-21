/// نماذج البيانات المشتركة مع نسخة المركز (نفس جداول Supabase).
library;

DateTime _dt(Object? v) => v is String ? DateTime.parse(v).toLocal() : (v is DateTime ? v.toLocal() : DateTime.now());
DateTime? _dtn(Object? v) => v == null ? null : _dt(v);
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(Object? v) => v == null ? '' : '$v';

class CenterInfo {
  final String name;
  final String phone;
  final String address;
  final double lat;
  final double lng;
  final String workingHours;
  final String? welcomeVoiceUrl;
  final String? arrivalVoiceUrl;
  final bool proximityEnabled;
  final int proximityRadius;
  final int proximityFromMin;
  final int proximityToMin;
  final int latestApkBuild;
  final String? latestApkUrl;
  final int minAppBuild;

  const CenterInfo({
    this.name = 'روسم للتجميل',
    this.phone = '07718814000',
    this.address = 'بغداد — الكرادة داخل، شارع سبع قصور، فرحان مول',
    this.lat = 33.3060,
    this.lng = 44.4290,
    this.workingHours = 'السبت – الخميس، 10 صباحاً – 9 مساءً',
    this.welcomeVoiceUrl,
    this.arrivalVoiceUrl,
    this.proximityEnabled = true,
    this.proximityRadius = 500,
    this.proximityFromMin = 600,
    this.proximityToMin = 1260,
    this.latestApkBuild = 0,
    this.latestApkUrl,
    this.minAppBuild = 0,
  });

  factory CenterInfo.fromJson(Map<String, dynamic> j) => CenterInfo(
    name: _s(j['name']).isEmpty ? 'روسم للتجميل' : _s(j['name']),
    phone: _s(j['phone']),
    address: _s(j['address']),
    lat: _num(j['lat']),
    lng: _num(j['lng']),
    workingHours: _s(j['working_hours']),
    welcomeVoiceUrl: j['welcome_voice_url'] as String?,
    arrivalVoiceUrl: j['arrival_voice_url'] as String?,
    proximityEnabled: j['proximity_enabled'] != false,
    proximityRadius: _int(j['proximity_radius_m']) == 0 ? 500 : _int(j['proximity_radius_m']),
    proximityFromMin: j['proximity_from_min'] == null ? 600 : _int(j['proximity_from_min']),
    proximityToMin: j['proximity_to_min'] == null ? 1260 : _int(j['proximity_to_min']),
    latestApkBuild: _int(j['latest_apk_build']),
    latestApkUrl: j['latest_apk_url'] as String?,
    minAppBuild: _int(j['min_app_build']),
  );
}

class MallStep {
  final int id;
  final int sort;
  final String text;
  final String? voiceUrl;
  const MallStep({required this.id, required this.sort, required this.text, this.voiceUrl});
  factory MallStep.fromJson(Map<String, dynamic> j) =>
      MallStep(id: _int(j['id']), sort: _int(j['sort']), text: _s(j['text']), voiceUrl: j['voice_url'] as String?);
}

class Post {
  final int id;
  final String kind; // post | offer
  final String? url;
  final String? platform; // instagram | facebook | other
  final String title;
  final String body;
  final String? imageUrl;
  final bool pinned;
  final bool notify;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const Post({
    required this.id,
    this.kind = 'post',
    this.url,
    this.platform,
    this.title = '',
    this.body = '',
    this.imageUrl,
    this.pinned = false,
    this.notify = true,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isOffer => kind == 'offer';
  bool get expired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: _int(j['id']),
    kind: _s(j['kind']).isEmpty ? 'post' : _s(j['kind']),
    url: j['url'] as String?,
    platform: j['platform'] as String?,
    title: _s(j['title']),
    body: _s(j['body']),
    imageUrl: j['image_url'] as String?,
    pinned: j['pinned'] == true,
    notify: j['notify'] != false,
    createdAt: _dt(j['created_at']),
    expiresAt: _dtn(j['expires_at']),
  );

  /// رابط التضمين الرسمي للمنشور (يعمل للمنشورات العامة بدون أي ربط بالحساب).
  String? get embedUrl {
    final u = url;
    if (u == null || u.isEmpty) return null;
    final p = platform ?? detectPlatform(u);
    if (p == 'instagram') {
      final m = RegExp(r'instagram\.com/(?:[A-Za-z0-9_.]+/)?(p|reel|reels|tv)/([A-Za-z0-9_-]+)').firstMatch(u);
      if (m != null) {
        final type = m.group(1) == 'reels' ? 'reel' : m.group(1);
        return 'https://www.instagram.com/$type/${m.group(2)}/embed/captioned/';
      }
      return null;
    }
    if (p == 'facebook') {
      final isVideo = u.contains('/videos/') || u.contains('/reel/') || u.contains('fb.watch') || u.contains('/watch');
      final plugin = isVideo ? 'video.php' : 'post.php';
      return 'https://www.facebook.com/plugins/$plugin?href=${Uri.encodeComponent(u)}&show_text=true&width=500';
    }
    return null;
  }

  static String? detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('instagram.com') || u.contains('instagr.am')) return 'instagram';
    if (u.contains('facebook.com') || u.contains('fb.watch') || u.contains('fb.com')) return 'facebook';
    return 'other';
  }
}

class WorkItem {
  final int id;
  final String category; // tattoo, piercing, laser, skin, other
  final String imageUrl;
  final String caption;
  const WorkItem({required this.id, required this.category, required this.imageUrl, this.caption = ''});
  factory WorkItem.fromJson(Map<String, dynamic> j) =>
      WorkItem(id: _int(j['id']), category: _s(j['category']), imageUrl: _s(j['image_url']), caption: _s(j['caption']));
}

const workCategories = <String, String>{
  'all': 'الكل',
  'tattoo': 'تاتو',
  'piercing': 'بيرسنك',
  'laser': 'ليزر',
  'skin': 'بشرة وإبر',
  'other': 'أخرى',
};

class ChatMessage {
  final int id;
  final String sender; // customer | staff | system
  final String? displayName;
  final String kind; // text | image | booking | coupon
  final String body;
  final String? imageUrl;
  final String? refId;
  final DateTime createdAt;
  final bool pending;

  const ChatMessage({
    required this.id,
    required this.sender,
    this.displayName,
    this.kind = 'text',
    this.body = '',
    this.imageUrl,
    this.refId,
    required this.createdAt,
    this.pending = false,
  });

  bool get mine => sender == 'customer';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: _int(j['id']),
    sender: _s(j['sender']),
    displayName: j['display_name'] as String?,
    kind: _s(j['kind']).isEmpty ? 'text' : _s(j['kind']),
    body: _s(j['body']),
    imageUrl: j['image_url'] as String?,
    refId: j['ref_id'] as String?,
    createdAt: _dt(j['created_at']),
  );
}

class Coupon {
  final int id;
  final String code;
  final String title;
  final String discountText;
  final String status; // active | used | expired
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? usedAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.title,
    this.discountText = '',
    this.status = 'active',
    required this.expiresAt,
    required this.createdAt,
    this.usedAt,
  });

  String get effectiveStatus => status == 'active' && expiresAt.isBefore(DateTime.now()) ? 'expired' : status;
  bool get usable => effectiveStatus == 'active';

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
    id: _int(j['id']),
    code: _s(j['code']),
    title: _s(j['title']),
    discountText: _s(j['discount_text']),
    status: _s(j['status']),
    expiresAt: _dt(j['expires_at']),
    createdAt: _dt(j['created_at']),
    usedAt: _dtn(j['used_at']),
  );
}

class Booking {
  final String id;
  final String serviceName;
  final String staffName;
  final DateTime start;
  final DateTime end;
  final double price;
  final String status; // confirmed | cancelled | completed | postponed
  final String notes;

  const Booking({
    required this.id,
    this.serviceName = '',
    this.staffName = '',
    required this.start,
    required this.end,
    this.price = 0,
    this.status = 'confirmed',
    this.notes = '',
  });

  bool get upcoming => status == 'confirmed' && end.isAfter(DateTime.now());

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: _s(j['id']),
    serviceName: _s(j['service_name']),
    staffName: _s(j['staff_name']),
    start: _dt(j['start_at']),
    end: _dt(j['end_at']),
    price: _num(j['price']),
    status: _s(j['status']),
    notes: _s(j['notes']),
  );
}

class ServiceInfo {
  final int id;
  final String name;
  final int durationMin;
  final double price;
  const ServiceInfo({required this.id, required this.name, this.durationMin = 30, this.price = 0});
  factory ServiceInfo.fromJson(Map<String, dynamic> j) =>
      ServiceInfo(id: _int(j['id']), name: _s(j['name']), durationMin: _int(j['duration_min']), price: _num(j['price']));
}

class CustomerProfile {
  final String name;
  final String phone;
  final String? neighborTier; // building | near | area
  final bool proximityOn;
  final bool promoOptIn;
  const CustomerProfile({this.name = '', this.phone = '', this.neighborTier, this.proximityOn = false, this.promoOptIn = true});

  bool get complete => name.trim().isNotEmpty && phone.trim().length >= 10;

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
    name: _s(j['name']),
    phone: _s(j['phone']),
    neighborTier: j['neighbor_tier'] as String?,
    proximityOn: j['proximity_on'] == true,
    promoOptIn: j['promo_opt_in'] != false,
  );

  CustomerProfile copyWith({String? name, String? phone, String? neighborTier, bool clearTier = false, bool? proximityOn, bool? promoOptIn}) =>
      CustomerProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        neighborTier: clearTier ? null : (neighborTier ?? this.neighborTier),
        proximityOn: proximityOn ?? this.proximityOn,
        promoOptIn: promoOptIn ?? this.promoOptIn,
      );
}

const neighborTiers = <String, String>{
  'building': 'أسكن بنفس البناية / فرحان مول',
  'near': 'قريب جداً (أقل من كيلو)',
  'area': 'بنفس المنطقة (الكرادة وما حولها)',
};
