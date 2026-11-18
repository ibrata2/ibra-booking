import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/tr.dart';
import '../../domain/entities/entities.dart';
import '../../services/sound_service.dart';
import '../providers.dart';

String soundLabel(BuildContext context, String? key, List<AlertSound> customs) {
  if (key == null) return context.t('sound_inherit');
  if (key == 'default') return context.t('sound_default');
  if (key.startsWith('app_')) return context.t('sound_$key');
  return customs.where((s) => s.key == key).firstOrNull?.name ?? context.t('sound_app_chime');
}

/// اختيار صوت تنبيه مع معاينة.
class SoundPickerTile extends ConsumerWidget {
  const SoundPickerTile({super.key, required this.title, required this.value, required this.onChanged, this.allowInherit = false, this.icon});
  final String title;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowInherit;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customs = ref.watch(customSoundsProvider).value ?? const <AlertSound>[];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon ?? Icons.music_note_rounded),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(soundLabel(context, value, customs)),
      trailing: const Icon(Icons.expand_more_rounded),
      onTap: () async {
        final r = await showModalBottomSheet<_Pick>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _SoundSheet(current: value, allowInherit: allowInherit),
        );
        await ref.read(soundServiceProvider).stop();
        if (r != null) onChanged(r.key);
      },
    );
  }
}

class _Pick {
  final String? key;
  const _Pick(this.key);
}

class _SoundSheet extends ConsumerStatefulWidget {
  const _SoundSheet({required this.current, required this.allowInherit});
  final String? current;
  final bool allowInherit;
  @override
  ConsumerState<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends ConsumerState<_SoundSheet> {
  String? _playing;
  late final SoundService _svc = ref.read(soundServiceProvider);

  @override
  void initState() {
    super.initState();
    _svc;
  }

  @override
  void dispose() {
    _svc.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = _svc;
    final customs = ref.watch(customSoundsProvider).value ?? const <AlertSound>[];
    final vol = ref.watch(settingsProvider).previewVolume;
    final all = <AlertSound>[SoundService.systemDefault, for (final k in SoundService.builtinKeys) svc.builtin(k), ...customs];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (c, scroll) => ListView(
        controller: scroll,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(context.t('choose_sound'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          if (widget.allowInherit)
            ListTile(
              leading: Icon(widget.current == null ? Icons.radio_button_checked : Icons.radio_button_off),
              title: Text(context.t('sound_inherit')),
              onTap: () => Navigator.pop(context, const _Pick(null)),
            ),
          for (final s in all)
            ListTile(
              leading: Icon(
                widget.current == s.key ? Icons.radio_button_checked : Icons.radio_button_off,
                color: widget.current == s.key ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(soundLabel(context, s.key, customs)),
              subtitle: s.isCustom ? Text(context.t('custom_sound')) : null,
              trailing: IconButton(
                icon: Icon(_playing == s.key ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded),
                onPressed: () async {
                  if (_playing == s.key) {
                    await svc.stop();
                    setState(() => _playing = null);
                  } else {
                    setState(() => _playing = s.key);
                    await svc.preview(s, volume: vol);
                  }
                },
              ),
              onTap: () => Navigator.pop(context, _Pick(s.key)),
            ),
        ],
      ),
    );
  }
}
