import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'notifications.dart';

const _fenceId = 'rawsam_center';
const _kPending = 'prox_pending';
const _kLastNear = 'prox_last_near_ms';
const _kTitle = 'prox_title';
const _kFrom = 'prox_from';
const _kTo = 'prox_to';
const _kFence = 'prox_fence';

/// يُستدعى من نظام الجهاز عند دخول الزبون دائرة المركز — حتى لو التطبيق مسدود.
/// لا يرسل موقع الزبون لأي جهة: يعرض تنبيهاً محلياً فقط، والكوبون ينصرف لما يفتح التطبيق.
@pragma('vm:entry-point')
Future<void> rawsamGeofenceTriggered(GeofenceCallbackParams params) async {
  if (params.event != GeofenceEvent.enter) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final now = DateTime.now().toUtc();
  // مرة كل 12 ساعة كحد أقصى من جهة الجهاز (والمركز يحدد المدة الحقيقية)
  final last = prefs.getInt(_kLastNear) ?? 0;
  if (now.millisecondsSinceEpoch - last < const Duration(hours: 12).inMilliseconds) return;
  // ضمن ساعات العرض بتوقيت بغداد (UTC+3)
  final baghdad = now.add(const Duration(hours: 3));
  final minute = baghdad.hour * 60 + baghdad.minute;
  final from = prefs.getInt(_kFrom) ?? 600;
  final to = prefs.getInt(_kTo) ?? 1260;
  if (minute < from || minute > to) return;

  await prefs.setInt(_kLastNear, now.millisecondsSinceEpoch);
  await prefs.setBool(_kPending, true);
  await LocalNotifications.init(background: true);
  await LocalNotifications.show(
    id: 7001,
    title: prefs.getString(_kTitle) ?? 'مدام صرت قريب على روسم… مر علينا 🌸',
    body: 'عندك هدية تنتظرك — اضغط حتى تستلم الكود',
    sound: AppSounds.gift,
    tap: const NotificationTap('proximity'),
  );
}

enum ProximityPermission { granted, foregroundOnly, denied, serviceOff }

class ProximityService {
  ProximityService._();

  static Future<ProximityPermission> status() async {
    if (!await Geolocator.isLocationServiceEnabled()) return ProximityPermission.serviceOff;
    if (await Permission.locationAlways.isGranted) return ProximityPermission.granted;
    if (await Permission.locationWhenInUse.isGranted) return ProximityPermission.foregroundOnly;
    return ProximityPermission.denied;
  }

  /// طلب صلاحية الموقع «دائماً» على مرحلتين كما تشترط أندرويد وآيفون.
  static Future<ProximityPermission> request() async {
    var w = await Permission.locationWhenInUse.request();
    if (!w.isGranted) return ProximityPermission.denied;
    final a = await Permission.locationAlways.request();
    if (a.isGranted) return ProximityPermission.granted;
    return ProximityPermission.foregroundOnly;
  }

  static Future<void> openSettings() => openAppSettings();

  /// تفعيل دائرة المركز على الجهاز (أو تحديثها إذا تغير موقع المركز أو المسافة).
  static Future<bool> enable(CenterInfo c) async {
    if (await status() != ProximityPermission.granted) return false;
    final prefs = await SharedPreferences.getInstance();
    final sig = '${c.lat.toStringAsFixed(5)},${c.lng.toStringAsFixed(5)},${c.proximityRadius}';
    try {
      await NativeGeofenceManager.instance.initialize();
      final ids = await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
      if (ids.contains(_fenceId) && prefs.getString(_kFence) == sig) return true;
      if (ids.contains(_fenceId)) await NativeGeofenceManager.instance.removeGeofenceById(_fenceId);
      await NativeGeofenceManager.instance.createGeofence(
        Geofence(
          id: _fenceId,
          location: Location(latitude: c.lat, longitude: c.lng),
          radiusMeters: c.proximityRadius.toDouble(),
          triggers: const {GeofenceEvent.enter},
          iosSettings: const IosGeofenceSettings(initialTrigger: false),
          androidSettings: const AndroidGeofenceSettings(
            initialTriggers: <GeofenceEvent>{},
            expiration: null,
            loiteringDelay: Duration(minutes: 1),
            notificationResponsiveness: Duration(minutes: 3),
          ),
        ),
        rawsamGeofenceTriggered,
      );
      await prefs.setString(_kFence, sig);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    try {
      await NativeGeofenceManager.instance.initialize();
      await NativeGeofenceManager.instance.removeGeofenceById(_fenceId);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFence);
  }

  /// نحفظ نص العرض وساعاته على الجهاز حتى يستخدمها التنبيه بالخلفية.
  static Future<void> cacheOffer(CenterInfo c, {String? title}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFrom, c.proximityFromMin);
    await prefs.setInt(_kTo, c.proximityToMin);
    if (title != null && title.isNotEmpty) await prefs.setString(_kTitle, title);
  }

  /// بعد فتح التطبيق: إذا كان الزبون قريباً من المركز ننصرف له الكوبون.
  static Future<Coupon?> claimIfPending(CenterRepository repo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(_kPending) != true) return null;
    await prefs.setBool(_kPending, false);
    try {
      return await repo.claimProximity();
    } catch (_) {
      return null;
    }
  }
}

/// منطقة الزبون التقريبية: تنحسب بالجهاز كل ما يفتح التطبيق (إذا مفعّل الموقع)،
/// وينرسل للمركز بس: الكرادة / بغداد / خارج بغداد + البعد عن المركز مقرّب لنص كيلو.
/// حتى المركز يكدر يرسل إشعار للقريبين أو لأهل الكرادة أو لبغداد بس.
class AreaService {
  AreaService._();
  static const _kAt = 'area_sent_ms';
  static const _karradaLat = 33.3050, _karradaLng = 44.4260, _karradaKm = 3.5;
  static const _baghdadLat = 33.3152, _baghdadLng = 44.3661, _baghdadKm = 30.0;

  static Future<void> update(CenterRepository repo, CenterInfo c, {bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kAt) ?? 0;
      if (!force && DateTime.now().millisecondsSinceEpoch - last < const Duration(minutes: 30).inMilliseconds) return;
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
          );
      final km = Geolocator.distanceBetween(pos.latitude, pos.longitude, c.lat, c.lng) / 1000;
      final kar = Geolocator.distanceBetween(pos.latitude, pos.longitude, _karradaLat, _karradaLng) / 1000;
      final bag = Geolocator.distanceBetween(pos.latitude, pos.longitude, _baghdadLat, _baghdadLng) / 1000;
      final area = kar <= _karradaKm ? 'karrada' : (bag <= _baghdadKm ? 'baghdad' : 'outside');
      await repo.updateArea(area, km);
      await prefs.setInt(_kAt, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
