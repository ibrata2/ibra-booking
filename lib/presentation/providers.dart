import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/sqlite_repositories.dart';
import '../domain/entities/entities.dart';
import '../domain/repositories.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/sound_service.dart';

/// يتم استبدالها عند الإقلاع بالقيم المهيأة (main.dart).
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('database not initialized'));
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());
final notificationServiceProvider = Provider<NotificationService>((ref) => throw UnimplementedError('notifications not initialized'));

final appointmentRepoProvider = Provider<AppointmentRepository>((ref) => SqliteAppointmentRepository(ref.watch(databaseProvider).db));
final customerRepoProvider = Provider<CustomerRepository>((ref) => SqliteCustomerRepository(ref.watch(databaseProvider).db));
final categoryRepoProvider = Provider<CategoryRepository>((ref) => SqliteCategoryRepository(ref.watch(databaseProvider).db));
final soundRepoProvider = Provider<SoundRepository>((ref) => SqliteSoundRepository(ref.watch(databaseProvider).db));
final financeRepoProvider = Provider<FinanceRepository>((ref) => SqliteFinanceRepository(ref.watch(databaseProvider).db));
final attachmentRepoProvider = Provider<AttachmentRepository>((ref) => SqliteAttachmentRepository(ref.watch(databaseProvider).db));
final staffRepoProvider = Provider<StaffRepository>((ref) => SqliteStaffRepository(ref.watch(databaseProvider).db));
final serviceRepoProvider = Provider<ServiceRepository>((ref) => SqliteServiceRepository(ref.watch(databaseProvider).db));
final settingsRepoProvider = Provider<SettingsRepository>((ref) => SqliteSettingsRepository(ref.watch(databaseProvider).db));
final reminderLogRepoProvider = Provider<ReminderLogRepository>((ref) => SqliteReminderLogRepository(ref.watch(databaseProvider).db));

final soundServiceProvider = Provider<SoundService>((ref) => SoundService(ref.watch(soundRepoProvider)));
final backupServiceProvider = Provider<BackupService>((ref) => BackupService(ref.watch(databaseProvider).db));

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> set(AppSettings s) async {
    state = s;
    await ref.read(settingsRepoProvider).save(s);
  }

  Future<void> reload() async => state = await ref.read(settingsRepoProvider).load();
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// رقم يتغير بعد أي تعديل على البيانات ليعاد تحميل القوائم.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final dataVersionProvider = NotifierProvider<DataVersion, int>(DataVersion.new);

final appointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(appointmentRepoProvider).all();
});

final categoriesProvider = FutureProvider<List<EventCategory>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(categoryRepoProvider).all();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(customerRepoProvider).all();
});

final customSoundsProvider = FutureProvider<List<AlertSound>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(soundRepoProvider).all();
});

final staffProvider = FutureProvider<List<Staff>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(staffRepoProvider).all();
});

final servicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(serviceRepoProvider).all();
});

/// فلتر الموظف المعروض في الرئيسية والتقويم (null = الكل).
class StaffFilter extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final staffFilterProvider = NotifierProvider<StaffFilter, int?>(StaffFilter.new);

final paidTotalsProvider = FutureProvider<Map<int, double>>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(financeRepoProvider).paidTotals();
});

/// ساعة تتحدث كل ثانية (للعدادات التنازلية).
final clockProvider = StreamProvider<DateTime>((ref) {
  final c = StreamController<DateTime>();
  c.add(DateTime.now());
  final t = Timer.periodic(const Duration(seconds: 1), (_) => c.add(DateTime.now()));
  ref.onDispose(() {
    t.cancel();
    c.close();
  });
  return c.stream;
});

/// حالة صلاحيات الإشعارات (تحدث عند العودة للتطبيق).
final permissionStatusProvider = FutureProvider<PermissionStatus>((ref) async {
  ref.watch(dataVersionProvider);
  return ref.watch(notificationServiceProvider).status();
});

/// المبلغ المستلم لحجز = العربون + الدفعات.
double receivedFor(Appointment a, Map<int, double> paid) => a.deposit + (paid[a.id] ?? 0);
