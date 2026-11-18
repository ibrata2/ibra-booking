import 'reminder_config.dart';

/// حالات الحجز المخزنة يدوياً. الحالتان «قادم» و«جارٍ الآن» تحسبان زمنياً.
enum BookingStatus {
  confirmed,
  pending,
  upcoming,
  ongoing,
  completed,
  cancelled,
  postponed,
  noShow;

  static BookingStatus parse(String? v) => BookingStatus.values.firstWhere((e) => e.name == v, orElse: () => BookingStatus.confirmed);

  /// الحالات التي تنهي الحجز فلا تُجدول لها تنبيهات.
  bool get isClosed =>
      this == BookingStatus.completed || this == BookingStatus.cancelled || this == BookingStatus.postponed || this == BookingStatus.noShow;
}

class Appointment {
  final int? id;
  final int? customerId;
  final String customerName;
  final String phone;
  final String phone2;
  final int? categoryId;
  final String placeName;
  final String province;
  final String area;
  final String address;
  final String landmark;
  final String mapUrl;
  final double? lat;
  final double? lng;
  final DateTime start;
  final DateTime end;
  final double fee;
  final double deposit;
  final String notes;
  final BookingStatus status;
  final int? recurrenceId;
  final ReminderConfig? reminderOverride;

  /// مفتاح صوت خاص بهذا الحجز (يتجاوز أصوات الأنواع). null = حسب الإعدادات.
  final String? soundKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    this.id,
    this.customerId,
    required this.customerName,
    this.phone = '',
    this.phone2 = '',
    this.categoryId,
    this.placeName = '',
    this.province = '',
    this.area = '',
    this.address = '',
    this.landmark = '',
    this.mapUrl = '',
    this.lat,
    this.lng,
    required this.start,
    required this.end,
    this.fee = 0,
    this.deposit = 0,
    this.notes = '',
    this.status = BookingStatus.confirmed,
    this.recurrenceId,
    this.reminderOverride,
    this.soundKey,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get duration => end.difference(start);

  bool isOngoingAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  /// الحالة المعروضة حسب الوقت الحالي.
  BookingStatus effectiveStatus(DateTime now) {
    if (status.isClosed) return status;
    if (isOngoingAt(now)) return BookingStatus.ongoing;
    if (!now.isBefore(end)) {
      return status == BookingStatus.pending ? BookingStatus.pending : BookingStatus.completed;
    }
    if (status == BookingStatus.pending) return BookingStatus.pending;
    if (start.difference(now) <= const Duration(hours: 24)) return BookingStatus.upcoming;
    return BookingStatus.confirmed;
  }

  /// يجمع العنوان الكامل بشكل مقروء.
  String get fullAddress => [province, area, address, landmark.isEmpty ? '' : '($landmark)'].where((e) => e.trim().isNotEmpty).join(' - ');

  Appointment copyWith({
    int? id,
    bool clearId = false,
    int? customerId,
    String? customerName,
    String? phone,
    String? phone2,
    int? categoryId,
    String? placeName,
    String? province,
    String? area,
    String? address,
    String? landmark,
    String? mapUrl,
    double? lat,
    double? lng,
    bool clearCoords = false,
    DateTime? start,
    DateTime? end,
    double? fee,
    double? deposit,
    String? notes,
    BookingStatus? status,
    int? recurrenceId,
    bool clearRecurrence = false,
    ReminderConfig? reminderOverride,
    bool clearReminderOverride = false,
    String? soundKey,
    bool clearSoundKey = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: clearId ? null : (id ?? this.id),
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      categoryId: categoryId ?? this.categoryId,
      placeName: placeName ?? this.placeName,
      province: province ?? this.province,
      area: area ?? this.area,
      address: address ?? this.address,
      landmark: landmark ?? this.landmark,
      mapUrl: mapUrl ?? this.mapUrl,
      lat: clearCoords ? null : (lat ?? this.lat),
      lng: clearCoords ? null : (lng ?? this.lng),
      start: start ?? this.start,
      end: end ?? this.end,
      fee: fee ?? this.fee,
      deposit: deposit ?? this.deposit,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      recurrenceId: clearRecurrence ? null : (recurrenceId ?? this.recurrenceId),
      reminderOverride: clearReminderOverride ? null : (reminderOverride ?? this.reminderOverride),
      soundKey: clearSoundKey ? null : (soundKey ?? this.soundKey),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'phone': phone,
    'phone2': phone2,
    'category_id': categoryId,
    'place_name': placeName,
    'province': province,
    'area': area,
    'address': address,
    'landmark': landmark,
    'map_url': mapUrl,
    'lat': lat,
    'lng': lng,
    'start_ms': start.millisecondsSinceEpoch,
    'end_ms': end.millisecondsSinceEpoch,
    'fee': fee,
    'deposit': deposit,
    'notes': notes,
    'status': status.name,
    'recurrence_id': recurrenceId,
    'reminder_json': reminderOverride?.encode(),
    'sound_key': soundKey,
    'created_ms': createdAt.millisecondsSinceEpoch,
    'updated_ms': updatedAt.millisecondsSinceEpoch,
  };

  factory Appointment.fromMap(Map<String, Object?> m) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    return Appointment(
      id: m['id'] as int?,
      customerId: m['customer_id'] as int?,
      customerName: (m['customer_name'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      phone2: (m['phone2'] as String?) ?? '',
      categoryId: m['category_id'] as int?,
      placeName: (m['place_name'] as String?) ?? '',
      province: (m['province'] as String?) ?? '',
      area: (m['area'] as String?) ?? '',
      address: (m['address'] as String?) ?? '',
      landmark: (m['landmark'] as String?) ?? '',
      mapUrl: (m['map_url'] as String?) ?? '',
      lat: d(m['lat']),
      lng: d(m['lng']),
      start: DateTime.fromMillisecondsSinceEpoch(m['start_ms'] as int),
      end: DateTime.fromMillisecondsSinceEpoch(m['end_ms'] as int),
      fee: d(m['fee']) ?? 0,
      deposit: d(m['deposit']) ?? 0,
      notes: (m['notes'] as String?) ?? '',
      status: BookingStatus.parse(m['status'] as String?),
      recurrenceId: m['recurrence_id'] as int?,
      reminderOverride: ReminderConfig.tryDecode(m['reminder_json'] as String?),
      soundKey: m['sound_key'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_ms'] as int?) ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((m['updated_ms'] as int?) ?? 0),
    );
  }
}
