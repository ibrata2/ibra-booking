import 'entities/entities.dart';

/// عقود المستودعات (طبقة المجال) — التطبيق يعتمد عليها وليس على SQLite مباشرة.

abstract interface class AppointmentRepository {
  Future<List<Appointment>> all();
  Future<List<Appointment>> between(DateTime from, DateTime to);
  Future<Appointment?> byId(int id);
  Future<List<Appointment>> byCustomer(int customerId);
  Future<List<Appointment>> bySeries(int recurrenceId);
  Future<List<Appointment>> search(String query);
  Future<int> save(Appointment a);
  Future<List<int>> saveSeries(Appointment first, RecurrenceRule rule);
  Future<void> updateSeries(int recurrenceId, Appointment edited);
  Future<void> delete(int id);
  Future<void> deleteSeries(int recurrenceId);
  Future<RecurrenceRule?> rule(int id);
}

abstract interface class CustomerRepository {
  Future<List<Customer>> all();
  Future<Customer?> byId(int id);
  Future<int> save(Customer c);
  Future<void> delete(int id);
  Future<int> findOrCreate({required String name, String phone, String phone2, String address});
}

abstract interface class CategoryRepository {
  Future<List<EventCategory>> all();
  Future<int> save(EventCategory c);
  Future<void> delete(int id);
}

abstract interface class SoundRepository {
  Future<List<AlertSound>> all();
  Future<int> save(AlertSound s);
  Future<void> delete(int id);
}

abstract interface class FinanceRepository {
  Future<List<Payment>> paymentsFor(int appointmentId);
  Future<Map<int, double>> paidTotals();
  Future<List<Payment>> paymentsBetween(DateTime from, DateTime to);
  Future<int> addPayment(Payment p);
  Future<void> deletePayment(int id);
  Future<List<Expense>> expensesBetween(DateTime from, DateTime to);
  Future<List<Expense>> expensesFor(int appointmentId);
  Future<int> addExpense(Expense e);
  Future<void> deleteExpense(int id);
}

abstract interface class AttachmentRepository {
  Future<List<Attachment>> forAppointment(int appointmentId);
  Future<List<Attachment>> all();
  Future<int> add(Attachment a);
  Future<void> delete(int id);
}

abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings s);
}

/// سجل الإشعارات المجدولة (لمنع التكرار ومتابعة الاستلام).
class ReminderLog {
  final int appointmentId;
  final String type;
  final DateTime fireAt;
  final int notificationId;
  final bool acknowledged;
  const ReminderLog({required this.appointmentId, required this.type, required this.fireAt, required this.notificationId, this.acknowledged = false});
}

abstract interface class ReminderLogRepository {
  Future<void> replaceAll(List<ReminderLog> logs);
  Future<List<ReminderLog>> all();
  Future<void> acknowledge(int notificationId);
  Future<void> acknowledgeAppointment(int appointmentId);
  Future<Set<int>> acknowledgedIds();
}

abstract interface class StaffRepository {
  Future<List<Staff>> all();
  Future<int> save(Staff s);
  Future<void> delete(int id);
}

abstract interface class ServiceRepository {
  Future<List<ServiceItem>> all();
  Future<int> save(ServiceItem s);
  Future<void> delete(int id);
}
