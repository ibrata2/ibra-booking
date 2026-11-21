import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/notifications.dart';
import '../../services/proximity.dart';
import '../../services/push.dart';
import '../../state.dart';

/// بطاقة تفعيل الإشعارات — صياغة إيجابية وصادقة كما تطلب المتاجر.
class NotificationPermissionCard extends ConsumerStatefulWidget {
  const NotificationPermissionCard({super.key, this.onChanged});
  final VoidCallback? onChanged;
  @override
  ConsumerState<NotificationPermissionCard> createState() => _NotificationPermissionCardState();
}

class _NotificationPermissionCardState extends ConsumerState<NotificationPermissionCard> {
  bool? _on;

  @override
  void initState() {
    super.initState();
    LocalNotifications.enabled().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  Future<void> _enable() async {
    final ok = await LocalNotifications.requestPermission();
    if (ok) {
      await PushService.attach(ref.read(repoProvider), promos: ref.read(profileProvider).promoOptIn);
    }
    if (!mounted) return;
    setState(() => _on = ok);
    widget.onChanged?.call();
    if (!ok) toast(context, 'تكدر تفعلها بعدين من إعدادات الجهاز');
  }

  @override
  Widget build(BuildContext context) => _PermCard(
    icon: Icons.notifications_active_rounded,
    color: Brand.sky,
    title: 'الإشعارات',
    text: 'يوصلك تنبيه بصوت مميز من ننشر شغل جديد أو عرض، ومن يرد عليك المركز، وتذكير قبل موعدك.',
    done: _on == true,
    doneText: 'مفعّلة ✓',
    button: 'فعّل الإشعارات',
    onTap: _enable,
  );
}

/// بطاقة عروض القرب — تحتاج الموقع «طوال الوقت» حتى تشتغل والتطبيق مسدود.
class ProximityPermissionCard extends ConsumerStatefulWidget {
  const ProximityPermissionCard({super.key});
  @override
  ConsumerState<ProximityPermissionCard> createState() => _ProximityPermissionCardState();
}

class _ProximityPermissionCardState extends ConsumerState<ProximityPermissionCard> {
  ProximityPermission? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await ProximityService.status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _enable() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('عروض القرب 📍'),
        content: const Text(
          'حتى يوصلك العرض من تمر قريب من المركز، راح يطلب منك الجهاز صلاحية الموقع.\n\n'
          'اختار «السماح طوال الوقت» حتى تشتغل والتطبيق مسدود.\n\n'
          'ما نحفظ موقعك بالضبط — بس منطقتك التقريبية (الكرادة / بغداد) وبعدك عن المركز بالكيلو، حتى توصلك العروض اللي تخص منطقتك.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('مو هسه')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      var s = await ProximityService.request();
      if (s == ProximityPermission.foregroundOnly && mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('خطوة وحدة باقية'),
            content: const Text('من إعدادات التطبيق ← الموقع، اختار «السماح طوال الوقت» وارجع للتطبيق.', style: TextStyle(height: 1.6)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('بعدين')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('فتح الإعدادات')),
            ],
          ),
        );
        if (open == true) await ProximityService.openSettings();
      }
      s = await ProximityService.status();
      if (s == ProximityPermission.granted) {
        final c = centerOf(ref);
        await ProximityService.cacheOffer(c);
        final ok = await ProximityService.enable(c);
        await ref.read(profileProvider.notifier).save(ref.read(profileProvider).copyWith(proximityOn: ok));
        await AreaService.update(ref.read(repoProvider), c, force: true);
        if (mounted && ok) toast(context, 'تم تفعيل عروض القرب 🎁');
      }
      if (mounted) setState(() => _status = s);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _status == ProximityPermission.granted && ref.watch(profileProvider).proximityOn;
    return _PermCard(
      icon: Icons.near_me_rounded,
      color: Brand.gold,
      title: 'عروض القرب',
      text: 'من تمر قريب من مركز روسم يوصلك عرض خاص بيك، مثل خصم 10% إذا مريت علينا، وعروض تخص منطقتك.',
      done: on,
      doneText: 'مفعّلة ✓',
      button: _busy ? 'لحظة…' : 'فعّل عروض القرب',
      onTap: _busy ? null : _enable,
      footer: on ? null : 'إذا ما فعّلتها، بس عروض القرب ما توصلك — باقي العروض والمنشورات توصلك عادي.',
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.done,
    required this.doneText,
    required this.button,
    required this.onTap,
    this.footer,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final bool done;
  final String doneText;
  final String button;
  final VoidCallback? onTap;
  final String? footer;

  @override
  Widget build(BuildContext context) => Glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (done) Text(doneText, style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(height: 1.55, color: Colors.white.withValues(alpha: 0.78))),
        if (!done) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onTap, child: Text(button)),
          if (footer != null) ...[
            const SizedBox(height: 8),
            Text(footer!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ],
        ],
      ],
    ),
  );
}
