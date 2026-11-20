import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';

/// حسابات الموظفين (للمدير): كل موظف يدخل بحسابه حتى يرد على المحادثات ويمسح الكوبونات.
class StaffAccountsScreen extends ConsumerWidget {
  const StaffAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(staffMembersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حسابات الموظفين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => const _AddStaff()) == true) {
            ref.invalidate(staffMembersProvider);
            ref.invalidate(staffNamesProvider);
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('موظف جديد'),
      ),
      body: AppBackground(
        child: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.wifi_off_rounded, text: '$e'),
          data: (rows) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            children: [
              for (final s in rows)
                Glass(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SwitchListTile(
                    value: s['active'] == true,
                    title: Text(s['display_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(s['role'] == 'admin' ? 'مدير' : 'موظف'),
                    onChanged: s['user_id'] == Cloud.user?.id
                        ? null
                        : (v) async {
                            await Cloud.db.from('staff_members').update({'active': v}).eq('user_id', s['user_id'] as Object);
                            ref.invalidate(staffMembersProvider);
                          },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddStaff extends StatefulWidget {
  const _AddStaff();
  @override
  State<_AddStaff> createState() => _AddStaffState();
}

class _AddStaffState extends State<_AddStaff> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _admin = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('موظف جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم (مثلاً: محمد)')),
        const SizedBox(height: 10),
        TextField(
          controller: _email,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'بريد الدخول'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _pw, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة السر (6 أحرف أو أكثر)')),
        SwitchListTile(value: _admin, onChanged: (v) => setState(() => _admin = v), title: const Text('صلاحية مدير')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _pw.text.length < 6) {
                    toast(context, 'كمّل الاسم والبريد وكلمة السر');
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await Cloud.addStaff(email: _email.text, password: _pw.text, name: _name.text, admin: _admin);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted) toast(context, 'ما انضاف: $e');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'لحظة…' : 'إضافة'),
        ),
      ],
    ),
  );
}
