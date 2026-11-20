import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// بطاقة الهدية: كود رقمي + باركود QR يراويه الزبون للموظف.
Future<void> showCouponSheet(BuildContext context, Coupon c, {bool celebrate = false}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (celebrate) ...[
            const Text('🎉', style: TextStyle(fontSize: 46)),
            const Text('وصلتك هدية!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
          ],
          Text(c.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (c.discountText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c.discountText, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Brand.gold)),
          ],
          const SizedBox(height: 16),
          Opacity(
            opacity: c.usable ? 1 : 0.35,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: QrImageView(data: c.code, size: 210, backgroundColor: Colors.white, padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Clipboard.setData(ClipboardData(text: c.code));
              toast(ctx, 'انتسخ الكود');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                c.code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 28, letterSpacing: 3, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(switch (c.effectiveStatus) {
            'used' => 'مستخدم ${c.usedAt == null ? '' : '— ${Fmt.day(c.usedAt!)}'}',
            'expired' => 'منتهي الصلاحية',
            _ => 'صالح لحد ${Fmt.day(c.expiresAt)}',
          }, style: TextStyle(color: c.usable ? Brand.green : Colors.white54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'راوي الباركود أو الكود للموظف بالمركز حتى ينطبق الخصم.\nيشتغل مرة وحدة بس.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    ),
  ),
);
