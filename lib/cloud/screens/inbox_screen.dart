import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_format.dart';
import '../../presentation/providers.dart';
import '../../presentation/screens/appointment_form_screen.dart';
import '../../presentation/widgets/common.dart';
import '../../services/file_helper.dart';
import '../../services/launcher_service.dart';
import '../cloud.dart';
import '../cloud_providers.dart';
import 'cloud_hub_screen.dart';

/// صندوق محادثات المركز: كل الموظفين يشوفونه، وأي واحد متوفر يرد.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);
    final customers = ref.watch(cloudCustomersProvider).value ?? const {};
    final names = ref.watch(staffNamesProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات')),
      body: AppBackground(
        child: convs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.wifi_off_rounded, text: '$e'),
          data: (list) {
            final active = list.where((c) => (c['last_message'] as String? ?? '').isNotEmpty).toList();
            if (active.isEmpty) return const EmptyState(icon: Icons.forum_outlined, text: 'ما وصلت رسائل بعد');
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
              itemCount: active.length,
              itemBuilder: (_, i) {
                final c = active[i];
                final cu = customers[c['customer_id']];
                final unread = (c['unread_staff'] as num?)?.toInt() ?? 0;
                final at = DateTime.tryParse('${c['last_message_at']}')?.toLocal() ?? DateTime.now();
                final handler = c['handling_staff'] as String?;
                final until = DateTime.tryParse('${c['handling_until']}')?.toLocal();
                final busy = handler != null && handler != Cloud.user?.id && until != null && until.isAfter(DateTime.now());
                return Glass(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffChatScreen(conversationId: c['id'] as String))),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF2F6BFF).withValues(alpha: 0.25),
                        child: Text(((cu?['name'] as String?) ?? '؟').characters.firstOrNull ?? '؟'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (cu?['name'] as String?)?.isNotEmpty == true ? cu!['name'] as String : 'زبون',
                              style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, fontSize: 15.5),
                            ),
                            Text(
                              c['last_message'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).hintColor),
                            ),
                            if (busy)
                              Text('✍️ ${names[handler] ?? 'موظف'} يرد هسه', style: const TextStyle(fontSize: 12, color: Color(0xFFFFA000))),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(cloudTime(at, true), style: TextStyle(fontSize: 11.5, color: Theme.of(context).hintColor)),
                          const SizedBox(height: 4),
                          if (unread > 0) Badge(label: Text('$unread')),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class StaffChatScreen extends ConsumerStatefulWidget {
  const StaffChatScreen({super.key, required this.conversationId});
  final String conversationId;
  @override
  ConsumerState<StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends ConsumerState<StaffChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;
  DateTime _lastClaim = DateTime(2000);
  String? _otherHandler;

  String get _conv => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _markRead();
    _claim(force: true);
    _text.addListener(() {
      if (_text.text.isNotEmpty) _claim();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await Cloud.db.rpc('mark_read_staff', params: {'p_conv': _conv});
    } catch (_) {}
  }

  /// «فلان يرد هسه»: نحجز المحادثة دقيقتين ونجددها أثناء الكتابة.
  Future<void> _claim({bool force = false}) async {
    if (!force && DateTime.now().difference(_lastClaim) < const Duration(seconds: 40)) return;
    _lastClaim = DateTime.now();
    try {
      final other = await Cloud.db.rpc('claim_conversation', params: {'p_conv': _conv});
      if (mounted) setState(() => _otherHandler = other as String?);
    } catch (_) {}
  }

  Future<void> _send({String kind = 'text', String body = '', String? imageUrl, String? refId}) async {
    await Cloud.db.from('messages').insert({
      'conversation_id': _conv,
      'sender': 'staff',
      'kind': kind,
      'body': body,
      'image_url': ?imageUrl,
      'ref_id': ?refId,
    });
  }

  Future<void> _sendText() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    if (_otherHandler != null &&
        !await confirmDialog(context, title: 'انتبه', message: '$_otherHandler يرد على هالزبون هسه. ترسل رغم ذلك؟', ok: 'أرسل')) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _send(body: t);
      _text.clear();
    } catch (e) {
      if (mounted) toast(context, 'ما انرسلت: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final f = await FileHelper.pickOne(type: FileType.image);
    if (f == null) return;
    setState(() => _sending = true);
    try {
      final url = await Cloud.upload('chat', File(f.$1), folder: 'staff');
      await _send(kind: 'image', imageUrl: url);
    } catch (e) {
      if (mounted) toast(context, 'ما انرسلت الصورة: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// سجّل حجز من المحادثة: نفس نموذج الحجز (خدمة، موظف، أوقات فارغة)، وبعدها يوصل للزبون كبطاقة.
  Future<void> _book(CRow? customer) async {
    final id = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => AppointmentFormScreen(customer: cloudCustomer(customer))));
    if (id == null || !mounted) return;
    final a = await ref.read(appointmentRepoProvider).byId(id);
    if (a == null || customer == null) return;
    final staff = await ref.read(staffRepoProvider).all();
    final services = await ref.read(serviceRepoProvider).all();
    final staffName = staff.where((s) => s.id == a.staffId).map((s) => s.name).firstOrNull ?? '';
    final serviceName = services.where((s) => s.id == a.serviceId).map((s) => s.name).firstOrNull ?? '';
    try {
      final row = await Cloud.db
          .from('bookings')
          .insert({
            'customer_id': customer['id'],
            'service_name': serviceName,
            'staff_name': staffName,
            'start_at': a.start.toUtc().toIso8601String(),
            'end_at': a.end.toUtc().toIso8601String(),
            'price': a.fee,
            'notes': a.notes,
            'local_appointment_id': id,
            'created_by': Cloud.user?.id,
          })
          .select()
          .single();
      final summary = [
        if (serviceName.isNotEmpty) '💇 $serviceName',
        '📅 ${TimeFmt.dateLong(a.start)}',
        '🕘 ${TimeFmt.range(a.start, a.end)}',
        if (staffName.isNotEmpty) '👤 $staffName',
        if (a.fee > 0) '💵 ${a.fee.round()} د.ع',
      ].join('\n');
      await _send(kind: 'booking', body: summary, refId: row['id'] as String?);
      if (mounted) toast(context, 'انحفظ الحجز ووصل للزبون ✓');
    } catch (e) {
      if (mounted) toast(context, 'انحفظ الحجز بالجهاز بس ما وصل للزبون: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatMessagesProvider(_conv));
    final customers = ref.watch(cloudCustomersProvider).value ?? const {};
    final conv = (ref.watch(conversationsProvider).value ?? const []).where((c) => c['id'] == _conv).firstOrNull;
    final customer = conv == null ? null : customers[conv['customer_id']];
    final names = ref.watch(staffNamesProvider).value ?? const {};
    ref.listen(chatMessagesProvider(_conv), (_, _) => _markRead());
    final handler = conv?['handling_staff'] as String?;
    final until = DateTime.tryParse('${conv?['handling_until']}')?.toLocal();
    final otherBusy = handler != null && handler != Cloud.user?.id && until != null && until.isAfter(DateTime.now());
    final phone = (customer?['phone'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text((customer?['name'] as String?) ?? 'زبون'),
            if (phone.isNotEmpty) Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (phone.isNotEmpty) IconButton(onPressed: () => Launcher.call(phone), icon: const Icon(Icons.call_rounded)),
          IconButton(tooltip: 'سجّل حجز', onPressed: () => _book(customer), icon: const Icon(Icons.event_available_rounded)),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (otherBusy)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFFFFA000).withValues(alpha: 0.2),
                  child: Text('✍️ ${names[handler] ?? 'موظف'} يرد هسه على هالزبون', textAlign: TextAlign.center),
                ),
              Expanded(
                child: msgs.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => EmptyState(icon: Icons.wifi_off_rounded, text: '$e'),
                  data: (list) {
                    final rev = list.reversed.toList();
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: rev.length,
                      itemBuilder: (_, i) => _StaffBubble(m: rev[i], names: names),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Glass(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  radius: 26,
                  child: Row(
                    children: [
                      IconButton(onPressed: _sending ? null : _sendImage, icon: const Icon(Icons.image_rounded)),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'اكتب الرد…',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton.filled(onPressed: _sending ? null : _sendText, icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffBubble extends StatelessWidget {
  const _StaffBubble({required this.m, required this.names});
  final CRow m;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final fromCustomer = m['sender'] == 'customer';
    final kind = m['kind'] as String? ?? 'text';
    final at = DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now();
    final who = fromCustomer ? null : names[m['staff_user']];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: fromCustomer ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: kind == 'booking'
              ? const Color(0xFF00C853).withValues(alpha: 0.18)
              : fromCustomer
              ? (dark ? Colors.white.withValues(alpha: 0.08) : Colors.white)
              : const Color(0xFF2F6BFF).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (who != null && who.isNotEmpty) Text(who, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white70)),
            if (kind == 'booking') const Text('📅 حجز مثبّت', style: TextStyle(fontWeight: FontWeight.w800)),
            if (kind == 'image' && m['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => Launcher.open(m['image_url'] as String),
                  child: Image.network(m['image_url'] as String, width: 220, fit: BoxFit.cover),
                ),
              ),
            if ((m['body'] as String? ?? '').isNotEmpty) SelectableText(m['body'] as String, style: const TextStyle(height: 1.45)),
            Text(cloudTime(at, true), style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
