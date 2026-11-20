import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state.dart';

/// محادثة الزبون ويا المركز. أي موظف متوفر يرد، والاسم يطلع إذا المركز فعّل هالخيار.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(repoProvider).sendText(t);
      _text.clear();
    } catch (_) {
      if (mounted) toast(context, 'ما انرسلت — تأكد من الإنترنت');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('من المعرض'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('تصوير'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(repoProvider).sendImage(File(x.path));
    } catch (_) {
      if (mounted) toast(context, 'ما انرسلت الصورة');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إبلاغ عن المحادثة'),
        content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(hintText: 'شنو المشكلة؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repoProvider).report(reason.text.trim());
      if (mounted) toast(context, 'وصل البلاغ، شكراً إلك');
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(messagesProvider);
    final visible = ref.watch(tabProvider) == Tabs.chat;
    ref.listen(messagesProvider, (_, next) {
      if (ref.read(tabProvider) == Tabs.chat) ref.read(repoProvider).markRead();
    });
    ref.listen(tabProvider, (_, t) {
      if (t == Tabs.chat) ref.read(repoProvider).markRead();
    });
    final c = centerOf(ref);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Brand.blue, Color(0xFF1B3FB8)]),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(child: Text('ر', style: TextStyle(fontFamily: 'ReemKufi', fontSize: 22, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('اكتب شنو تحتاج ونثبتلك موعدك', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'report') _report();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('إبلاغ'))],
                ),
              ],
            ),
          ),
          Expanded(
            child: msgs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const EmptyState(icon: Icons.wifi_off_rounded, text: 'تعذر تحميل المحادثة'),
              data: (list) {
                if (visible) WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(repoProvider).markRead());
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.waving_hand_rounded, text: 'اكتب أول رسالة للمركز 🌸\nمثلاً: «أريد موعد تاتو يوم الخميس العصر»');
                }
                final rev = list.reversed.toList();
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: rev.length,
                  itemBuilder: (_, i) => _Bubble(m: rev[i], center: c.name),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 96),
            child: Glass(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              radius: 26,
              child: Row(
                children: [
                  IconButton(onPressed: _sending ? null : _attach, icon: const Icon(Icons.add_photo_alternate_rounded)),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك…',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.center});
  final ChatMessage m;
  final String center;

  @override
  Widget build(BuildContext context) {
    if (m.kind == 'booking') return _BookingCard(m: m);
    if (m.kind == 'coupon') return _GiftCard(m: m);
    final mine = m.mine;
    final who = m.sender == 'system' ? null : (m.displayName == null || m.displayName!.isEmpty ? center : '$center · ${m.displayName}');
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? Brand.blue.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: Radius.circular(mine ? 18 : 4),
            bottomEnd: Radius.circular(mine ? 4 : 18),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: mine ? 0.2 : 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && who != null)
              Text(who, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Brand.sky)),
            if (m.kind == 'image' && m.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(m.imageUrl!, width: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
                ),
              ),
            if (m.body.isNotEmpty) SelectableText(m.body, style: const TextStyle(fontSize: 15, height: 1.45)),
            const SizedBox(height: 2),
            Text(Fmt.time(m.createdAt), style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.m});
  final ChatMessage m;
  @override
  Widget build(BuildContext context) => Glass(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
    tint: Brand.green.withValues(alpha: 0.12),
    child: Column(
      children: [
        const Row(
          children: [
            Icon(Icons.event_available_rounded, color: Brand.green),
            SizedBox(width: 8),
            Text('تم تثبيت موعدك ✅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        const Divider(height: 18),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(m.body, style: const TextStyle(height: 1.6))),
      ],
    ),
  );
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.m});
  final ChatMessage m;
  @override
  Widget build(BuildContext context) => Glass(
    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
    tint: Brand.gold.withValues(alpha: 0.12),
    child: Row(
      children: [
        const Icon(Icons.card_giftcard_rounded, color: Brand.gold),
        const SizedBox(width: 10),
        Expanded(child: Text(m.body, style: const TextStyle(height: 1.5))),
      ],
    ),
  );
}
