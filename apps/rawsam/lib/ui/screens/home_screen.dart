import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/media.dart';
import '../../state.dart';
import '../widgets/post_card.dart';
import 'directions_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = centerOf(ref);
    final repo = ref.watch(repoProvider);
    final posts = ref.watch(postsProvider);
    final bookings = (ref.watch(bookingsProvider).value ?? const <Booking>[]).where((b) => b.upcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final name = ref.watch(profileProvider).name.split(' ').first;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(postsProvider);
          ref.invalidate(worksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
          children: [
            if (repo.isDemo)
              Glass(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                tint: Brand.gold.withValues(alpha: 0.12),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: Brand.gold, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('وضع العرض — بيانات تجريبية لحد ما يتفعل ربط التطبيق بالمركز.', style: TextStyle(fontSize: 12.5))),
                  ],
                ),
              ),
            _UpdateBanner(info: c),
            Row(
              children: [
                const BrandTitle(size: 34),
                const Spacer(),
                IconButton.filledTonal(onPressed: () => Launch.call(c.phone), icon: const Icon(Icons.call_rounded), tooltip: 'اتصل'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name.isEmpty ? 'أهلاً بيك 🌸' : 'أهلاً $name 🌸',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Action(
                    icon: Icons.chat_rounded,
                    label: 'احجز موعد',
                    sub: 'احچي ويا المركز',
                    colors: const [Color(0xFF2F6BFF), Color(0xFF1B3FB8)],
                    onTap: () => ref.read(tabProvider.notifier).go(Tabs.chat),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Action(
                    icon: Icons.navigation_rounded,
                    label: 'وصّلني',
                    sub: 'خرائط وصوت توجيه',
                    colors: const [Color(0xFFFF5C8A), Color(0xFFB8336A)],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectionsScreen())),
                  ),
                ),
              ],
            ),
            if (bookings.isNotEmpty) ...[
              const SectionTitle('موعدك القادم'),
              _NextBooking(b: bookings.first),
            ],
            const SectionTitle('المنشورات والعروض'),
            posts.when(
              data: (list) => list.isEmpty
                  ? const EmptyState(icon: Icons.auto_awesome_rounded, text: 'قريباً ننشر هنا شغلنا وعروضنا ✨')
                  : Column(children: [for (final p in list) PostCard(post: p)]),
              loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const EmptyState(icon: Icons.wifi_off_rounded, text: 'تعذر تحميل المنشورات'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.sub, required this.colors, required this.onTap});
  final IconData icon;
  final String label;
  final String sub;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(sub, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      ),
    ),
  );
}

class _NextBooking extends StatelessWidget {
  const _NextBooking({required this.b});
  final Booking b;
  @override
  Widget build(BuildContext context) => Glass(
    tint: Brand.blue.withValues(alpha: 0.14),
    child: Row(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Brand.blue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text('${b.start.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(Fmt.day(b.start).split(' ').first, style: const TextStyle(fontSize: 10.5)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.serviceName.isEmpty ? 'موعد' : b.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(Fmt.dateTime(b.start), style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        const Icon(Icons.event_available_rounded, color: Brand.green),
      ],
    ),
  );
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.info});
  final CenterInfo info;
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: Updater.hasUpdate(info),
    builder: (context, s) => s.data != true
        ? const SizedBox.shrink()
        : Glass(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            tint: Brand.green.withValues(alpha: 0.14),
            onTap: () => Launch.url(info.latestApkUrl!),
            child: const Row(
              children: [
                Icon(Icons.system_update_rounded, color: Brand.green),
                SizedBox(width: 10),
                Expanded(child: Text('نسخة جديدة من التطبيق جاهزة — اضغط للتحديث', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
  );
}
