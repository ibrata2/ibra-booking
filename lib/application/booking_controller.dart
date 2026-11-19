import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/edition.dart';
import '../domain/entities/entities.dart';
import '../domain/logic/scheduling.dart';
import '../presentation/providers.dart';
import '../services/notification_service.dart';

/// حالات الاستخدام (Use cases): الحفظ، الحذف، تغيير الحالة، النقل، وإعادة جدولة التنبيهات.
class BookingController {
  BookingController(this.ref);
  final Ref ref;

  NotificationService get _notif => ref.read(notificationServiceProvider);

  /// فحص التعارض قبل الحفظ.
  Future<List<ConflictInfo>> conflicts(DateTime start, DateTime end, {Set<int> ignoreIds = const {}, int? staffId}) async {
    final all = await ref.read(appointmentRepoProvider).between(start.subtract(const Duration(days: 1)), end.add(const Duration(days: 1)));
    final travel = Duration(minutes: ref.read(settingsProvider).travelMinutes);
    return ConflictChecker.find(
      start: start,
      end: end,
      existing: all,
      ignoreIds: ignoreIds,
      travel: Edition.isCenter ? Duration.zero : travel,
      perStaff: Edition.isCenter,
      staffId: staffId,
    );
  }

  /// حفظ حجز (جديد أو تعديل)، مع إنشاء/تحديث سجل الزبون تلقائياً.
  /// [rule]: تكرار للحجز الجديد. [applyToSeries]: تطبيق التعديل على كل حجوزات السلسلة.
  Future<int> save(Appointment a, {RecurrenceRule? rule, bool applyToSeries = false}) async {
    final repo = ref.read(appointmentRepoProvider);
    final customerId = a.customerName.trim().isEmpty
        ? a.customerId
        : await ref.read(customerRepoProvider).findOrCreate(name: a.customerName, phone: a.phone, phone2: a.phone2, address: a.fullAddress);
    final now = DateTime.now();
    var item = a.copyWith(customerId: customerId, updatedAt: now, createdAt: a.id == null ? now : a.createdAt);
    int id;
    if (a.id == null && rule != null && !rule.isNone) {
      final ids = await repo.saveSeries(item, rule);
      id = ids.first;
    } else if (a.id != null && applyToSeries && a.recurrenceId != null) {
      await repo.updateSeries(a.recurrenceId!, item);
      id = a.id!;
    } else {
      id = await repo.save(item);
    }
    _bump();
    await rescheduleNotifications();
    return id;
  }

  Future<void> delete(Appointment a, {bool series = false}) async {
    final repo = ref.read(appointmentRepoProvider);
    if (series && a.recurrenceId != null) {
      for (final o in await repo.bySeries(a.recurrenceId!)) {
        if (o.id != null) await _notif.cancelForAppointment(o.id!);
      }
      await repo.deleteSeries(a.recurrenceId!);
    } else if (a.id != null) {
      await _notif.cancelForAppointment(a.id!);
      await repo.delete(a.id!);
    }
    _bump();
    await rescheduleNotifications();
  }

  Future<void> setStatus(Appointment a, BookingStatus s) async {
    await ref.read(appointmentRepoProvider).save(a.copyWith(status: s, updatedAt: DateTime.now()));
    if (s.isClosed && a.id != null) await _notif.cancelForAppointment(a.id!);
    _bump();
    await rescheduleNotifications();
  }

  /// نقل حجز لوقت جديد (السحب والإفلات) مع الحفاظ على المدة.
  Future<void> move(Appointment a, DateTime newStart, {int? staffId, bool changeStaff = false}) async {
    final d = a.duration;
    var upd = a.copyWith(start: newStart, end: newStart.add(d), updatedAt: DateTime.now());
    if (changeStaff) upd = staffId == null ? upd.copyWith(clearStaff: true) : upd.copyWith(staffId: staffId);
    await ref.read(appointmentRepoProvider).save(upd);
    _bump();
    await rescheduleNotifications();
  }

  Future<int> rescheduleNotifications() async {
    final appts = await ref
        .read(appointmentRepoProvider)
        .between(DateTime.now().subtract(const Duration(days: 1)), DateTime.now().add(const Duration(days: 60)));
    final s = ref.read(settingsProvider);
    if (Edition.isCenter) {
      final staff = await ref.read(staffRepoProvider).all();
      final services = await ref.read(serviceRepoProvider).all();
      _notif.staffNames = {for (final x in staff) x.id!: x.name};
      _notif.serviceNames = {for (final x in services) x.id!: x.name};
    }
    final mine = Edition.isCenter && s.notifyStaffId != 0 ? appts.where((a) => a.staffId == s.notifyStaffId).toList() : appts;
    return _notif.rescheduleAll(
      appointments: mine,
      settings: ref.read(settingsProvider),
      categories: await ref.read(categoryRepoProvider).all(),
      customSounds: await ref.read(soundRepoProvider).all(),
    );
  }

  void _bump() => ref.read(dataVersionProvider.notifier).bump();
  void refresh() => _bump();
}

final bookingControllerProvider = Provider<BookingController>((ref) => BookingController(ref));
