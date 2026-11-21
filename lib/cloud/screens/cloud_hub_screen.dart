import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../presentation/providers.dart';
import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';
import 'center_settings_screen.dart';
import 'inbox_screen.dart';
import 'offers_screen.dart';
import 'posts_screen.dart';
import 'scan_screen.dart';
import 'staff_accounts_screen.dart';
import 'works_admin_screen.dart';

/// «تطبيق الزبائن»: الربط بين نسخة المركز وتطبيق روسم للتجميل.
class CloudHubScreen extends ConsumerWidget {
  const CloudHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Cloud.ready) return const CloudSetupScreen();
    ref.watch(cloudSessionProvider);
    if (Cloud.user == null) return const CloudLoginScreen();
    final me = ref.watch(staffMeProvider);
    return me.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => _Scaffold(
        title: 'تطبيق الزبائن',
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          text: 'تعذر الاتصال\n$e',
          action: FilledButton(onPressed: () => ref.read(cloudSessionProvider.notifier).bump(), child: const Text('حاول مرة ثانية')),
        ),
      ),
      data: (m) => m == null ? const _NotStaff() : _Hub(me: m),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: AppBackground(child: SafeArea(child: child)),
  );
}

class _Hub extends ConsumerWidget {
  const _Hub({required this.me});
  final StaffMe me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadStaffProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget tile(IconData icon, Color color, String title, String sub, VoidCallback onTap, {int badge = 0}) => Glass(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color),
            ),
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
          const Icon(Icons.chevron_left_rounded),
        ],
      ),
    );

    return _Scaffold(
      title: 'تطبيق الزبائن',
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v != 'delete') return;
            final ok = await confirmDialog(
              context,
              title: 'حذف حسابي',
              message: 'ينحذف حساب ${me.name} نهائياً ويطلع من تطبيق الزبائن. الحجوزات بالجهاز تبقى. هذا الإجراء ما يرجع.',
              ok: 'احذف',
              danger: true,
            );
            if (!ok) return;
            try {
              await Cloud.db.rpc('delete_my_account');
              await Cloud.signOut();
              ref.read(cloudSessionProvider.notifier).bump();
              if (context.mounted) toast(context, 'انحذف الحساب');
            } catch (e) {
              if (context.mounted) toast(context, 'ما انحذف: $e');
            }
          },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف حسابي'))],
        ),
        IconButton(
          tooltip: 'تسجيل خروج',
          onPressed: () async {
            if (!await confirmDialog(context, title: 'تسجيل خروج', message: 'تطلع من حساب ${me.name}؟')) return;
            await Cloud.signOut();
            ref.read(cloudSessionProvider.notifier).bump();
          },
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text('أهلاً ${me.name}${me.admin ? ' — مدير' : ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('كل شي تسويه هنا يوصل لتطبيق «روسم للتجميل» عند الزبائن فوراً.', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 14),
          tile(Icons.forum_rounded, const Color(0xFF2F6BFF), 'المحادثات', 'رد على الزبائن وسجّل حجوزاتهم', () => go(const InboxScreen()), badge: unread),
          tile(Icons.qr_code_scanner_rounded, const Color(0xFF00C853), 'مسح كوبون', 'امسح باركود الهدية أو اكتب الكود', () => go(const ScanScreen())),
          tile(Icons.campaign_rounded, const Color(0xFFEC407A), 'المنشورات والعروض', 'الصق رابط انستا/فيس أو اكتب عرض — يوصل إشعار للكل', () => go(const PostsScreen())),
          tile(Icons.card_giftcard_rounded, const Color(0xFFFFA000), 'عروض القرب والجيران', 'خصومات تلقائية بالكود والباركود', () => go(const OffersScreen())),
          tile(Icons.photo_library_rounded, const Color(0xFF7C4DFF), 'أعمالنا', 'صور الشغل اللي تطلع للزبائن', () => go(const WorksAdminScreen())),
          tile(Icons.storefront_rounded, const Color(0xFF00ACC1), 'معلومات المركز', 'الموقع، أصوات التوجيه، خطوات المول، إظهار الأسماء', () => go(const CenterSettingsScreen())),
          tile(Icons.sync_rounded, const Color(0xFF78909C), 'مزامنة الخدمات', 'ترفع خدمات المركز وأسعارها للتطبيق', () => _syncServices(context, ref)),
          if (me.admin) tile(Icons.badge_rounded, const Color(0xFF3D7BFF), 'حسابات الموظفين', 'أضف موظف حتى يرد على المحادثات', () => go(const StaffAccountsScreen())),
        ],
      ),
    );
  }

  Future<void> _syncServices(BuildContext context, WidgetRef ref) async {
    try {
      final services = await ref.read(serviceRepoProvider).all();
      final rows = [
        for (final s in services)
          {'id': s.id, 'name': s.name, 'duration_min': s.durationMin, 'price': s.price, 'color': s.color, 'sort': s.sort, 'active': s.active},
      ];
      if (rows.isNotEmpty) await Cloud.db.from('public_services').upsert(rows);
      final ids = services.map((s) => s.id).whereType<int>().toList();
      if (ids.isEmpty) {
        await Cloud.db.from('public_services').delete().gte('id', 0);
      } else {
        await Cloud.db.from('public_services').delete().not('id', 'in', '(${ids.join(',')})');
      }
      if (context.mounted) toast(context, 'تمت مزامنة ${services.length} خدمة ✓');
    } catch (e) {
      if (context.mounted) toast(context, 'فشلت المزامنة: $e');
    }
  }
}

