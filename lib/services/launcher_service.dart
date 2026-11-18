import 'package:url_launcher/url_launcher.dart';

import '../domain/entities/entities.dart';

/// الاتصال، واتساب، الخرائط والملاحة، المشاركة عبر الروابط.
class Launcher {
  Launcher._();

  static String _digits(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  /// رقم دولي لواتساب (العراق افتراضياً: 07xx → 9647xx).
  static String intl(String phone) {
    var d = _digits(phone);
    if (d.startsWith('+')) return d.substring(1);
    if (d.startsWith('00')) return d.substring(2);
    if (d.startsWith('0')) return '964${d.substring(1)}';
    return d;
  }

  static Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: _digits(phone)));

  static Future<bool> sms(String phone, [String body = '']) =>
      launchUrl(Uri(scheme: 'sms', path: _digits(phone), queryParameters: body.isEmpty ? null : {'body': body}));

  static Future<bool> whatsapp(String phone, [String text = '']) => launchUrl(
    Uri.parse('https://wa.me/${intl(phone)}${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}'),
    mode: LaunchMode.externalApplication,
  );

  /// استخراج الإحداثيات من رابط خرائط Google أو نص "lat,lng".
  static (double, double)? parseCoords(String text) {
    final patterns = [
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'[?&](?:q|query|ll|destination|daddr)=(-?\d+\.\d+)(?:,|%2C)\s*(-?\d+\.\d+)'),
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'^\s*(-?\d{1,2}\.\d+)\s*[,،]\s*(-?\d{1,3}\.\d+)\s*$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!), lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) return (lat, lng);
      }
    }
    return null;
  }

  static String _query(Appointment a) => [a.placeName, a.address, a.area, a.province].where((e) => e.trim().isNotEmpty).join(', ');

  static bool hasLocation(Appointment a) => a.lat != null || a.mapUrl.isNotEmpty || _query(a).isNotEmpty;

  /// فتح الموقع (أو الملاحة إليه) في خرائط Google أو Apple حسب اختيار المستخدم.
  static Future<bool> openMap(Appointment a, {required String app, bool navigate = true}) async {
    Uri uri;
    if (a.lat != null && a.lng != null) {
      uri = app == 'apple'
          ? Uri.parse('https://maps.apple.com/?${navigate ? 'daddr' : 'll'}=${a.lat},${a.lng}&q=${Uri.encodeComponent(a.placeName)}')
          : Uri.parse(
              navigate
                  ? 'https://www.google.com/maps/dir/?api=1&destination=${a.lat},${a.lng}'
                  : 'https://www.google.com/maps/search/?api=1&query=${a.lat},${a.lng}',
            );
    } else if (a.mapUrl.isNotEmpty && Uri.tryParse(a.mapUrl)?.hasScheme == true) {
      uri = Uri.parse(a.mapUrl);
    } else {
      final q = Uri.encodeComponent(_query(a));
      uri = app == 'apple'
          ? Uri.parse('https://maps.apple.com/?${navigate ? 'daddr' : 'q'}=$q')
          : Uri.parse(navigate ? 'https://www.google.com/maps/dir/?api=1&destination=$q' : 'https://www.google.com/maps/search/?api=1&query=$q');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// رابط قابل للمشاركة لموقع المناسبة.
  static String shareLink(Appointment a) {
    if (a.lat != null && a.lng != null) return 'https://www.google.com/maps/search/?api=1&query=${a.lat},${a.lng}';
    if (a.mapUrl.isNotEmpty) return a.mapUrl;
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_query(a))}';
  }

  static Future<bool> open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
