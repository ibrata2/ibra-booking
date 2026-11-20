import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';
import 'finance_screen.dart';
import 'notification_settings_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';
import 'staff_screen.dart';
import '../../core/edition.dart';
import '../../cloud/cloud_providers.dart';
import '../../cloud/screens/cloud_hub_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, Color color, String title, String sub, Widget page) => Glass(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => go(page),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text(sub, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
              ],
            ),
          ),
          Icon(context.ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(context.t('nav_more'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (s.showFinance)
            tile(
              Icons.account_balance_wallet_rounded,
              const Color(0xFF00C853),
              context.t('finance'),
              context.t('finance_sub'),
              const FinanceScreen(),
            ),
          tile(
            Icons.notifications_active_rounded,
            const Color(0xFFFF8F00),
            context.t('notif_settings'),
            context.t('notif_settings_sub'),
            const NotificationSettingsScreen(),
          ),
          tile(Icons.library_music_rounded, const Color(0xFFEC407A), context.t('sounds'), context.t('sounds_sub'), const SoundsScreen()),
          if (Edition.isCenter) ...[
            Badge(
              isLabelVisible: ref.watch(unreadStaffProvider) > 0,
              label: Text('${ref.watch(unreadStaffProvider)}'),
              alignment: AlignmentDirectional.topStart,
              child: tile(
                Icons.phone_iphone_rounded,
                const Color(0xFF2F6BFF),
                'تطبيق الزبائن «روسم للتجميل»',
                'المحادثات، المنشورات، العروض، الكوبونات',
                const CloudHubScreen(),
              ),
            ),
            tile(Icons.badge_rounded, const Color(0xFF3D7BFF), context.t('staff'), context.t('staff_sub'), const StaffScreen()),
            tile(Icons.spa_rounded, const Color(0xFFEC407A), context.t('services'), context.t('services_sub'), const ServicesScreen()),
          ] else
            tile(Icons.category_rounded, const Color(0xFF7C4DFF), context.t('categories'), context.t('categories_sub'), const CategoriesScreen()),
          tile(Icons.backup_rounded, const Color(0xFF00ACC1), context.t('backup'), context.t('backup_sub'), const BackupScreen()),
          tile(Icons.lock_rounded, const Color(0xFFE53935), context.t('security'), context.t('security_sub'), const SecurityScreen()),
          tile(Icons.settings_rounded, const Color(0xFF3D7BFF), context.t('settings'), context.t('settings_sub'), const SettingsScreen()),
          tile(Icons.info_rounded, const Color(0xFF78909C), context.t('about'), context.t('about_sub'), const AboutScreen()),
        ],
      ),
    );
  }
}
