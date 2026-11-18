import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/booking_controller.dart';
import '../../core/l10n/tr.dart';
import '../../core/time/time_format.dart';
import '../../services/export_service.dart';
import '../../services/file_helper.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// النسخ الاحتياطي اليدوي والتلقائي، التصدير والاستيراد (تشمل الأصوات والمرفقات).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  List<File> _auto = const [];

  @override
  void initState() {
    super.initState();
    _loadAuto();
  }

  Future<void> _loadAuto() async {
    final l = await ref.read(backupServiceProvider).autoBackups();
    if (mounted) setState(() => _auto = l);
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      if (mounted) toast(context, '${context.t('error')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    final f = await ref.read(backupServiceProvider).create();
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).set(s.copyWith(lastBackupMs: DateTime.now().millisecondsSinceEpoch));
    await ExportService.share(f, text: 'IBRA BOOKING backup');
  });

  Future<void> _restoreBytes(Uint8List buffer) async {
    final svc = ref.read(backupServiceProvider);
    Map<String, Object?> info;
    try {
      info = svc.inspect(buffer);
    } catch (_) {
      if (mounted) toast(context, context.t('invalid_backup'));
      return;
    }
    if (!mounted) return;
    final counts = (info['counts'] as Map?) ?? const {};
    final ok = await confirmDialog(
      context,
      title: context.t('restore'),
      message: context.t('restore_confirm', {'date': info['created'] ?? '', 'n': counts['appointments'] ?? 0, 'c': counts['customers'] ?? 0}),
      danger: true,
      ok: context.t('restore'),
    );
    if (!ok) return;
    await _run(() async {
      await svc.restore(buffer);
      await ref.read(soundServiceProvider).reRegisterAll();
      await ref.read(settingsProvider.notifier).reload();
      final ctrl = ref.read(bookingControllerProvider);
      ctrl.refresh();
      await ctrl.rescheduleNotifications();
      if (mounted) toast(context, context.t('restored'));
    });
  }

  Future<void> _import() async {
    final picked = await FileHelper.pickOne();
    if (picked == null) return;
    await _restoreBytes(await File(picked.$1).readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.ar;
    final s = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.t('backup'))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Glass(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF00C853)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(context.t('local_data_note'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.lastBackupMs == 0
                          ? context.t('never_backed_up')
                          : '${context.t('last_backup')}: ${TimeFmt.dateTime(DateTime.fromMillisecondsSinceEpoch(s.lastBackupMs), ar: ar)}',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(context.t('export_backup')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.cloud_download_rounded),
                label: Text(context.t('import_backup')),
              ),
              const SizedBox(height: 6),
              Text(context.t('backup_share_hint'), style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              SectionTitle(context.t('auto_backup')),
              Glass(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.autoBackup,
                      title: Text(context.t('auto_backup_daily')),
                      subtitle: Text(context.t('auto_backup_hint')),
                      onChanged: (v) => ref.read(settingsProvider.notifier).set(s.copyWith(autoBackup: v)),
                    ),
                    if (_auto.isEmpty) Text(context.t('no_auto_backups'), style: TextStyle(color: Theme.of(context).hintColor)),
                    for (final f in _auto)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history_rounded),
                        title: Text(() {
                          final ms = int.tryParse(p.basenameWithoutExtension(f.path).replaceFirst('auto_', ''));
                          return ms == null ? p.basename(f.path) : TimeFmt.dateTime(DateTime.fromMillisecondsSinceEpoch(ms), ar: ar);
                        }()),
                        subtitle: Text('${(f.lengthSync() / 1024).toStringAsFixed(0)} KB'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(onPressed: () => ExportService.share(f), icon: const Icon(Icons.share_rounded)),
                            IconButton(onPressed: () async => _restoreBytes(await f.readAsBytes()), icon: const Icon(Icons.restore_rounded)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SectionTitle(context.t('cloud')),
              Glass(
                child: Row(
                  children: [
                    const Icon(Icons.cloud_queue_rounded),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.t('cloud_future'))),
                  ],
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
