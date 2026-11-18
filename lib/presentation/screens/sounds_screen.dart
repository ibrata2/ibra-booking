import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ibra_native/ibra_native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../domain/entities/entities.dart';
import '../../services/file_helper.dart';
import '../../services/sound_service.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/sound_picker.dart';

/// إدارة أصوات التنبيهات: استيراد، تسجيل، قص، معاينة، تسمية، حذف، وتخصيص صوت لكل نوع.
class SoundsScreen extends ConsumerStatefulWidget {
  const SoundsScreen({super.key});
  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  String? _playing;
  bool _busy = false;
  late final SoundService _svc = ref.read(soundServiceProvider);

  @override
  void dispose() {
    _svc.stop();
    super.dispose();
  }

  Future<void> _play(AlertSound s) async {
    if (_playing == s.key) {
      await _svc.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = s.key);
    await _svc.preview(s, volume: ref.read(settingsProvider).previewVolume);
  }

  Future<void> _afterChange() async {
    ref.read(dataVersionProvider.notifier).bump();
    await ref.read(bookingControllerProvider).rescheduleNotifications();
  }

  Future<void> _importFile() async {
    final picked = await FileHelper.pickOne(extensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'caf']);
    if (picked == null || !mounted) return;
    await _trimAndSave(picked.$1, p.basenameWithoutExtension(picked.$2));
  }

  Future<void> _record() async {
    final path = await showDialog<String>(context: context, barrierDismissible: false, builder: (_) => const _RecordDialog());
    if (path == null || !mounted) return;
    await _trimAndSave(path, context.t('my_recording'));
  }

  Future<void> _trimAndSave(String path, String defaultName) async {
    final r = await showDialog<_TrimResult>(
      context: context,
      builder: (_) => _TrimDialog(path: path, name: defaultName),
    );
    if (r == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _svc.import(sourcePath: path, name: r.name, startMs: r.startMs, endMs: r.endMs);
      await _afterChange();
      if (mounted) toast(context, context.t('sound_added'));
    } catch (e) {
      if (mounted) toast(context, '${context.t('sound_failed')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(AlertSound s) async {
    final c = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(d.t('rename')),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(d.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(d.t('save'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _svc.rename(s, name);
    ref.read(dataVersionProvider.notifier).bump();
  }

  Future<void> _delete(AlertSound s) async {
    if (!await confirmDialog(context, title: context.t('delete'), message: s.name, danger: true, ok: context.t('delete'))) return;
    await _svc.delete(s);
    await ref.read(notificationServiceProvider).deleteChannelsForSound(s.key);
    // إزالة الصوت المحذوف من الإعدادات
    final st = ref.read(settingsProvider);
    final map = {...st.soundByType}..removeWhere((k, v) => v == s.key);
    await ref.read(settingsProvider.notifier).set(st.copyWith(soundByType: map));
    await _afterChange();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final customs = ref.watch(customSoundsProvider).value ?? const <AlertSound>[];
    final all = <AlertSound>[SoundService.systemDefault, for (final k in SoundService.builtinKeys) _svc.builtin(k), ...customs];

    Future<void> setType(ReminderType t, String? key) async {
      final map = {...settings.soundByType};
      if (key == null) {
        map.remove(t.name);
      } else {
        map[t.name] = key;
      }
      await ref.read(settingsProvider.notifier).set(settings.copyWith(soundByType: map));
      await ref.read(bookingControllerProvider).rescheduleNotifications();
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.t('sounds'))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              SectionTitle(context.t('sound_per_type')),
              Glass(
                child: Column(
                  children: [
                    for (final t in ReminderType.values)
                      SoundPickerTile(
                        icon: Icons.notifications_rounded,
                        title: context.t('rt_${t.name}'),
                        value: settings.soundFor(t),
                        onChanged: (k) => setType(t, k),
                      ),
                  ],
                ),
              ),
              SectionTitle(context.t('sound_options')),
              Glass(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.vibrate,
                      title: Text(context.t('vibrate')),
                      secondary: const Icon(Icons.vibration_rounded),
                      onChanged: (v) async {
                        await ref.read(settingsProvider.notifier).set(settings.copyWith(vibrate: v));
                        await ref.read(bookingControllerProvider).rescheduleNotifications();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.volume_up_rounded),
                      title: Text(context.t('preview_volume')),
                      subtitle: Slider(
                        value: settings.previewVolume,
                        onChanged: (v) => ref.read(settingsProvider.notifier).set(settings.copyWith(previewVolume: v)),
                      ),
                    ),
                    Text(context.t('volume_note'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              SectionTitle(context.t('add_sound')),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _importFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(context.t('import_file')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _record,
                      icon: const Icon(Icons.mic_rounded),
                      label: Text(context.t('record_mic')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(context.t('sound_formats_note'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              SectionTitle(context.t('all_sounds')),
              for (final s in all)
                Glass(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconButton(
                      onPressed: () => _play(s),
                      icon: Icon(
                        _playing == s.key ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(soundLabel(context, s.key, customs), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      s.isCustom
                          ? '${context.t('custom_sound')} • ${TimeFmt.human(Duration(milliseconds: s.durationMs), ar: context.ar)}'
                          : s.isSystemDefault
                          ? context.t('system_sound')
                          : context.t('builtin_sound'),
                    ),
                    trailing: s.isCustom
                        ? PopupMenuButton<String>(
                            onSelected: (v) => v == 'r' ? _rename(s) : _delete(s),
                            itemBuilder: (c) => [
                              PopupMenuItem(value: 'r', child: Text(c.t('rename'))),
                              PopupMenuItem(
                                value: 'd',
                                child: Text(c.t('delete'), style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrimResult {
  final String name;
  final int startMs;
  final int endMs;
  const _TrimResult(this.name, this.startMs, this.endMs);
}

/// قص الملف الصوتي وتحديد الجزء المطلوب (حد أقصى 29 ثانية لتوافق iOS).
class _TrimDialog extends StatefulWidget {
  const _TrimDialog({required this.path, required this.name});
  final String path;
  final String name;
  @override
  State<_TrimDialog> createState() => _TrimDialogState();
}

class _TrimDialogState extends State<_TrimDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  int _duration = 0;
  RangeValues _range = const RangeValues(0, 1);
  bool _loading = true;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    IbraNative.durationMs(widget.path)
        .then((d) {
          if (!mounted) return;
          setState(() {
            _duration = d;
            _range = RangeValues(0, (d > SoundService.maxMs ? SoundService.maxMs : d).toDouble());
            _loading = false;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  void dispose() {
    IbraNative.stop();
    _name.dispose();
    super.dispose();
  }

  String _fmt(double ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${((ms % 1000) ~/ 100)}';
  }

  @override
  Widget build(BuildContext context) {
    final len = _range.end - _range.start;
    final tooLong = len > SoundService.maxMs;
    return AlertDialog(
      title: Text(context.t('trim_sound')),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: context.t('sound_name')),
                  ),
                  const SizedBox(height: 14),
                  if (_duration > 0) ...[
                    RangeSlider(
                      values: _range,
                      min: 0,
                      max: _duration.toDouble(),
                      divisions: (_duration / 100).clamp(1, 3000).toInt(),
                      labels: RangeLabels(_fmt(_range.start), _fmt(_range.end)),
                      onChanged: (v) => setState(() => _range = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(_range.start)),
                        Text(
                          '${context.t('length')}: ${_fmt(len)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: tooLong ? Colors.red : null),
                        ),
                        Text(_fmt(_range.end)),
                      ],
                    ),
                    if (tooLong) Text(context.t('max_29s'), style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (_playing) {
                          await IbraNative.stop();
                        } else {
                          await IbraNative.play(widget.path, startMs: _range.start.round(), endMs: _range.end.round());
                        }
                        setState(() => _playing = !_playing);
                      },
                      icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(context.t('preview_part')),
                    ),
                  ] else
                    Text(context.t('duration_unknown')),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('cancel'))),
        FilledButton(
          onPressed: _loading || tooLong
              ? null
              : () => Navigator.pop(
                  context,
                  _TrimResult(
                    _name.text.trim().isEmpty ? widget.name : _name.text.trim(),
                    _duration > 0 ? _range.start.round() : 0,
                    _duration > 0 ? _range.end.round() : 0,
                  ),
                ),
          child: Text(context.t('save')),
        ),
      ],
    );
  }
}

/// تسجيل صوت من الميكروفون.
class _RecordDialog extends StatefulWidget {
  const _RecordDialog();
  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _rec = AudioRecorder();
  Timer? _timer;
  int _seconds = 0;
  bool _recording = false;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, context.t('mic_denied'));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _rec.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 44100, numChannels: 1), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= 29) _stop();
    });
    setState(() {
      _recording = true;
      _seconds = 0;
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _rec.stop();
    setState(() {
      _recording = false;
      _path = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('record_mic')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded, size: 64, color: _recording ? Colors.red : Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text('00:${_seconds.toString().padLeft(2, '0')} / 00:29', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (!_recording && _path == null)
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.fiber_manual_record_rounded), label: Text(context.t('start_recording'))),
          if (_recording)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: Text(context.t('stop_recording')),
            ),
          if (_path != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => IbraNative.play(_path!),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(context.t('listen')),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    try {
                      File(_path!).deleteSync();
                    } catch (_) {}
                    setState(() {
                      _path = null;
                      _seconds = 0;
                    });
                  },
                  child: Text(context.t('retry')),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (_recording) await _rec.cancel();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(context.t('cancel')),
        ),
        FilledButton(onPressed: _path == null ? null : () => Navigator.pop(context, _path), child: Text(context.t('use_recording'))),
      ],
    );
  }
}
