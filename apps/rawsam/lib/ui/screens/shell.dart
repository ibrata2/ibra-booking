import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../services/proximity.dart';
import '../../services/push.dart';
import '../../state.dart';
import '../widgets/coupon_sheet.dart';
import 'chat_screen.dart';
import 'gifts_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'works_screen.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  final _subs = <StreamSubscription<NotificationTap>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subs.add(LocalNotifications.taps.listen(_onTap));
    _subs.add(PushService.taps.listen(_onTap));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(repoProvider);
      if (await LocalNotifications.enabled()) {
        await PushService.attach(repo, promos: ref.read(profileProvider).promoOptIn);
      }
      final launch = LocalNotifications.launchTap ?? PushService.launchTap;
      LocalNotifications.launchTap = null;
      PushService.launchTap = null;
      if (launch != null) _onTap(launch);
      await _claimProximity();
      await AreaService.update(repo, centerOf(ref));
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _claimProximity();
      AreaService.update(ref.read(repoProvider), ref.read(centerInfoProvider).value ?? const CenterInfo());
    }
  }

  Future<void> _claimProximity() async {
    final c = await ProximityService.claimIfPending(ref.read(repoProvider));
    if (c != null && mounted) {
      ref.read(tabProvider.notifier).go(Tabs.gifts);
      showCouponSheet(context, c, celebrate: true);
    }
  }

  void _onTap(NotificationTap t) {
    final tabs = ref.read(tabProvider.notifier);
    switch (t.type) {
      case 'chat':
        tabs.go(Tabs.chat);
      case 'coupon':
        tabs.go(Tabs.gifts);
      case 'proximity':
        tabs.go(Tabs.gifts);
        _claimProximity();
      case 'booking':
        tabs.go(Tabs.home);
      default:
        tabs.go(Tabs.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // تذكير الزبون بمواعيده كلما تغيرت
    ref.listen<AsyncValue<List<Booking>>>(bookingsProvider, (_, next) {
      final list = next.value;
      if (list != null) LocalNotifications.scheduleBookingReminders(list);
    });
    // تحديث دائرة المركز إذا غيّر المركز موقعه أو المسافة أو أوقات العرض
    ref.listen<AsyncValue<CenterInfo>>(centerInfoProvider, (_, next) async {
      final c = next.value;
      if (c == null) return;
      await ProximityService.cacheOffer(c);
      final p = ref.read(profileProvider);
      if (!p.proximityOn) return;
      if (!c.proximityEnabled) {
        await ProximityService.disable();
      } else {
        await ProximityService.enable(c);
      }
    });

    final index = ref.watch(tabProvider);
    final unread = ref.watch(unreadProvider).value ?? 0;
    final gifts = (ref.watch(couponsProvider).value ?? const <Coupon>[]).where((c) => c.usable).length;
    const pages = [HomeScreen(), WorksScreen(), ChatScreen(), GiftsScreen(), MoreScreen()];
    final items = [
      (Icons.home_rounded, 'الرئيسية', 0),
      (Icons.photo_library_rounded, 'أعمالنا', 0),
      (Icons.chat_bubble_rounded, 'احجز', unread),
      (Icons.card_giftcard_rounded, 'هداياي', gifts),
      (Icons.more_horiz_rounded, 'المزيد', 0),
    ];
    return Scaffold(
      extendBody: true,
      body: AppBackground(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: items[i].$1,
                        label: items[i].$2,
                        badge: items[i].$3,
                        selected: i == index,
                        onTap: () => ref.read(tabProvider.notifier).go(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.badge, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Brand.sky : Colors.white.withValues(alpha: 0.55);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            backgroundColor: Brand.rose,
            child: AnimatedScale(scale: selected ? 1.15 : 1, duration: const Duration(milliseconds: 220), child: Icon(icon, color: color)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        ],
      ),
    );
  }
}
