# النشر على Google Play و App Store — روسم للتجميل

كل شي بالتطبيق مبني حسب شروط المتجرين. هنا الأجوبة الجاهزة اللي تكتبها بنماذج المتاجر حتى ينقبل بسرعة.

## اللي جاهز داخل التطبيق

| الشرط | وين |
|---|---|
| حذف الحساب من داخل التطبيق (Apple 5.1.1v + Google) | المزيد ← حذف حسابي وبياناتي |
| رابط حذف الحساب على الويب (Google) | `web/delete.html` ← ارفعه على `ibraprogram.netlify.app/rawsam/delete.html` |
| سياسة الخصوصية | `web/privacy.html` ← ارفعها على `ibraprogram.netlify.app/rawsam/privacy.html` |
| طلب الصلاحيات بوقتها ومع شرح | الإشعارات وعروض القرب بشاشة شرح قبل الطلب، بدون أي ضغط أو تهديد |
| الموقع بالخلفية | للـ Geofence فقط، الموقع ما يطلع من الجهاز، ويقدر يطفيه |
| إبلاغ بالمحادثة (محتوى بين المستخدمين) | قائمة ⋮ بالمحادثة ← إبلاغ |
| إيقاف إشعارات العروض | المزيد ← الإشعارات والعروض |
| Android 16 (API 36) | يبني بأحدث Flutter و SDK 37 |
| Xcode 26 / iOS 26 SDK | البناء على `macos-15` بأحدث Xcode |
| بدون تحديث ذاتي بنسخة المتاجر | نسخة `store` ما تعرض تنبيه تنزيل APK، ولا تطلب صلاحية تنصيب تطبيقات |
| مكتبات أصلية بمحاذاة 16KB (شرط Play) | تم الفحص على ملف APK: كلها 16KB أو 64KB |
| Privacy Manifest لآبل | `PrivacyInfo.xcprivacy` ينضاف تلقائياً للمشروع بالبناء |
| آيفون فقط | بدون آيباد، فما تحتاج لقطات آيباد |

## Google Play

- **الملف:** `Rawsam-*-google-play.aab` من صفحة Releases.
- **الحساب الشخصي الجديد:** اختبار مغلق بـ 12 مختبِر على الأقل لمدة 14 يوم متواصل قبل النشر.
- **Data safety:**
  - يجمع: الاسم، رقم الهاتف، الرسائل، الصور (اختياري)، معرّفات الجهاز (رمز الإشعارات).
  - ما يجمع الموقع (يُستخدم على الجهاز فقط ولا يُرسل) — جاوب «لا يُجمع» للموقع.
  - البيانات مشفّرة أثناء النقل: نعم. يقدر يطلب الحذف: نعم (من التطبيق + رابط الويب).
  - ما تُشارك مع طرف ثالث لأغراض إعلانية.
- **Background location declaration** (النص المقترح):
  > The app shows customers a special in-store discount when they pass near our beauty center. It registers a single geofence around the center using the OS geofencing API; the location never leaves the device. This feature is opt-in, explained before the permission request, and can be turned off at any time.
  - فيديو قصير (30 ثانية): افتح التطبيق ← المزيد ← الإشعارات والعروض ← «فعّل عروض القرب» ← شاشة الشرح ← اختيار «السماح طوال الوقت» ← وصول إشعار «مدام صرت قريب…».
- **Foreground service (Location):** Play يطلب تصريح لنوع الخدمة `location` (من مكتبة Geofence). بنموذج **App content ← Foreground service permissions** اختار **Location** وارفع نفس فيديو عروض القرب.
- **التصنيف العمري:** 18+ (خدمات تاتو وبيرسنك).
- **الفئة:** Beauty / الجمال.

## App Store

- **البناء:** `Rawsam-*-ios-xcode-project.zip` ← افتحه بـ Xcode على ماك أو بخدمة بناء سحابية ← Archive ← Upload.
- **Capabilities:** Push Notifications، و Background Modes → Remote notifications.
- **App Privacy:** Contact Info (Name, Phone) و User Content (Messages, Photos) و Identifiers (Device ID) — مرتبطة بالمستخدم، ما تُستخدم للتتبع.
- **ملاحظات للمراجع (Review Notes):**
  > Customers sign in anonymously; no password is needed. Enter any name and phone on first launch. Chat with the center from the "احجز" tab — a staff member replies and confirms bookings. "Nearby offers" are optional and use region monitoring around the center; location never leaves the device. Account deletion: More → حذف حسابي وبياناتي.
- **لقطات الشاشة:** 6.9 إنج (1320×2868) و 6.5 إنج — الرئيسية، أعمالنا، المحادثة، هداياي، وصّلني.

## وصف المتجر (عربي)

**الاسم:** روسم للتجميل
**الوصف المختصر:** أعمالنا وعروضنا، احجز موعدك بالمحادثة، واستلم هدايا خاصة بيك.

**الوصف:**
تطبيق مركز روسم للتجميل في الكرادة — فرحان مول.
• شوف أعمالنا: تاتو، بيرسنك، ليزر، وعناية البشرة.
• المنشورات والعروض الجديدة توصلك أول بأول بإشعار مميز.
• احجز موعدك بمحادثة مباشرة ويا المركز، ويوصلك تأكيد وتذكير قبل الموعد.
• هداياي: خصومات خاصة بيك بكود وباركود تراويه بالمركز.
• عروض القرب: من تمر قريب منا يوصلك عرض خاص (اختياري).
• وصّلني: الطريق للمركز ويا صوت توجيه لحد الباب.


---

# نسخة المركز «مواعيد المركز IBRA» والنسختين الثانيتين

| الشرط | الحالة |
|---|---|
| حذف حساب الموظف من داخل التطبيق | تطبيق الزبائن ← ⋮ ← حذف حسابي |
| `SCHEDULE_EXACT_ALARM` | تصريح بنموذج Play: «تطبيق حجوزات وتقويم يرن بموعد الحجز بالضبط» |
| `USE_FULL_SCREEN_INTENT` | تصريح: «منبه الحجز يرن بملء الشاشة لحد ما يستلمه المستخدم» (فئة Alarm). إذا رفضوه، التطبيق يشتغل بدونه بإشعار عادي |
| `READ_CONTACTS` و `RECORD_AUDIO` | تُطلب بس وقت استيراد زبون أو تسجيل صوت تنبيه، ومذكورة بسلامة البيانات |
| `CAMERA` (المركز فقط) | لمسح كوبونات الزبائن |
| آبل: تطبيق داخلي لموظفي مركز واحد | آبل ممكن تطلب نشره كـ **Unlisted App** (رابط مباشر بدون ما يطلع بالبحث). اطلبه من https://developer.apple.com/contact/request/unlisted-app/ |
| ملاحظة للمراجع (المركز) | أعطهم إيميل وكلمة سر موظف تجريبي حتى يدخلون قسم «تطبيق الزبائن» |
