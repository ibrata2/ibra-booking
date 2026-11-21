import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';

/// منو يوصله الإشعار/العرض: الكل، القريبين، الكرادة، بغداد، زبائن محددين، أو الكل ماعدا.
class Audience {
  final String kind; // all | near | karrada | baghdad | only | except
  final double nearKm;
  final Set<String> targets;
  const Audience({this.kind = 'all', this.nearKm = 2, this.targets = const {}});

  Audience copyWith({String? kind, double? nearKm, Set<String>? targets}) =>
      Audience(kind: kind ?? this.kind, nearKm: nearKm ?? this.nearKm, targets: targets ?? this.targets);

  factory Audience.fromRow(CRow? r) => Audience(
    kind: (r?['audience'] as String?) ?? 'all',
    nearKm: ((r?['near_km'] as num?) ?? 2).toDouble(),
    targets: {...((r?['target_ids'] as List?) ?? const []).map((e) => '$e')},
  );

  Map<String, Object?> toRow() => {
    'audience': kind,
    'near_km': nearKm,
    'target_ids': (kind == 'only' || kind == 'except') ? targets.toList() : <String>[],
  };

  bool get valid => !(kind == 'only' || kind == 'except') || targets.isNotEmpty;

  String get label => switch (kind) {
    'near' => 'القريبين (لحد ${_km(nearKm)} كم)',
    'karrada' => 'أهل الكرادة',
    'baghdad' => 'بغداد بس',
    'only' => 'بس ${targets.length} زبون محدد',
    'except' => 'الكل ماعدا ${targets.length}',
    _ => 'كل الزبائن',
  };

  static String _km(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
}

String areaLabel(CRow c) {
  final a = c['area'] as String?;
  final d = (c['dist_km'] as num?)?.toDouble();
  final name = switch (a) {
    'karrada' => 'الكرادة',
    'baghdad' => 'بغداد',
    'outside' => 'خارج بغداد',
    _ => '',
  };
  if (name.isEmpty) return 'الموقع مو مفعّل';
  return d == null ? name : '$name • ${Audience._km(d)} كم';
}

class AudiencePicker extends ConsumerStatefulWidget {
  const AudiencePicker({super.key, required this.value, required this.onChanged});
  final Audience value;
  final ValueChanged<Audience> onChanged;
  @override
  ConsumerState<AudiencePicker> createState() => _AudiencePickerState();
}

class _AudiencePickerState extends ConsumerState<AudiencePicker> {
  String _search = '';
  int? _count;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  @override
  void didUpdateWidget(covariant AudiencePicker old) {
    super.didUpdateWidget(old);
    final a = widget.value, b = old.value;
    if (a.kind != b.kind || a.nearKm != b.nearKm || a.targets.length != b.targets.length) _recount();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _recount() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final a = widget.value;
        final n = await Cloud.db.rpc('audience_count', params: {'aud': a.kind, 'targets': a.targets.toList(), 'near': a.nearKm});
        if (mounted) setState(() => _count = (n as num).toInt());
      } catch (_) {
        if (mounted) setState(() => _count = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.value;
    const kinds = {
      'all': 'الكل',
      'near': '📍 القريبين',
      'karrada': 'الكرادة',
      'baghdad': 'بغداد',
      'only': 'زبائن محددين',
      'except': 'الكل ماعدا',
    };
    final customers = (ref.watch(cloudCustomersProvider).value ?? const <String, CRow>{}).values
        .where((c) => (c['name'] as String? ?? '').isNotEmpty)
        .where((c) => _search.isEmpty || '${c['name']} ${c['phone']}'.contains(_search))
        .toList()
      ..sort((x, y) => '${x['name']}'.compareTo('${y['name']}'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in kinds.entries)
              ChoiceChip(label: Text(e.value), selected: a.kind == e.key, onSelected: (_) => widget.onChanged(a.copyWith(kind: e.key))),
          ],
        ),
        if (a.kind == 'near') ...[
          const SizedBox(height: 8),
          Text('لحد ${Audience._km(a.nearKm)} كم من المركز'),
          Slider(
            value: a.nearKm.clamp(0.5, 20),
            min: 0.5,
            max: 20,
            divisions: 39,
            label: '${Audience._km(a.nearKm)} كم',
            onChanged: (v) => widget.onChanged(a.copyWith(nearKm: (v * 2).round() / 2)),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          _count == null ? 'يوصل لـ: ${a.label}' : 'يوصل لـ ${a.label} — حالياً $_count زبون',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00C853)),
        ),
        if (a.kind == 'near' || a.kind == 'karrada' || a.kind == 'baghdad')
          Text(
            'حسب آخر منطقة للزبون من فتح التطبيق. اللي مطفين الموقع ما يدخلون بهالاختيار.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
          ),
        if (a.kind == 'only' || a.kind == 'except') ...[
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث بالاسم أو الرقم'),
            onChanged: (v) => setState(() => _search = v.trim()),
          ),
          const SizedBox(height: 6),
          Glass(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (customers.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('ماكو زبائن بعد')),
                for (final c in customers)
                  CheckboxListTile(
                    dense: true,
                    value: a.targets.contains(c['id']),
                    title: Text(c['name'] as String),
                    subtitle: Text('${c['phone'] ?? ''} • ${areaLabel(c)}'),
                    onChanged: (v) {
                      final t = {...a.targets};
                      v == true ? t.add(c['id'] as String) : t.remove(c['id']);
                      widget.onChanged(a.copyWith(targets: t));
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
