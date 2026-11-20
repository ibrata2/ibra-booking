import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../presentation/widgets/common.dart';
import '../../services/file_helper.dart';
import '../../services/launcher_service.dart';
import '../cloud.dart';
import '../cloud_providers.dart';

/// معلومات المركز كما يشوفها الزبون: الموقع، الأوقات، أصوات التوجيه، خطوات المول، وإظهار أسماء الموظفين.
class CenterSettingsScreen extends ConsumerStatefulWidget {
  const CenterSettingsScreen({super.key});
  @override
  ConsumerState<CenterSettingsScreen> createState() => _CenterSettingsScreenState();
}

class _CenterSettingsScreenState extends ConsumerState<CenterSettingsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _hours = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _apkUrl = TextEditingController();
  final _apkBuild = TextEditingController();
  bool _showNames = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _hours, _lat, _lng, _apkUrl, _apkBuild]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(CRow r) {
    if (_loaded || r.isEmpty) return;
    _loaded = true;
    _name.text = r['name'] as String? ?? '';
    _phone.text = r['phone'] as String? ?? '';
    _address.text = r['address'] as String? ?? '';
    _hours.text = r['working_hours'] as String? ?? '';
    _lat.text = '${r['lat'] ?? ''}';
    _lng.text = '${r['lng'] ?? ''}';
    _apkUrl.text = r['latest_apk_url'] as String? ?? '';
    _apkBuild.text = '${r['latest_apk_build'] ?? 0}';
    _showNames = r['show_staff_names'] == true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Cloud.db.from('center_settings').update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'working_hours': _hours.text.trim(),
        'lat': double.tryParse(_lat.text.trim()) ?? 0,
        'lng': double.tryParse(_lng.text.trim()) ?? 0,
        'show_staff_names': _showNames,
        'latest_apk_url': _apkUrl.text.trim().isEmpty ? null : _apkUrl.text.trim(),
        'latest_apk_build': int.tryParse(_apkBuild.text.trim()) ?? 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);
      if (mounted) toast(context, 'انحفظ ووصل للتطبيق ✓');
    } catch (e) {
      if (mounted) toast(context, 'ما انحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// أسهل طريقة: افتح هالشاشة وإنت واقف بباب المركز واضغط «موقعي الحالي».
  Future<void> _useMyLocation() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        if (mounted) toast(context, 'ما في صلاحية موقع');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      });
      if (mounted) toast(context, 'تم — اضغط حفظ');
    } catch (e) {
      if (mounted) toast(context, 'تعذر تحديد الموقع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(cloudSettingsProvider).value ?? const {};
    _fill(r);
    final steps = ref.watch(mallStepsAdminProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('معلومات المركز')),
      body: AppBackground(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المركز')),
                  const SizedBox(height: 10),
                  TextField(controller: _phone, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                  const SizedBox(height: 10),
                  TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'العنوان')),
                  const SizedBox(height: 10),
                  TextField(controller: _hours, decoration: const InputDecoration(labelText: 'أوقات الدوام (نص)')),
                  const SizedBox(height: 10),
                  Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SwitchListTile(
                      value: _showNames,
                      onChanged: (v) => setState(() => _showNames = v),
                      title: const Text('إظهار اسم الموظف للزبون', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('مثل: «روسم للتجميل · محمد». داخلياً ينحفظ دائماً منو رد.'),
                    ),
                  ),
                  const SectionTitle('موقع المركز (للخرائط وعروض القرب)'),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(controller: _lat, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Latitude')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(controller: _lng, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Longitude')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _useMyLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('موقعي الحالي'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Launcher.open('https://www.google.com/maps/search/?api=1&query=${_lat.text},${_lng.text}'),
                          icon: const Icon(Icons.map_rounded),
                          label: const Text('تأكد بالخريطة'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('أدق طريقة: كون واقف بباب المركز واضغط «موقعي الحالي» ثم حفظ.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  const SectionTitle('صوت التوجيه (بنت بلهجة عراقية)'),
                  _VoiceField(
                    label: 'صوت الترحيب عند «وصّلني»',
                    hint: 'مثلاً: «هلا بيك! راح أوصلك لمركز روسم بالكرادة، فرحان مول»',
                    url: r['welcome_voice_url'] as String?,
                    onChanged: (u) => Cloud.db.from('center_settings').update({'welcome_voice_url': u}).eq('id', 1),
                  ),
                  _VoiceField(
                    label: 'صوت «وصلت!»',
                    hint: 'مثلاً: «وصلت! نورتنا، تفضل ادخل»',
                    url: r['arrival_voice_url'] as String?,
                    onChanged: (u) => Cloud.db.from('center_settings').update({'arrival_voice_url': u}).eq('id', 1),
                  ),
                  SectionTitle(
                    'داخل المول لحد الباب',
                    trailing: IconButton(
                      onPressed: () async {
                        final n = (steps.value ?? const []).length + 1;
                        await _editStep(context, null, n);
                        ref.invalidate(mallStepsAdminProvider);
                      },
                      icon: const Icon(Icons.add_circle_rounded),
                    ),
                  ),
                  ...((steps.value ?? const <CRow>[]).map(
                    (s) => Glass(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onTap: () async {
                        await _editStep(context, s, (s['sort'] as num?)?.toInt() ?? 0);
                        ref.invalidate(mallStepsAdminProvider);
                      },
                      child: Row(
                        children: [
                          CircleAvatar(radius: 14, child: Text('${s['sort']}')),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s['text'] as String? ?? '')),
                          if ((s['voice_url'] as String?)?.isNotEmpty == true) const Icon(Icons.volume_up_rounded, size: 18),
                          IconButton(
                            onPressed: () async {
                              await Cloud.db.from('mall_steps').delete().eq('id', s['id'] as Object);
                              ref.invalidate(mallStepsAdminProvider);
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SectionTitle('تحديث نسخة الموقع (أندرويد)'),
                  TextField(controller: _apkUrl, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'رابط آخر APK')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apkBuild,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'رقم البناء (Build) للنسخة الجديدة'),
                  ),
                  const SizedBox(height: 4),
                  Text('الزبائن اللي عندهم نسخة أقدم يطلعلهم «نسخة جديدة جاهزة».', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'جاري الحفظ…' : 'حفظ'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _editStep(BuildContext context, CRow? s, int sort) async {
    final text = TextEditingController(text: s?['text'] as String? ?? '');
    String? voice = s?['voice_url'] as String?;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(c).bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الخطوة $sort', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TextField(controller: text, maxLines: 2, decoration: const InputDecoration(labelText: 'مثلاً: اصعد السلم المتحرك للطابق الأول')),
              const SizedBox(height: 10),
              _VoiceField(label: 'صوت الخطوة', url: voice, onChanged: (u) async => setS(() => voice = u)),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () async {
                  if (text.text.trim().isEmpty) return;
                  final row = {'sort': sort, 'text': text.text.trim(), 'voice_url': voice};
                  if (s == null) {
                    await Cloud.db.from('mall_steps').insert(row);
                  } else {
                    await Cloud.db.from('mall_steps').update(row).eq('id', s['id'] as Object);
                  }
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('حفظ الخطوة'),
              ),
            ],
          ),
        ),
      ),
    );
    text.dispose();
  }
}

/// تسجيل صوت من المايك (أو اختيار ملف صوتي) ورفعه، مع تشغيل للتجربة.
class _VoiceField extends StatefulWidget {
  const _VoiceField({required this.label, this.hint, required this.url, required this.onChanged});
  final String label;
  final String? hint;
  final String? url;
  final Future<void> Function(String? url) onChanged;
  @override
  State<_VoiceField> createState() => _VoiceFieldState();
}

class _VoiceFieldState extends State<_VoiceField> {
  final _rec = AudioRecorder();
  bool _recording = false;
  bool _busy = false;
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.url;
  }

  @override
  void dispose() {
    _rec.dispose();
    super.dispose();
  }

  Future<void> _upload(File f) async {
    setState(() => _busy = true);
    try {
      final url = await Cloud.upload('voice', f);
      await widget.onChanged(url);
      setState(() => _url = url);
      if (mounted) toast(context, 'انرفع الصوت ✓');
    } catch (e) {
      if (mounted) toast(context, 'ما انرفع: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _rec.stop();
      setState(() => _recording = false);
      if (path != null) await _upload(File(path));
      return;
    }
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, 'اسمح للتطبيق باستخدام المايك');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, numChannels: 1), path: path);
    setState(() => _recording = true);
  }

  Future<void> _pick() async {
    final f = await FileHelper.pickOne(type: FileType.custom, extensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg']);
    if (f != null) await _upload(File(f.$1));
  }

  @override
  Widget build(BuildContext context) => Glass(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (_url != null && _url!.isNotEmpty) const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 18),
          ],
        ),
        if (widget.hint != null) Text(widget.hint!, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _toggleRecord,
              icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: _recording ? Colors.redAccent : null),
              label: Text(_recording ? 'إيقاف ورفع' : 'سجّل'),
            ),
            OutlinedButton.icon(onPressed: _busy || _recording ? null : _pick, icon: const Icon(Icons.audio_file_rounded), label: const Text('ملف')),
            if (_url != null && _url!.isNotEmpty) ...[
              IconButton(onPressed: () => Launcher.open(_url!), icon: const Icon(Icons.play_arrow_rounded), tooltip: 'تشغيل'),
              IconButton(
                onPressed: () async {
                  await widget.onChanged(null);
                  setState(() => _url = null);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'حذف',
              ),
            ],
            if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ],
    ),
  );
}
