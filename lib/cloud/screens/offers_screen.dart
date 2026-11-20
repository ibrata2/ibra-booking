import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_format.dart';
import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';

/// العروض الذكية: عرض القرب (من يمر قريب)، عروض الجيران الدورية، وعروض عامة تُرسل فوراً.
/// كل عرض يوصل للزبون ككوبون بكود وباركود ينستخدم مرة وحدة.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    final stats = ref.watch(offerStatsProvider).value ?? const {};
    final settings = ref.watch(cloudSettingsProvider).value ?? const {};
    void refresh() {
      ref.invalidate(offersProvider);
      ref.invalidate(offerStatsProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('عروض القرب والجيران')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showOfferEditor(context) == true) refresh();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('عرض جديد'),
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            children: [
              _ProximitySettings(row: settings),
              const SectionTitle('العروض'),
              ...offers.when(
                loading: () => [const Center(child: CircularProgressIndicator())],
                error: (e, _) => [EmptyState(icon: Icons.wifi_off_rounded, text: '$e')],
                data: (list) => list.isEmpty
                    ? [const EmptyState(icon: Icons.card_giftcard_outlined, text: 'ضيف أول عرض، مثلاً:\n«مدام صرت قريب… مر علينا والك خصم 10%»')]
                    : [for (final o in list) _OfferTile(o: o, stat: stats[(o['id'] as num).toInt()], onChanged: refresh)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.o, required this.stat, required this.onChanged});
  final CRow o;
  final (int, int)? stat;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final kind = o['kind'] as String;
    final active = o['active'] == true;
    final label = switch (kind) {
      'proximity' => '📍 عرض القرب',
      'neighbor' => '🏠 عرض الجيران — كل ${o['every_days']} يوم',
      _ => '📣 عرض عام',
    };
    final tiers = ((o['neighbor_tiers'] as List?) ?? const []).map((t) => kNeighborTiers[t] ?? t).join('، ');
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFFA000)))),
              Switch(
                value: active,
                onChanged: (v) async {
                  await Cloud.db.from('offers').update({'active': v}).eq('id', o['id'] as Object);
                  onChanged();
                },
              ),
            ],
          ),
          Text(o['title'] as String? ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if ((o['discount_text'] as String? ?? '').isNotEmpty)
            Text(o['discount_text'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF00C853))),
          if (kind == 'neighbor' && tiers.isNotEmpty) Text('للـ: $tiers', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'انرسل ${stat?.$1 ?? 0} — استُخدم ${stat?.$2 ?? 0} — صالح ${o['valid_days']} يوم',
                style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
              ),
              const Spacer(),
              if (kind != 'proximity' && active)
                TextButton.icon(
                  onPressed: () async {
                    final who = kind == 'neighbor' ? 'الجيران المطابقين' : 'كل الزبائن';
                    if (!await confirmDialog(context, title: 'إرسال الآن', message: 'ينرسل كوبون لـ $who فوراً؟', ok: 'أرسل')) return;
                    try {
                      final n = await Cloud.db.rpc('issue_offer_now', params: {'p_offer': o['id']});
                      if (context.mounted) toast(context, 'انرسل لـ $n زبون 🎁');
                      onChanged();
                    } catch (e) {
                      if (context.mounted) toast(context, 'ما انرسل: $e');
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('أرسل الآن'),
                ),
              IconButton(
                onPressed: () async {
                  if (!await confirmDialog(context, title: 'حذف العرض', message: 'الكوبونات اللي انرسلت تبقى صالحة لحد ما تنتهي.', danger: true)) {
                    return;
                  }
                  await Cloud.db.from('offers').delete().eq('id', o['id'] as Object);
                  onChanged();
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// إعدادات عرض القرب: المسافة، الساعات، والتكرار لنفس الزبون.
class _ProximitySettings extends StatefulWidget {
  const _ProximitySettings({required this.row});
  final CRow row;
  @override
  State<_ProximitySettings> createState() => _ProximitySettingsState();
}

class _ProximitySettingsState extends State<_ProximitySettings> {
  bool? _enabled;
  double? _radius;
  int? _from;
  int? _to;
  int? _cooldown;

  bool get _loaded => widget.row.isNotEmpty;

  Future<void> _save(Map<String, Object?> patch) async {
    try {
      await Cloud.db.from('center_settings').update({...patch, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', 1);
    } catch (e) {
      if (mounted) toast(context, 'ما انحفظ: $e');
    }
  }

  Future<int?> _pickMinute(int current) async {
    final t = await pickTime12(context, TimeOfDay(hour: current ~/ 60, minute: current % 60));
    return t == null ? null : t.hour * 60 + t.minute;
  }

  String _fmt(int m) => TimeFmt.time(DateTime(2026, 1, 1, m ~/ 60, m % 60));

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final r = widget.row;
    final enabled = _enabled ?? (r['proximity_enabled'] != false);
    final radius = _radius ?? ((r['proximity_radius_m'] as num?) ?? 500).toDouble();
    final from = _from ?? ((r['proximity_from_min'] as num?) ?? 600).toInt();
    final to = _to ?? ((r['proximity_to_min'] as num?) ?? 1260).toInt();
    final cooldown = _cooldown ?? ((r['proximity_cooldown_d'] as num?) ?? 7).toInt();
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: enabled,
            title: const Text('عروض القرب شغالة', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('من يمر زبون مفعّلها قريب من المركز يوصله عرض القرب'),
            onChanged: (v) {
              setState(() => _enabled = v);
              _save({'proximity_enabled': v});
            },
          ),
          Text('المسافة: ${radius.round()} متر'),
          Slider(
            value: radius.clamp(150, 3000),
            min: 150,
            max: 3000,
            divisions: 57,
            label: '${radius.round()} م',
            onChanged: (v) => setState(() => _radius = v),
            onChangeEnd: (v) => _save({'proximity_radius_m': v.round()}),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final m = await _pickMinute(from);
                    if (m == null) return;
                    setState(() => _from = m);
                    _save({'proximity_from_min': m});
                  },
                  child: Text('من ${_fmt(from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final m = await _pickMinute(to);
                    if (m == null) return;
                    setState(() => _to = m);
                    _save({'proximity_to_min': m});
                  },
                  child: Text('لحد ${_fmt(to)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: [1, 3, 7, 14, 30].contains(cooldown) ? cooldown : 7,
            decoration: const InputDecoration(labelText: 'لنفس الزبون مرة وحدة كل'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('يوم')),
              DropdownMenuItem(value: 3, child: Text('3 أيام')),
              DropdownMenuItem(value: 7, child: Text('أسبوع')),
              DropdownMenuItem(value: 14, child: Text('أسبوعين')),
              DropdownMenuItem(value: 30, child: Text('شهر')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cooldown = v);
              _save({'proximity_cooldown_d': v});
            },
          ),
        ],
      ),
    );
  }
}

Future<bool?> showOfferEditor(BuildContext context) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _OfferEditor(),
);

