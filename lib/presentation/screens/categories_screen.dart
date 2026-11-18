import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';

const kPalette = <int>[
  0xFF9E9E9E,
  0xFFE53935,
  0xFF43A047,
  0xFFEC407A,
  0xFF1E88E5,
  0xFF8E24AA,
  0xFFFB8C00,
  0xFF00ACC1,
  0xFF6D4C41,
  0xFFFDD835,
  0xFF3949AB,
  0xFF00897B,
  0xFFC9A84C,
  0xFF546E7A,
  0xFFD81B60,
  0xFF7CB342,
];

/// إدارة أنواع المناسبات: إضافة، تعديل الاسم واللون والأيقونة، حذف.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ar = context.ar;
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final appts = ref.watch(appointmentsProvider).value ?? const <Appointment>[];
    return Scaffold(
      appBar: AppBar(title: Text(context.t('categories'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null, cats.length),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('add_category')),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: cats.length,
        onReorder: (from, to) async {
          final list = [...cats];
          if (to > from) to--;
          final item = list.removeAt(from);
          list.insert(to, item);
          final repo = ref.read(categoryRepoProvider);
          for (var i = 0; i < list.length; i++) {
            await repo.save(list[i].copyWith(sort: i));
          }
          ref.read(dataVersionProvider.notifier).bump();
        },
        itemBuilder: (c, i) {
          final cat = cats[i];
          final count = appts.where((a) => a.categoryId == cat.id).length;
          return Glass(
            key: ValueKey(cat.id),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            onTap: () => _edit(context, ref, cat, i),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Color(cat.color), borderRadius: BorderRadius.circular(14)),
                  child: Icon(categoryIcon(cat.icon), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name(ar), style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${context.t('bookings_count')}: $count', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final msg = count > 0 ? context.t('delete_category_used', {'n': count}) : context.t('delete_category_msg');
                    if (await confirmDialog(context, title: context.t('delete'), message: msg, danger: true, ok: context.t('delete'))) {
                      await ref.read(categoryRepoProvider).delete(cat.id!);
                      ref.read(dataVersionProvider.notifier).bump();
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                const Icon(Icons.drag_handle_rounded),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, EventCategory? cat, int sort) async {
    final nameAr = TextEditingController(text: cat?.nameAr);
    final nameEn = TextEditingController(text: cat?.nameEn);
    var color = cat?.color ?? kPalette[sort % kPalette.length];
    var icon = cat?.icon ?? 'event';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: Color(color), borderRadius: BorderRadius.circular(20)),
                    child: Icon(categoryIcon(icon), color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameAr,
                  decoration: InputDecoration(labelText: ctx.t('name_ar')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameEn,
                  decoration: InputDecoration(labelText: ctx.t('name_en')),
                ),
                const SizedBox(height: 14),
                Text(ctx.t('color'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kPalette)
                      GestureDetector(
                        onTap: () => set(() => color = c),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 3),
                            boxShadow: color == c ? [BoxShadow(color: Color(c), blurRadius: 10)] : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(ctx.t('icon'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in kCategoryIcons.entries)
                      ChoiceChip(selected: icon == e.key, onSelected: (_) => set(() => icon = e.key), label: Icon(e.value, size: 20)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('save'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final ar = nameAr.text.trim().isEmpty ? nameEn.text.trim() : nameAr.text.trim();
    if (ar.isEmpty) return;
    final repo = ref.read(categoryRepoProvider);
    if (cat == null) {
      await repo.save(EventCategory(nameAr: ar, nameEn: nameEn.text.trim(), color: color, icon: icon, sort: sort));
    } else {
      await repo.save(cat.copyWith(nameAr: ar, nameEn: nameEn.text.trim(), color: color, icon: icon));
    }
    ref.read(dataVersionProvider.notifier).bump();
    await ref.read(bookingControllerProvider).rescheduleNotifications();
  }
}
