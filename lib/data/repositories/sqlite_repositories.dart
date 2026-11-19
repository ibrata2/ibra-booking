import 'package:sqflite/sqflite.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories.dart';

class SqliteAppointmentRepository implements AppointmentRepository {
  SqliteAppointmentRepository(this.db);
  final Database db;

  List<Appointment> _map(List<Map<String, Object?>> rows) => rows.map(Appointment.fromMap).toList();

  @override
  Future<List<Appointment>> all() async => _map(await db.query('appointments', orderBy: 'start_ms'));

  @override
  Future<List<Appointment>> between(DateTime from, DateTime to) async => _map(
    await db.query(
      'appointments',
      where: 'start_ms < ? AND end_ms > ?',
      whereArgs: [to.millisecondsSinceEpoch, from.millisecondsSinceEpoch],
      orderBy: 'start_ms',
    ),
  );

  @override
  Future<Appointment?> byId(int id) async {
    final r = await db.query('appointments', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Appointment.fromMap(r.first);
  }

  @override
  Future<List<Appointment>> byCustomer(int customerId) async =>
      _map(await db.query('appointments', where: 'customer_id = ?', whereArgs: [customerId], orderBy: 'start_ms DESC'));

  @override
  Future<List<Appointment>> bySeries(int recurrenceId) async =>
      _map(await db.query('appointments', where: 'recurrence_id = ?', whereArgs: [recurrenceId], orderBy: 'start_ms'));

  @override
  Future<List<Appointment>> search(String query) async {
    final q = '%${query.trim()}%';
    return _map(
      await db.query(
        'appointments',
        where:
            'customer_name LIKE ? OR phone LIKE ? OR phone2 LIKE ? OR place_name LIKE ? OR address LIKE ? OR area LIKE ? OR province LIKE ? OR notes LIKE ?',
        whereArgs: List.filled(8, q),
        orderBy: 'start_ms DESC',
        limit: 300,
      ),
    );
  }

  @override
  Future<int> save(Appointment a) async {
    final map = a.toMap();
    if (a.id == null) return db.insert('appointments', map);
    await db.update('appointments', map, where: 'id = ?', whereArgs: [a.id]);
    return a.id!;
  }

  @override
  Future<List<int>> saveSeries(Appointment first, RecurrenceRule rule) async {
    return db.transaction((txn) async {
      final rid = await txn.insert('recurring_appointments', rule.toMap()..remove('id'));
      final dur = first.end.difference(first.start);
      final ids = <int>[];
      for (final s in rule.expand(first.start)) {
        final occ = first.copyWith(clearId: true, start: s, end: s.add(dur), recurrenceId: rid);
        ids.add(await txn.insert('appointments', occ.toMap()));
      }
      return ids;
    });
  }

  @override
  Future<void> updateSeries(int recurrenceId, Appointment edited) async {
    final items = await bySeries(recurrenceId);
    final dur = edited.end.difference(edited.start);
    await db.transaction((txn) async {
      for (final o in items) {
        if (o.status.isClosed && o.id != edited.id) continue;
        final s = DateTime(o.start.year, o.start.month, o.start.day, edited.start.hour, edited.start.minute);
        final upd = edited.copyWith(
          id: o.id,
          start: o.id == edited.id ? edited.start : s,
          end: o.id == edited.id ? edited.end : s.add(dur),
          status: o.id == edited.id ? edited.status : o.status,
          createdAt: o.createdAt,
          recurrenceId: recurrenceId,
        );
        await txn.update('appointments', upd.toMap(), where: 'id = ?', whereArgs: [o.id]);
      }
    });
  }

  @override
  Future<void> delete(int id) => db.delete('appointments', where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> deleteSeries(int recurrenceId) async {
    await db.transaction((txn) async {
      await txn.delete('appointments', where: 'recurrence_id = ?', whereArgs: [recurrenceId]);
      await txn.delete('recurring_appointments', where: 'id = ?', whereArgs: [recurrenceId]);
    });
  }

  @override
  Future<RecurrenceRule?> rule(int id) async {
    final r = await db.query('recurring_appointments', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : RecurrenceRule.fromMap(r.first);
  }
}

class SqliteCustomerRepository implements CustomerRepository {
  SqliteCustomerRepository(this.db);
  final Database db;

  @override
  Future<List<Customer>> all() async => (await db.query('customers', orderBy: 'name COLLATE NOCASE')).map(Customer.fromMap).toList();

  @override
  Future<Customer?> byId(int id) async {
    final r = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : Customer.fromMap(r.first);
  }

  @override
  Future<int> save(Customer c) async {
    if (c.id == null) return db.insert('customers', c.toMap());
    await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    // مزامنة الاسم والهاتف في حجوزاته
    await db.update('appointments', {'customer_name': c.name, 'phone': c.phone}, where: 'customer_id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  @override
  Future<void> delete(int id) => db.delete('customers', where: 'id = ?', whereArgs: [id]);

  static String normalizePhone(String p) {
    final digits = p.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+964')) return '0${digits.substring(4)}';
    if (digits.startsWith('00964')) return '0${digits.substring(5)}';
    if (digits.startsWith('964') && digits.length > 11) return '0${digits.substring(3)}';
    return digits;
  }

  @override
  Future<int> findOrCreate({required String name, String phone = '', String phone2 = '', String address = ''}) async {
    final np = normalizePhone(phone);
    List<Map<String, Object?>> r = const [];
    if (np.isNotEmpty) {
      r = await db.query('customers', where: 'phone = ?', whereArgs: [np], limit: 1);
    }
    if (r.isEmpty && np.isEmpty) {
      r = await db.query('customers', where: 'name = ? AND phone = ?', whereArgs: [name.trim(), ''], limit: 1);
    }
    if (r.isNotEmpty) {
      final c = Customer.fromMap(r.first);
      final upd = c.copyWith(
        name: name.trim().isEmpty ? c.name : name.trim(),
        phone2: c.phone2.isEmpty ? phone2 : c.phone2,
        address: c.address.isEmpty ? address : c.address,
      );
      await db.update('customers', upd.toMap(), where: 'id = ?', whereArgs: [c.id]);
      return c.id!;
    }
    return db.insert(
      'customers',
      Customer(name: name.trim(), phone: np, phone2: normalizePhone(phone2), address: address, createdAt: DateTime.now()).toMap(),
    );
  }
}

class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository(this.db);
  final Database db;

  @override
  Future<List<EventCategory>> all() async => (await db.query('categories', orderBy: 'sort, id')).map(EventCategory.fromMap).toList();

  @override
  Future<int> save(EventCategory c) async {
    if (c.id == null) return db.insert('categories', c.toMap());
    await db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  @override
  Future<void> delete(int id) => db.delete('categories', where: 'id = ?', whereArgs: [id]);
}

class SqliteSoundRepository implements SoundRepository {
  SqliteSoundRepository(this.db);
  final Database db;

  @override
  Future<List<AlertSound>> all() async => (await db.query('custom_sounds', orderBy: 'created_ms DESC')).map(AlertSound.fromMap).toList();

  @override
  Future<int> save(AlertSound s) async {
    if (s.id == null) return db.insert('custom_sounds', s.toMap());
    await db.update('custom_sounds', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  @override
  Future<void> delete(int id) => db.delete('custom_sounds', where: 'id = ?', whereArgs: [id]);
}

class SqliteFinanceRepository implements FinanceRepository {
  SqliteFinanceRepository(this.db);
  final Database db;

  @override
  Future<List<Payment>> paymentsFor(int appointmentId) async =>
      (await db.query('payments', where: 'appointment_id = ?', whereArgs: [appointmentId], orderBy: 'date_ms')).map(Payment.fromMap).toList();

  @override
  Future<Map<int, double>> paidTotals() async {
    final rows = await db.rawQuery('SELECT appointment_id, SUM(amount) AS total FROM payments GROUP BY appointment_id');
    return {for (final r in rows) r['appointment_id'] as int: (r['total'] as num?)?.toDouble() ?? 0};
  }

  @override
  Future<List<Payment>> paymentsBetween(DateTime from, DateTime to) async => (await db.query(
    'payments',
    where: 'date_ms >= ? AND date_ms < ?',
    whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
  )).map(Payment.fromMap).toList();

  @override
  Future<int> addPayment(Payment p) => db.insert('payments', p.toMap());

  @override
  Future<void> deletePayment(int id) => db.delete('payments', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<Expense>> expensesBetween(DateTime from, DateTime to) async => (await db.query(
    'expenses',
    where: 'date_ms >= ? AND date_ms < ?',
    whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    orderBy: 'date_ms DESC',
  )).map(Expense.fromMap).toList();

  @override
  Future<List<Expense>> expensesFor(int appointmentId) async =>
      (await db.query('expenses', where: 'appointment_id = ?', whereArgs: [appointmentId])).map(Expense.fromMap).toList();

  @override
  Future<int> addExpense(Expense e) => db.insert('expenses', e.toMap());

  @override
  Future<void> deleteExpense(int id) => db.delete('expenses', where: 'id = ?', whereArgs: [id]);
}

class SqliteAttachmentRepository implements AttachmentRepository {
  SqliteAttachmentRepository(this.db);
  final Database db;

  @override
  Future<List<Attachment>> forAppointment(int appointmentId) async =>
      (await db.query('attachments', where: 'appointment_id = ?', whereArgs: [appointmentId])).map(Attachment.fromMap).toList();

  @override
  Future<List<Attachment>> all() async => (await db.query('attachments')).map(Attachment.fromMap).toList();

  @override
  Future<int> add(Attachment a) => db.insert('attachments', a.toMap());

  @override
  Future<void> delete(int id) => db.delete('attachments', where: 'id = ?', whereArgs: [id]);
}

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this.db);
  final Database db;

  @override
  Future<AppSettings> load() async {
    final r = await db.query('settings', where: 'key = ?', whereArgs: ['app'], limit: 1);
    return AppSettings.decode(r.isEmpty ? null : r.first['value'] as String?);
  }

  @override
  Future<void> save(AppSettings s) => db.insert('settings', {'key': 'app', 'value': s.encode()}, conflictAlgorithm: ConflictAlgorithm.replace);
}

class SqliteReminderLogRepository implements ReminderLogRepository {
  SqliteReminderLogRepository(this.db);
  final Database db;

  @override
  Future<void> replaceAll(List<ReminderLog> logs) async {
    final acked = await acknowledgedIds();
    await db.transaction((txn) async {
      await txn.delete('reminders');
      for (final l in logs) {
        await txn.insert('reminders', {
          'appointment_id': l.appointmentId,
          'type': l.type,
          'fire_ms': l.fireAt.millisecondsSinceEpoch,
          'notification_id': l.notificationId,
          'acknowledged': acked.contains(l.notificationId) ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<List<ReminderLog>> all() async => (await db.query('reminders', orderBy: 'fire_ms'))
      .map(
        (r) => ReminderLog(
          appointmentId: r['appointment_id'] as int,
          type: r['type'] as String,
          fireAt: DateTime.fromMillisecondsSinceEpoch(r['fire_ms'] as int),
          notificationId: r['notification_id'] as int,
          acknowledged: r['acknowledged'] == 1,
        ),
      )
      .toList();

  @override
  Future<void> acknowledge(int notificationId) =>
      db.update('reminders', {'acknowledged': 1}, where: 'notification_id = ?', whereArgs: [notificationId]);

  @override
  Future<void> acknowledgeAppointment(int appointmentId) => db.update(
    'reminders',
    {'acknowledged': 1},
    where: 'appointment_id = ? AND fire_ms <= ?',
    whereArgs: [appointmentId, DateTime.now().millisecondsSinceEpoch],
  );

  @override
  Future<Set<int>> acknowledgedIds() async =>
      (await db.query('reminders', columns: ['notification_id'], where: 'acknowledged = 1')).map((r) => r['notification_id'] as int).toSet();
}

class SqliteStaffRepository implements StaffRepository {
  SqliteStaffRepository(this.db);
  final Database db;

  @override
  Future<List<Staff>> all() async => (await db.query('staff', orderBy: 'sort, id')).map(Staff.fromMap).toList();

  @override
  Future<int> save(Staff s) async {
    if (s.id == null) return db.insert('staff', s.toMap());
    await db.update('staff', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  @override
  Future<void> delete(int id) => db.delete('staff', where: 'id = ?', whereArgs: [id]);
}

class SqliteServiceRepository implements ServiceRepository {
  SqliteServiceRepository(this.db);
  final Database db;

  @override
  Future<List<ServiceItem>> all() async => (await db.query('services', orderBy: 'sort, id')).map(ServiceItem.fromMap).toList();

  @override
  Future<int> save(ServiceItem s) async {
    if (s.id == null) return db.insert('services', s.toMap());
    await db.update('services', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  @override
  Future<void> delete(int id) => db.delete('services', where: 'id = ?', whereArgs: [id]);
}
