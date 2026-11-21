import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_format.dart';
import '../../presentation/widgets/common.dart';
import '../cloud.dart';
import '../cloud_providers.dart';
import '../widgets/audience_picker.dart';

/// العروض: عرض القرب (يوصل من يمر الزبون قريب) وعرض عام (ترسله بنفسك).
/// كل عرض يوصل للزبون مرة وحدة بس، وتحدد منو يستلمه ومنو لا.
/// الزبون اللي عنده هدية قرب صالحة ما يستلم غيرها لحد ما تنتهي أو يستخدمها، وبعدها يستلم العرض الجاي.
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
      appBar: AppBar(title: const Text('العروض والهدايا')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const OfferEditor())) == true) refresh();
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
                data: (all) {
                  final list = all.where((o) => o['kind'] != 'neighbor').toList();
                  return list.isEmpty
                      ? [const EmptyState(icon: Icons.card_giftcard_outlined, text: 'ضيف أول عرض، مثلاً:\n«مدام صرت قريب… مر علينا والك خصم 10%»')]
                      : [for (final o in list) _OfferTile(o: o, stat: stats[(o['id'] as num).toInt()], onChanged: refresh)];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String audienceLabel(CRow o) => '👥 ${Audience.fromRow(o).label}';

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.o, required this.stat, required this.onChanged});
  final CRow o;
  final (int, int)? stat;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final kind = o['kind'] as String;
    final active = o['active'] == true;
    return Glass(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OfferRecipientsScreen(offer: o))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kind == 'proximity' ? '📍 عرض القرب' : '📣 عرض ترسله بنفسك',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFFA000)),
                ),
              ),
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
          Text(audienceLabel(o), style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'استلمه ${stat?.$1 ?? 0} — استخدمه ${stat?.$2 ?? 0} — صالح ${o['valid_days']} يوم',
                  style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
                ),
              ),
              if (active)
                TextButton.icon(
                  onPressed: () => sendOfferNow(context, o, onChanged),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('أرسل الآن'),
                ),
              IconButton(
                onPressed: () async {
                  if (!await confirmDialog(context, title: 'حذف العرض', message: 'الهدايا اللي انرسلت تبقى صالحة لحد ما تنتهي.', danger: true)) {
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

Future<void> sendOfferNow(BuildContext context, CRow o, VoidCallback onDone) async {
  if (!await confirmDialog(
    context,
    title: 'أرسل الآن',
    message: 'ينرسل للي ما استلموا هالعرض بعد (${audienceLabel(o)})، ويوصلهم إشعار.\nاللي استلموه قبل ما يوصلهم مرة ثانية.',
    ok: 'أرسل',
  )) {
    return;
  }
  try {
    final n = await Cloud.db.rpc('issue_offer_now', params: {'p_offer': o['id']});
    if (context.mounted) toast(context, n == 0 ? 'كلهم مستلمين هالعرض من قبل' : 'انرسل لـ $n زبون 🎁');
    onDone();
  } catch (e) {
    if (context.mounted) toast(context, 'ما انرسل: $e');
  }
}

/// منو استلم العرض ومنو لا.
class OfferRecipientsScreen extends StatefulWidget {
  const OfferRecipientsScreen({super.key, required this.offer});
  final CRow offer;
  @override
  State<OfferRecipientsScreen> createState() => _OfferRecipientsScreenState();
}

class _OfferRecipientsScreenState extends State<OfferRecipientsScreen> {
  late Future<List<CRow>> _rows = _load();

  Future<List<CRow>> _load() async {
    final r = await Cloud.db.rpc('offer_recipients', params: {'p_offer': widget.offer['id']});
    return [for (final e in (r as List)) Map<String, dynamic>.from(e as Map)];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.offer['title'] as String? ?? 'العرض'),
      actions: [
        IconButton(
          tooltip: 'تعديل منو يستلم',
          onPressed: () async {
            final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => OfferEditor(offer: widget.offer)));
            if (ok == true && context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.edit_rounded),
        ),
      ],
    ),
    body: AppBackground(
      child: FutureBuilder<List<CRow>>(
        future: _rows,
        builder: (context, s) {
          if (s.hasError) return EmptyState(icon: Icons.error_outline, text: '${s.error}');
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final got = s.data!.where((r) => r['code'] != null).toList();
          final waiting = s.data!.where((r) => r['code'] == null && r['allowed'] == true).toList();
          final blocked = s.data!.where((r) => r['code'] == null && r['allowed'] != true).toList();
          String st(String? x) => switch (x) {
            'used' => '✅ استخدمه',
            'expired' => '⌛ انتهى',
            _ => '🎁 عنده (صالح)',
          };
          Widget row(CRow r, String trailing) => ListTile(
            dense: true,
            title: Text(r['name'] as String? ?? ''),
            subtitle: Text(r['phone'] as String? ?? '', textDirection: TextDirection.ltr, textAlign: TextAlign.end),
            trailing: Text(trailing),
          );
          return RefreshIndicator(
            onRefresh: () async => setState(() => _rows = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
              children: [
                Glass(
                  child: Row(
                    children: [
                      Expanded(child: Text('استلمه ${got.length} — ينتظر ${waiting.length} — ما يشملهم ${blocked.length}')),
                      if (widget.offer['active'] == true && waiting.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () => sendOfferNow(context, widget.offer, () => setState(() => _rows = _load())),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('أرسل للباقين'),
                        ),
                    ],
                  ),
                ),
                SectionTitle('استلموه (${got.length})'),
                for (final r in got) row(r, st(r['status'] as String?)),
                SectionTitle('ما استلموه بعد (${waiting.length})'),
                for (final r in waiting) row(r, '⏳'),
                if (blocked.isNotEmpty) ...[
                  SectionTitle('ما يشملهم العرض (${blocked.length})'),
                  for (final r in blocked) row(r, '🚫'),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// إعدادات عرض القرب: المسافة والساعات.
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
    final r = widget.row;
    if (r.isEmpty) return const SizedBox.shrink();
    final enabled = _enabled ?? (r['proximity_enabled'] != false);
    final radius = _radius ?? ((r['proximity_radius_m'] as num?) ?? 500).toDouble();
    final from = _from ?? ((r['proximity_from_min'] as num?) ?? 600).toInt();
    final to = _to ?? ((r['proximity_to_min'] as num?) ?? 1260).toInt();
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
          Text(
            'كل عرض يوصل للزبون مرة وحدة بس. إذا عنده هدية قرب صالحة، ما يوصله العرض الجاي إلا بعد ما يستخدمها أو تنتهي.',
            style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

/// إضافة/تعديل عرض مع اختيار منو يستلمه.
class OfferEditor extends ConsumerStatefulWidget {
  const OfferEditor({super.key, this.offer});
  final CRow? offer;
  @override
  ConsumerState<OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends ConsumerState<OfferEditor> {
  late String _kind = widget.offer?['kind'] as String? ?? 'proximity';
  late final _title = TextEditingController(text: widget.offer?['title'] as String? ?? 'مدام صرت قريب على روسم… مر علينا 🌸');
  late final _discount = TextEditingController(text: widget.offer?['discount_text'] as String? ?? 'خصم 10%');
  late final _body = TextEditingController(text: widget.offer?['body'] as String? ?? '');
  late Audience _aud = Audience.fromRow(widget.offer);
  late int _valid = (widget.offer?['valid_days'] as num?)?.toInt() ?? 3;
  bool _busy = false;

  bool get _editing => widget.offer != null;

  @override
  void dispose() {
    _title.dispose();
    _discount.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    if (!_aud.valid) {
      toast(context, 'اختار الزبائن من القائمة');
      return;
    }
    setState(() => _busy = true);
    final row = {
      'kind': _kind,
      'title': _title.text.trim(),
      'discount_text': _discount.text.trim(),
      'body': _body.text.trim(),
      ..._aud.toRow(),
      'valid_days': _valid,
      'sound': 'rs_gift',
    };
    try {
      if (_editing) {
        await Cloud.db.from('offers').update(row).eq('id', widget.offer!['id'] as Object);
      } else {
        await Cloud.db.from('offers').insert(row);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, 'ما انحفظ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'تعديل العرض' : 'عرض جديد')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'proximity', label: Text('📍 عرض القرب')),
                ButtonSegment(value: 'general', label: Text('📣 أرسله بنفسي')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                if (!_editing) _title.text = _kind == 'proximity' ? 'مدام صرت قريب على روسم… مر علينا 🌸' : 'عرض خاص إلك 🎁';
              }),
            ),
            const SizedBox(height: 6),
            Text(
              _kind == 'proximity'
                  ? 'يوصل للزبون تلقائياً من يمر قريب من المركز، وتكدر هم ترسله فوراً بزر «أرسل الآن».'
                  : 'ترسله بنفسك بزر «أرسل الآن» للزبائن اللي تختارهم.',
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'نص العرض')),
            const SizedBox(height: 10),
            TextField(controller: _discount, decoration: const InputDecoration(labelText: 'الخصم (مثلاً: خصم 10%)')),
            const SizedBox(height: 10),
            TextField(controller: _body, decoration: const InputDecoration(labelText: 'ملاحظة (اختيارية)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: [1, 3, 7, 14, 30].contains(_valid) ? _valid : 7,
              decoration: const InputDecoration(labelText: 'الهدية صالحة لمدة'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('يوم')),
                DropdownMenuItem(value: 3, child: Text('3 أيام')),
                DropdownMenuItem(value: 7, child: Text('أسبوع')),
                DropdownMenuItem(value: 14, child: Text('أسبوعين')),
                DropdownMenuItem(value: 30, child: Text('شهر')),
              ],
              onChanged: (v) => setState(() => _valid = v ?? 7),
            ),
            const SectionTitle('منو يستلم العرض'),
            AudiencePicker(value: _aud, onChanged: (v) => setState(() => _aud = v)),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'حفظ التعديل' : 'حفظ العرض')),
          ],
        ),
      ),
    );
  }
}
