import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common.dart';
import '../../services/file_helper.dart';
import '../cloud.dart';
import '../cloud_providers.dart';
import 'cloud_hub_screen.dart';
import '../widgets/audience_picker.dart';

/// المنشورات والعروض: تلصق رابط منشور انستا/فيس (أو تكتب عرض) → يطلع بالتطبيق ويوصل إشعار بصوت مميز.
class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(cloudPostsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('المنشورات والعروض')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostEditor())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('نشر جديد'),
      ),
      body: AppBackground(
        child: posts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.wifi_off_rounded, text: '$e'),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.campaign_outlined, text: 'ما نشرت شي بعد.\nاضغط «نشر جديد» والصق رابط منشورك.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                  children: [
                    for (final p in list)
                      Glass(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        child: Row(
                          children: [
                            Icon(
                              p['kind'] == 'offer'
                                  ? Icons.card_giftcard_rounded
                                  : p['platform'] == 'facebook'
                                  ? Icons.facebook_rounded
                                  : p['platform'] == 'instagram'
                                  ? Icons.camera_alt_rounded
                                  : Icons.article_rounded,
                              color: p['kind'] == 'offer' ? const Color(0xFFEC407A) : const Color(0xFF2F6BFF),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (p['title'] as String?)?.isNotEmpty == true ? p['title'] as String : (p['url'] as String? ?? 'منشور'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    cloudTime(DateTime.tryParse('${p['created_at']}')?.toLocal() ?? DateTime.now(), true),
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'تثبيت بالأعلى',
                              onPressed: () => Cloud.db.from('posts').update({'pinned': p['pinned'] != true}).eq('id', p['id'] as Object),
                              icon: Icon(p['pinned'] == true ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                            ),
                            IconButton(
                              tooltip: 'حذف من التطبيق',
                              onPressed: () async {
                                if (!await confirmDialog(context, title: 'حذف المنشور', message: 'ينحذف من تطبيق الزبائن؟', danger: true)) return;
                                await Cloud.db.from('posts').delete().eq('id', p['id'] as Object);
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class PostEditor extends StatefulWidget {
  const PostEditor({super.key});
  @override
  State<PostEditor> createState() => _PostEditorState();
}

class _PostEditorState extends State<PostEditor> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'post';
  String _sound = 'rs_post';
  bool _notify = true;
  bool _pinned = false;
  int _expiresDays = 0;
  String? _imagePath;
  bool _busy = false;
  Audience _aud = const Audience();

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  static String? _platform(String u) {
    final s = u.toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('instagram.com') || s.contains('instagr.am')) return 'instagram';
    if (s.contains('facebook.com') || s.contains('fb.watch') || s.contains('fb.com')) return 'facebook';
    return 'other';
  }

  Future<void> _publish() async {
    final url = _url.text.trim();
    if (url.isEmpty && _title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      toast(context, 'الصق رابط المنشور أو اكتب عنوان');
      return;
    }
    if (!_aud.valid) {
      toast(context, 'اختار الزبائن من القائمة');
      return;
    }
    setState(() => _busy = true);
    try {
      String? image;
      if (_imagePath != null) image = await Cloud.upload('works', File(_imagePath!), folder: 'posts');
      await Cloud.db.from('posts').insert({
        'kind': _kind,
        'url': url.isEmpty ? null : url,
        'platform': _platform(url),
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'image_url': image,
        'sound': _sound,
        'notify': _notify,
        'pinned': _pinned,
        'expires_at': _expiresDays == 0 ? null : DateTime.now().add(Duration(days: _expiresDays)).toUtc().toIso8601String(),
        'created_by': Cloud.user?.id,
        ..._aud.toRow(),
      });
      if (mounted) {
        toast(context, _notify ? 'انتشر ووصل إشعار لـ ${_aud.label} ✓' : 'انتشر ✓');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, 'ما انتشر: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نشر جديد')),
    body: AppBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'post', label: Text('منشور'), icon: Icon(Icons.article_rounded)),
              ButtonSegment(value: 'offer', label: Text('عرض'), icon: Icon(Icons.card_giftcard_rounded)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              _sound = _kind == 'offer' ? 'rs_offer' : 'rs_post';
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _url,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'رابط المنشور (انستغرام أو فيسبوك) — اختياري',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                tooltip: 'لصق',
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) setState(() => _url.text = d!.text!.trim());
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('المنشور لازم يكون عام حتى يطلع للزبائن داخل التطبيق.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان (يطلع بالإشعار)')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف (اختياري)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final f = await FileHelper.pickOne(type: FileType.image);
              if (f != null) setState(() => _imagePath = f.$1);
            },
            icon: const Icon(Icons.image_rounded),
            label: Text(_imagePath == null ? 'صورة (اختيارية — للعروض بدون رابط)' : 'تم اختيار صورة ✓'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _sound,
            decoration: const InputDecoration(labelText: 'صوت الإشعار'),
            items: [for (final e in kNotifSounds.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _sound = v ?? _sound),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _expiresDays,
            decoration: const InputDecoration(labelText: 'يختفي من التطبيق بعد'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('ما يختفي')),
              DropdownMenuItem(value: 1, child: Text('يوم')),
              DropdownMenuItem(value: 3, child: Text('3 أيام')),
              DropdownMenuItem(value: 7, child: Text('أسبوع')),
              DropdownMenuItem(value: 30, child: Text('شهر')),
            ],
            onChanged: (v) => setState(() => _expiresDays = v ?? 0),
          ),
          SwitchListTile(value: _notify, onChanged: (v) => setState(() => _notify = v), title: const Text('أرسل إشعار')),
          if (_notify) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('منو يوصله الإشعار', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            AudiencePicker(value: _aud, onChanged: (v) => setState(() => _aud = v)),
            const SizedBox(height: 4),
            Text('المنشور نفسه يطلع بالتطبيق للكل، والإشعار يوصل بس للي اخترتهم.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
          SwitchListTile(value: _pinned, onChanged: (v) => setState(() => _pinned = v), title: const Text('تثبيت بأعلى الصفحة')),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: const Icon(Icons.send_rounded),
            label: Text(_busy ? 'جاري النشر…' : 'انشر'),
          ),
        ],
      ),
    ),
  );
}
