import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/time/time_format.dart';
import '../../presentation/widgets/common.dart';
import '../cloud.dart';

/// مسح كوبون الزبون بالكاميرا (أو كتابة الكود) → يطلع الزبون والعرض وصلاحيته → «استخدام» مرة وحدة.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _check(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    await _ctrl.stop();
    try {
      final rows = await Cloud.db.rpc('coupon_info', params: {'p_code': code});
      if (!mounted) return;
      if (rows is! List || rows.isEmpty) {
        await _result('❌', 'الكود غير موجود', code);
      } else {
        await _showCoupon(Map<String, dynamic>.from(rows.first as Map));
      }
    } catch (e) {
      if (mounted) toast(context, 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _ctrl.start();
    }
  }

  Future<void> _showCoupon(Map<String, dynamic> c) async {
    final status = c['status'] as String;
    final expires = DateTime.tryParse('${c['expires_at']}')?.toLocal();
    final usedAt = DateTime.tryParse('${c['used_at']}')?.toLocal();
    final ok = status == 'active';
    final use = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ok ? '✅ كوبون صالح' : (status == 'used' ? '⚠️ مستخدم من قبل' : '⌛ منتهي')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if ((c['discount_text'] as String? ?? '').isNotEmpty)
              Text(c['discount_text'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF00C853))),
            const SizedBox(height: 10),
            Text('👤 ${c['customer_name'] ?? ''}'),
            Text('📞 ${c['customer_phone'] ?? ''}', textDirection: TextDirection.ltr),
            Text('🔖 ${c['code']}', textDirection: TextDirection.ltr),
            if (expires != null) Text('صالح لحد ${TimeFmt.date(expires)}'),
            if (usedAt != null) Text('استُخدم ${TimeFmt.date(usedAt)} ${TimeFmt.time(usedAt)} — ${c['used_by_name'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إغلاق')),
          if (ok) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استخدام الخصم')),
        ],
      ),
    );
    if (use != true) return;
    final r = await Cloud.db.rpc('redeem_coupon', params: {'p_code': c['code']});
    if (!mounted) return;
    switch (r) {
      case 'ok':
        await _result('🎉', 'انطبق الخصم — طبّقه على الفاتورة', c['discount_text'] as String? ?? '');
      case 'used':
        await _result('⚠️', 'مستخدم من قبل', '');
      case 'expired':
        await _result('⌛', 'منتهي الصلاحية', '');
      default:
        await _result('❌', 'الكود غير موجود', '');
    }
  }

  Future<void> _result(String icon, String title, String sub) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$icon $title'),
      content: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مسح كوبون')),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _ctrl,
                onDetect: (cap) {
                  final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
                  if (v != null) _check(v);
                },
              ),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)),
                ),
              ),
              if (_busy) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'RSM-XXXXX', labelText: 'أو اكتب الكود'),
                    onSubmitted: _check,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _check(_code.text), child: const Text('تحقق')),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
