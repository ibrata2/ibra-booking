import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state.dart';
import '../widgets/coupon_sheet.dart';

class GiftsScreen extends ConsumerWidget {
  const GiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider);
    return SafeArea(
      bottom: false,
      child: coupons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.wifi_off_rounded, text: 'تعذر تحميل الهدايا'),
        data: (list) {
          final active = list.where((c) => c.usable).toList();
          final old = list.where((c) => !c.usable).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            children: [
              const Text('هداياي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('العروض الخاصة بيك — راويها للموظف حتى ينطبق الخصم', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              if (active.isEmpty)
                const EmptyState(
                  icon: Icons.card_giftcard_outlined,
                  text: 'ما عندك هدايا هسه.\nفعّل «عروض القرب» من المزيد حتى يوصلك عرض من تمر قريب من المركز 🎁',
                ),
              for (final c in active) _CouponTile(c: c),
              if (old.isNotEmpty) ...[
                const SectionTitle('المستخدمة والمنتهية'),
                for (final c in old) _CouponTile(c: c),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.c});
  final Coupon c;
  @override
  Widget build(BuildContext context) {
    final usable = c.usable;
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      tint: usable ? Brand.gold.withValues(alpha: 0.10) : null,
      onTap: () => showCouponSheet(context, c),
      child: Opacity(
        opacity: usable ? 1 : 0.55,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: usable ? const LinearGradient(colors: [Brand.gold, Color(0xFFFF8A3D)]) : null,
                color: usable ? null : Colors.white10,
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  if (c.discountText.isNotEmpty) Text(c.discountText, style: const TextStyle(color: Brand.gold, fontWeight: FontWeight.w800)),
                  Text(
                    switch (c.effectiveStatus) {
                      'used' => 'مستخدم',
                      'expired' => 'منتهي',
                      _ => 'صالح لحد ${Fmt.day(c.expiresAt)}',
                    },
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            Text(c.code, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
