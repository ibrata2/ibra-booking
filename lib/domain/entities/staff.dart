import 'dart:convert';

/// فترة عمل داخل اليوم بالدقائق من منتصف الليل (مثلاً 600–1200 = 10 صباحاً إلى 8 مساءً).
class WorkSpan {
  final int start;
  final int end;
  const WorkSpan(this.start, this.end);

  bool get isValid => end > start;
  List<int> toJson() => [start, end];
  static WorkSpan fromJson(Object? v) {
    if (v is List && v.length == 2 && v[0] is num && v[1] is num) return WorkSpan((v[0] as num).toInt(), (v[1] as num).toInt());
    return const WorkSpan(0, 0);
  }
}

/// ساعات دوام الموظف لكل يوم من أيام الأسبوع (DateTime.weekday: 1=الإثنين .. 7=الأحد).
/// يوم بلا فترات = عطلة. فترتان في اليوم = دوام مع استراحة بينهما.
class WorkHours {
  final Map<int, List<WorkSpan>> days;
  const WorkHours(this.days);

  /// الافتراضي: السبت–الخميس 10:00 صباحاً – 8:00 مساءً، والجمعة عطلة.
  static WorkHours standard() => WorkHours({
    for (final d in [1, 2, 3, 4, 6, 7]) d: [const WorkSpan(600, 1200)],
    5: const [],
  });

  List<WorkSpan> forDay(int weekday) => (days[weekday] ?? const []).where((s) => s.isValid).toList()..sort((a, b) => a.start.compareTo(b.start));

  bool worksOn(int weekday) => forDay(weekday).isNotEmpty;

  /// هل الفترة [start, end) داخل الدوام بالكامل؟ (يدعم الحجوزات التي تمتد لليوم التالي بعدم قبولها)
  bool covers(DateTime start, DateTime end) {
    final dayStart = DateTime(start.year, start.month, start.day);
    final s = start.difference(dayStart).inMinutes;
    final e = end.difference(dayStart).inMinutes;
    for (final span in forDay(start.weekday)) {
      if (s >= span.start && e <= span.end) return true;
    }
    return false;
  }

  WorkHours withDay(int weekday, List<WorkSpan> spans) => WorkHours({...days, weekday: spans});

  String encode() => jsonEncode({for (final e in days.entries) '${e.key}': e.value.map((s) => s.toJson()).toList()});

  static WorkHours decode(String? s) {
    if (s == null || s.isEmpty) return standard();
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return WorkHours({
        for (final e in j.entries) int.parse(e.key): [for (final v in (e.value as List)) WorkSpan.fromJson(v)],
      });
    } catch (_) {
      return standard();
    }
  }
}

/// موظف في المركز.
class Staff {
  final int? id;
  final String name;
  final String phone;
  final String role; // اختياري: «مصففة شعر»، «أخصائي ليزر»...
  final int color;
  final WorkHours hours;
  final bool active;
  final int sort;
  final DateTime createdAt;

  const Staff({
    this.id,
    required this.name,
    this.phone = '',
    this.role = '',
    this.color = 0xFF3D7BFF,
    required this.hours,
    this.active = true,
    this.sort = 0,
    required this.createdAt,
  });

  Staff copyWith({String? name, String? phone, String? role, int? color, WorkHours? hours, bool? active, int? sort}) => Staff(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    color: color ?? this.color,
    hours: hours ?? this.hours,
    active: active ?? this.active,
    sort: sort ?? this.sort,
    createdAt: createdAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'color': color,
    'hours_json': hours.encode(),
    'active': active ? 1 : 0,
    'sort': sort,
    'created_ms': createdAt.millisecondsSinceEpoch,
  };

  factory Staff.fromMap(Map<String, Object?> m) => Staff(
    id: m['id'] as int?,
    name: (m['name'] as String?) ?? '',
    phone: (m['phone'] as String?) ?? '',
    role: (m['role'] as String?) ?? '',
    color: (m['color'] as int?) ?? 0xFF3D7BFF,
    hours: WorkHours.decode(m['hours_json'] as String?),
    active: (m['active'] as int?) != 0,
    sort: (m['sort'] as int?) ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_ms'] as int?) ?? 0),
  );
}

/// خدمة يقدمها المركز (قص شعر، تنظيف بشرة، ليزر...).
class ServiceItem {
  final int? id;
  final String name;
  final int durationMin;
  final double price;
  final int color;

  /// الموظفون الذين يقدمون الخدمة (فارغة = الكل).
  final Set<int> staffIds;
  final bool active;
  final int sort;

  const ServiceItem({
    this.id,
    required this.name,
    this.durationMin = 30,
    this.price = 0,
    this.color = 0xFFEC407A,
    this.staffIds = const {},
    this.active = true,
    this.sort = 0,
  });

  bool offeredBy(int? staffId) => staffIds.isEmpty || (staffId != null && staffIds.contains(staffId));

  ServiceItem copyWith({String? name, int? durationMin, double? price, int? color, Set<int>? staffIds, bool? active, int? sort}) => ServiceItem(
    id: id,
    name: name ?? this.name,
    durationMin: durationMin ?? this.durationMin,
    price: price ?? this.price,
    color: color ?? this.color,
    staffIds: staffIds ?? this.staffIds,
    active: active ?? this.active,
    sort: sort ?? this.sort,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'duration_min': durationMin,
    'price': price,
    'color': color,
    'staff_ids': (staffIds.toList()..sort()).join(','),
    'active': active ? 1 : 0,
    'sort': sort,
  };

  factory ServiceItem.fromMap(Map<String, Object?> m) => ServiceItem(
    id: m['id'] as int?,
    name: (m['name'] as String?) ?? '',
    durationMin: (m['duration_min'] as int?) ?? 30,
    price: ((m['price'] as num?) ?? 0).toDouble(),
    color: (m['color'] as int?) ?? 0xFFEC407A,
    staffIds: ((m['staff_ids'] as String?) ?? '').split(',').where((e) => e.isNotEmpty).map(int.parse).toSet(),
    active: (m['active'] as int?) != 0,
    sort: (m['sort'] as int?) ?? 0,
  );
}
