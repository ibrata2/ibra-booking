export 'appointment.dart';
export 'reminder_config.dart';
export 'recurrence.dart';
export 'app_settings.dart';

class Customer {
  final int? id;
  final String name;
  final String phone;
  final String phone2;
  final String address;
  final String notes;
  final DateTime createdAt;

  const Customer({this.id, required this.name, this.phone = '', this.phone2 = '', this.address = '', this.notes = '', required this.createdAt});

  Customer copyWith({String? name, String? phone, String? phone2, String? address, String? notes}) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    phone2: phone2 ?? this.phone2,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'phone2': phone2,
    'address': address,
    'notes': notes,
    'created_ms': createdAt.millisecondsSinceEpoch,
  };

  factory Customer.fromMap(Map<String, Object?> m) => Customer(
    id: m['id'] as int?,
    name: (m['name'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    phone2: (m['phone2'] as String?) ?? '',
    address: (m['address'] as String?) ?? '',
    notes: (m['notes'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_ms'] as int?) ?? 0),
  );
}

/// إحصائيات زبون محسوبة من حجوزاته.
class CustomerStats {
  final int total;
  final int upcoming;
  final double totalFees;
  final double remaining;
  final DateTime? lastDate;
  const CustomerStats({this.total = 0, this.upcoming = 0, this.totalFees = 0, this.remaining = 0, this.lastDate});
}

class EventCategory {
  final int? id;
  final String nameAr;
  final String nameEn;
  final int color;
  final String icon;
  final int sort;
  final bool isDefault;

  const EventCategory({
    this.id,
    required this.nameAr,
    required this.nameEn,
    required this.color,
    this.icon = 'event',
    this.sort = 0,
    this.isDefault = false,
  });

  String name(bool ar) => ar ? nameAr : (nameEn.isEmpty ? nameAr : nameEn);

  EventCategory copyWith({String? nameAr, String? nameEn, int? color, String? icon, int? sort}) => EventCategory(
    id: id,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    sort: sort ?? this.sort,
    isDefault: isDefault,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name_ar': nameAr,
    'name_en': nameEn,
    'color': color,
    'icon': icon,
    'sort': sort,
    'is_default': isDefault ? 1 : 0,
  };

  factory EventCategory.fromMap(Map<String, Object?> m) => EventCategory(
    id: m['id'] as int?,
    nameAr: (m['name_ar'] as String?) ?? '',
    nameEn: (m['name_en'] as String?) ?? '',
    color: (m['color'] as int?) ?? 0xFF9E9E9E,
    icon: (m['icon'] as String?) ?? 'event',
    sort: (m['sort'] as int?) ?? 0,
    isDefault: (m['is_default'] as int?) == 1,
  );

  static const eventsDefaults = <EventCategory>[
    EventCategory(nameAr: 'الفواتح', nameEn: 'Fatiha', color: 0xFF9E9E9E, icon: 'mosque', sort: 0, isDefault: true),
    EventCategory(nameAr: 'مجالس العزاء', nameEn: 'Condolences', color: 0xFFE53935, icon: 'heart', sort: 1, isDefault: true),
    EventCategory(nameAr: 'المواليد', nameEn: 'Births', color: 0xFF43A047, icon: 'baby', sort: 2, isDefault: true),
    EventCategory(nameAr: 'الأفراح', nameEn: 'Weddings', color: 0xFFEC407A, icon: 'ring', sort: 3, isDefault: true),
    EventCategory(nameAr: 'المجالس الدينية', nameEn: 'Religious gatherings', color: 0xFF1E88E5, icon: 'book', sort: 4, isDefault: true),
    EventCategory(nameAr: 'المناسبات الخاصة', nameEn: 'Private events', color: 0xFF8E24AA, icon: 'star', sort: 5, isDefault: true),
    EventCategory(nameAr: 'مناسبات أخرى', nameEn: 'Other events', color: 0xFFFB8C00, icon: 'event', sort: 6, isDefault: true),
  ];

  static const generalDefaults = <EventCategory>[
    EventCategory(nameAr: 'موعد عمل', nameEn: 'Work appointment', color: 0xFF1E88E5, icon: 'work', sort: 0, isDefault: true),
    EventCategory(nameAr: 'اجتماع', nameEn: 'Meeting', color: 0xFF8E24AA, icon: 'group', sort: 1, isDefault: true),
    EventCategory(nameAr: 'زيارة عميل', nameEn: 'Client visit', color: 0xFF43A047, icon: 'home', sort: 2, isDefault: true),
    EventCategory(nameAr: 'جلسة / خدمة', nameEn: 'Session / service', color: 0xFFEC407A, icon: 'star', sort: 3, isDefault: true),
    EventCategory(nameAr: 'توصيل / مشوار', nameEn: 'Delivery / trip', color: 0xFFFB8C00, icon: 'car', sort: 4, isDefault: true),
    EventCategory(nameAr: 'مناسبة', nameEn: 'Event', color: 0xFF00ACC1, icon: 'celebration', sort: 5, isDefault: true),
    EventCategory(nameAr: 'شخصي', nameEn: 'Personal', color: 0xFF9E9E9E, icon: 'event', sort: 6, isDefault: true),
    EventCategory(nameAr: 'أخرى', nameEn: 'Other', color: 0xFF6D4C41, icon: 'event', sort: 7, isDefault: true),
  ];

  static List<EventCategory> defaultsFor(bool general) => general ? generalDefaults : eventsDefaults;
}

/// صوت تنبيه. الأصوات المدمجة لها key يبدأ بـ app_ ، والمخصصة مخزنة في قاعدة البيانات.
class AlertSound {
  final int? id;
  final String key; // 'default' | 'app_chime' | 'c12'
  final String name;
  final String filePath; // ملف WAV داخل مساحة التطبيق (أو أصل مدمج)
  final int durationMs;
  final String androidUri; // content:// مسجل في MediaStore (للأصوات المخصصة)
  final DateTime createdAt;

  const AlertSound({
    this.id,
    required this.key,
    required this.name,
    this.filePath = '',
    this.durationMs = 0,
    this.androidUri = '',
    required this.createdAt,
  });

  bool get isCustom => key.startsWith('c');
  bool get isBuiltIn => key.startsWith('app_');
  bool get isSystemDefault => key == 'default';

  /// اسم المورد الخام في أندرويد واسم الملف في Library/Sounds في iOS.
  String get resourceName => key.replaceFirst('app_', 'ib_');

  AlertSound copyWith({String? name, String? androidUri}) => AlertSound(
    id: id,
    key: key,
    name: name ?? this.name,
    filePath: filePath,
    durationMs: durationMs,
    androidUri: androidUri ?? this.androidUri,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'file_path': filePath,
    'duration_ms': durationMs,
    'android_uri': androidUri,
    'created_ms': createdAt.millisecondsSinceEpoch,
  };

  factory AlertSound.fromMap(Map<String, Object?> m) => AlertSound(
    id: m['id'] as int?,
    key: 'c${m['id']}',
    name: (m['name'] as String?) ?? '',
    filePath: (m['file_path'] as String?) ?? '',
    durationMs: (m['duration_ms'] as int?) ?? 0,
    androidUri: (m['android_uri'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_ms'] as int?) ?? 0),
  );
}

class Payment {
  final int? id;
  final int appointmentId;
  final double amount;
  final DateTime date;
  final String note;
  const Payment({this.id, required this.appointmentId, required this.amount, required this.date, this.note = ''});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'appointment_id': appointmentId,
    'amount': amount,
    'date_ms': date.millisecondsSinceEpoch,
    'note': note,
  };

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
    id: m['id'] as int?,
    appointmentId: m['appointment_id'] as int,
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.fromMillisecondsSinceEpoch(m['date_ms'] as int),
    note: (m['note'] as String?) ?? '',
  );
}

class Expense {
  final int? id;
  final int? appointmentId;
  final String kind; // travel | other
  final double amount;
  final DateTime date;
  final String note;
  const Expense({this.id, this.appointmentId, this.kind = 'travel', required this.amount, required this.date, this.note = ''});

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'appointment_id': appointmentId,
    'kind': kind,
    'amount': amount,
    'date_ms': date.millisecondsSinceEpoch,
    'note': note,
  };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int?,
    appointmentId: m['appointment_id'] as int?,
    kind: (m['kind'] as String?) ?? 'travel',
    amount: (m['amount'] as num).toDouble(),
    date: DateTime.fromMillisecondsSinceEpoch(m['date_ms'] as int),
    note: (m['note'] as String?) ?? '',
  );
}

class Attachment {
  final int? id;
  final int appointmentId;
  final String filePath;
  final String name;
  final DateTime createdAt;
  const Attachment({this.id, required this.appointmentId, required this.filePath, required this.name, required this.createdAt});

  bool get isImage {
    final p = filePath.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.webp') || p.endsWith('.heic') || p.endsWith('.gif');
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'appointment_id': appointmentId,
    'file_path': filePath,
    'name': name,
    'created_ms': createdAt.millisecondsSinceEpoch,
  };

  factory Attachment.fromMap(Map<String, Object?> m) => Attachment(
    id: m['id'] as int?,
    appointmentId: m['appointment_id'] as int,
    filePath: (m['file_path'] as String?) ?? '',
    name: (m['name'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_ms'] as int?) ?? 0),
  );
}
