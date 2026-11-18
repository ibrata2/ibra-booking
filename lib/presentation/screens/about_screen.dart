import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../services/launcher_service.dart';
import '../widgets/common.dart';
import '../../core/edition.dart';

/// حول التطبيق.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    Widget link(IconData icon, Color color, String title, String sub, String url) => Glass(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onTap: () => Launcher.open(url),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(sub, textDirection: TextDirection.ltr),
        trailing: const Icon(Icons.open_in_new_rounded),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.t('about'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Glass(
            child: Column(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/images/logo.png', width: 110, height: 110)),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [Brand.red, Brand.blue]).createShader(r),
                  child: const Text(
                    Edition.nameEn,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const Text(Edition.nameAr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${context.t('version')} $version', style: TextStyle(color: Theme.of(context).hintColor)),
                const SizedBox(height: 10),
                Text(context.t('about_desc'), textAlign: TextAlign.center),
                const Divider(height: 28),
                const Text('برمجة وتطوير ابراهيم الخزرجي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const Text('Developer: IBRA', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          link(Icons.language_rounded, Brand.blue, context.t('apps_site'), 'ibraprogram.netlify.app', 'https://ibraprogram.netlify.app/'),
          link(Icons.send_rounded, const Color(0xFF29B6F6), 'Telegram', 't.me/ibraprogram', 'https://t.me/ibraprogram'),
          link(Icons.music_note_rounded, Brand.red, 'TikTok', '@ibraprogram', 'https://www.tiktok.com/@ibraprogram'),
          link(Icons.camera_alt_rounded, const Color(0xFFEC407A), 'Instagram', '@ibraprogram', 'https://www.instagram.com/ibraprogram'),
        ],
      ),
    );
  }
}