class _NotStaff extends ConsumerWidget {
  const _NotStaff();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Scaffold(
    title: 'تطبيق الزبائن',
    child: EmptyState(
      icon: Icons.lock_person_rounded,
      text: 'هذا الحساب مو مسجل كموظف بالمركز.\nخلي المدير يضيفك من «حسابات الموظفين».',
      action: FilledButton(
        onPressed: () async {
          await Cloud.signOut();
          ref.read(cloudSessionProvider.notifier).bump();
        },
        child: const Text('تسجيل خروج'),
      ),
    ),
  );
}

/// أول مرة: عنوان قاعدة البيانات ومفتاحها (من Supabase → Project Settings → API).
class CloudSetupScreen extends ConsumerStatefulWidget {
  const CloudSetupScreen({super.key});
  @override
  ConsumerState<CloudSetupScreen> createState() => _CloudSetupScreenState();
}

class _CloudSetupScreenState extends ConsumerState<CloudSetupScreen> {
  final _url = TextEditingController(text: Cloud.config.url);
  final _key = TextEditingController(text: Cloud.config.anonKey);
  bool _saved = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
    title: 'ربط تطبيق الزبائن',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Icon(Icons.hub_rounded, size: 56, color: Color(0xFF2F6BFF)),
        const SizedBox(height: 10),
        const Text(
          'اكتب عنوان ومفتاح قاعدة البيانات من Supabase\n(Project Settings ← API) — نفس القيم اللي بتطبيق الزبائن.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _url,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Project URL', hintText: 'https://xxxx.supabase.co'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          textDirection: TextDirection.ltr,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'anon public key'),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            final c = CloudConfig(url: _url.text.trim(), anonKey: _key.text.trim());
            if (!c.valid) {
              toast(context, 'تأكد من العنوان والمفتاح');
              return;
            }
            await c.save(ref.read(databaseProvider).db);
            setState(() => _saved = true);
          },
          child: const Text('حفظ'),
        ),
        if (_saved) ...[
          const SizedBox(height: 14),
          const Glass(
            child: Text('انحفظ ✓ — سد التطبيق وافتحه من جديد حتى يتفعل الربط.', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    ),
  );
}

class CloudLoginScreen extends ConsumerStatefulWidget {
  const CloudLoginScreen({super.key});
  @override
  ConsumerState<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends ConsumerState<CloudLoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _name = TextEditingController();
  bool _first = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _pw.text.length < 6) {
      toast(context, 'اكتب البريد وكلمة سر (6 أحرف على الأقل)');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_first) {
        final ok = await Cloud.signUpFirstAdmin(_email.text, _pw.text, _name.text);
        if (!ok && mounted) toast(context, 'المدير مسجل من قبل — خلي يضيفك من حسابات الموظفين');
      } else {
        await Cloud.signIn(_email.text, _pw.text);
      }
      ref.read(cloudSessionProvider.notifier).bump();
    } catch (e) {
      if (mounted) toast(context, 'ما تم الدخول: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Scaffold(
    title: 'دخول الموظف',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Icon(Icons.support_agent_rounded, size: 56, color: Color(0xFF2F6BFF)),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('دخول')),
            ButtonSegment(value: true, label: Text('أول مرة (حساب المدير)')),
          ],
          selected: {_first},
          onSelectionChanged: (s) => setState(() => _first = s.first),
        ),
        const SizedBox(height: 16),
        if (_first) ...[
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسمك (يطلع للزبون إذا فعّلت إظهار الأسماء)')),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _pw, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة السر')),
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'لحظة…' : (_first ? 'إنشاء حساب المدير' : 'دخول'))),
        const SizedBox(height: 10),
        Text(
          'أول حساب ينسوه يصير المدير، وبعدها المدير يضيف باقي الموظفين.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
        ),
      ],
    ),
  );
}

/// تنسيق مختصر لوقت الرسائل.
String cloudTime(DateTime t, bool ar) {
  final now = DateTime.now();
  if (t.year == now.year && t.month == now.month && t.day == now.day) return TimeFmt.time(t, ar: ar);
  return '${t.day}/${t.month} ${TimeFmt.time(t, ar: ar)}';
}

/// زبون الإنترنت كزبون محلي (لنموذج الحجز).
Customer cloudCustomer(CRow? c) => Customer(name: (c?['name'] as String?) ?? '', phone: (c?['phone'] as String?) ?? '', createdAt: DateTime.now());
