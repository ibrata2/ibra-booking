import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/edition.dart';
import '../../domain/entities/entities.dart';

/// قاعدة البيانات المحلية (SQLite). كل ترقية مستقبلية تضاف في [_migrations]
/// بدون حذف أي بيانات حجوزات سابقة.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const fileName = 'ibra_booking.db';
  static const version = 1;

  static Future<String> path() async => p.join(await getDatabasesPath(), fileName);

  static Future<AppDatabase> open() async {
    final database = await openDatabase(
      await path(),
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, v) async {
        final b = db.batch();
        _createV1(b);
        await b.commit(noResult: true);
        await _seed(db);
      },
      onUpgrade: (db, from, to) async {
        for (var v = from + 1; v <= to; v++) {
          final m = _migrations[v];
          if (m != null) await m(db);
        }
      },
    );
    return AppDatabase._(database);
  }

  /// ترقيات المخطط: رقم الإصدار -> دالة الترقية.
  static final Map<int, Future<void> Function(Database)> _migrations = {
    // 2: (db) async { await db.execute('ALTER TABLE appointments ADD COLUMN ...'); },
  };

  static void _createV1(Batch b) {
    b.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        phone2 TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_ms INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    b.execute('CREATE INDEX idx_customers_name ON customers(name)');

    b.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name_ar TEXT NOT NULL,
        name_en TEXT NOT NULL DEFAULT '',
        color INTEGER NOT NULL,
        icon TEXT NOT NULL DEFAULT 'event',
        sort INTEGER NOT NULL DEFAULT 0,
        is_default INTEGER NOT NULL DEFAULT 0
      )''');

    b.execute('''
      CREATE TABLE recurring_appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        interval INTEGER NOT NULL DEFAULT 1,
        weekdays TEXT NOT NULL DEFAULT '',
        count INTEGER,
        until_ms INTEGER
      )''');

    b.execute('''
      CREATE TABLE custom_sounds(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        android_uri TEXT NOT NULL DEFAULT '',
        created_ms INTEGER NOT NULL
      )''');

    b.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
        customer_name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        phone2 TEXT NOT NULL DEFAULT '',
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        place_name TEXT NOT NULL DEFAULT '',
        province TEXT NOT NULL DEFAULT '',
        area TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        landmark TEXT NOT NULL DEFAULT '',
        map_url TEXT NOT NULL DEFAULT '',
        lat REAL,
        lng REAL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        fee REAL NOT NULL DEFAULT 0,
        deposit REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'confirmed',
        recurrence_id INTEGER REFERENCES recurring_appointments(id) ON DELETE SET NULL,
        reminder_json TEXT,
        sound_key TEXT,
        created_ms INTEGER NOT NULL,
        updated_ms INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_appt_start ON appointments(start_ms)');
    b.execute('CREATE INDEX idx_appt_end ON appointments(end_ms)');
    b.execute('CREATE INDEX idx_appt_customer ON appointments(customer_id)');
    b.execute('CREATE INDEX idx_appt_recurrence ON appointments(recurrence_id)');
    b.execute('CREATE INDEX idx_appt_status ON appointments(status)');

    b.execute('''
      CREATE TABLE reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        fire_ms INTEGER NOT NULL,
        notification_id INTEGER NOT NULL,
        acknowledged INTEGER NOT NULL DEFAULT 0,
        UNIQUE(notification_id)
      )''');
    b.execute('CREATE INDEX idx_rem_appt ON reminders(appointment_id)');
    b.execute('CREATE INDEX idx_rem_fire ON reminders(fire_ms)');

    b.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        date_ms INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    b.execute('CREATE INDEX idx_pay_appt ON payments(appointment_id)');
    b.execute('CREATE INDEX idx_pay_date ON payments(date_ms)');

    b.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER REFERENCES appointments(id) ON DELETE SET NULL,
        kind TEXT NOT NULL DEFAULT 'travel',
        amount REAL NOT NULL,
        date_ms INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )''');
    b.execute('CREATE INDEX idx_exp_date ON expenses(date_ms)');

    b.execute('''
      CREATE TABLE attachments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appointment_id INTEGER NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        created_ms INTEGER NOT NULL
      )''');
    b.execute('CREATE INDEX idx_att_appt ON attachments(appointment_id)');

    b.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
  }

  static Future<void> _seed(Database db) async {
    final b = db.batch();
    for (final c in EventCategory.defaultsFor(Edition.isGeneral)) {
      b.insert('categories', c.toMap());
    }
    await b.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
