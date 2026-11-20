import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../data/models.dart';

/// مشغّل أصوات التوجيه (صوت البنت بلهجة عراقية الذي يسجله المركز من نسخته).
class VoiceGuide {
  VoiceGuide._();
  static final _player = AudioPlayer();

  static Future<bool> play(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      await _player.stop();
      await _player.setUrl(url);
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}

class Launch {
  Launch._();

  static Future<void> url(String u) async {
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  /// فتح الملاحة نحو المركز في كوكل ماب (أو خرائط آبل إذا ما موجود).
  static Future<void> directions(CenterInfo c) async {
    final g = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}&travelmode=driving');
    if (Platform.isIOS) {
      final gm = Uri.parse('comgooglemaps://?daddr=${c.lat},${c.lng}&directionsmode=driving');
      if (await canLaunchUrl(gm)) {
        await launchUrl(gm);
        return;
      }
      final am = Uri.parse('https://maps.apple.com/?daddr=${c.lat},${c.lng}&dirflg=d');
      await launchUrl(am, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(g, mode: LaunchMode.externalApplication);
  }
}

/// تحديث نسخة الموقع: التغييرات اليومية تنزل بصمت من السيرفر، والنسخة الكاملة الجديدة
/// تنعرض كتنبيه داخل التطبيق (نسخة المتاجر تتحدث من المتجر نفسه).
class Updater {
  Updater._();
  static int? _build;

  static Future<int> currentBuild() async {
    if (_build != null) return _build!;
    try {
      final info = await PackageInfo.fromPlatform();
      _build = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      _build = 0;
    }
    return _build!;
  }

  static Future<bool> hasUpdate(CenterInfo c) async {
    if (AppConfig.isStore || !Platform.isAndroid) return false;
    final url = c.latestApkUrl;
    if (url == null || url.isEmpty) return false;
    return c.latestApkBuild > await currentBuild();
  }

  static Future<bool> mustUpdate(CenterInfo c) async => c.minAppBuild > await currentBuild();
}
