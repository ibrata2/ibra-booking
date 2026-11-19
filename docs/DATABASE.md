# قاعدة البيانات — IBRA BOOKING

SQLite محلية (`ibra_booking.db`) عبر `sqflite`، الإصدار الحالي للمخطط: **2**.
المفاتيح الأجنبية مفعلة (`PRAGMA foreign_keys = ON`). كل الأوقات تخزن كطوابع زمنية بالملي ثانية (UTC epoch) وتعرض للمستخدم بنظام 12 ساعة فقط.

## الجداول

### appointments — الحجوزات
| العمود | النوع | الوصف |
|---|---|---|
| id | INTEGER PK | |
| customer_id | INTEGER → customers.id (SET NULL) | الزبون |
| customer_name, phone, phone2 | TEXT | نسخة للعرض السريع |
| category_id | INTEGER → categories.id (SET NULL) | نوع المناسبة |
| place_name, province, area, address, landmark, map_url | TEXT | المكان |
| lat, lng | REAL | الإحداثيات (من رابط الخريطة) |
| start_ms, end_ms | INTEGER | البداية والنهاية (النهاية قد تكون في اليوم التالي) |
| fee, deposit | REAL | الأجر والعربون |
| notes | TEXT | |
| status | TEXT | confirmed, pending, completed, cancelled, postponed, noShow |
| recurrence_id | INTEGER → recurring_appointments.id | سلسلة التكرار |
| reminder_json | TEXT | إعدادات تنبيه خاصة (NULL = الافتراضية) |
| sound_key | TEXT | صوت خاص بالحجز (NULL = حسب نوع التنبيه) |
| created_ms, updated_ms | INTEGER | |

فهارس: `start_ms`, `end_ms`, `customer_id`, `recurrence_id`, `status`.

الحالتان «قادم» و«جارٍ الآن» تحسبان زمنياً (`Appointment.effectiveStatus`) ولا تخزنان.

### customers — الزبائن
`id, name, phone, phone2, address, notes, created_ms` — فهرس على `phone` و `name`.
ينشأ السجل تلقائياً عند حفظ حجز (مطابقة بالهاتف بعد توحيده: `+9647…` → `07…`).

### categories — أنواع المناسبات
`id, name_ar, name_en, color, icon, sort, is_default` — تُزرع 7 أنواع افتراضية (الفواتح رمادي، العزاء أحمر، المواليد أخضر، الأفراح وردي، الدينية أزرق، الخاصة بنفسجي، أخرى برتقالي).

### recurring_appointments — قواعد التكرار
`id, type (daily|weekly|monthly|yearly|weekdays|range), interval, weekdays ("1,5"), count, until_ms`
كل تكرار يحفظ كحجز مستقل في `appointments` بنفس `recurrence_id`، فيمكن تعديل حجز واحد أو كل السلسلة.

### reminders — سجل الإشعارات المجدولة
`id, appointment_id (CASCADE), type, fire_ms, notification_id UNIQUE, acknowledged`
يُعاد بناؤه عند كل إعادة جدولة. يستخدم لمنع التكرار، ومتابعة الاستلام، وحفظ التأجيلات (`type = snooze:<type>`).

### custom_sounds — الأصوات المخصصة
`id, name, file_path, duration_ms, android_uri, created_ms` — الملف WAV داخل مساحة التطبيق، و `android_uri` هو content:// المسجل في مكتبة أصوات الإشعارات.

### payments — الدفعات
`id, appointment_id (CASCADE), amount, date_ms, note` — المستلم = العربون + مجموع الدفعات.

### expenses — المصروفات
`id, appointment_id (SET NULL, اختياري), kind (travel|other), amount, date_ms, note`

### attachments — المرفقات
`id, appointment_id (CASCADE), file_path, name, created_ms` — الملفات في `ApplicationSupport/attachments`.

### settings — الإعدادات
`key, value` — المفتاح `app` يحمل JSON لكل الإعدادات (`AppSettings`).

### staff — الموظفون (الإصدار 2)
`id, name, phone, role, color, hours_json, active, sort, created_ms` — `hours_json`: لكل يوم أسبوع قائمة فترات بالدقائق، مثل `{"6":[[600,780],[840,1200]],"5":[]}` (السبت دوام مع استراحة، الجمعة عطلة).

### services — الخدمات (الإصدار 2)
`id, name, duration_min, price, color, staff_ids ("1,3" أو فارغ = الكل), active, sort`

وأُضيف إلى `appointments`: `staff_id` و `service_id` (SET NULL عند الحذف) مع فهرس على `staff_id`.

## الترقية دون فقدان البيانات
`AppDatabase._migrations` خريطة `رقم الإصدار → دالة ALTER`. عند زيادة `AppDatabase.version` تنفذ الترقيات بالتسلسل ولا تحذف أي جدول.

## النسخة الاحتياطية (`.ibrabackup`)
ملف ZIP يحتوي:
- `manifest.json` — التطبيق، إصدار المخطط، التاريخ، الأعداد
- `data.json` — كل الجداول كـ JSON
- `files/sounds/custom_<id>.wav`
- `files/attachments/*`

الاستعادة تستبدل كل البيانات داخل معاملة واحدة، ثم تعيد تسجيل الأصوات لدى النظام وتعيد جدولة التنبيهات.
