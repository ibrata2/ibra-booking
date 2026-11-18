import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../domain/entities/entities.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'appointment_details_screen.dart';

/// البحث في كل الحجوزات (الاسم، الهاتف، المكان، العنوان، الملاحظات).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  List<Appointment> _results = const [];
  bool _searched = false;

  Future<void> _run(String v) async {
    if (v.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
      });
      return;
    }
    final r = await ref.read(appointmentRepoProvider).search(v);
    if (mounted) {
      setState(() {
        _results = r;
        _searched = true;
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).value ?? const <EventCategory>[];
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: _run,
          decoration: InputDecoration(
            hintText: context.t('search_hint'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _q.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _q.clear();
                      _run('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
      body: !_searched
          ? EmptyState(icon: Icons.manage_search_rounded, text: context.t('search_intro'))
          : _results.isEmpty
          ? EmptyState(icon: Icons.search_off_rounded, text: context.t('no_results'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final a in _results)
                  AppointmentTile(
                    appt: a,
                    category: cats.where((c) => c.id == a.categoryId).firstOrNull,
                    now: now,
                    showDate: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: a.id!))),
                  ),
              ],
            ),
    );
  }
}
