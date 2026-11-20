import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../services/media.dart';
import '../../state.dart';
import '../widgets/permission_sheets.dart';

/// أول مرة: الاسم ورقم الهاتف (حتى يعرفك المركز بالمحادثة والحجز) ثم شرح الإشعارات وعروض القرب.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _name.text = p.name;
    _phone.text = p.phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final p = ref.read(profileProvider).copyWith(name: _name.text.trim(), phone: _normalize(_phone.text));
      await ref.read(profileProvider.notifier).save(p);
      setState(() => _step = 1);
    } catch (_) {
      if (mounted) toast(context, 'ما انحفظت البيانات — تأكد من الإنترنت');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _normalize(String s) {
    var d = s.replaceAll(RegExp(r'[^0-9+٠-٩]'), '');
    const ar = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      d = d.replaceAll(ar[i], '$i');
    }
    if (d.startsWith('+964')) d = '0${d.substring(4)}';
    if (d.startsWith('00964')) d = '0${d.substring(5)}';
    return d;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _step == 0 ? _info() : _permissions()),
      ),
    ),
  );

  Widget _info() => Form(
    key: _form,
    child: ListView(
      key: const ValueKey('info'),
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
      children: [
        const Center(child: BrandTitle(size: 48)),
        const SizedBox(height: 14),
        Text(
          'أهلاً بيك 🌸\nشوف أعمالنا وعروضنا، احجز موعدك بالمحادثة، واستلم هدايا خاصة بيك.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.6, color: Colors.white.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 30),
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded)),
          validator: (v) => (v == null || v.trim().length < 2) ? 'اكتب اسمك' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'رقم الهاتف', hintText: '07XXXXXXXXX', prefixIcon: Icon(Icons.phone_rounded)),
          validator: (v) => _normalize(v ?? '').length < 10 ? 'اكتب رقم صحيح' : null,
        ),
        const SizedBox(height: 10),
        Text(
          'الرقم يشوفه المركز بس، حتى يتواصل وياك بخصوص حجزك. ما نشاركه ويا أي جهة.',
          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Text('ابدأ'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Launch.url(AppConfig.privacyUrl), child: const Text('بالاستمرار أنت موافق على سياسة الخصوصية')),
      ],
    ),
  );

  Widget _permissions() => ListView(
    key: const ValueKey('perm'),
    padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
    children: [
      const Icon(Icons.card_giftcard_rounded, size: 64, color: Brand.gold),
      const SizedBox(height: 14),
      const Text('خلي العروض توصلك', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 22),
      NotificationPermissionCard(onChanged: () => setState(() {})),
      const SizedBox(height: 12),
      const ProximityPermissionCard(),
      const SizedBox(height: 26),
      FilledButton(onPressed: widget.onDone, child: const Text('يلا نبدي')),
      const SizedBox(height: 8),
      Text(
        'تكدر تغيّر هالخيارات بأي وقت من «المزيد».',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.55)),
      ),
    ],
  );
}
