import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state.dart';

class WorksScreen extends ConsumerStatefulWidget {
  const WorksScreen({super.key});
  @override
  ConsumerState<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends ConsumerState<WorksScreen> {
  String _cat = 'all';

  @override
  Widget build(BuildContext context) {
    final works = ref.watch(worksProvider);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [Text('أعمالنا', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))]),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final e in workCategories.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(label: Text(e.value), selected: _cat == e.key, onSelected: (_) => setState(() => _cat = e.key)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: works.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const EmptyState(icon: Icons.wifi_off_rounded, text: 'تعذر تحميل الأعمال'),
              data: (all) {
                final list = _cat == 'all' ? all : all.where((w) => w.category == _cat).toList();
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.photo_library_outlined, text: 'قريباً نضيف هنا صور شغلنا ✨');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(worksProvider),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                    itemCount: list.length,
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => _Viewer(items: list, index: i))),
                      child: Hero(
                        tag: 'work_${list[i].id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            list[i].imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white10),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.items, required this.index});
  final List<WorkItem> items;
  final int index;
  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final _ctrl = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  Widget build(BuildContext context) {
    final w = widget.items[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black54, title: Text(workCategories[w.category] ?? '')),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Hero(tag: 'work_${widget.items[i].id}', child: Image.network(widget.items[i].imageUrl, fit: BoxFit.contain)),
          ),
        ),
      ),
      bottomNavigationBar: w.caption.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(w.caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              ),
            ),
    );
  }
}