class _OfferEditor extends StatefulWidget {
  const _OfferEditor();
  @override
  State<_OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends State<_OfferEditor> {
  String _kind = 'proximity';
  final _title = TextEditingController(text: 'مدام صرت قريب على روسم… مر علينا 🌸');
  final _discount = TextEditingController(text: 'خصم 10%');
  final _body = TextEditingController();
  final _tiers = <String>{'building', 'near'};
  int _every = 30;
  int _valid = 3;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _discount.dispose();
    _body.dispose();
    super.dispose();
  }

  void _setKind(String k) {
    setState(() {
      _kind = k;
      if (k == 'proximity') {
        _title.text = 'مدام صرت قريب على روسم… مر علينا 🌸';
        _valid = 3;
      } else if (k == 'neighbor') {
        _title.text = 'هدية الجيران الشهرية 🏠';
        _valid = 14;
      } else {
        _title.text = 'عرض خاص إلك 🎁';
        _valid = 7;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Cloud.db.from('offers').insert({
        'kind': _kind,
        'title': _title.text.trim(),
        'discount_text': _discount.text.trim(),
        'body': _body.text.trim(),
        'neighbor_tiers': _kind == 'neighbor' ? _tiers.toList() : <String>[],
        'every_days': _every,
        'valid_days': _valid,
        'sound': 'rs_gift',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, 'ما انحفظ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('عرض جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'proximity', label: Text('القرب')),
              ButtonSegment(value: 'neighbor', label: Text('الجيران')),
              ButtonSegment(value: 'general', label: Text('عام')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _setKind(s.first),
          ),
          const SizedBox(height: 6),
          Text(
            switch (_kind) {
              'proximity' => 'يوصل للزبون من يمر قريب من المركز (حسب الإعدادات فوق).',
              'neighbor' => 'يوصل تلقائياً للي بيوتهم قريبة، بشكل دوري.',
              _ => 'ترسله بنفسك لكل الزبائن بزر «أرسل الآن».',
            },
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'نص العرض')),
          const SizedBox(height: 10),
          TextField(controller: _discount, decoration: const InputDecoration(labelText: 'الخصم (مثلاً: خصم 10%)')),
          const SizedBox(height: 10),
          TextField(controller: _body, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
          if (_kind == 'neighbor') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final e in kNeighborTiers.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _tiers.contains(e.key),
                    onSelected: (v) => setState(() => v ? _tiers.add(e.key) : _tiers.remove(e.key)),
                  ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: _every,
              decoration: const InputDecoration(labelText: 'يتكرر كل'),
              items: const [
                DropdownMenuItem(value: 7, child: Text('أسبوع')),
                DropdownMenuItem(value: 14, child: Text('أسبوعين')),
                DropdownMenuItem(value: 30, child: Text('شهر')),
                DropdownMenuItem(value: 60, child: Text('شهرين')),
              ],
              onChanged: (v) => setState(() => _every = v ?? 30),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _valid,
            decoration: const InputDecoration(labelText: 'الكوبون صالح لمدة'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('يوم')),
              DropdownMenuItem(value: 3, child: Text('3 أيام')),
              DropdownMenuItem(value: 7, child: Text('أسبوع')),
              DropdownMenuItem(value: 14, child: Text('أسبوعين')),
              DropdownMenuItem(value: 30, child: Text('شهر')),
            ],
            onChanged: (v) => setState(() => _valid = v ?? 7),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ العرض')),
        ],
      ),
    ),
  );
}
