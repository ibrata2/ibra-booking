import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/media.dart';
import '../../services/proximity.dart';
import '../../services/push.dart';
import '../../state.dart';
import '../widgets/permission_sheets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        children: [
          const Text('المزيد', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.person_rounded,
            color: Brand.sky,
            title: p.name.isEmpty ? 'بياناتي' : p.name,
            sub: p.phone.isEmpty ? 'الاسم ورقم الهاتف' : p.phone,
            onTap: () => go(const _ProfileScreen()),
          ),
          _Tile(icon: Icons.event_note_rounded, color: Brand.green, title: 'حجوزاتي', sub: 'مواعيدك ويا المركز', onTap: () => go(const _BookingsScreen())),
          _Tile(
            icon: Icons.notifications_rounded,
            color: Brand.gold,
            title: 'الإشعارات وعروض القرب',
            sub: 'الأصوات، العروض، والجيران',
            onTap: () => go(const _NotificationsScreen()),
          ),
          _Tile(icon: Icons.privacy_tip_rounded, color: Colors.tealAccent, title: 'سياسة الخصوصية', sub: 'شنو نجمع وليش', onTap: () => Launch.url(AppConfig.privacyUrl)),
          _Tile(icon: Icons.info_rounded, color: Colors.blueGrey, title: 'حول التطبيق', sub: 'برمجة وتطوير ابراهيم الخزرجي', onTap: () => go(const _AboutScreen())),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () => _deleteAccount(context, ref),
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            label: const Text('حذف حسابي وبياناتي', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'راح ينحذف اسمك ورقمك ومحادثتك وحجوزاتك وهداياك نهائياً من المركز.\nهذا الإجراء ما يرجع.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text('احذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProximityService.disable();
      await ref.read(repoProvider).deleteAccount();
      await ref.read(repoProvider).start();
      ref.read(profileProvider.notifier).setLoaded(const CustomerProfile());
      ref.invalidate(messagesProvider);
      ref.invalidate(couponsProvider);
      ref.invalidate(bookingsProvider);
      ref.invalidate(unreadProvider);
      if (context.mounted) toast(context, 'انحذف حسابك وبياناتك');
    } catch (_) {
      if (context.mounted) toast(context, 'ما كدرنا نحذف هسه — تأكد من الإنترنت');
    }
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Glass(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    onTap: onTap,
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
              Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left_rounded),
      ],
    ),
  );
}

class _ProfileScreen extends ConsumerStatefulWidget {
  const _ProfileScreen();
  @override
  ConsumerState<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<_ProfileScreen> {
  late final _name = TextEditingController(text: ref.read(profileProvider).name);
  late final _phone = TextEditingController(text: ref.read(profileProvider).phone);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بياناتي')),
    body: AppBackground(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded))),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_rounded)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(profileProvider.notifier).save(ref.read(profileProvider).copyWith(name: _name.text.trim(), phone: _phone.text.trim()));
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) toast(context, 'ما انحفظ — تأكد من الإنترنت');
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

class _BookingsScreen extends ConsumerWidget {
  const _BookingsScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(bookingsProvider).value ?? const <Booking>[];
    String st(String s) => switch (s) {
      'cancelled' => 'ملغى',
      'completed' => 'مكتمل',
      'postponed' => 'مؤجل',
      _ => 'مثبّت',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('حجوزاتي')),
      body: AppBackground(
        child: list.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  text: 'ما عندك حجوزات بعد.\nاحجز من المحادثة ويا المركز.',
                  action: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(tabProvider.notifier).go(Tabs.chat);
                    },
                    child: const Text('احجز هسه'),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final b in list)
                    Glass(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            b.upcoming ? Icons.event_available_rounded : Icons.history_rounded,
                            color: b.upcoming ? Brand.green : Colors.white54,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.serviceName.isEmpty ? 'موعد' : b.serviceName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(Fmt.dateTime(b.start), style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                                if (b.staffName.isNotEmpty) Text(b.staffName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                              ],
                            ),
                          ),
                          Text(st(b.status), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NotificationsScreen extends ConsumerStatefulWidget {
  const _NotificationsScreen();
  @override
  ConsumerState<_NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<_NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات والعروض')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            const NotificationPermissionCard(),
            const SizedBox(height: 10),
            Glass(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SwitchListTile(
                value: p.promoOptIn,
                title: const Text('إشعارات المنشورات والعروض', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('رسائل المركز وتذكير الحجوزات توصلك دائماً'),
                onChanged: (v) async {
                  await ref.read(profileProvider.notifier).save(p.copyWith(promoOptIn: v));
                  await PushService.setPromos(v);
                },
              ),
            ),
            const SizedBox(height: 10),
            const ProximityPermissionCard(),
            if (p.proximityOn)
              TextButton(
                onPressed: () async {
                  await ProximityService.disable();
                  await ref.read(profileProvider.notifier).save(p.copyWith(proximityOn: false));
                  if (mounted) setState(() {});
                },
                child: const Text('إيقاف عروض القرب'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حول')),
    body: AppBackground(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: BrandTitle(size: 46)),
          const SizedBox(height: 10),
          FutureBuilder<int>(
            future: Updater.currentBuild(),
            builder: (_, s) => Text('الإصدار 1.0.0 (${s.data ?? ''})', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 24),
          const Glass(
            child: Column(
              children: [
                Text('برمجة وتطوير ابراهيم الخزرجي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Link(icon: Icons.language_rounded, label: 'موقع تطبيقاتي', url: 'https://ibraprogram.netlify.app/'),
          _Link(icon: Icons.send_rounded, label: 'Telegram', url: 'https://t.me/ibraprogram'),
          _Link(icon: Icons.music_note_rounded, label: 'TikTok — ibraprogram', url: 'https://www.tiktok.com/@ibraprogram'),
        ],
      ),
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;
  @override
  Widget build(BuildContext context) => Glass(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    onTap: () => Launch.url(url),
    child: Row(
      children: [
        Icon(icon, color: Brand.sky),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        const Icon(Icons.open_in_new_rounded, size: 18),
      ],
    ),
  );
}
