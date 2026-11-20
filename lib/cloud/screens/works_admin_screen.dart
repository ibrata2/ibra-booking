import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';

/// «أعمالنا»: صور الشغل اللي تطلع بتطبيق الزبائن، مقسمة حسب الخدمة.
class WorksAdminScreen extends ConsumerStatefulWidget {
  const WorksAdminScreen({super.key});
  @override
  ConsumerState<WorksAdminScreen> createState() => _WorksAdminScreenState();
}

class _WorksAdminScreenState extends ConsumerState<WorksAdminScreen> {
  int _uploading = 0;

  Future<void> _add() async {
    final cat = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(8), child: Text('القسم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            for (final e in kWorkCategories.entries) ListTile(title: Text(e.value), onTap: () => Navigator.pop(c, e.key)),
          ],
        ),
      ),
    );
    if (cat == null) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    setState(() => _uploading = files.length);
    var ok = 0;
    for (final f in files) {
      try {
        final path = f.path;
        if (path == null) continue;
        final url = await Cloud.upload('works', File(path), folder: cat);
        await Cloud.db.from('works').insert({'category': cat, 'image_url': url});
        ok++;
      } catch (_) {}
      if (mounted) setState(() => _uploading--);
    }
    ref.invalidate(cloudWorksProvider);
    if (mounted) toast(context, 'انرفعت $ok صورة ✓');
  }

  @override
  Widget build(BuildContext context) {
    final works = ref.watch(cloudWorksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('أعمالنا')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading > 0 ? null : _add,
        icon: _uploading > 0
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_photo_alternate_rounded),
        label: Text(_uploading > 0 ? 'باقي $_uploading' : 'إضافة صور'),
      ),
      body: AppBackground(
        child: works.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.wifi_off_rounded, text: '$e'),
          data: (list) => list.isEmpty
              ? const EmptyState(icon: Icons.photo_library_outlined, text: 'ضيف صور شغلك حتى يشوفها الزبائن')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w = list[i];
                    return GestureDetector(
                      onLongPress: () async {
                        if (!await confirmDialog(context, title: 'حذف الصورة', message: 'تنحذف من تطبيق الزبائن؟', danger: true)) return;
                        await Cloud.db.from('works').delete().eq('id', w['id'] as Object);
                        ref.invalidate(cloudWorksProvider);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(w['image_url'] as String, fit: BoxFit.cover, cacheWidth: 300),
                          ),
                          PositionedDirectional(
                            bottom: 4,
                            start: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Text(kWorkCategories[w['category']] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
